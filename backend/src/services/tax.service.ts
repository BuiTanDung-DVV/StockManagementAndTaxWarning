import { AppDataSource } from '../config/db.config';
import { SalesOrder } from '../sales/entities';
import { TaxRule } from '../finance/entities';
import { Between } from 'typeorm';
import { ShopProfile } from '../system/entities';

export class TaxService {
    async getTaxReportData(shopId: number, period: string, year: string) {
        // period: "01", "02", ... or "Q1", "Q2"
        let startDate: Date;
        let endDate: Date;

        const y = parseInt(year);
        if (period.startsWith('Q')) {
            const q = parseInt(period.replace('Q', ''));
            startDate = new Date(y, (q - 1) * 3, 1);
            endDate = new Date(y, q * 3, 0, 23, 59, 59);
        } else {
            const m = parseInt(period);
            startDate = new Date(y, m - 1, 1);
            endDate = new Date(y, m, 0, 23, 59, 59);
        }

        const shopRepo = AppDataSource.getRepository(ShopProfile);
        const shop = await shopRepo.findOne({ where: { shopId: shopId } });
        const shopName = shop?.shopName || 'Hộ kinh doanh';
        const taxCode = shop?.taxCode || '0123456789'; // Dummy tax code if not available

        const orderRepo = AppDataSource.getRepository(SalesOrder);
        const orders = await orderRepo.find({
            where: {
                shopId,
                status: 'COMPLETED',
                orderDate: Between(startDate, endDate)
            }
        });

        const totalRevenue = orders.reduce((sum, order) => sum + Number(order.totalAmount), 0);

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
        } else if (shop?.applyVatReduction) {
            // Apply 20% reduction to the VAT rate based on current policy
            vatRate = vatRate * 0.8;
        }

        if (shop?.customPitRate != null) {
            pitRate = Number(shop.customPitRate);
        }

        const yearStartDate = new Date(y, 0, 1);
        const yearEndDate = new Date(y, 11, 31, 23, 59, 59);
        const yearlyOrders = await orderRepo.find({
            where: {
                shopId,
                status: 'COMPLETED',
                orderDate: Between(yearStartDate, yearEndDate)
            }
        });
        const yearlyRevenue = yearlyOrders.reduce((sum, order) => sum + Number(order.totalAmount), 0);
        const taxExempt = yearlyRevenue <= 100000000;

        const vatOwed = taxExempt ? 0 : totalRevenue * (vatRate / 100);
        const pitOwed = taxExempt ? 0 : totalRevenue * (pitRate / 100);

        return {
            shopName,
            taxCode,
            totalRevenue,
            vatOwed,
            pitOwed,
            yearlyRevenue,
            taxExempt,
            warning: yearlyRevenue > 90000000 && yearlyRevenue <= 100000000
                ? 'Doanh thu năm của bạn đạt trên 90 triệu đồng, sắp chạm ngưỡng chịu thuế 100 triệu đồng.'
                : undefined
        };
    }
}
