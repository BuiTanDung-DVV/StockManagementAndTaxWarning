import { Router } from 'express';

const router = Router();
// Reject old cached clients too. Do not drain an existing device outbox.
router.post('/sync/operations', (_req, res) => {
    return res.status(410).json({
        success: false,
        code: 'OFFLINE_DISABLED',
        message: 'Ghi chép offline đã ngừng hỗ trợ. Vui lòng kết nối mạng và kiểm tra chứng từ trước khi ghi trực tuyến.',
    });
});
export default router;
