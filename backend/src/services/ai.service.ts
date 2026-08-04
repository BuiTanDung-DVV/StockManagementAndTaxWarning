import { GoogleGenerativeAI } from '@google/generative-ai';
import { AppDataSource } from '../config/db.config';
import { config } from '../config/env.config';
import { AiKnowledgeDocument } from '../system/entities';

export interface ChatMessage {
  role: 'user' | 'model' | 'assistant';
  content: string;
}

export interface ChatRequestDto {
  question: string;
  history?: ChatMessage[];
}

export interface CreateKnowledgeDto {
  title: string;
  category: string;
  content: string;
  isActive?: boolean;
}

export class AiService {
  private knowledgeRepo = AppDataSource.getRepository(AiKnowledgeDocument);

  /**
   * Tổng hợp dữ liệu thực tế từ cơ sở dữ liệu của cửa hàng (Store Snapshot)
   */
  private async getStoreContext(shopId: number): Promise<string> {
    try {
      // 1. Tồn kho cảnh báo
      const lowStockResult = await AppDataSource.query(`
        SELECT name, sku, stock_quantity, min_stock_alert 
        FROM products 
        WHERE shop_id = $1 AND deleted_at IS NULL AND stock_quantity <= min_stock_alert 
        ORDER BY stock_quantity ASC LIMIT 5
      `, [shopId]);

      // 2. Doanh thu 30 ngày qua
      const salesResult = await AppDataSource.query(`
        SELECT COALESCE(SUM(total_amount), 0) AS total_revenue, COUNT(id) AS total_orders
        FROM sales_orders
        WHERE shop_id = $1 AND status != 'CANCELLED' AND created_at >= NOW() - INTERVAL '30 days'
      `, [shopId]);

      // 3. Công nợ khách hàng
      const debtResult = await AppDataSource.query(`
        SELECT COALESCE(SUM(current_debt), 0) AS total_debt
        FROM customers
        WHERE shop_id = $1 AND deleted_at IS NULL
      `, [shopId]);

      // 4. Nghĩa vụ thuế / Cảnh báo thuế
      const taxObligations = await AppDataSource.query(`
        SELECT tax_type, amount, status, due_date
        FROM tax_obligations
        WHERE shop_id = $1 AND status IN ('PENDING', 'OVERDUE')
        ORDER BY due_date ASC LIMIT 5
      `, [shopId]);

      const lowStockText = lowStockResult.length > 0
        ? lowStockResult.map((p: any) => `- ${p.name} (SKU: ${p.sku}): Còn ${p.stock_quantity} (Mức báo động: ${p.min_stock_alert})`).join('\n')
        : 'Không có sản phẩm nào chạm mức tồn kho tối thiểu.';

      const revenue = Number(salesResult[0]?.total_revenue || 0).toLocaleString('vi-VN');
      const orders = salesResult[0]?.total_orders || 0;
      const debt = Number(debtResult[0]?.total_debt || 0).toLocaleString('vi-VN');

      const taxText = taxObligations.length > 0
        ? taxObligations.map((t: any) => `- Loại thuế: ${t.tax_type}, Số tiền: ${Number(t.amount).toLocaleString('vi-VN')} VNĐ, Trạng thái: ${t.status}, Hạn nộp: ${new Date(t.due_date).toLocaleDateString('vi-VN')}`).join('\n')
        : 'Không có nghĩa vụ thuế đọng hoặc quá hạn.';

      return `
=== DỮ LIỆU THỰC TẾ CỬA HÀNG (CẬP NHẬT TỰ ĐỘNG) ===
- Tổng doanh thu (30 ngày gần nhất): ${revenue} VNĐ (${orders} đơn hàng)
- Tổng công nợ khách hàng cần thu: ${debt} VNĐ
- Sản phẩm sắp hết hàng / Cần nhập thêm:
${lowStockText}
- Cảnh báo nghĩa vụ Thuế:
${taxText}
=================================================
`;
    } catch (error) {
      console.error('Lỗi khi lấy dữ liệu thực tế cửa hàng cho AI:', error);
      return '=== KHÔNG THỂ LẤY DỮ LIỆU THỰC TẾ CỬA HÀNG ===';
    }
  }

