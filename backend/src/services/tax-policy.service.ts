import { AppDataSource } from '../config/db.config';
import { TaxRule } from '../finance/entities';
import { ShopProfile } from '../system/entities';
import { TaxPolicy } from '../tax/tax-policy';

type ConfigRow = { config_key: string; config_value: string };

const requiredPolicyKeys = [
    'TAX_FISCAL_YEAR',
    'TAX_EFFECTIVE_FROM',
    'TAX_EXEMPTION_THRESHOLD',
    'WARNING_REVENUE_THRESHOLD',
    'E_INVOICE_THRESHOLD',
    'TAX_POLICY_SOURCE_CODE',
    'TAX_POLICY_SOURCE_URL',
] as const;

const requiredIndustryCodes = ['BAN_LE', 'SAN_XUAT', 'DICH_VU', 'KHAC'] as const;

export class TaxPolicyConfigurationError extends Error {
    constructor(message: string) {
        super(message);
        this.name = 'TaxPolicyConfigurationError';
    }
}

const positiveNumber = (value: string | undefined, key: string): number => {
    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed <= 0) {
        throw new TaxPolicyConfigurationError(`Cấu hình ${key} trong DB không hợp lệ`);
    }
    return parsed;
};

export const DEFAULT_VERIFIED_TAX_POLICY_2026: TaxPolicy = {
    fiscalYear: 2026,
    effectiveFrom: '2026-01-01',
    taxExemptionThreshold: 1000000000,
    warningRevenueThreshold: 900000000,
    eInvoiceThreshold: 1000000000,
    sourceCode: '141/2026/NĐ-CP',
    sourceUrl: 'https://vanban.chinhphu.vn/?classid=1&docid=217960&pageid=27160&typegroupid=4',
};

const DEFAULT_VERIFIED_RULES: Record<string, { name: string; vat: number; pit: number }> = {
    BAN_LE: { name: 'Phân phối, cung cấp hàng hóa', vat: 1.0, pit: 0.5 },
    SAN_XUAT: { name: 'Sản xuất, vận tải, xây dựng có bao thầu NVL', vat: 3.0, pit: 1.5 },
    DICH_VU: { name: 'Dịch vụ, xây dựng không bao thầu NVL', vat: 5.0, pit: 2.0 },
    KHAC: { name: 'Hoạt động kinh doanh khác', vat: 2.0, pit: 1.0 },
};

export class TaxPolicyService {
    async getCurrentPolicy(): Promise<TaxPolicy> {
        try {
            const rows = await AppDataSource.query(
                `SELECT config_key, config_value
                 FROM system_configs
                 WHERE shop_id IS NULL
                   AND config_key = ANY($1::text[])`,
                [requiredPolicyKeys],
            ) as ConfigRow[];
            const values = new Map(rows.map(row => [row.config_key, row.config_value]));
            const missing = requiredPolicyKeys.filter(key => !values.get(key));
            if (missing.length > 0) {
                console.warn(`[TaxPolicyService] Thiếu cấu hình thuế trong DB: ${missing.join(', ')}. Áp dụng chính sách chuẩn 2026 đã xác minh.`);
                return DEFAULT_VERIFIED_TAX_POLICY_2026;
            }

            const fiscalYear = positiveNumber(values.get('TAX_FISCAL_YEAR'), 'TAX_FISCAL_YEAR');
            if (!Number.isInteger(fiscalYear)) {
                return DEFAULT_VERIFIED_TAX_POLICY_2026;
            }
            const effectiveFrom = String(values.get('TAX_EFFECTIVE_FROM'));
            if (!/^\d{4}-\d{2}-\d{2}$/.test(effectiveFrom)) {
                return DEFAULT_VERIFIED_TAX_POLICY_2026;
            }

            return {
                fiscalYear,
                effectiveFrom,
                taxExemptionThreshold: positiveNumber(
                    values.get('TAX_EXEMPTION_THRESHOLD'),
                    'TAX_EXEMPTION_THRESHOLD',
                ),
                warningRevenueThreshold: positiveNumber(
                    values.get('WARNING_REVENUE_THRESHOLD'),
                    'WARNING_REVENUE_THRESHOLD',
                ),
                eInvoiceThreshold: positiveNumber(
                    values.get('E_INVOICE_THRESHOLD'),
                    'E_INVOICE_THRESHOLD',
                ),
                sourceCode: String(values.get('TAX_POLICY_SOURCE_CODE')),
                sourceUrl: String(values.get('TAX_POLICY_SOURCE_URL')),
            };
        } catch (e) {
            console.warn('[TaxPolicyService] Lỗi truy vấn chính sách thuế, chuyển sang cấu hình chuẩn 2026:', e);
            return DEFAULT_VERIFIED_TAX_POLICY_2026;
        }
    }

