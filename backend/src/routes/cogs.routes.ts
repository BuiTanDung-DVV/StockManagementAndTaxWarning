import { Router, Request, Response } from 'express';
import { COGSService } from '../services/cogs.service';

const router = Router();
const svc = new COGSService();

// GET /api/cogs/method — Phương pháp tính giá vốn hiện tại
router.get('/method', async (_: Request, res: Response) => {
    try {
        const method = await svc.getCostingMethod();
        res.json({ success: true, data: { method } });
    } catch (e: any) {
        res.status(400).json({ success: false, message: e.message });
    }
});

// GET /api/cogs/avg-cost/:productId — Giá bình quân gia quyền
router.get('/avg-cost/:productId', async (req: Request, res: Response) => {
    try {
        const cost = await svc.getWeightedAvgCost(Number(req.params.productId));
        res.json({ success: true, data: { avgCost: cost } });
    } catch (e: any) {
        res.status(400).json({ success: false, message: e.message });
    }
});

// GET /api/cogs/valuation — Giá trị tồn kho
router.get('/valuation', async (req: Request, res: Response) => {
    try {
        const productId = req.query.productId ? Number(req.query.productId) : undefined;
        const data = await svc.getInventoryValuation(productId);
        res.json({ success: true, data });
    } catch (e: any) {
        res.status(400).json({ success: false, message: e.message });
    }
});

// GET /api/cogs/lots/:productId — Danh sách lô tồn kho
router.get('/lots/:productId', async (req: Request, res: Response) => {
    try {
        const lots = await svc.getLotsByProduct(Number(req.params.productId));
        res.json({ success: true, data: lots });
    } catch (e: any) {
        res.status(400).json({ success: false, message: e.message });
    }
});

// POST /api/cogs/lots — Thêm lô tồn kho thủ công
router.post('/lots', async (req: Request, res: Response) => {
    try {
        const lot = await svc.addInventoryLot(req.body);
        res.json({ success: true, data: lot, message: 'Thêm lô tồn kho thành công' });
    } catch (e: any) {
        res.status(400).json({ success: false, message: e.message });
    }
});

export default router;
