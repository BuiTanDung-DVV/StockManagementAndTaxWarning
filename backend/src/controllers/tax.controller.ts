import { Request, Response } from 'express';
import { TaxService } from '../services/tax.service';
import { Builder } from 'xml2js';
import { AppDataSource } from '../config/db.config';
import { ShopProfile } from '../system/entities';
import {
    CURRENT_TAX_POLICY,
    requireValidTaxCode,
    TaxValidationError,
    validateTaxPeriod,
} from '../tax/tax-policy';

const taxService = new TaxService();

export const getConfig = async (req: Request, res: Response) => {
    try {
        const shopId = (req as any).shopId;
        const shopRepo = AppDataSource.getRepository(ShopProfile);
        const shop = await shopRepo.findOne({ where: { shopId } });
        
        res.json({
            success: true,
            data: {
                thresholds: {
                    tier1: 250000000,
                    tier2: 500000000,
                    tier3: CURRENT_TAX_POLICY.warningRevenueThreshold,
                    tier4: CURRENT_TAX_POLICY.taxExemptionThreshold,
                },
                policy: CURRENT_TAX_POLICY,
                currentPolicies: {
                    vatReductionActive: false,
                    vatReductionScope: 'PRODUCT_LEVEL_NOT_SUPPORTED',
                },
                shopConfig: {
                    businessSector: shop?.businessSector || 'TRADE',
                    applyVatReduction: false,
                }
            }
        });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

export const updateConfig = async (req: Request, res: Response) => {
    try {
        const shopId = (req as any).shopId;
        const { businessSector } = req.body;
        
        const shopRepo = AppDataSource.getRepository(ShopProfile);
        let shop = await shopRepo.findOne({ where: { shopId } });
        
        if (shop) {
            if (businessSector !== undefined) shop.businessSector = businessSector;
            await shopRepo.save(shop);
        }
        
        res.json({ success: true, message: 'Cập nhật cấu hình thuế thành công' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

export const exportToHTKK = async (req: Request, res: Response) => {
    try {
        const shopId = (req as any).shopId;
        const period = req.query.period as string || '01';
        const year = req.query.year as string || new Date().getFullYear().toString();
        validateTaxPeriod(period, year);

        const reportData = await taxService.getTaxReportData(shopId, period, year);
        const taxCode = requireValidTaxCode(reportData.taxCode);

        // Build cấu trúc XML theo chuẩn XSD của Tổng cục Thuế mẫu 01/CNKD
        const xmlObject = {
            HSoKhaiThue: {
                $: {
                    xmlns: "http://kekhaithue.gdt.gov.vn/TKhaiThue",
                    "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance"
                },
                TTinChung: {
                    MaHSo: "01/CNKD",
                    TenHSo: "Tờ khai thuế đối với cá nhân kinh doanh",
                    NguoiNopThue: reportData.shopName,
                    MST: taxCode,
                    KyTinhThue: period
                },
                CtietTKhai: {
                    DoanhThuTinhThue: reportData.totalRevenue,
                    ThueGTGTPHaiNop: reportData.vatOwed,
                    ThueTNCNPHaiNop: reportData.pitOwed
                }
            }
        };

        const builder = new Builder({ xmldec: { version: '1.0', encoding: 'UTF-8' } });
        const xml = builder.buildObject(xmlObject);

        res.setHeader('Content-Type', 'text/xml');
        res.setHeader('Content-Disposition', `attachment; filename=01_CNKD_${period}_${year}.xml`);
        res.send(xml);
    } catch (e: any) {
        const status = e instanceof TaxValidationError ? 422 : 500;
        res.status(status).json({ success: false, message: e.message });
    }
};

export const getTaxEstimate = async (req: Request, res: Response) => {
    try {
        const shopId = (req as any).shopId;
        const period = req.query.period as string || '01';
        const year = req.query.year as string || new Date().getFullYear().toString();
        validateTaxPeriod(period, year);

        const reportData = await taxService.getTaxReportData(shopId, period, year);
        res.json({ success: true, data: reportData });
    } catch (e: any) {
        const status = e instanceof TaxValidationError ? 422 : 500;
        res.status(status).json({ success: false, message: e.message });
    }
};
