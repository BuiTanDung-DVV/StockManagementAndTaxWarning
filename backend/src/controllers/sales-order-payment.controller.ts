import { Response } from 'express';
import { AuthRequest } from '../middleware/auth.middleware';
import { SalesOrderPaymentService, SalesPaymentError } from '../services/sales-order-payment.service';
const service = new SalesOrderPaymentService();
function fail(res: Response, error: unknown) {
    if (error instanceof SalesPaymentError) return res.status(error.status).json({ success: false, message: error.message });
    if (['55P03', '40001', '40P01', '23505'].includes((error as any)?.code)) return res.status(409).json({ success: false, message: 'Dữ liệu đang được xử lý. Kiểm tra lại bằng cùng mã lượt ghi nhận; không tạo lượt mới.' });
    console.error('Sales payment failed', { name: (error as any)?.name, code: (error as any)?.code });
    return res.status(500).json({ success: false, message: 'Chưa xác nhận được kết quả thu tiền. Hãy kiểm tra lượt ghi nhận trước khi thử lại.' });
}
export async function recordSalesOrderPayment(req: AuthRequest, res: Response) {
    try {
        const data = await service.record(Number(req.shopId), Number(req.params.id), { id: Number(req.user?.sub), authVersion: Number(req.user?.ver) }, req.body);
        return res.json({ success: true, data });
    } catch (error) { return fail(res, error); }
}
export async function salesOrderPaymentStatus(req: AuthRequest, res: Response) {
    try {
        const data = await service.status(Number(req.shopId), Number(req.params.id), { id: Number(req.user?.sub), authVersion: Number(req.user?.ver) }, String(req.params.operationId));
        return res.json({ success: true, data });
    } catch (error) { return fail(res, error); }
}