  /**
   * Lấy các tài liệu tri thức / quy định thuế đã cấu hình của cửa hàng
   */
  private async getKnowledgeContext(shopId: number): Promise<string> {
    try {
      const docs = await this.knowledgeRepo.find({
        where: { shopId, isActive: true },
        order: { createdAt: 'DESC' },
        take: 10,
      });

      if (docs.length === 0) {
        return `
=== TÀI LIỆU TRI THỨC VÀ QUY ĐỊNH THUẾ ĐÃ CẤU HÌNH ===
- Quy định mặc định: Áp dụng Thông tư 88/2021/TT-BTC về chế độ kế toán cho Hộ kinh doanh, cá nhân kinh doanh và Nghị định 123/2020/NĐ-CP về hóa đơn chứng từ.
==================================================
`;
      }

      const docsText = docs
        .map((d, index) => `[Tài liệu ${index + 1}: ${d.title} (Danh mục: ${d.category})]\n${d.content}`)
        .join('\n\n');

      return `
=== TÀI LIỆU TRI THỨC VÀ QUY ĐỊNH THUẾ CẤU HÌNH CỬA HÀNG ===
${docsText}
==========================================================
`;
    } catch (error) {
      console.error('Lỗi khi lấy tài liệu tri thức cho AI:', error);
      return '';
    }
  }

  /**
   * Đặt câu hỏi và nhận câu trả lời từ AI Trợ lý (Google Gemini API)
   */
  async askAdvisor(shopId: number, dto: ChatRequestDto): Promise<{ answer: string; provider: string }> {
    const storeContext = await this.getStoreContext(shopId);
    const knowledgeContext = await this.getKnowledgeContext(shopId);

    const systemPrompt = `Bạn là Trợ lý AI chuyên nghiệp tư vấn về Quản lý Bán hàng, Tồn kho và Nghĩa vụ Thuế cho Hộ kinh doanh Việt Nam.
Nhiệm vụ của bạn:
1. Đưa ra lời khuyên kinh doanh, phân tích tồn kho, cảnh báo rủi ro thuế dựa trên dữ liệu thực tế của cửa hàng và các văn bản quy định thuế đã được cung cấp.
2. Trả lời bằng tiếng Việt lịch sự, rõ ràng, chính xác, sử dụng định dạng Markdown (in đậm, danh mục, bảng biểu) để dễ đọc.
3. Phân biệt rõ ràng giữa quy tắc thuế hiện hành và khuyến nghị kinh doanh. Nếu thông tin chưa đủ, hãy nêu rõ giả định hoặc khuyên người dùng kiểm tra lại hóa đơn/chứng từ.

${storeContext}

${knowledgeContext}
`;

    if (!config.geminiApiKey) {
      return {
        answer: `### 💡 Phân tích & Lời khuyên từ Trợ lý AI

Cảm ơn bạn đã đặt câu hỏi: **"${dto.question}"**

${storeContext}

${knowledgeContext}

> ⚠️ *Lưu ý*: Vui lòng cung cấp \`GEMINI_API_KEY\` trong file cấu hình hệ thống (\`.env\`) để nhận được câu trả lời trực tiếp từ Google Gemini API.`,
        provider: 'System Context Engine',
      };
    }

    try {
      const genAI = new GoogleGenerativeAI(config.geminiApiKey);
      const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

      const historyPrompt = dto.history && dto.history.length > 0
        ? dto.history.map(m => `${m.role === 'user' ? 'Người dùng' : 'Trợ lý AI'}: ${m.content}`).join('\n')
        : '';

      const fullPrompt = `${systemPrompt}

${historyPrompt ? `--- LỊCH SỬ TRÒ CHUYỆN ---:\n${historyPrompt}\n---------------------------\n` : ''}
Người dùng hỏi: ${dto.question}`;

      const result = await model.generateContent(fullPrompt);
      const responseText = result.response.text();

      return {
        answer: responseText,
        provider: 'Google Gemini 1.5 Flash',
      };
    } catch (err: any) {
      console.error('Lỗi khi gọi Gemini API:', err?.message || err);
      throw new Error(`Lỗi kết nối với Google Gemini API: ${err?.message || 'Không thể lấy phản hồi'}`);
    }
  }

