import { AppDataSource } from '../config/db.config';
import { SalesOrder, SalesReturn } from '../sales/entities';
import { TaxRule } from '../finance/entities';
import { Between, In, Not } from 'typeorm';
import { ShopProfile } from '../system/entities';
import {
    CURRENT_TAX_POLICY,
    normalizeNonNegative,
    normalizeTaxCode,
} from '../tax/tax-policy';
import { resolveCurrentMonthExpensePeriod } from '../finance/finance-period.utils';

export class TaxService {
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
        const { fromDate: startDate, toDate: endDate } =
            resolveCurrentMonthExpensePeriod(from, to);

        const shopRepo = AppDataSource.getRepository(ShopProfile);
        const shop = await shopRepo.findOne({ where: { shopId: shopId } });
        const shopName = shop?.shopName || 'Hộ kinh doanh';
        const taxCode = normalizeTaxCode(shop?.taxCode);

        const orderRepo = AppDataSource.getRepository(SalesOrder);
        const orders = await orderRepo.find({
            where: {
                shopId,
                status: Not(In(['CANCELLED', 'REJECTED'])),
                orderDate: Between(startDate, endDate)
            }
        });
        const returnRepo = AppDataSource.getRepository(SalesReturn);
        const returns = await returnRepo.find({
            where: {
                shopId,
                status: Not(In(['CANCELLED', 'REJECTED'])),
                returnDate: Between(startDate, endDate),
            },
            relations: ['order'],
        });

        const totalRevenue = normalizeNonNegative(
            orders.reduce(
                (sum, order) =>
                    sum + normalizeNonNegative(Number(order.totalAmount)),
                0,
            ) - returns.reduce(
                (sum, salesReturn) =>
                    sum + normalizeNonNegative(Number(
                        salesReturn.order?.totalAmount ?? salesReturn.refundAmount,
                    )),
                0,
            ),
        );

        // Determine industry code from shop sector
        let industryCode = 'BAN_LE';
        if (shop?.businessSector === 'SERVICE') industryCode = 'DICH_VU';
        if (shop?.businessSector === 'PRODUCTION') industryCode = 'SAN_XUAT';

        // Fetch tax rules
        const ruleRepo = AppDataSource.getRepository(TaxRule);
        const activeRule = await ruleRepo.findOne({
            where: { industryCode } 
        });

        let vatRate = activeRule ? Number(activeRule.vatRate) : 1.0; // 1% default
        let pitRate = activeRule ? Number(activeRule.pitRate) : 0.5; // 0.5% default

        // Override with shop's custom rates if they exist
        if (shop?.customVatRate != null) {
            vatRate = Number(shop.customVatRate);
        }

        if (shop?.customPitRate != null) {
            pitRate = Number(shop.customPitRate);
        }
        vatRate = Math.min(100, normalizeNonNegative(vatRate));
        pitRate = Math.min(100, normalizeNonNegative(pitRate));

        const { fromDate: yearStartDate, toDate: yearEndDate } =
            resolveCurrentMonthExpensePeriod(`${y}-01-01`, `${y}-12-31`);
        const yearlyOrders = await orderRepo.find({
            where: {
                shopId,
                status: Not(In(['CANCELLED', 'REJECTED'])),
                orderDate: Between(yearStartDate, yearEndDate)
            }
        });
        const yearlyReturns = await returnRepo.find({
            where: {
                shopId,
                status: Not(In(['CANCELLED', 'REJECTED'])),
                returnDate: Between(yearStartDate, yearEndDate),
            },
            relations: ['order'],
        });
        const yearlyRevenue = normalizeNonNegative(
            yearlyOrders.reduce(
                (sum, order) =>
                    sum + normalizeNonNegative(Number(order.totalAmount)),
                0,
            ) - yearlyReturns.reduce(
                (sum, salesReturn) =>
                    sum + normalizeNonNegative(Number(
                        salesReturn.order?.totalAmount ?? salesReturn.refundAmount,
                    )),
                0,
            ),
        );

        const {
            taxExemptionThreshold,
            warningRevenueThreshold,
        } = CURRENT_TAX_POLICY;
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
            policy: CURRENT_TAX_POLICY,
            warning: yearlyRevenue > warningRevenueThreshold && yearlyRevenue <= taxExemptionThreshold
                ? `Doanh thu năm của bạn đạt trên ${warningRevenueThreshold.toLocaleString('vi-VN')} đồng, sắp chạm ngưỡng chịu thuế ${taxExemptionThreshold.toLocaleString('vi-VN')} đồng.`
                : undefined
        };
    }
}
