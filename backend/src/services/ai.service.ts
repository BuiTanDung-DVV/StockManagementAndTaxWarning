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
    let lowStockText = 'Không có sản phẩm nào chạm mức tồn kho tối thiểu.';
    let revenue = '0';
    let orders = 0;
    let debt = '0';
    let taxText = 'Không có nghĩa vụ thuế đọng hoặc quá hạn.';

    // 1. Tồn kho sản phẩm
    try {
      const lowStockResult = await AppDataSource.query(`
        SELECT name, sku, min_stock 
        FROM products 
        WHERE shop_id = $1 AND is_active = true AND min_stock > 0
        ORDER BY min_stock DESC LIMIT 5
      `, [shopId]);

      if (lowStockResult && lowStockResult.length > 0) {
        lowStockText = lowStockResult.map((p: any) => `- ${p.name} (SKU: ${p.sku || 'N/A'}): Mức báo động tồn kho là ${p.min_stock}`).join('\n');
      }
    } catch (e) {
      console.warn('AI StoreContext - Lỗi truy vấn sản phẩm:', e);
    }

    // 2. Doanh thu 30 ngày qua
    try {
      const salesResult = await AppDataSource.query(`
        SELECT COALESCE(SUM(total_amount), 0) AS total_revenue, COUNT(id) AS total_orders
        FROM sales_orders
        WHERE shop_id = $1 AND status != 'CANCELLED' AND created_at >= NOW() - INTERVAL '30 days'
      `, [shopId]);

      if (salesResult && salesResult.length > 0) {
        revenue = Number(salesResult[0]?.total_revenue || 0).toLocaleString('vi-VN');
        orders = Number(salesResult[0]?.total_orders || 0);
      }
    } catch (e) {
      console.warn('AI StoreContext - Lỗi truy vấn doanh thu:', e);
    }

    // 3. Công nợ khách hàng
    try {
      const debtResult = await AppDataSource.query(`
        SELECT COALESCE(SUM(balance), 0) AS total_debt
        FROM customers
        WHERE shop_id = $1 AND is_active = true
      `, [shopId]);

      if (debtResult && debtResult.length > 0) {
        debt = Number(debtResult[0]?.total_debt || 0).toLocaleString('vi-VN');
      }
    } catch (e) {
      console.warn('AI StoreContext - Lỗi truy vấn công nợ:', e);
    }

    // 4. Nghĩa vụ thuế / Cảnh báo thuế
    try {
      const taxObligations = await AppDataSource.query(`
        SELECT period, due_date, status, COALESCE(vat_declared + pit_declared - vat_paid - pit_paid, 0) AS amount
        FROM tax_obligations
        WHERE shop_id = $1 AND status IN ('PENDING', 'OVERDUE')
        ORDER BY due_date ASC LIMIT 5
      `, [shopId]);

      if (taxObligations && taxObligations.length > 0) {
        taxText = taxObligations.map((t: any) => `- Kỳ thuế: ${t.period}, Số tiền còn lại: ${Number(t.amount).toLocaleString('vi-VN')} VNĐ, Trạng thái: ${t.status}, Hạn nộp: ${t.due_date ? new Date(t.due_date).toLocaleDateString('vi-VN') : 'N/A'}`).join('\n');
      }
    } catch (e) {
      console.warn('AI StoreContext - Lỗi truy vấn nghĩa vụ thuế:', e);
    }

    return `
=== DỮ LIỆU THỰC TẾ CỬA HÀNG (CẬP NHẬT TỰ ĐỘNG) ===
- Tổng doanh thu (30 ngày gần nhất): ${revenue} VNĐ (${orders} đơn hàng)
- Tổng công nợ khách hàng cần thu: ${debt} VNĐ
- Sản phẩm trong danh mục cảnh báo tồn kho:
${lowStockText}
- Cảnh báo nghĩa vụ Thuế:
${taxText}
=================================================
`;
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

      if (!docs || docs.length === 0) {
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
   * Đặt câu hỏi và nhận câu trả lời 100% từ Google Gemini API
   */
  async askAdvisor(shopId: number, dto: ChatRequestDto): Promise<{ answer: string; provider: string }> {
    const storeContext = await this.getStoreContext(shopId);
    const knowledgeContext = await this.getKnowledgeContext(shopId);

    const systemPrompt = `Bạn là Trợ lý AI chuyên nghiệp tư vấn về Quản lý Bán hàng, Tồn kho và Nghĩa vụ Thuế cho Hộ kinh doanh Việt Nam.

Nhiệm vụ của bạn:
1. Trả lời TRỰC TIẾP, ĐÚNG TRỌNG TÂM và CHÍNH XÁC câu hỏi của người dùng.
2. Dữ liệu cửa hàng và các quy định bên dưới là THÔNG TIN NỀN THAM KHẢO. Hãy suy luận và lồng ghép thông tin này vào câu trả lời khi người dùng hỏi liên quan.
3. Trả lời bằng tiếng Việt tự nhiên, rõ ràng, định dạng Markdown (tiêu đề, danh mục, bảng biểu) để dễ đọc.

--- THÔNG TIN NỀN CỬA HÀNG & THUẾ ---
${storeContext}

${knowledgeContext}
-------------------------------------
`;

    if (!config.geminiApiKey) {
      throw new Error('Vui lòng cài đặt GEMINI_API_KEY trên Vercel / file .env để kết nối trực tiếp với Google Gemini AI API.');
    }

    const genAI = new GoogleGenerativeAI(config.geminiApiKey);
    const modelCandidates = [
      'gemini-1.5-flash',
      'gemini-1.5-flash-latest',
      'gemini-2.0-flash',
      'gemini-1.5-pro',
      'gemini-2.0-flash-lite',
      'gemini-2.0-flash-exp',
    ];

    let lastError: any;
    for (const modelName of modelCandidates) {
      try {
        const model = genAI.getGenerativeModel({ model: modelName });
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
          provider: `Google Gemini (${modelName})`,
        };
      } catch (err: any) {
        lastError = err;
        console.warn(`Gemini Model ${modelName} failed, trying next candidate:`, err?.message || err);
      }
    }

    console.error('Lỗi khi gọi Google Gemini API:', lastError?.message || lastError);
    throw new Error(`Lỗi kết nối với Google Gemini API: ${lastError?.message || 'Không thể lấy phản hồi từ Google Gemini AI'}`);
  }

  /**
   * Lấy danh sách gợi ý phân tích nhanh (Quick Insights)
   */
  async getQuickInsights(shopId: number): Promise<{ title: string; category: 'INVENTORY' | 'TAX' | 'SALES' | 'FINANCE'; description: string; priority: 'HIGH' | 'MEDIUM' | 'INFO' }[]> {
    const insights: { title: string; category: 'INVENTORY' | 'TAX' | 'SALES' | 'FINANCE'; description: string; priority: 'HIGH' | 'MEDIUM' | 'INFO' }[] = [];

    // 1. Kiểm tra tồn kho
    try {
      const lowStock = await AppDataSource.query(`
        SELECT COUNT(*)::int AS count FROM products WHERE shop_id = $1 AND is_active = true AND min_stock > 0
      `, [shopId]);
      if (lowStock && lowStock[0]?.count > 0) {
        insights.push({
          title: 'Cảnh báo hàng sắp hết kho',
          category: 'INVENTORY',
          description: `Có ${lowStock[0].count} mặt hàng đang áp dụng định mức tồn kho tối thiểu. Nên kiểm tra và tạo đơn nhập hàng mới.`,
          priority: 'HIGH',
        });
      }
    } catch (e) {
      console.warn('AI Insights - Lỗi tồn kho:', e);
    }

    // 2. Kiểm tra nghĩa vụ thuế
    try {
      const pendingTax = await AppDataSource.query(`
        SELECT COUNT(*)::int AS count, COALESCE(SUM(vat_declared + pit_declared - vat_paid - pit_paid), 0) AS total 
        FROM tax_obligations WHERE shop_id = $1 AND status IN ('PENDING', 'OVERDUE')
      `, [shopId]);
      if (pendingTax && pendingTax[0]?.count > 0) {
        insights.push({
          title: 'Nghĩa vụ thuế cần xử lý',
          category: 'TAX',
          description: `Bạn có ${pendingTax[0].count} khoản thuế chưa hoàn thành với tổng số tiền ${Number(pendingTax[0].total).toLocaleString('vi-VN')} VNĐ.`,
          priority: 'MEDIUM',
        });
      }
    } catch (e) {
      console.warn('AI Insights - Lỗi thuế:', e);
    }

    // 3. Công nợ khách hàng
    try {
      const debtSum = await AppDataSource.query(`
        SELECT COALESCE(SUM(balance), 0) AS total FROM customers WHERE shop_id = $1 AND is_active = true AND balance > 0
      `, [shopId]);
      if (debtSum && Number(debtSum[0]?.total) > 0) {
        insights.push({
          title: 'Quản lý thu hồi công nợ',
          category: 'FINANCE',
          description: `Tổng công nợ khách hàng cần thu là ${Number(debtSum[0].total).toLocaleString('vi-VN')} VNĐ. Hãy kiểm tra lịch sử nợ để đối soát.`,
          priority: 'MEDIUM',
        });
      }
    } catch (e) {
      console.warn('AI Insights - Lỗi công nợ:', e);
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
