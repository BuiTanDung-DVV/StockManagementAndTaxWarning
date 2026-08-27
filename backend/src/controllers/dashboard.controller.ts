import { Response } from 'express';
import { AuthRequest } from '../middleware/auth.middleware';
import { DashboardService } from '../services/dashboard.service';

const dashboardService = new DashboardService();

export const getActionItems = async (req: AuthRequest, res: Response) => {
    try {
        const userId = Number(req.user?.sub);
        const scope = req.isAllShops ? req.shopIds : req.shopId;
        if (!Number.isSafeInteger(userId) || !scope || (Array.isArray(scope) && !scope.length)) {
            return res.status(400).json({
                success: false,
                message: 'Phạm vi Dashboard không hợp lệ',
            });
        }
        const data = await dashboardService.getActionItems(userId, scope);
        return res.json({ success: true, data });
    } catch (error) {
        console.error('Dashboard action-items error:', error);
        return res.status(500).json({
            success: false,
            message: 'Không thể tải danh sách việc cần làm',
        });
    }
};

