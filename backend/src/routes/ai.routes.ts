import { Router } from 'express';
import * as aiCtrl from '../controllers/ai.controller';
import { requirePermission } from '../middleware/permission.middleware';

const router = Router();

// Route tương tác chat với Trợ lý AI
router.post('/chat', aiCtrl.chatWithAdvisor);

// Route lấy gợi ý phân tích nhanh (Quick Insights)
router.get('/insights', aiCtrl.getQuickInsights);

// Routes quản lý kho tài liệu tri thức (AI Knowledge Documents)
router.get(
    '/knowledge',
    requirePermission('settings', 'view'),
    aiCtrl.getKnowledgeDocuments,
);
router.post(
    '/knowledge',
    requirePermission('settings', 'edit'),
    aiCtrl.createKnowledgeDocument,
);
router.put(
    '/knowledge/:id',
    requirePermission('settings', 'edit'),
    aiCtrl.updateKnowledgeDocument,
);
router.delete(
    '/knowledge/:id',
    requirePermission('settings', 'edit'),
    aiCtrl.deleteKnowledgeDocument,
);

export default router;
