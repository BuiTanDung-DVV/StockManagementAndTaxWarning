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

  private generateSmartFallback(question: string, storeContext: string, knowledgeContext: string): string {
    const qLower = question.toLowerCase().trim();

    if (qLower.includes('hello') || qLower.includes('hi') || qLower.includes('chào') || qLower.includes('chao')) {
      return `### 👋 Chào bạn!

Tôi là **Trợ lý AI chuyên nghiệp** tư vấn về Quản lý Bán hàng, Tồn kho và Nghĩa vụ Thuế cho Hộ kinh doanh.

Bạn có thể đặt bất kỳ câu hỏi nào cho tôi về:
- 📊 **Doanh thu & Nghĩa vụ Thuế**: Ngưỡng chịu thuế mới (1 tỷ VNĐ/năm từ 2026), thuế VAT & TNCN.
- 📦 **Tồn kho & Định mức**: Danh sách hàng sắp hết, quy trình kiểm kê và nhập kho bổ sung.
- 💳 **Công nợ khách hàng**: Hạn mức nợ, đối soát và thu hồi công nợ.

Tôi có thể hỗ trợ thông tin gì cho cửa hàng của bạn ngay bây giờ?`;
    }

    if (qLower.includes('thuế') || qLower.includes('doanh thu') || qLower.includes('ngưỡng') || qLower.includes('nghĩa vụ')) {
      return `### 📜 Tư vấn về Ngưỡng Doanh Thu & Nghĩa Vụ Thuế Hộ Kinh Doanh

1. **Quy định về ngưỡng doanh thu chịu thuế (Từ 2026)**:
   - Theo Nghị quyết mới áp dụng từ năm 2026, Hộ kinh doanh có doanh thu dưới **1.000.000.000 VNĐ / năm** (1 tỷ đồng) thuộc diện **MIỄN NỘP Thuế Giá Trị Gia Tăng (VAT) và Thuế Thu Nhập Ca Nhân (TNCN)**.
   - Khi tổng doanh thu trong năm vượt ngưỡng 1 tỷ đồng, hộ kinh doanh thực hiện nghĩa vụ khai và nộp thuế theo tỷ lệ phần trăm trên doanh thu (Thương mại: VAT 1%, TNCN 0.5%).

2. **Dữ liệu thực tế tại Cửa hàng của bạn**:
${storeContext}

> 💡 *Lời khuyên*: Định kỳ kiểm tra doanh thu ghi nhận trên hệ thống để chủ động lập hồ sơ báo cáo thuế khi đến kỳ.`;
    }

    if (qLower.includes('tồn kho') || qLower.includes('định mức') || qLower.includes('hàng') || qLower.includes('sản phẩm')) {
      return `### 📦 Quy trình Xử lý Hàng hóa dưới Định mức Tồn kho

1. **Các bước xử lý khuyến nghị**:
   - **Bước 1**: Rà soát danh sách sản phẩm chạm mức báo động tồn kho.
   - **Bước 2**: Lập đơn đặt hàng (Purchase Order) bổ sung gửi đến Nhà cung cấp.
   - **Bước 3**: Kiểm đếm quy cách và số lượng thực tế khi nhận hàng trước khi hoàn thành đơn nhập.

2. **Sản phẩm đang áp dụng cảnh báo tồn kho tại Cửa hàng**:
${storeContext}

${knowledgeContext}`;
    }

    if (qLower.includes('nợ') || qLower.includes('công nợ') || qLower.includes('khách hàng') || qLower.includes('thu')) {
      return `### 💳 Quy trình Kiểm soát & Thu hồi Công nợ Khách hàng

1. **Quy định quản lý nợ**:
   - Chỉ thực hiện bán chịu cho các khách hàng có hồ sơ và hạn mức tín dụng được duyệt.
   - Theo dõi kỳ hạn nợ và gửi đối soát công nợ định kỳ.

2. **Tổng hợp công nợ hiện tại**:
${storeContext}

${knowledgeContext}`;
    }

    return `### 💡 Tư vấn Trợ lý AI Cửa hàng

Dành cho câu hỏi của bạn: **"${question}"**

${storeContext}

${knowledgeContext}`;
  }

  /**
   * Đặt câu hỏi và nhận câu trả lời từ AI Trợ lý (Google Gemini API)
   */
  async askAdvisor(shopId: number, dto: ChatRequestDto): Promise<{ answer: string; provider: string }> {
    const storeContext = await this.getStoreContext(shopId);
    const knowledgeContext = await this.getKnowledgeContext(shopId);

    const systemPrompt = `Bạn là Trợ lý AI chuyên nghiệp tư vấn về Quản lý Bán hàng, Tồn kho và Nghĩa vụ Thuế cho Hộ kinh doanh Việt Nam.

Nhiệm vụ của bạn:
1. Hãy trả lời TRỰC TIẾP, ĐÚNG TRỌNG TÂM và CHÍNH XÁC câu hỏi của người dùng.
2. Dữ liệu cửa hàng và quy định đính kèm bên dưới là THÔNG TIN NỀN THAM KHẢO. Hãy phân tích và lồng ghép tự nhiên thông tin này vào câu trả lời khi người dùng hỏi liên quan. KHÔNG in lại toàn bộ khối dữ liệu thô nếu người dùng không yêu cầu.
3. Sử dụng tiếng Việt lịch sự, định dạng Markdown (tiêu đề, danh mục, bảng biểu) để trình bày rõ ràng.

--- THÔNG TIN NỀN CỬA HÀNG ---
${storeContext}

${knowledgeContext}
--------------------------------
`;

    if (!config.geminiApiKey) {
      return {
        answer: this.generateSmartFallback(dto.question, storeContext, knowledgeContext),
        provider: 'System Context Engine',
      };
    }

    const genAI = new GoogleGenerativeAI(config.geminiApiKey);
    const modelCandidates = [
      'gemini-1.5-flash-latest',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-2.0-flash-exp',
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
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
        console.warn(`Gemini Model ${modelName} failed, trying next model candidate:`, err?.message || err);
      }
    }

    console.error('Tất cả mô hình Gemini API đều báo lỗi, chuyển sang bộ phân tích nội bộ (System Context Engine):', lastError?.message || lastError);

    return {
      answer: this.generateSmartFallback(dto.question, storeContext, knowledgeContext),
      provider: 'Trợ lý Hệ thống (System Context Engine)',
    };
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
