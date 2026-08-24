import { AppDataSource } from '../config/db.config';
import { ShopProfile } from '../system/entities';
import {
    normalizeNonNegative,
    normalizeTaxCode,
} from '../tax/tax-policy';
import { resolveCurrentMonthExpensePeriod } from '../finance/finance-period.utils';
import { taxPolicyService } from './tax-policy.service';
import { SalesService } from './sales.service';

export class TaxService {
    private salesService = new SalesService();

    async getRevenueBasis(shopId: number, from: string, to: string) {
        const summary = await this.salesService.summary(shopId, from, to);
        return normalizeNonNegative(Number(summary.totalRevenue));
    }

    async getTaxReportData(shopId: number, period: string, year: string) {
        // period: "01", "02", ... or "Q1", "Q2"
        let from: string;
        let to: string;

        const y = parseInt(year);
        if (period.startsWith('Q')) {
            const q = parseInt(period.replace('Q', ''));
            const startMonth = (q - 1) * 3 + 1;
            const endMonth = q * 3;
            const endDay = new Date(Date.UTC(y, endMonth, 0)).getUTCDate();
            from = `${y}-${String(startMonth).padStart(2, '0')}-01`;
            to = `${y}-${String(endMonth).padStart(2, '0')}-${String(endDay).padStart(2, '0')}`;
        } else {
            const m = parseInt(period);
            const endDay = new Date(Date.UTC(y, m, 0)).getUTCDate();
            from = `${y}-${String(m).padStart(2, '0')}-01`;
            to = `${y}-${String(m).padStart(2, '0')}-${String(endDay).padStart(2, '0')}`;
        }
        const { fromDate: startDate } =
            resolveCurrentMonthExpensePeriod(from, to);

        const shopRepo = AppDataSource.getRepository(ShopProfile);
        const shop = await shopRepo.findOne({ where: { shopId: shopId } });
        const shopName = shop?.shopName || 'Hộ kinh doanh';
        const taxCode = normalizeTaxCode(shop?.taxCode);

        // Determine industry code from shop sector
        let industryCode = 'BAN_LE';
        if (shop?.businessSector === 'SERVICE') industryCode = 'DICH_VU';
        if (shop?.businessSector === 'PRODUCTION') industryCode = 'SAN_XUAT';
        if (shop?.businessSector === 'OTHER') industryCode = 'KHAC';

        const [policy, activeRules, totalRevenue] = await Promise.all([
            taxPolicyService.getCurrentPolicy(),
            taxPolicyService.getCurrentRules(startDate),
            this.getRevenueBasis(shopId, from, to),
        ]);
        const activeRule = activeRules.find(rule => rule.industryCode === industryCode);
        if (!activeRule) {
            throw new Error(`Thiếu tỷ lệ thuế cho nhóm ngành ${industryCode}`);
        }

        let vatRate = Number(activeRule.vatRate);
        let pitRate = Number(activeRule.pitRate);

        // Override with shop's custom rates if they exist
        if (shop?.customVatRate != null) {
            vatRate = Number(shop.customVatRate);
        }

        if (shop?.customPitRate != null) {
            pitRate = Number(shop.customPitRate);
        }
        vatRate = Math.min(100, normalizeNonNegative(vatRate));
        pitRate = Math.min(100, normalizeNonNegative(pitRate));

        const yearlyRevenue = await this.getRevenueBasis(
            shopId,
            `${y}-01-01`,
            `${y}-12-31`,
        );

        const { taxExemptionThreshold, warningRevenueThreshold } = policy;
        const taxExempt = yearlyRevenue <= taxExemptionThreshold;

        const vatOwed = taxExempt
            ? 0
            : normalizeNonNegative(totalRevenue * (vatRate / 100));
        const pitOwed = taxExempt
            ? 0
            : normalizeNonNegative(totalRevenue * (pitRate / 100));

        return {
            shopName,
            taxCode,
            totalRevenue,
            vatOwed,
            pitOwed,
            yearlyRevenue,
            taxExempt,
            policy,
            warning: yearlyRevenue > warningRevenueThreshold && yearlyRevenue <= taxExemptionThreshold
                ? `Doanh thu năm của bạn đạt trên ${warningRevenueThreshold.toLocaleString('vi-VN')} đồng, sắp chạm ngưỡng chịu thuế ${taxExemptionThreshold.toLocaleString('vi-VN')} đồng.`
                : undefined
        };
    }
}
