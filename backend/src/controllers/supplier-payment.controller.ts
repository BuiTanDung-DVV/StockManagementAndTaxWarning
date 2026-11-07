import { Response } from 'express';
import { AuthRequest } from '../middleware/auth.middleware';
import { SupplierPaymentError, SupplierPaymentService } from '../services/supplier-payment.service';

const service = new SupplierPaymentService();
function fail(res: Response, error: unknown) {
    if (error instanceof SupplierPaymentError) return res.status(error.status).json({ success: false, message: error.message });
    if (['55P03', '40001', '40P01', '23505'].includes((error as any)?.code)) {
        return res.status(409).json({ success: false, message: 'Dữ liệu đang được xử lý. Kiểm tra lại bằng cùng mã lượt ghi nhận; không tạo lượt mới.' });
    }
    console.error('Supplier payment failed', { name: (error as any)?.name, code: (error as any)?.code });
    return res.status(500).json({ success: false, message: 'Chưa thể xác nhận kết quả. Hãy kiểm tra lại lượt ghi nhận trước khi thử lại.' });
}
export async function recordSupplierPayment(req: AuthRequest, res: Response) {
    try {
        const data = await service.record(Number(req.shopId), Number(req.params.payableId),
            { id: Number(req.user?.sub), authVersion: Number(req.user?.ver) }, req.body);
        return res.json({ success: true, data });
    } catch (error) { return fail(res, error); }
}
export async function supplierPaymentStatus(req: AuthRequest, res: Response) {
    try {
        const data = await service.status(Number(req.shopId), { id: Number(req.user?.sub), authVersion: Number(req.user?.ver) }, String(req.params.operationId));
        return res.json({ success: true, data });
    } catch (error) { return fail(res, error); }
}
