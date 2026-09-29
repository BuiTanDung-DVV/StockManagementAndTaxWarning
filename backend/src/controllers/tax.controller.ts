import { Request, Response } from 'express';
import { TaxService } from '../services/tax.service';
import { Builder } from 'xml2js';
import { AppDataSource } from '../config/db.config';
import { ShopProfile } from '../system/entities';
import {
    requireValidTaxCode,
    TaxValidationError,
    validateTaxPeriod,
} from '../tax/tax-policy';
import {
    taxPolicyService,
    TaxPolicyConfigurationError,
} from '../services/tax-policy.service';

const taxService = new TaxService();
const taxConfigurationMessage =
    'Chức năng thuế chưa sẵn sàng. Vui lòng hoàn tất cấu hình thuế hoặc thử lại sau.';

export const getConfig = async (req: Request, res: Response) => {
    try {
        const shopId = (req as any).shopId;
        const config = await taxPolicyService.getShopTaxConfiguration(shopId);
        res.json({
            success: true,
            data: config,
        });
    } catch (e: any) {
        console.error('Error fetching tax configuration:', e);
        res.status(e instanceof TaxPolicyConfigurationError ? 503 : 500)
            .json({
                success: false,
                message: e instanceof TaxPolicyConfigurationError
                    ? taxConfigurationMessage
                    : 'Không thể tải cấu hình thuế. Vui lòng thử lại.',
            });
    }
};

export const updateConfig = async (req: Request, res: Response) => {
    try {
        const shopId = (req as any).shopId;
        const { businessSector, customVatRate, customPitRate } = req.body;

        if (customVatRate !== undefined && customVatRate !== null && customVatRate !== '') {
            const vat = Number(customVatRate);
            if (!Number.isFinite(vat) || vat < 0 || vat > 100) {
                return res.status(400).json({
                    success: false,
                    message: 'Thuế suất GTGT tùy chỉnh phải từ 0% đến 100%',
                });
            }
        }

        if (customPitRate !== undefined && customPitRate !== null && customPitRate !== '') {
            const pit = Number(customPitRate);
            if (!Number.isFinite(pit) || pit < 0 || pit > 100) {
                return res.status(400).json({
                    success: false,
                    message: 'Thuế suất TNCN tùy chỉnh phải từ 0% đến 100%',
                });
            }
        }
        
        const shopRepo = AppDataSource.getRepository(ShopProfile);
        const shop = await shopRepo.findOne({ where: { shopId } });
        
        if (shop) {
            if (businessSector !== undefined) shop.businessSector = businessSector;
            if (customVatRate !== undefined) {
                shop.customVatRate = (customVatRate === null || customVatRate === '') ? (null as any) : Number(customVatRate);
            }
            if (customPitRate !== undefined) {
                shop.customPitRate = (customPitRate === null || customPitRate === '') ? (null as any) : Number(customPitRate);
            }
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
        const policy = await taxPolicyService.getCurrentPolicy();
        validateTaxPeriod(period, year, policy.fiscalYear);

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
        const policy = await taxPolicyService.getCurrentPolicy();
        validateTaxPeriod(period, year, policy.fiscalYear);

        const reportData = await taxService.getTaxReportData(shopId, period, year);
        res.json({ success: true, data: reportData });
    } catch (e: any) {
        const status = e instanceof TaxValidationError ? 422 : 500;
        res.status(status).json({ success: false, message: e.message });
    }
};
