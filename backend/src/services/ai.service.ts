import { GoogleGenerativeAI } from '@google/generative-ai';
import { AppDataSource } from '../config/db.config';
import { config } from '../config/env.config';
import { AiKnowledgeDocument } from '../system/entities';

import { tvplSearchService } from './tvpl-search.service';

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

    // Tra cứu danh mục văn bản pháp luật chuẩn từ Thư Viện Pháp Luật theo từ khóa câu hỏi
    const tvplResults = await tvplSearchService.searchLegalDocumentsByTitle(dto.question);
    const tvplText = tvplResults.length > 0
      ? `=== DANH MỤC VĂN BẢN TRÁC CỨU TỪ THƯ VIỆN PHÁP LUẬT (TVPL) ===\n` +
        tvplResults.map((r, i) => `${i + 1}. [${r.title}] (${r.status} - Ngày áp dụng: ${r.effectiveDate})\n   🔗 Link TVPL: ${r.url}${r.summary ? `\n   📝 Tóm tắt: ${r.summary}` : ''}`).join('\n\n')
      : '';

    const systemPrompt = `Bạn là Trợ lý AI chuyên nghiệp tư vấn về Quản lý Bán hàng, Tồn kho và Nghĩa vụ Thuế cho Hộ kinh doanh Việt Nam.

Nhiệm vụ của bạn:
1. Hãy trả lời TRỰC TIẾP, ĐÚNG TRỌNG TÂM và CHÍNH XÁC câu hỏi của người dùng dựa trên thông tin pháp luật mới nhất từ Thư Viện Pháp Luật (TVPL).
2. QUY TẮC DẪN LINK CHÍNH XÁC: TUYỆT ĐỐI KHÔNG tự bịa ra hoặc tự tạo đường link URL không có thật. Bạn CHỈ ĐƯỢC PHÉP đính kèm link Markdown \`[📄 Tên văn bản](Link TVPL)\` nếu đường link URL đó NẰM TRONG khối DANH MỤC VĂN BẢN TRÁC CỨU TỪ THƯ VIỆN PHÁP LUẬT đính kèm bên dưới! Nếu văn bản không có link URL trong danh mục đính kèm, hãy ghi tên văn bản mà KHÔNG kèm link Markdown.
3. Dữ liệu cửa hàng và danh mục văn bản TVPL đính kèm bên dưới là THÔNG TIN NỀN THAM KHẢO CHUẨN XÁC. Hãy phân tích và lồng ghép tự nhiên thông tin này vào câu trả lời.
4. Trả lời bằng tiếng Việt tự nhiên, rõ ràng, trình bày dạng Markdown.

--- THÔNG TIN NỀN CỬA HÀNG & TRA CỨU THƯ VIỆN PHÁP LUẬT (TVPL) ---
${storeContext}

${knowledgeContext}

${tvplText}
-------------------------------------------------------------------
`;

    const key = config.geminiApiKey;
    console.log(`[AI DEBUG] GEMINI_API_KEY check: present=${!!key}, length=${key ? key.length : 0}`);

    if (!key) {
      throw new Error('[AI ERROR] GEMINI_API_KEY is empty on Vercel environment variables. Please set GEMINI_API_KEY in Vercel Settings.');
    }

    const genAI = new GoogleGenerativeAI(key);
    // Mô hình chuẩn theo thứ tự ưu tiên (Gemini 1.5 Flash -> 2.0 Flash -> 1.5 Pro):
    const modelCandidates = [
      'gemini-1.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash-latest',
      'gemini-1.5-pro',
    ];

    let lastError: any;
    for (const modelName of modelCandidates) {
      try {
        const model = genAI.getGenerativeModel({
          model: modelName,
          generationConfig: {
            temperature: 0.2,
            maxOutputTokens: 1024,
          },
        });
        const historyPrompt = dto.history && dto.history.length > 0
          ? dto.history.map(m => `${m.role === 'user' ? 'Người dùng' : 'Trợ lý AI'}: ${m.content}`).join('\n')
          : '';

        const fullPrompt = `${systemPrompt}

${historyPrompt ? `--- LỊCH SỬ TRÒ CHUYỆN ---:\n${historyPrompt}\n---------------------------\n` : ''}
Người dùng hỏi: ${dto.question}`;

        const generatePromise = model.generateContent(fullPrompt);
        const timeoutPromise = new Promise<never>((_, reject) => {
          setTimeout(() => reject(new Error(`Model ${modelName} timed out after 8s`)), 8000);
        });

        const result = await Promise.race([generatePromise, timeoutPromise]);
        const responseText = result.response.text();

        if (responseText && responseText.trim().length > 0) {
          return {
            answer: responseText,
            provider: `Google Gemini (${modelName})`,
          };
        }
      } catch (err: any) {
        lastError = err;
        console.warn(`Gemini Model ${modelName} call failed:`, err?.message || err);
      }
    }

    const errStr = (lastError?.message || '').toLowerCase();
    if (errStr.includes('429') || errStr.includes('quota') || errStr.includes('rate limit')) {
      throw new Error('Hệ thống Google AI đang tạm thời vượt quá lượt truy vấn trong phút. Vui lòng đợi 15-30 giây rồi gửi lại câu hỏi.');
    }

    console.error('Gemini Models failed:', lastError);
    throw new Error('Không thể kết nối với Trợ lý AI lúc này. Vui lòng thử lại sau.');
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
