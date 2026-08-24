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

export class TaxPolicyService {
    async getCurrentPolicy(): Promise<TaxPolicy> {
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
            throw new TaxPolicyConfigurationError(
                `Thiếu cấu hình thuế trong DB: ${missing.join(', ')}`,
            );
        }

        const fiscalYear = positiveNumber(values.get('TAX_FISCAL_YEAR'), 'TAX_FISCAL_YEAR');
        if (!Number.isInteger(fiscalYear)) {
            throw new TaxPolicyConfigurationError('TAX_FISCAL_YEAR phải là số nguyên');
        }
        const effectiveFrom = String(values.get('TAX_EFFECTIVE_FROM'));
        if (!/^\d{4}-\d{2}-\d{2}$/.test(effectiveFrom)) {
            throw new TaxPolicyConfigurationError('TAX_EFFECTIVE_FROM không đúng định dạng YYYY-MM-DD');
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
    }

    async getCurrentRules(referenceDate = new Date()): Promise<TaxRule[]> {
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
        const missing = requiredIndustryCodes.filter(code => !byCode.has(code));
        if (missing.length > 0) {
            throw new TaxPolicyConfigurationError(
                `Thiếu tỷ lệ thuế đang hiệu lực trong DB: ${missing.join(', ')}`,
            );
        }
        return requiredIndustryCodes.map(code => byCode.get(code)!);
    }

    async getRevenueThresholds(policy?: TaxPolicy): Promise<{
        tier1: number;
        tier2: number;
        tier3: number;
        tier4: number;
    }> {
        const currentPolicy = policy ?? await this.getCurrentPolicy();
        const rows = await AppDataSource.query(
            `SELECT config_key, config_value
             FROM system_configs
             WHERE shop_id IS NULL
               AND config_key = ANY($1::text[])`,
            [['TAX_REVENUE_TIER_1', 'TAX_REVENUE_TIER_2']],
        ) as ConfigRow[];
        const values = new Map(rows.map(row => [row.config_key, row.config_value]));
        return {
            tier1: positiveNumber(values.get('TAX_REVENUE_TIER_1'), 'TAX_REVENUE_TIER_1'),
            tier2: positiveNumber(values.get('TAX_REVENUE_TIER_2'), 'TAX_REVENUE_TIER_2'),
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
        if (!shop) {
            throw new TaxPolicyConfigurationError('Không tìm thấy hồ sơ cửa hàng trong DB');
        }
        const [thresholds, policyRows] = await Promise.all([
            this.getRevenueThresholds(policy),
            AppDataSource.query(
                `SELECT config_key, config_value
                 FROM system_configs
                 WHERE shop_id IS NULL
                   AND config_key = ANY($1::text[])`,
                [['VAT_REDUCTION_ACTIVE', 'VAT_REDUCTION_RATE', 'VAT_REDUCTION_SCOPE']],
            ) as Promise<ConfigRow[]>,
        ]);
        const policyValues = new Map(
            policyRows.map(row => [row.config_key, row.config_value]),
        );
        const missing = ['VAT_REDUCTION_ACTIVE', 'VAT_REDUCTION_RATE', 'VAT_REDUCTION_SCOPE']
            .filter(key => policyValues.get(key) == null);
        if (missing.length > 0) {
            throw new TaxPolicyConfigurationError(
                `Thiếu cấu hình chính sách GTGT trong DB: ${missing.join(', ')}`,
            );
        }
        const rule = (code: string) => {
            const value = rules.find(item => item.industryCode === code)!;
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
                vatReductionRate: Number(policyValues.get('VAT_REDUCTION_RATE')),
                vatReductionScope: policyValues.get('VAT_REDUCTION_SCOPE'),
            },
            shopConfig: {
                businessSector: shop.businessSector,
                applyVatReduction: shop.applyVatReduction,
                customVatRate: shop.customVatRate,
                customPitRate: shop.customPitRate,
            },
        };
    }
}

export const taxPolicyService = new TaxPolicyService();
