import { Request, Response } from 'express';
import { aiService } from '../services/ai.service';

const getShopId = (req: Request): number => {
  const shopId = (req as any).shopId || (req as any).user?.shopId;
  if (!shopId) {
    throw new Error('Thiếu shopId trong ngữ cảnh yêu cầu');
  }
  return Number(shopId);
};

export const chatWithAdvisor = async (req: Request, res: Response): Promise<void> => {
  try {
    const shopId = getShopId(req);
    const { question, history } = req.body;

    if (!question || typeof question !== 'string' || !question.trim()) {
      res.status(400).json({ success: false, message: 'Câu hỏi không được để trống' });
      return;
    }

    const result = await aiService.askAdvisor(shopId, { question, history });
    res.json({
      success: true,
      data: result,
    });
  } catch (error: any) {
    console.error('Lỗi khi gọi chatWithAdvisor controller:', error);
    res.status(500).json({
      success: false,
      message: error?.message || 'Lỗi hệ thống khi kết nối với Trợ lý AI',
    });
  }
};

export const getQuickInsights = async (req: Request, res: Response): Promise<void> => {
  try {
    const shopId = getShopId(req);
    const insights = await aiService.getQuickInsights(shopId);
    res.json({
      success: true,
      data: insights,
    });
  } catch (error: any) {
    console.error('Lỗi khi gọi getQuickInsights controller:', error);
    res.status(500).json({
      success: false,
      message: error?.message || 'Lỗi khi lấy thông tin phân tích nhanh',
    });
  }
};

export const getKnowledgeDocuments = async (req: Request, res: Response): Promise<void> => {
  try {
    const shopId = getShopId(req);
    const docs = await aiService.getKnowledgeDocs(shopId);
    res.json({
      success: true,
      data: docs,
    });
  } catch (error: any) {
    console.error('Lỗi khi lấy danh sách tài liệu tri thức:', error);
    res.status(500).json({
      success: false,
      message: error?.message || 'Lỗi khi truy vấn kho tài liệu tri thức',
    });
  }
};

export const createKnowledgeDocument = async (req: Request, res: Response): Promise<void> => {
  try {
    const shopId = getShopId(req);
    const userId = (req as any).user?.id;
    const { title, category, content, isActive } = req.body;

    if (!title || !category || !content) {
      res.status(400).json({ success: false, message: 'Vui lòng điền đầy đủ Tiêu đề, Danh mục và Nội dung' });
      return;
    }

    const doc = await aiService.createKnowledgeDoc(shopId, { title, category, content, isActive }, userId);
    res.status(201).json({
      success: true,
      data: doc,
      message: 'Thêm tài liệu tri thức thành công',
    });
  } catch (error: any) {
    console.error('Lỗi khi tạo tài liệu tri thức:', error);
    res.status(500).json({
      success: false,
      message: error?.message || 'Lỗi khi tạo tài liệu tri thức mới',
    });
  }
};

export const updateKnowledgeDocument = async (req: Request, res: Response): Promise<void> => {
  try {
    const shopId = getShopId(req);
    const docId = Number(req.params.id);

    if (!docId || isNaN(docId)) {
      res.status(400).json({ success: false, message: 'ID tài liệu không hợp lệ' });
      return;
    }

    const updated = await aiService.updateKnowledgeDoc(shopId, docId, req.body);
    res.json({
      success: true,
      data: updated,
      message: 'Cập nhật tài liệu tri thức thành công',
    });
  } catch (error: any) {
    console.error('Lỗi khi cập nhật tài liệu tri thức:', error);
    res.status(500).json({
      success: false,
      message: error?.message || 'Lỗi khi cập nhật tài liệu tri thức',
    });
  }
};

export const deleteKnowledgeDocument = async (req: Request, res: Response): Promise<void> => {
  try {
    const shopId = getShopId(req);
    const docId = Number(req.params.id);

    if (!docId || isNaN(docId)) {
      res.status(400).json({ success: false, message: 'ID tài liệu không hợp lệ' });
      return;
    }

    const deleted = await aiService.deleteKnowledgeDoc(shopId, docId);
    if (!deleted) {
      res.status(404).json({ success: false, message: 'Không tìm thấy tài liệu cần xóa' });
      return;
    }

    res.json({
      success: true,
      message: 'Xóa tài liệu tri thức thành công',
    });
  } catch (error: any) {
    console.error('Lỗi khi xóa tài liệu tri thức:', error);
    res.status(500).json({
      success: false,
      message: error?.message || 'Lỗi khi xóa tài liệu tri thức',
    });
  }
};
