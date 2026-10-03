import { GoogleGenerativeAI } from '@google/generative-ai';
import { AppDataSource } from '../config/db.config';
import { config } from '../config/env.config';
import { AiKnowledgeDocument } from '../system/entities';
import { vietnamDateKey } from '../finance/finance-period.utils';
import {
  isLegalDocumentQuestion,
  LegalClaimEvidence,
  LegalSourceCitation,
} from '../ai/legal-grounding.utils';

import { SalesService } from './sales.service';
import { legalGroundingService } from './legal-grounding.service';
import { withAiDeadline } from '../ai/ai-deadline.utils';

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
  claims: LegalClaimEvidence[];
}

export class AiService {
  private knowledgeRepo = AppDataSource.getRepository(AiKnowledgeDocument);
  private salesService = new SalesService();

  /**
   * Tổng hợp dữ liệu thực tế từ cơ sở dữ liệu của cửa hàng (Store Snapshot)
   */
  private async getStoreContext(shopId: number): Promise<string> {
    let inventoryOverviewText: string = 'Đang cập nhật';
    let outOfStockText: string = 'Không có mặt hàng nào hết sạch tồn kho.';
    let lowStockText: string = 'Không có sản phẩm nào chạm mức tồn kho tối thiểu.';
    let categoriesText: string = 'Đa dạng';
    let topSellingText: string = 'Chưa có dữ liệu bán chạy trong 30 ngày gần nhất.';
    let revenue: string | null = null;
    let orders: number | null = null;
    let customerDebt: string | null = null;
    let supplierDebt: string | null = null;
    let taxText: string | null = null;

    // 1. Tổng quan kho hàng & Mặt hàng
    try {
      const invOverview = await AppDataSource.query(`
        SELECT
          COUNT(p.id)::int AS total_products,
          COALESCE(SUM(s.quantity), 0)::numeric AS total_qty,
          COALESCE(SUM(s.quantity * COALESCE(p.cost_price, 0)), 0)::numeric AS total_inventory_value
        FROM products p
        LEFT JOIN inventory_stocks s
          ON s.product_id = p.id
          AND s.shop_id = p.shop_id
        WHERE p.shop_id = $1
          AND p.is_active = true
      `, [shopId]);

      if (invOverview && invOverview.length > 0) {
        const row = invOverview[0];
        const totalProducts = Number(row.total_products || 0);
        const totalQty = Number(row.total_qty || 0);
        const totalVal = Number(row.total_inventory_value || 0);
        inventoryOverviewText = `Đang quản lý ${totalProducts.toLocaleString('vi-VN')} mặt hàng, tổng tồn kho ${totalQty.toLocaleString('vi-VN')} đơn vị, ước tính tổng giá trị vốn tồn kho là ${totalVal.toLocaleString('vi-VN')} VNĐ.`;
      }
    } catch (e) {
      console.warn('AI StoreContext - Lỗi truy vấn tổng quan kho:', e);
    }

    // 1.1 Danh mục ngành hàng đang kinh doanh
    try {
      const catRows = await AppDataSource.query(`
        SELECT DISTINCT c.name AS category
        FROM products p
        JOIN categories c ON c.id = p.category_id AND c.shop_id = p.shop_id
        WHERE p.shop_id = $1 AND p.is_active = true AND TRIM(c.name) != ''
        LIMIT 10
      `, [shopId]);
      if (catRows && catRows.length > 0) {
        categoriesText = catRows.map((r: any) => r.category).join(', ');
      }
    } catch (e) {
      console.warn('AI StoreContext - Lỗi truy vấn danh mục ngành hàng:', e);
    }

    // 1.2 Mặt hàng đã hết sạch tồn kho (tồn = 0)
    try {
      const outOfStockRows = await AppDataSource.query(`
        SELECT
          p.name,
          p.sku,
          p.unit,
          p.min_stock
        FROM products p
        LEFT JOIN inventory_stocks s
          ON s.product_id = p.id
          AND s.shop_id = p.shop_id
        WHERE p.shop_id = $1
          AND p.is_active = true
        GROUP BY p.id, p.name, p.sku, p.unit, p.min_stock
        HAVING COALESCE(SUM(s.quantity), 0) <= 0
        ORDER BY p.name ASC
        LIMIT 6
      `, [shopId]);

      if (outOfStockRows && outOfStockRows.length > 0) {
        outOfStockText = outOfStockRows.map((p: any) =>
          `- ${p.name} (SKU: ${p.sku || 'N/A'}): Tồn kho = 0 ${p.unit || 'sản phẩm'} (Định mức tối thiểu: ${Number(p.min_stock || 0).toLocaleString('vi-VN')})`,
        ).join('\n');
      }
    } catch (e) {
      console.warn('AI StoreContext - Lỗi truy vấn hàng hết tồn:', e);
    }

    // 1.3 Mặt hàng chạm ngưỡng tồn kho tối thiểu (còn hàng nhưng <= min_stock)
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
        HAVING COALESCE(SUM(s.quantity), 0) > 0 AND COALESCE(SUM(s.quantity), 0) <= p.min_stock
        ORDER BY (p.min_stock - COALESCE(SUM(s.quantity), 0)) DESC, p.name ASC
        LIMIT 6
      `, [shopId]);

      if (lowStockResult && lowStockResult.length > 0) {
        lowStockText = lowStockResult.map((p: any) =>
          `- ${p.name} (SKU: ${p.sku || 'N/A'}): còn ${Number(p.current_stock || 0).toLocaleString('vi-VN')} ${p.unit || 'sản phẩm'} (Định mức: ${Number(p.min_stock || 0).toLocaleString('vi-VN')})`,
        ).join('\n');
      }
    } catch (e) {
      console.warn('AI StoreContext - Lỗi truy vấn sản phẩm chạm định mức:', e);
    }

    // 2. Doanh thu & Top bán chạy 30 ngày qua
    try {
      const toDate = new Date();
      const fromDate = new Date(toDate.getTime() - 29 * 24 * 60 * 60 * 1000);
      const sales = await this.salesService.summary(
        shopId,
        vietnamDateKey(fromDate),
        vietnamDateKey(toDate),
      );
      revenue = Number(sales.netSalesRevenue).toLocaleString('vi-VN');
      orders = Number(sales.orderCount);

      // Top 5 sản phẩm bán chạy
      const topSellingRows = (await this.salesService.getTopProducts(
        shopId,
        vietnamDateKey(fromDate),
        vietnamDateKey(toDate),
      )).slice(0, 5);

      if (topSellingRows && topSellingRows.length > 0) {
        topSellingText = topSellingRows.map((p: any, idx: number) =>
          `${idx + 1}. ${p.name}: Đã bán ${Number(p.quantity).toLocaleString('vi-VN')} sản phẩm, doanh thu thuần ${Number(p.value).toLocaleString('vi-VN')} VNĐ`,
        ).join('\n');
      }
    } catch (e) {
      console.warn('AI StoreContext - Lỗi truy vấn doanh thu và top bán chạy:', e);
    }

    // 3. Công nợ khách hàng phải thu
    try {
      const debtResult = await AppDataSource.query(`
        SELECT COALESCE(SUM(GREATEST(amount - paid_amount, 0)), 0) AS total_debt
        FROM receivables
        WHERE shop_id = $1
          AND UPPER(COALESCE(status, '')) NOT IN ('PAID', 'CANCELLED')
      `, [shopId]);

      if (debtResult && debtResult.length > 0) {
        customerDebt = Number(debtResult[0]?.total_debt || 0).toLocaleString('vi-VN');
      } else {
        customerDebt = '0';
      }
    } catch (e) {
      console.warn('AI StoreContext - Lỗi truy vấn công nợ khách hàng:', e);
    }

    // 3.1 Nợ nhà cung cấp phải trả
    try {
      const payableResult = await AppDataSource.query(`
        SELECT COALESCE(SUM(GREATEST(amount - paid_amount, 0)), 0) AS total_payable
        FROM payables
        WHERE shop_id = $1
          AND UPPER(COALESCE(status, '')) NOT IN ('PAID', 'CANCELLED')
      `, [shopId]);

      if (payableResult && payableResult.length > 0) {
        supplierDebt = Number(payableResult[0]?.total_payable || 0).toLocaleString('vi-VN');
      } else {
        supplierDebt = '0';
      }
    } catch (e) {
      console.warn('AI StoreContext - Lỗi truy vấn nợ nhà cung cấp:', e);
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
=== BẢN TỔNG HỢP DỮ LIỆU THỰC TẾ CỬA HÀNG (CẬP NHẬT TỰ ĐỘNG) ===
1. Tổng quan Kho hàng:
- Tình trạng: ${inventoryOverviewText}
- Các ngành hàng kinh doanh chính: ${categoriesText}
- Mặt hàng đã HẾT HÀNG (cần nhập khẩn cấp):
${outOfStockText}
- Mặt hàng chạm định mức tồn kho tối thiểu:
${lowStockText ?? 'CHƯA THỂ TRUY VẤN DB'}

2. Hiệu quả Bán hàng (30 ngày gần nhất):
- Tổng doanh thu bán hàng: ${revenue === null ? 'CHƯA THỂ TRUY VẤN DB' : `${revenue} VNĐ (${orders} đơn hàng thành công)`}
- Top 5 sản phẩm bán chạy nhất:
${topSellingText}

3. Quản lý Tài chính & Công nợ:
- Tổng nợ khách hàng cần thu: ${customerDebt === null ? 'CHƯA THỂ TRUY VẤN DB' : `${customerDebt} VNĐ`}
- Tổng nợ phải trả cho nhà cung cấp: ${supplierDebt === null ? 'CHƯA THỂ TRUY VẤN DB' : `${supplierDebt} VNĐ`}

4. Nghĩa vụ Thuế hộ kinh doanh:
${taxText ?? 'CHƯA THỂ TRUY VẤN DB'}
- Mọi mục ghi CHƯA THỂ TRUY VẤN DB là dữ liệu không khả dụng, không được suy diễn thành 0 hoặc trạng thái an toàn.
=============================================================
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
    return withAiDeadline(remainingMs => this.askAdvisorWithinDeadline(shopId, dto, remainingMs));
  }

  private async askAdvisorWithinDeadline(
    shopId: number,
    dto: ChatRequestDto,
    remainingMs: () => number,
  ): Promise<AiAdvisorResult> {
    const key = config.geminiApiKey;
    if (!key) {
      throw new Error('Trợ lý AI chưa được cấu hình. Vui lòng liên hệ quản trị viên.');
    }
    const storeContext = await this.getStoreContext(shopId);
    remainingMs();
    const knowledgeContext = await this.getKnowledgeContext(shopId);
    remainingMs();
    const requiresLegalSources = isLegalDocumentQuestion(dto.question);
    const searchedAt = requiresLegalSources ? new Date().toISOString() : undefined;

    const systemPrompt = `Bạn là Trợ lý AI thông minh kiêm Cố vấn Quản trị & Tài chính chuyên nghiệp cho Hộ kinh doanh tại Việt Nam.

Hướng dẫn trả lời:
1. Bạn có bức tranh tổng thể về tình hình kinh doanh, kho hàng và tài chính của cửa hàng qua bản tổng hợp số liệu thực tế bên dưới. Hãy phân tích sắc bén, tự nhiên, đầy đủ và đưa ra các hành động cụ thể cho chủ cửa hàng.
2. Tuyệt đối KHÔNG đưa ra những câu máy móc kiểu "chưa thể truy vấn trực tiếp từ cơ sở dữ liệu" hay thắc mắc về kỹ thuật. Hãy sử dụng linh hoạt các số liệu tổng quan sẵn có (tổng số mặt hàng, giá trị tồn kho, các mặt hàng hết hàng cần nhập gấp, mặt hàng chạm định mức, top bán chạy, doanh thu, công nợ) để trả lời trọn vẹn và chuyên nghiệp.
3. Khi tư vấn nhập hàng/tồn kho: Luôn ưu tiên cảnh báo các mặt hàng đã HẾT HÀNG (tồn = 0) và chạm định mức tối thiểu, đồng thời đối chiếu với Top sản phẩm bán chạy để tối ưu hóa dòng vốn lưu động.
4. Với câu hỏi pháp luật/thuế: Bắt buộc tra cứu web ở thời điểm trả lời và chỉ kết luận từ nguồn được tìm thấy trên các trang chính thống (vbpl.vn, vanban.chinhphu.vn, gdt.gov.vn, thuvienphapluat.vn).
5. Trình bày tiếng Việt thân thiện, rõ ràng, cấu trúc đẹp mắt dạng Markdown (tiêu đề in đậm, gạch đầu dòng, bảng số liệu nếu phù hợp).
6. ĐỐI SOÁT & TRÍCH DẪN TÀI LIỆU TRI THỨC CỬA HÀNG (RAG GROUNDING):
- Trong phần [TÀI LIỆU TRI THỨC VÀ QUY ĐỊNH THUẾ CẤU HÌNH CỬA HÀNG], chứa các tài liệu chính sách, quy chế và quy định đã được phê duyệt nạp vào kho dữ liệu của cửa hàng.
- Khi người dùng hỏi về bất kỳ nội dung nào liên quan đến quy định thuế, chính sách bán hàng, nợ, tồn kho hay quy trình nội bộ: Bạn BẮT BUỘC phải đối soát và ưu tiên áp dụng nội dung từ các tài liệu này.
- Khi sử dụng thông tin từ tài liệu tri thức, hãy nêu rõ: "Theo [Tên tài liệu] của cửa hàng: ..." và trích dẫn chuẩn xác các điều khoản, tỷ lệ hoặc nguyên tắc quy định.

--- THÔNG TIN CỬA HÀNG & THAM KHẢO ---
${storeContext}

${knowledgeContext}
--------------------------------------
`;

    const genAI = new GoogleGenerativeAI(key);
    const modelCandidates = requiresLegalSources
      ? [
        'gemini-2.0-flash',
        'gemini-1.5-flash',
        'gemini-1.5-flash-latest',
        'gemini-1.5-pro',
      ]
      : [
        'gemini-2.0-flash',
        'gemini-1.5-flash',
        'gemini-1.5-flash-latest',
        'gemini-1.5-flash-8b',
        'gemini-1.5-pro',
        'gemini-2.0-flash-lite',
      ];

    let lastError: any;
    for (const modelName of modelCandidates) {
      const timeoutMs = Math.min(20000, remainingMs());
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
            timeoutMs,
          );
          const evidence = await legalGroundingService.extractTrustedGrounding(
            grounded.chunks,
            grounded.supports,
          );
          if (evidence.sources.length === 0 || evidence.claims.length === 0) {
            return {
              answer: 'Mình chưa tìm được tài liệu đủ tin cậy từ cơ quan nhà nước hoặc Thư Viện Pháp Luật trong lần tra cứu này, nên chưa thể đưa ra kết luận pháp lý. Bạn có thể nêu rõ loại thuế, loại hóa đơn hoặc số hiệu văn bản cần kiểm tra.',
              provider: `Google Gemini (${modelName})`,
              groundingStatus: 'insufficient_sources',
              searchedAt,
              sources: [],
              claims: [],
            };
          }

          return {
            answer: grounded.answer,
            provider: `Google Gemini (${modelName})`,
            groundingStatus: 'grounded',
            searchedAt,
            sources: evidence.sources,
            claims: evidence.claims,
          };
        }

        const model = genAI.getGenerativeModel({ model: modelName });
        const result = await model.generateContent(fullPrompt, { timeout: timeoutMs });
        const responseText = result.response.text();

        if (responseText && responseText.trim().length > 0) {
          return {
            answer: responseText,
            provider: `Google Gemini (${modelName})`,
            groundingStatus: 'not_required',
            sources: [],
            claims: [],
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

    console.error('Gemini Models failed', { status: lastError?.status, name: lastError?.name });
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
