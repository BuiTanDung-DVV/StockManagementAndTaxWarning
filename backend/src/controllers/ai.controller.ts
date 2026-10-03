import { Request, Response } from 'express';
import { aiService } from '../services/ai.service';
import {
  AiShopContextError,
  requireAiShopId,
} from '../ai/ai-shop-context.utils';

export const getAiShopId = (req: Request): number => {
  return requireAiShopId((req as any).shopId);
};

const aiErrorStatus = (error: unknown) => error instanceof AiShopContextError ? 400 : 500;

export const chatWithAdvisor = async (req: Request, res: Response): Promise<void> => {
  try {
    const shopId = getAiShopId(req);
    const { question, history } = req.body;

    if (!question || typeof question !== 'string' || !question.trim()) {
      res.status(400).json({ success: false, message: 'Câu hỏi không được để trống' });
      return;
    }
    if (question.trim().length > 1500) {
      res.status(400).json({ success: false, message: 'Câu hỏi không được vượt quá 1.500 ký tự' });
      return;
    }
    if (history !== undefined && !Array.isArray(history)) {
      res.status(400).json({ success: false, message: 'Lịch sử trò chuyện không hợp lệ' });
      return;
    }
    if (Array.isArray(history) && (
      history.length > 12
      || history.some(item => (
        !item
        || !['user', 'model', 'assistant'].includes(item.role)
        || typeof item.content !== 'string'
        || item.content.length > 2000
      ))
    )) {
      res.status(400).json({ success: false, message: 'Lịch sử trò chuyện không hợp lệ hoặc quá dài' });
      return;
    }

    const result = await aiService.askAdvisor(shopId, {
      question: question.trim(),
      history,
    });
    res.json({
      success: true,
      data: result,
    });
  } catch (error: any) {
    console.error('Lỗi khi gọi chatWithAdvisor controller:', error);
    res.status(aiErrorStatus(error)).json({
      success: false,
      message: error?.message || 'Lỗi hệ thống khi kết nối với Trợ lý AI',
    });
  }
};

export const getQuickInsights = async (req: Request, res: Response): Promise<void> => {
  try {
    const shopId = getAiShopId(req);
    const insights = await aiService.getQuickInsights(shopId);
    res.json({
      success: true,
      data: insights,
    });
  } catch (error: any) {
    console.error('Lỗi khi gọi getQuickInsights controller:', error);
    res.status(aiErrorStatus(error)).json({
      success: false,
      message: error?.message || 'Lỗi khi lấy thông tin phân tích nhanh',
    });
  }
};

export const getKnowledgeDocuments = async (req: Request, res: Response): Promise<void> => {
  try {
    const shopId = getAiShopId(req);
    const docs = await aiService.getKnowledgeDocs(shopId);
    res.json({
      success: true,
      data: docs,
    });
  } catch (error: any) {
    console.error('Lỗi khi lấy danh sách tài liệu tri thức:', error);
    res.status(aiErrorStatus(error)).json({
      success: false,
      message: error?.message || 'Lỗi khi truy vấn kho tài liệu tri thức',
    });
  }
};

export const createKnowledgeDocument = async (req: Request, res: Response): Promise<void> => {
  try {
    const shopId = getAiShopId(req);
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
    res.status(aiErrorStatus(error)).json({
      success: false,
      message: error?.message || 'Lỗi khi tạo tài liệu tri thức mới',
    });
  }
};

export const updateKnowledgeDocument = async (req: Request, res: Response): Promise<void> => {
  try {
    const shopId = getAiShopId(req);
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
    res.status(aiErrorStatus(error)).json({
      success: false,
      message: error?.message || 'Lỗi khi cập nhật tài liệu tri thức',
    });
  }
};

export const deleteKnowledgeDocument = async (req: Request, res: Response): Promise<void> => {
  try {
    const shopId = getAiShopId(req);
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
    res.status(aiErrorStatus(error)).json({
      success: false,
      message: error?.message || 'Lỗi khi xóa tài liệu tri thức',
    });
  }
};

