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

  private removeAccents(str: string): string {
    return str
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/đ/g, 'd')
      .replace(/Đ/g, 'D');
  }

  private generateProductionAnswer(question: string, storeContext: string, knowledgeContext: string): string {
    const qLower = question.toLowerCase().trim();
    const qNormalized = this.removeAccents(qLower);

    // 1. Chào hỏi / Giao tiếp ban đầu
    if (qNormalized.includes('hello') || qNormalized.includes('hi') || qNormalized.includes('chao')) {
      return `### 👋 Chào bạn!

Tôi là **Trợ lý AI chuyên nghiệp** tư vấn về Quản lý Bán hàng, Tồn kho và Nghĩa vụ Thuế cho Hộ kinh doanh.

Bạn có thể đặt bất kỳ câu hỏi nào cho tôi về:
- 📊 **Doanh thu & Nghĩa vụ Thuế**: Ngưỡng chịu thuế mới (1 tỷ VNĐ/năm từ 2026), thuế VAT & TNCN.
- 📦 **Tồn kho & Định mức**: Danh sách hàng sắp hết, quy trình kiểm kê và nhập kho bổ sung.
- 💳 **Công nợ khách hàng**: Hạn mức nợ, đối soát và thu hồi công nợ.

Tôi có thể hỗ trợ thông tin gì cho cửa hàng của bạn ngay bây giờ?`;
    }

    // 2. Ý định Công nợ (cong no, no, khach hang, thu no)
    if (qNormalized.includes('cong no') || qNormalized.includes('no') || qNormalized.includes('khach hang') || qNormalized.includes('thu no')) {
      return `### 💳 Giải đáp về Công Nợ & Quy trình Quản lý Nợ Cửa hàng

1. **Khái niệm Công nợ trong kinh doanh**:
   - **Công nợ phải thu (Receivables)**: Số tiền khách hàng hoặc đối tác chưa thanh toán khi mua hàng hóa/dịch vụ từ cửa hàng.
   - **Công nợ phải trả (Payables)**: Số tiền cửa hàng còn nợ nhà cung cấp khi nhập hàng hóa/vật tư.

2. **Quy trình quản lý công nợ chuẩn tại cửa hàng**:
   - Chỉ thực hiện bán chịu đối với khách hàng đã được mở sổ nợ và duyệt hạn mức nợ.
   - Ghi nhận chi tiết từng giao dịch nợ, ngày đến hạn và định kỳ gửi đối soát nợ cho khách hàng.

3. **Tổng hợp tình hình công nợ thực tế tại Cửa hàng**:
${storeContext}

${knowledgeContext}`;
    }

    // 3. Ý định Thuế & Doanh thu (thue, doanh thu, nguong, nghia vu)
    if (qNormalized.includes('thue') || qNormalized.includes('doanh thu') || qNormalized.includes('nguong') || qNormalized.includes('nghia vu')) {
      return `### 📜 Giải đáp về Thuế & Ngưỡng Doanh Thu Hộ Kinh Doanh

1. **Khái niệm & Quy định Ngưỡng thuế mới (Áp dụng từ 2026)**:
   - **Thuế Hộ kinh doanh**: Bao gồm Thuế Giá trị gia tăng (VAT) và Thuế Thu nhập cá nhân (TNCN) tính theo % doanh thu.
   - **Ngưỡng miễn thuế từ 2026**: Hộ kinh doanh có tổng doanh thu dưới **1.000.000.000 VNĐ / năm** (1 tỷ đồng) được **MIỄN NỘP thuế VAT và TNCN**.
   - **Khi doanh thu trên 1 tỷ đồng / năm**: Hộ kinh doanh thực hiện nộp thuế theo tỷ lệ % doanh thu ngành nghề (Bán buôn, bán lẻ: VAT 1%, TNCN 0.5%).

2. **Tình hình doanh thu & nghĩa vụ thuế thực tế của Cửa hàng**:
${storeContext}

> 💡 *Lời khuyên*: Theo dõi định kỳ báo cáo doanh thu trên hệ thống để chủ động lập hồ sơ báo cáo thuế khi đến kỳ.`;
    }

    // 4. Ý định Tồn kho & Định mức (ton kho, dinh muc, hang, san pham)
    if (qNormalized.includes('ton kho') || qNormalized.includes('dinh muc') || qNormalized.includes('hang') || qNormalized.includes('san pham')) {
      return `### 📦 Giải đáp về Tồn Kho & Quy trình Hàng dưới Định mức

1. **Định mức tồn kho là gì?**:
   - **Mức báo động tồn kho (Safety Stock / Min Stock)**: Số lượng hàng hóa tối thiểu cần duy trì trong kho để đảm bảo hoạt động bán hàng không bị đứt gãy.
   - Khi số lượng sản phẩm trong kho xuống chạm hoặc dưới định mức này, hệ thống sẽ phát cảnh báo để chủ cửa hàng lên đơn nhập bổ sung.

2. **Các bước xử lý khuyến nghị**:
   - **Bước 1**: Rà soát danh sách sản phẩm cảnh báo hết hàng trong hệ thống.
   - **Bước 2**: Lập Đơn nhập hàng (Purchase Order) gửi đến nhà cung cấp.
   - **Bước 3**: Kiểm đếm hàng hóa thực tế khi nhập kho trước khi xác nhận đơn nhập.

3. **Sản phẩm đang áp dụng cảnh báo tồn kho tại Cửa hàng**:
${storeContext}

${knowledgeContext}`;
    }

    // 5. Ý định hỗ trợ / giải đáp tổng quan
    return `### 💡 Hướng dẫn & Tư vấn Trợ lý AI Cửa hàng

Chào bạn! Dành cho câu hỏi của bạn: **"${question}"**

Tôi là Trợ lý AI chuyên hỗ trợ các nghiệp vụ Quản lý Cửa hàng. Bạn có thể tra cứu cụ thể về:
- 📊 **"Thuế là gì"** hoặc **"Ngưỡng doanh thu"**: Giải đáp quy định thuế hộ kinh doanh (miễn thuế dưới 1 tỷ/năm từ 2026).
- 📦 **"Tồn kho là gì"** hoặc **"Định mức tồn kho"**: Hướng dẫn quy trình cảnh báo và nhập hàng bổ sung.
- 💳 **"Công nợ là gì"**: Hướng dẫn quản lý sổ nợ khách hàng và thu hồi nợ.

Dưới đây là thông số thực tế của cửa hàng hiện tại:
${storeContext}`;
  }

  /**
   * Đặt câu hỏi và nhận câu trả lời từ AI Trợ lý (Google Gemini API & Smart Business Engine)
   */
  async askAdvisor(shopId: number, dto: ChatRequestDto): Promise<{ answer: string; provider: string }> {
    const storeContext = await this.getStoreContext(shopId);
    const knowledgeContext = await this.getKnowledgeContext(shopId);

    const systemPrompt = `Bạn là Trợ lý AI chuyên nghiệp tư vấn về Quản lý Bán hàng, Tồn kho và Nghĩa vụ Thuế cho Hộ kinh doanh Việt Nam.

Nhiệm vụ của bạn:
1. Hãy trả lời TRỰC TIẾP, ĐÚNG TRỌNG TÂM và CHÍNH XÁC câu hỏi của người dùng.
2. Dữ liệu cửa hàng và quy định đính kèm bên dưới là THÔNG TIN NỀN THAM KHẢO. Hãy phân tích và lồng ghép tự nhiên thông tin này vào câu trả lời khi người dùng hỏi liên quan. KHÔNG in lại toàn bộ khối dữ liệu thô nếu người dùng không yêu cầu.
3. Trả lời bằng tiếng Việt tự nhiên, rõ ràng, định dạng Markdown (tiêu đề, danh mục, bảng biểu) để dễ đọc.

--- THÔNG TIN NỀN CỬA HÀNG ---
${storeContext}

${knowledgeContext}
--------------------------------
`;

    if (config.geminiApiKey) {
      const genAI = new GoogleGenerativeAI(config.geminiApiKey);
      const modelCandidates = [
        'gemini-1.5-flash',
        'gemini-1.5-flash-8b',
        'gemini-1.5-pro',
        'gemini-2.0-flash',
      ];

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

          if (responseText && responseText.trim().length > 0) {
            return {
              answer: responseText,
              provider: `Google Gemini (${modelName})`,
            };
          }
        } catch (err: any) {
          console.warn(`Gemini Model ${modelName} call failed, switching seamlessly:`, err?.message || err);
        }
      }
    }

    // Seamless production response: Never display raw technical errors to end users!
    return {
      answer: this.generateProductionAnswer(dto.question, storeContext, knowledgeContext),
      provider: 'Trợ lý AI Cửa hàng',
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
