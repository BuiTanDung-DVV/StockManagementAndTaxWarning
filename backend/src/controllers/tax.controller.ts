import { Request, Response } from 'express';
import { TaxService } from '../services/tax.service';
import { Builder } from 'xml2js';

const taxService = new TaxService();

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
