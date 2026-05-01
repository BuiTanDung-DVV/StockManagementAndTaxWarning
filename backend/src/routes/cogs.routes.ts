import { Router, Request, Response } from 'express';
import { COGSService } from '../services/cogs.service';
import { AuthRequest } from '../middleware/auth.middleware';

const router = Router();
const svc = new COGSService();

// GET /api/cogs/method — Phương pháp tính giá vốn hiện tại
router.get('/method', async (req: Request, res: Response) => {
    try {
        const shopId = (req as AuthRequest).shopId;
        const method = await svc.getCostingMethod(shopId);
        res.json({ success: true, data: { method } });
    } catch (e: any) {
        res.status(400).json({ success: false, message: e.message });
    }
});

// GET /api/cogs/avg-cost/:productId — Giá bình quân gia quyền
router.get('/avg-cost/:productId', async (req: Request, res: Response) => {
    try {
        const shopId = (req as AuthRequest).shopId;
        const cost = await svc.getWeightedAvgCost(Number(req.params.productId), shopId);
        res.json({ success: true, data: { avgCost: cost } });
    } catch (e: any) {
        res.status(400).json({ success: false, message: e.message });
    }
});

// GET /api/cogs/valuation — Giá trị tồn kho
router.get('/valuation', async (req: Request, res: Response) => {
    try {
        const shopId = (req as AuthRequest).shopId;
        const productId = req.query.productId ? Number(req.query.productId) : undefined;
        const data = await svc.getInventoryValuation(productId, shopId);
        res.json({ success: true, data });
    } catch (e: any) {
        res.status(400).json({ success: false, message: e.message });
    }
});

// GET /api/cogs/lots/:productId — Danh sách lô tồn kho
router.get('/lots/:productId', async (req: Request, res: Response) => {
    try {
        const shopId = (req as AuthRequest).shopId;
        const lots = await svc.getLotsByProduct(Number(req.params.productId), shopId);
        res.json({ success: true, data: lots });
    } catch (e: any) {
        res.status(400).json({ success: false, message: e.message });
    }
});

// POST /api/cogs/lots — Thêm lô tồn kho thủ công
router.post('/lots', async (req: Request, res: Response) => {
    try {
        const shopId = (req as AuthRequest).shopId;
        const lot = await svc.addInventoryLot({ ...req.body, shopId });
        res.json({ success: true, data: lot, message: 'Thêm lô tồn kho thành công' });
    } catch (e: any) {
        res.status(400).json({ success: false, message: e.message });
    }
});

export default router;

