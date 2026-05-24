import { Request, Response } from 'express';

export const getTaxConfig = async (req: Request, res: Response) => {
    try {
        // Cấu hình luật thuế HKD 2026
        const config = {
            fiscalYear: 2026,
            thresholds: {
                tier1: 100000000,   // 100M: Miễn thuế
                tier2: 300000000,   // 300M: Ngưỡng cảnh báo kê khai
                tier3: 500000000,   // 500M: Ngưỡng kê khai mới 2026
                tier4: 1000000000,  // 1 Tỷ: Bắt buộc HĐĐT
            },
            taxRates: {
                wholesale_retail: {
                    vat: 0.01, // 1%
                    pit: 0.005, // 0.5%
                },
                manufacturing_transport: {
                    vat: 0.03, // 3%
                    pit: 0.015, // 1.5%
                },
                services: {
                    vat: 0.05, // 5%
                    pit: 0.02, // 2%
                },
                other: {
                    vat: 0.02, // 2%
                    pit: 0.01, // 1%
                }
            },
            currentPolicies: {
                vatReductionActive: false, // Ví dụ: Không còn giảm 20% VAT trong 2026
                vatReductionRate: 0.0, 
            }
        };

        res.json({ success: true, data: config });
    } catch (error) {
        console.error('Error fetching tax config:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch tax config' });
    }
};
