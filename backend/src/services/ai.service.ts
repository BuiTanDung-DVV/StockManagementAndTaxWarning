import { GoogleGenerativeAI } from '@google/generative-ai';
import { AppDataSource } from '../config/db.config';
import { config } from '../config/env.config';
import { AiKnowledgeDocument } from '../system/entities';
import { vietnamDateKey } from '../finance/finance-period.utils';
import {
  isLegalDocumentQuestion,
  LegalSourceCitation,
} from '../ai/legal-grounding.utils';

import { SalesService } from './sales.service';
import { legalGroundingService } from './legal-grounding.service';

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

export interface AiAdvisorResult {
  answer: string;
  provider: string;
  groundingStatus: 'not_required' | 'grounded' | 'insufficient_sources';
  searchedAt?: string;
  sources: LegalSourceCitation[];
}

export class AiService {
  private knowledgeRepo = AppDataSource.getRepository(AiKnowledgeDocument);
  private salesService = new SalesService();

  /**
   * Tổng hợp dữ liệu thực tế từ cơ sở dữ liệu của cửa hàng (Store Snapshot)
   */
  private async getStoreContext(shopId: number): Promise<string> {
    let lowStockText: string | null = null;
    let revenue: string | null = null;
    let orders: number | null = null;
    let debt: string | null = null;
    let taxText: string | null = null;

    // 1. Tồn kho sản phẩm
    try {
      const lowStockResult = await AppDataSource.query(`
        SELECT
          p.name,
          p.sku,
          p.unit,
          p.min_stock,
          COALESCE(SUM(s.quantity), 0) AS current_stock
        FROM products p
        LEFT JOIN inventory_stocks s
          ON s.product_id = p.id
          AND s.shop_id = p.shop_id
        WHERE p.shop_id = $1
          AND p.is_active = true
          AND p.min_stock > 0
        GROUP BY p.id, p.name, p.sku, p.unit, p.min_stock
        HAVING COALESCE(SUM(s.quantity), 0) <= p.min_stock
        ORDER BY (p.min_stock - COALESCE(SUM(s.quantity), 0)) DESC, p.name ASC
        LIMIT 5
      `, [shopId]);

      if (lowStockResult && lowStockResult.length > 0) {
        lowStockText = lowStockResult.map((p: any) =>
          `- ${p.name} (SKU: ${p.sku || 'N/A'}): còn ${Number(p.current_stock || 0).toLocaleString('vi-VN')} ${p.unit || 'sản phẩm'}, định mức ${Number(p.min_stock || 0).toLocaleString('vi-VN')}`,
        ).join('\n');
      } else {
        lowStockText = 'Không có sản phẩm nào chạm mức tồn kho tối thiểu.';
      }
    } catch (e) {
      console.warn('AI StoreContext - Lỗi truy vấn sản phẩm:', e);
    }

    // 2. Doanh thu 30 ngày qua
    try {
      const toDate = new Date();
      const fromDate = new Date(toDate.getTime() - 29 * 24 * 60 * 60 * 1000);
      const sales = await this.salesService.summary(
        shopId,
        vietnamDateKey(fromDate),
        vietnamDateKey(toDate),
      );
      revenue = Number(sales.totalRevenue).toLocaleString('vi-VN');
      orders = Number(sales.orderCount);
    } catch (e) {
      console.warn('AI StoreContext - Lỗi truy vấn doanh thu:', e);
    }

    // 3. Công nợ khách hàng
    try {
      const debtResult = await AppDataSource.query(`
        SELECT COALESCE(SUM(GREATEST(amount - paid_amount, 0)), 0) AS total_debt
        FROM receivables
        WHERE shop_id = $1
          AND UPPER(COALESCE(status, '')) NOT IN ('PAID', 'CANCELLED')
      `, [shopId]);

      if (debtResult && debtResult.length > 0) {
        debt = Number(debtResult[0]?.total_debt || 0).toLocaleString('vi-VN');
      } else {
        debt = '0';
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
      } else {
        taxText = 'Không có nghĩa vụ thuế đọng hoặc quá hạn.';
      }
    } catch (e) {
      console.warn('AI StoreContext - Lỗi truy vấn nghĩa vụ thuế:', e);
    }

    return `
=== DỮ LIỆU THỰC TẾ CỬA HÀNG (CẬP NHẬT TỰ ĐỘNG) ===
- Tổng doanh thu (30 ngày gần nhất): ${revenue === null ? 'CHƯA THỂ TRUY VẤN DB' : `${revenue} VNĐ (${orders} đơn hàng)`}
- Tổng công nợ khách hàng cần thu: ${debt === null ? 'CHƯA THỂ TRUY VẤN DB' : `${debt} VNĐ`}
- Sản phẩm trong danh mục cảnh báo tồn kho:
${lowStockText ?? 'CHƯA THỂ TRUY VẤN DB'}
- Cảnh báo nghĩa vụ Thuế:
${taxText ?? 'CHƯA THỂ TRUY VẤN DB'}
- Mọi mục ghi CHƯA THỂ TRUY VẤN DB là dữ liệu không khả dụng, không được suy diễn thành 0 hoặc trạng thái an toàn.
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
=== TÀI LIỆU TRI THỨC ĐÃ CẤU HÌNH TRONG CƠ SỞ DỮ LIỆU ===
- Chưa có tài liệu đang hoạt động cho cửa hàng này.
- Không được tự khẳng định quy định, ngưỡng hoặc nghĩa vụ pháp lý khi thiếu nguồn đã xác minh.
==========================================================
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
      return `
=== TÀI LIỆU TRI THỨC ĐÃ CẤU HÌNH TRONG CƠ SỞ DỮ LIỆU ===
- CHƯA THỂ TRUY VẤN DB.
- Không được tự khẳng định quy định, ngưỡng hoặc nghĩa vụ pháp lý.
==========================================================
`;
    }
  }

  /**
   * Đặt câu hỏi và nhận câu trả lời 100% từ Google Gemini API
   */
  async askAdvisor(shopId: number, dto: ChatRequestDto): Promise<AiAdvisorResult> {
    const storeContext = await this.getStoreContext(shopId);
    const knowledgeContext = await this.getKnowledgeContext(shopId);
    const requiresLegalSources = isLegalDocumentQuestion(dto.question);
    const searchedAt = requiresLegalSources ? new Date().toISOString() : undefined;

    const systemPrompt = `Bạn là Trợ lý AI thông minh chuyên tư vấn Quản lý Bán hàng, Tồn kho, Tài chính và Nghĩa vụ Thuế cho Hộ kinh doanh tại Việt Nam.

Hướng dẫn trả lời:
1. Trả lời tự nhiên, thông minh, đúng trọng tâm cho MỌI câu hỏi của chủ cửa hàng (từ bán hàng, xuất nhập kho, quản lý nợ, tài chính đến quy định pháp luật).
2. Với câu hỏi vận hành, chỉ dùng dữ liệu cửa hàng được cung cấp. Với câu hỏi pháp luật/thuế, bắt buộc tra cứu web ở thời điểm trả lời và chỉ kết luận từ nguồn được tìm thấy.
3. Với pháp luật/thuế, ưu tiên theo thứ tự: vbpl.vn; vanban.chinhphu.vn và website cơ quan nhà nước; sau đó mới đến thuvienphapluat.vn. Không dùng báo chí, blog, diễn đàn hoặc nguồn thương mại khác.
4. Không tự tạo tên văn bản, số hiệu, URL, ngày hiệu lực hoặc trạng thái hiệu lực. Nếu nguồn không xác nhận trạng thái hiệu lực thì phải ghi rõ "cần kiểm tra hiệu lực tại nguồn".
5. Mỗi kết luận pháp lý phải chỉ ra nguồn hỗ trợ ngay trong nội dung bằng ký hiệu [Nguồn]. Nếu nguồn mâu thuẫn hoặc không đủ rõ, không được suy đoán.
6. Lồng ghép tự nhiên thông tin tình hình thực tế của Cửa hàng để đưa ra lời khuyên thực tế nhất.
7. Trình bày tiếng Việt thân thiện, rõ ràng dạng Markdown.

--- THÔNG TIN CỬA HÀNG & THAM KHẢO ---
${storeContext}

${knowledgeContext}
--------------------------------------
`;

    const key = config.geminiApiKey;

    if (!key) {
      throw new Error('[AI ERROR] GEMINI_API_KEY is empty on Vercel environment variables. Please set GEMINI_API_KEY in Vercel Settings.');
    }

    const genAI = new GoogleGenerativeAI(key);
    const modelCandidates = requiresLegalSources
      ? ['gemini-3.7-flash', 'gemini-3.6-flash', 'gemini-2.5-flash']
      : [
        'gemini-3.5-flash-lite',
        'gemini-3.1-flash-lite',
        'gemini-3.6-flash',
        'gemini-3.5-flash',
        'gemini-3-flash',
        'gemini-2.5-flash',
        'gemini-2.0-flash',
        'gemma-4-31b',
        'gemma-4-26b',
        'gemini-1.5-flash-latest',
      ];

    let lastError: any;
    for (const modelName of modelCandidates) {
      try {
        const historyPrompt = dto.history && dto.history.length > 0
          ? dto.history.map(m => `${m.role === 'user' ? 'Người dùng' : 'Trợ lý AI'}: ${m.content}`).join('\n')
          : '';

        const legalSearchInstruction = requiresLegalSources
          ? `--- YÊU CẦU TRA CỨU BẮT BUỘC ---
Thời điểm tra cứu: ${searchedAt}.
Hãy tìm tài liệu mới nhất có liên quan, ưu tiên truy vấn trong các miền: vbpl.vn, vanban.chinhphu.vn, chinhphu.vn, mof.gov.vn, gdt.gov.vn, moj.gov.vn, quochoi.vn; chỉ dùng thuvienphapluat.vn khi cần nguồn bổ sung.
Không trả lời từ trí nhớ nếu chưa thực hiện tìm kiếm web trong lượt này.
----------------------------------`
          : '';

        const fullPrompt = `${systemPrompt}

${legalSearchInstruction}

${historyPrompt ? `--- LỊCH SỬ TRÒ CHUYỆN ---:\n${historyPrompt}\n---------------------------\n` : ''}
Người dùng hỏi: ${dto.question}`;

        if (requiresLegalSources) {
          const grounded = await legalGroundingService.generateWithGoogleSearch(
            key,
            modelName,
            fullPrompt,
          );
          const sources = await legalGroundingService.extractTrustedSources(grounded.chunks);
          if (sources.length === 0) {
            return {
              answer: 'Mình chưa tìm được tài liệu đủ tin cậy từ cơ quan nhà nước hoặc Thư Viện Pháp Luật trong lần tra cứu này, nên chưa thể đưa ra kết luận pháp lý. Bạn có thể nêu rõ loại thuế, loại hóa đơn hoặc số hiệu văn bản cần kiểm tra.',
              provider: `Google Gemini (${modelName})`,
              groundingStatus: 'insufficient_sources',
              searchedAt,
              sources: [],
            };
          }

          return {
            answer: grounded.answer,
            provider: `Google Gemini (${modelName})`,
            groundingStatus: 'grounded',
            searchedAt,
            sources,
          };
        }

        const model = genAI.getGenerativeModel({ model: modelName });
        const result = await model.generateContent(fullPrompt);
        const responseText = result.response.text();

        if (responseText && responseText.trim().length > 0) {
          return {
            answer: responseText,
            provider: `Google Gemini (${modelName})`,
            groundingStatus: 'not_required',
            sources: [],
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
        SELECT COUNT(*)::int AS count
        FROM (
          SELECT p.id
          FROM products p
          LEFT JOIN inventory_stocks s
            ON s.product_id = p.id
            AND s.shop_id = p.shop_id
          WHERE p.shop_id = $1
            AND p.is_active = true
            AND p.min_stock > 0
          GROUP BY p.id, p.min_stock
          HAVING COALESCE(SUM(s.quantity), 0) <= p.min_stock
        ) low_stock_products
      `, [shopId]);
      if (lowStock && lowStock[0]?.count > 0) {
        insights.push({
          title: 'Cảnh báo hàng sắp hết kho',
          category: 'INVENTORY',
          description: `Có ${lowStock[0].count} mặt hàng đang chạm hoặc thấp hơn định mức tồn kho tối thiểu. Nên kiểm tra và tạo đơn nhập hàng mới.`,
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
        SELECT COALESCE(SUM(GREATEST(amount - paid_amount, 0)), 0) AS total
        FROM receivables
        WHERE shop_id = $1
          AND UPPER(COALESCE(status, '')) NOT IN ('PAID', 'CANCELLED')
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
        title: 'Chưa ghi nhận cảnh báo trong phạm vi đã kiểm tra',
        category: 'SALES',
        description: 'Không có cảnh báo về hàng dưới định mức, nghĩa vụ thuế đang mở hoặc công nợ khách hàng trong dữ liệu hiện tại. Kết quả này không thay thế kiểm tra toàn bộ hoạt động cửa hàng.',
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