    async getCurrentRules(referenceDate = new Date()): Promise<TaxRule[]> {
        try {
            const rows = await AppDataSource.getRepository(TaxRule)
                .createQueryBuilder('rule')
                .where('rule.effective_from <= :referenceDate', { referenceDate })
                .andWhere('(rule.effective_to IS NULL OR rule.effective_to >= :referenceDate)', {
                    referenceDate,
                })
                .orderBy('rule.effective_from', 'DESC')
                .getMany();

            const byCode = new Map<string, TaxRule>();
            for (const row of rows) {
                if (!byCode.has(row.industryCode)) byCode.set(row.industryCode, row);
            }
            return requiredIndustryCodes.map(code => {
                if (byCode.has(code)) return byCode.get(code)!;
                const def = DEFAULT_VERIFIED_RULES[code];
                return {
                    id: 0,
                    industryCode: code,
                    name: def.name,
                    vatRate: def.vat,
                    pitRate: def.pit,
                    effectiveFrom: new Date('2026-01-01'),
                    effectiveTo: null,
                    createdAt: new Date(),
                    updatedAt: new Date(),
                } as unknown as TaxRule;
            });
        } catch (e) {
            console.warn('[TaxPolicyService] Lỗi truy vấn quy tắc thuế, áp dụng quy tắc mặc định 2026:', e);
            return requiredIndustryCodes.map(code => {
                const def = DEFAULT_VERIFIED_RULES[code];
                return {
                    id: 0,
                    industryCode: code,
                    name: def.name,
                    vatRate: def.vat,
                    pitRate: def.pit,
                    effectiveFrom: new Date('2026-01-01'),
                    effectiveTo: null,
                    createdAt: new Date(),
                    updatedAt: new Date(),
                } as unknown as TaxRule;
            });
        }
    }

    async getRevenueThresholds(policy?: TaxPolicy): Promise<{
        tier1: number;
        tier2: number;
        tier3: number;
        tier4: number;
    }> {
        const currentPolicy = policy ?? await this.getCurrentPolicy();
        let tier1 = 250000000;
        let tier2 = 500000000;
        try {
            const rows = await AppDataSource.query(
                `SELECT config_key, config_value
                 FROM system_configs
                 WHERE shop_id IS NULL
                   AND config_key = ANY($1::text[])`,
                [['TAX_REVENUE_TIER_1', 'TAX_REVENUE_TIER_2']],
            ) as ConfigRow[];
            const values = new Map(rows.map(row => [row.config_key, row.config_value]));
            if (values.has('TAX_REVENUE_TIER_1')) {
                tier1 = Number(values.get('TAX_REVENUE_TIER_1')) || tier1;
            }
            if (values.has('TAX_REVENUE_TIER_2')) {
                tier2 = Number(values.get('TAX_REVENUE_TIER_2')) || tier2;
            }
        } catch {
            // keep standard defaults
        }
        return {
            tier1,
            tier2,
            tier3: currentPolicy.warningRevenueThreshold,
            tier4: currentPolicy.taxExemptionThreshold,
        };
    }

    async getShopTaxConfiguration(shopId: number) {
        const [policy, rules, shop] = await Promise.all([
            this.getCurrentPolicy(),
            this.getCurrentRules(),
            AppDataSource.getRepository(ShopProfile).findOne({ where: { shopId } }),
        ]);

        const [thresholds, policyRows] = await Promise.all([
            this.getRevenueThresholds(policy),
            AppDataSource.query(
                `SELECT config_key, config_value
                 FROM system_configs
                 WHERE shop_id IS NULL
                   AND config_key = ANY($1::text[])`,
                [['VAT_REDUCTION_ACTIVE', 'VAT_REDUCTION_RATE', 'VAT_REDUCTION_SCOPE']],
            ).catch(() => []) as Promise<ConfigRow[]>,
        ]);
        const policyValues = new Map(
            (policyRows || []).map(row => [row.config_key, row.config_value]),
        );

        const rule = (code: string) => {
            const value = rules.find(item => item.industryCode === code) ?? {
                vatRate: DEFAULT_VERIFIED_RULES[code]?.vat ?? 1.0,
                pitRate: DEFAULT_VERIFIED_RULES[code]?.pit ?? 0.5,
            };
            return {
                vat: Number(value.vatRate) / 100,
                pit: Number(value.pitRate) / 100,
            };
        };

        return {
            fiscalYear: policy.fiscalYear,
            thresholds,
            policy,
            taxRates: {
                wholesale_retail: rule('BAN_LE'),
                manufacturing_transport: rule('SAN_XUAT'),
                services: rule('DICH_VU'),
                other: rule('KHAC'),
            },
            currentPolicies: {
                vatReductionActive: policyValues.get('VAT_REDUCTION_ACTIVE') === 'true',
                vatReductionRate: Number(policyValues.get('VAT_REDUCTION_RATE')) || 0,
                vatReductionScope: policyValues.get('VAT_REDUCTION_SCOPE') || 'PRODUCT_LEVEL_NOT_SUPPORTED',
            },
            shopConfig: {
                businessSector: shop?.businessSector || 'TRADE',
                applyVatReduction: shop?.applyVatReduction || false,
                customVatRate: shop?.customVatRate != null ? Number(shop.customVatRate) : null,
                customPitRate: shop?.customPitRate != null ? Number(shop.customPitRate) : null,
            },
        };
    }
}

export const taxPolicyService = new TaxPolicyService();
