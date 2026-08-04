import { Router } from 'express';
import * as aiCtrl from '../controllers/ai.controller';

const router = Router();

// Route tương tác chat với Trợ lý AI
router.post('/chat', aiCtrl.chatWithAdvisor);

// Route lấy gợi ý phân tích nhanh (Quick Insights)
router.get('/insights', aiCtrl.getQuickInsights);

// Routes quản lý kho tài liệu tri thức (AI Knowledge Documents)
router.get('/knowledge', aiCtrl.getKnowledgeDocuments);
router.post('/knowledge', aiCtrl.createKnowledgeDocument);
router.put('/knowledge/:id', aiCtrl.updateKnowledgeDocument);
router.delete('/knowledge/:id', aiCtrl.deleteKnowledgeDocument);

export default router;
