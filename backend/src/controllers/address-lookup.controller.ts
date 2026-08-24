import { Request, Response } from 'express';
import { addressLookupService } from '../services/address-lookup.service';

export const searchAddresses = async (req: Request, res: Response) => {
    try {
        const query = String(req.query.q ?? '').trim();
        if (query.length < 3 || query.length > 200) {
            return res.status(400).json({
                success: false,
                message: 'Địa chỉ tìm kiếm phải có từ 3 đến 200 ký tự',
            });
        }
        const data = await addressLookupService.searchVietnameseAddresses(query);
        return res.json({ success: true, data });
    } catch (error) {
        console.error('Address lookup failed:', error);
        return res.status(502).json({
            success: false,
            message: error instanceof Error
                ? error.message
                : 'Không thể tra cứu địa chỉ',
        });
    }
};
