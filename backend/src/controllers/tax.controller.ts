import { Request, Response } from 'express';
import { TaxService } from '../services/tax.service';
import { Builder } from 'xml2js';
import { AppDataSource } from '../config/db.config';
import { ShopProfile } from '../system/entities';

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
                    tier1: 100000000,
                    tier2: 300000000,
                    tier3: 500000000,
                    tier4: 1000000000,
                },
                currentPolicies: {
                    vatReductionActive: shop?.applyVatReduction || false
                },
                shopConfig: {
                    businessSector: shop?.businessSector || 'TRADE',
                    applyVatReduction: shop?.applyVatReduction || false
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
        const { businessSector, applyVatReduction } = req.body;
        
        const shopRepo = AppDataSource.getRepository(ShopProfile);
        let shop = await shopRepo.findOne({ where: { shopId } });
        
        if (shop) {
            if (businessSector !== undefined) shop.businessSector = businessSector;
            if (applyVatReduction !== undefined) shop.applyVatReduction = applyVatReduction;
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

        const reportData = await taxService.getTaxReportData(shopId, period, year);

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
                    MST: reportData.taxCode,
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
        res.status(500).json({ success: false, message: e.message });
    }
};

export const getTaxEstimate = async (req: Request, res: Response) => {
    try {
        const shopId = (req as any).shopId;
        const period = req.query.period as string || '01';
        const year = req.query.year as string || new Date().getFullYear().toString();

        const reportData = await taxService.getTaxReportData(shopId, period, year);
        res.json({ success: true, data: reportData });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};