export const extractContentFromUrl = async (req: Request, res: Response): Promise<void> => {
  try {
    const { url } = req.body;
    if (!url || typeof url !== 'string' || !url.trim().startsWith('http')) {
      res.status(400).json({
        success: false,
        message: 'Đường link URL không hợp lệ. Vui lòng nhập link bắt đầu bằng http:// hoặc https://',
      });
      return;
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);

    const fetchRes = await fetch(url.trim(), {
      signal: controller.signal,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
    });
    clearTimeout(timeout);

    if (!fetchRes.ok) {
      res.status(400).json({
        success: false,
        message: `Không thể tải nội dung từ đường link (Mã lỗi HTTP ${fetchRes.status})`,
      });
      return;
    }

    const html = await fetchRes.text();

    // 1. Trích xuất tiêu đề thông minh: og:title -> title -> h1
    let title = '';
    const ogTitleMatch = html.match(/<meta[^>]*property=["']og:title["'][^>]*content=["']([^"']+)["']/i) ||
      html.match(/<meta[^>]*content=["']([^"']+)["'][^>]*property=["']og:title["']/i);
    if (ogTitleMatch && ogTitleMatch[1]) {
      title = ogTitleMatch[1].trim();
    } else {
      const titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i);
      if (titleMatch && titleMatch[1]) {
        title = titleMatch[1].trim().replace(/\s+/g, ' ');
      } else {
        const h1Match = html.match(/<h1[^>]*>([^<]+)<\/h1>/i);
        if (h1Match && h1Match[1]) {
          title = h1Match[1].trim().replace(/\s+/g, ' ');
        }
      }
    }

    // 2. Ưu tiên bóc tách phần nội dung chính (article/main/content) để loại bỏ rác sidebar/quảng cáo
    let sourceHtml = html;
    const articleMatch = html.match(/<article\b[^>]*>([\s\S]*?)<\/article>/i);
    const mainMatch = html.match(/<main\b[^>]*>([\s\S]*?)<\/main>/i);
    const contentDivMatch = html.match(/<div\b[^>]*(?:class|id)=["'][^"']*(?:content|article-body|post-body|entry-content)[^"']*["'][^>]*>([\s\S]*?)<\/div>/i);

    if (articleMatch && articleMatch[1].length > 300) {
      sourceHtml = articleMatch[1];
    } else if (mainMatch && mainMatch[1].length > 300) {
      sourceHtml = mainMatch[1];
    } else if (contentDivMatch && contentDivMatch[1].length > 300) {
      sourceHtml = contentDivMatch[1];
    }

    // 3. Làm sạch HTML để lấy văn bản thuần tiếng Việt chuẩn xác
    let text = sourceHtml
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, ' ')
      .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, ' ')
      .replace(/<nav\b[^<]*(?:(?!<\/nav>)<[^<]*)*<\/nav>/gi, ' ')
      .replace(/<footer\b[^<]*(?:(?!<\/footer>)<[^<]*)*<\/footer>/gi, ' ')
      .replace(/<header\b[^<]*(?:(?!<\/header>)<[^<]*)*<\/header>/gi, ' ')
      .replace(/<aside\b[^<]*(?:(?!<\/aside>)<[^<]*)*<\/aside>/gi, ' ')
      .replace(/<form\b[^<]*(?:(?!<\/form>)<[^<]*)*<\/form>/gi, ' ')
      .replace(/<svg\b[^<]*(?:(?!<\/svg>)<[^<]*)*<\/svg>/gi, ' ')
      .replace(/<noscript\b[^<]*(?:(?!<\/noscript>)<[^<]*)*<\/noscript>/gi, ' ')
      .replace(/<[^>]+>/g, ' ')
      .replace(/&nbsp;/gi, ' ')
      .replace(/&amp;/gi, '&')
      .replace(/&quot;/gi, '"')
      .replace(/&#39;/gi, "'")
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>')
      .replace(/\s+/g, ' ')
      .trim();

    if (text.length > 12000) {
      text = text.slice(0, 12000) + '... (nội dung đã được rút gọn cho ngữ cảnh AI)';
    }

    res.json({
      success: true,
      data: {
        title: title || 'Tài liệu từ liên kết web',
        content: text,
      },
    });
  } catch (error: any) {
    console.error('Lỗi khi trích xuất URL:', error);
    res.status(500).json({
      success: false,
      message: error?.message || 'Lỗi khi trích xuất nội dung từ đường link',
    });
  }
};