  /**
   * Lấy danh sách gợi ý phân tích nhanh (Quick Insights)
   */
  async getQuickInsights(shopId: number): Promise<{ title: string; category: 'INVENTORY' | 'TAX' | 'SALES' | 'FINANCE'; description: string; priority: 'HIGH' | 'MEDIUM' | 'INFO' }[]> {
    const insights: { title: string; category: 'INVENTORY' | 'TAX' | 'SALES' | 'FINANCE'; description: string; priority: 'HIGH' | 'MEDIUM' | 'INFO' }[] = [];

    // 1. Kiểm tra tồn kho
    const lowStock = await AppDataSource.query(`
      SELECT COUNT(*)::int AS count FROM products WHERE shop_id = $1 AND deleted_at IS NULL AND stock_quantity <= min_stock_alert
    `, [shopId]);
    if (lowStock[0]?.count > 0) {
      insights.push({
        title: 'Cảnh báo hàng sắp hết kho',
        category: 'INVENTORY',
        description: `Có ${lowStock[0].count} mặt hàng đã chạm hoặc dưới mức tồn kho tối thiểu. Nên tạo đơn nhập hàng mới.`,
        priority: 'HIGH',
      });
    }

    // 2. Kiểm tra nghĩa vụ thuế
    const pendingTax = await AppDataSource.query(`
      SELECT COUNT(*)::int AS count, COALESCE(SUM(amount), 0) AS total FROM tax_obligations WHERE shop_id = $1 AND status = 'PENDING'
    `, [shopId]);
    if (pendingTax[0]?.count > 0) {
      insights.push({
        title: 'Nghĩa vụ thuế cần xử lý',
        category: 'TAX',
        description: `Bạn có ${pendingTax[0].count} khoản thuế chưa hoàn thành với tổng số tiền ${Number(pendingTax[0].total).toLocaleString('vi-VN')} VNĐ.`,
        priority: 'MEDIUM',
      });
    }

    // 3. Công nợ khách hàng
    const debtSum = await AppDataSource.query(`
      SELECT COALESCE(SUM(current_debt), 0) AS total FROM customers WHERE shop_id = $1 AND deleted_at IS NULL AND current_debt > 0
    `, [shopId]);
    if (Number(debtSum[0]?.total) > 0) {
      insights.push({
        title: 'Quản lý thu hồi công nợ',
        category: 'FINANCE',
        description: `Tổng công nợ khách hàng cần thu là ${Number(debtSum[0].total).toLocaleString('vi-VN')} VNĐ. Hãy kiểm tra lịch sử nợ để đối soát.`,
        priority: 'MEDIUM',
      });
    }

    if (insights.length === 0) {
      insights.push({
        title: 'Cửa hàng vận hành ổn định',
        category: 'SALES',
        description: 'Tồn kho, doanh thu và nghĩa vụ thuế hiện tại không có cảnh báo bất thường.',
        priority: 'INFO',
      });
    }

    return insights;
  }

  // --- QUẢN LÝ TÀI LIỆU TRI THỨC ---
  async getKnowledgeDocs(shopId: number): Promise<AiKnowledgeDocument[]> {
    return this.knowledgeRepo.find({
      where: { shopId },
      order: { createdAt: 'DESC' },
    });
  }

  async createKnowledgeDoc(shopId: number, dto: CreateKnowledgeDto, userId?: number): Promise<AiKnowledgeDocument> {
    const doc = this.knowledgeRepo.create({
      shopId,
      title: dto.title,
      category: dto.category,
      content: dto.content,
      isActive: dto.isActive ?? true,
      createdBy: userId,
    });
    return this.knowledgeRepo.save(doc);
  }

  async updateKnowledgeDoc(shopId: number, docId: number, dto: Partial<CreateKnowledgeDto>): Promise<AiKnowledgeDocument> {
    const doc = await this.knowledgeRepo.findOne({ where: { id: docId, shopId } });
    if (!doc) {
      throw new Error('Tài liệu tri thức không tồn tại');
    }
    if (dto.title !== undefined) doc.title = dto.title;
    if (dto.category !== undefined) doc.category = dto.category;
    if (dto.content !== undefined) doc.content = dto.content;
    if (dto.isActive !== undefined) doc.isActive = dto.isActive;

    return this.knowledgeRepo.save(doc);
  }

  async deleteKnowledgeDoc(shopId: number, docId: number): Promise<boolean> {
    const result = await this.knowledgeRepo.delete({ id: docId, shopId });
    return (result.affected || 0) > 0;
  }
}

export const aiService = new AiService();
