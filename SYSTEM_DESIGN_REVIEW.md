# 📊 SYSTEM DESIGN REVIEW - Sales & Stock Management for HKD (Hộ Kinh Doanh)

## Ngày đánh giá: 21/04/2026

---

## 🎯 TỔNG QUAN

Ứng dụng **Sales & Stock Management** được xây dựng để hỗ trợ quản lý bán hàng & kho hàng cho Hộ kinh doanh (HKD) ở Việt Nam. Đánh giá này so sánh các yêu cầu thực tế của HKD (từ tài liệu hướng dẫn) với những tính năng đã implement.

---

## ✅ CÁC TÍNH NĂNG ĐÃ IMPLEMENT - ĐÁNH GIÁ TÍCH CỰC

### 1. **Quản lý Bán Hàng (Sales Management)** ✅
**Status:** Hoàn thành cơ bản
- ✅ Tạo đơn hàng (SalesOrder, SalesOrderItem)
- ✅ Theo dõi trạng thái đơn hàng (PENDING → CONFIRMED → DELIVERED)
- ✅ Quản lý khách hàng (Customers, CustomerType: RETAIL/WHOLESALE/VIP)
- ✅ Tính toán thuế GTGT & giảm giá
- ✅ Xử lý trả hàng (SalesReturn)
- ✅ Ghi nhận thanh toán (SalesOrderPayment - CASH/TRANSFER/MOMO/ZALOPAY/QR)
- ✅ Ghi chú và theo dõi QR Payment Ref

**Database Schema:** 
- `sales_orders`, `sales_order_items`, `sales_order_payments`, `sales_returns`

**Điểm mạnh:**
- Schema tối ưu với quan hệ 1-n cộng được định nghĩa rõ ràng
- Hỗ trợ nhiều phương thức thanh toán (khớp với thực tế Việt Nam: tiền mặt, chuyển khoản, ví điện tử)
- Có field `totalCogs` để theo dõi giá vốn hàng bán (quan trọng cho tính lợi nhuận)

---

### 2. **Quản lý Kho Hàng (Inventory Management)** ✅
**Status:** Hoàn thành cơ bản
- ✅ Quản lý sản phẩm (Products)
- ✅ Theo dõi tồn kho (InventoryStock, StockTake)
- ✅ Ghi nhận vận động kho (InventoryMovement: IN/OUT/ADJUSTMENT/RETURN)
- ✅ Kiểm kho định kỳ (StockTake - DRAFT/COMPLETED)
- ✅ Quản lý nhiều kho (Warehouse)
- ✅ Phát hiện lỗi kiểm kho (so sánh systemQty vs actualQty)

**Database Schema:**
- `inventory_stocks`, `inventory_movements`, `stock_takes`, `stock_take_items`, `warehouses`

**Điểm mạnh:**
- Ghi nhận đầy đủ các loại vận động kho (IN, OUT, ADJUSTMENT, RETURN)
- Theo dõi người tạo và người duyệt quyết định (auditability)
- Có field `reference_type` & `reference_id` để track nguồn vận động (từ bán hàng hay nhập hàng)

---

### 3. **Quản lý Tài Chính Cơ Bản (Finance Management)** ✅
**Status:** Hoàn thành ở mức cơ bản

#### 3.1 Quản lý Tiền Mặt & Tài Khoản
- ✅ Tạo tài khoản quỹ (CashAccount: CASH/BANK)
- ✅ Ghi nhận giao dịch tiền mặt (CashTransaction: INCOME/EXPENSE)
- ✅ Phân loại giao dịch (SALES, PURCHASE, SALARY, RENT, UTILITIES, OTHER)
- ✅ Theo dõi số dư chạy (runningBalance)
- ✅ Hỗ trợ tải lên ảnh hóa đơn (receiptImageUrl)

**Database Schema:**
- `cash_accounts`, `cash_transactions`

#### 3.2 Quản lý Hóa Đơn
- ✅ Ghi nhận hóa đơn đầu vào (IN) & đầu ra (OUT)
- ✅ Lưu thông tin đối tác (tên, mã số thuế, địa chỉ, số CCCD)
- ✅ Ghi nhận số hiệu, ký hiệu hóa đơn
- ✅ Tính toán thuế GTGT, tổng tiền
- ✅ Lưu ảnh hóa đơn (imageUrl)
- ✅ Theo dõi trạng thái thanh toán (PAID/UNPAID/PARTIAL)

**Database Schema:**
- `invoices`

**Lưu ý:** Theo Thông tư 25/2025/TT-NHNN (từ 01/03/2026), tên tài khoản thanh toán **bắt buộc phải khớp** với tên đăng ký của HKD. ⚠️ **Cần verify thêm trên giao diện.**

#### 3.3 Ghi Nhận Mua Hàng Không Hóa Đơn (Mẫu 01/TNDN)
- ✅ Tạo bản ghi mua hàng nông sản không hóa đơn
- ✅ Lưu CCCD của người nông dân (sellerIdentityNumber)
- ✅ Ghi nhận chữ ký người bán (sellerSignatureUrl)
- ✅ Đối chiếu giá thị trường (marketPriceReference)
- ✅ Lưu chứng từ thanh toán (paymentProofUrl)

**Database Schema:**
- `purchases_without_invoice`

**Điểm mạnh:**
- Hỗ trợ mẫu 01/TNDN - một yêu cầu pháp lý quan trọng cho HKD kinh doanh nông sản

#### 3.4 Kế hoạch & Dự báo Tài Chính
- ✅ Kế hoạch ngân sách (BudgetPlan: so sánh planned vs actual income/expense)
- ✅ Dự báo dòng tiền (CashflowForecast)
- ✅ Đóng ngày hàng ngày (DailyClosing: so sánh expected vs actual cash)

**Database Schema:**
- `budget_plans`, `cashflow_forecasts`, `daily_closings`

**Điểm mạnh:**
- Có module dự báo dòng tiền (khớp với lưu ý: cần trích lập quỹ dự phòng 3-6 tháng chi phí)
- Hỗ trợ đóng ngày để kiểm soát sai lệch tiền mặt

#### 3.5 Quản lý Thuế
- ✅ Ghi nhận khoản nợ thuế (TaxObligation: VAT, PIT theo quý)
- ✅ Theo dõi trạng thái thanh toán (done/partial/pending/overdue)
- ✅ Ghi nhận số tiền khai báo vs số tiền đã nộp

**Database Schema:**
- `tax_obligations`

---

### 4. **Quản lý Công Nợ (Receivables & Payables)** ✅
**Status:** Hoàn thành

#### 4.1 Phải Thu (Receivables)
- ✅ Theo dõi công nợ khách hàng (Receivable)
- ✅ Phân loại trạng thái (UNPAID/PARTIAL/PAID/OVERDUE)
- ✅ Tính tuổi nợ (days overdue)
- ✅ Ghi nhận lý do nợ (debtReason)
- ✅ Lưu bằng chứng nợ (DebtEvidence: PHOTO/SIGNATURE/AUDIO/DOCUMENT/CONTRACT)
- ✅ Theo dõi lịch sử thanh toán (DebtPaymentHistory)
- ✅ Hỗ trợ nhắc nợ (reminderEnabled, lastReminderAt)

**Database Schema:**
- `receivables`, `debt_evidences`, `debt_payment_history`

**Điểm mạnh:**
- Lưu bằng chứng nợ bằng hình ảnh/audio/chữ ký - quan trọng khi tranh chấp
- Theo dõi người làm chứng (witness_name)
- Hỗ trợ hạn mức tín dụng (credit_limit) & số dư tài khoản

#### 4.2 Phải Trả (Payables)
- ✅ Quản lý đơn hàng mua (PurchaseOrder)
- ✅ Theo dõi hóa đơn nhà cung cấp (invoiceNumber)
- ✅ Tính toán giảm giá & thuế
- ✅ Theo dõi thanh toán (paidAmount vs totalAmount)

**Database Schema:**
- `purchase_orders`, `purchase_order_items`

---

### 5. **Authentication & Authorization** ✅
- ✅ Đăng ký tài khoản (registerScreensouth)
- ✅ Đăng nhập (LoginScreen)
- ✅ Phân loại tài khoản (SHOP owner / PERSONAL staff)
- ✅ JWT Token management
- ✅ Lưu trữ token bảo mật (SharedPreferences)

---

### 6. **Multi-Shop Support** ✅
- ✅ Hỗ trợ múi cửa hàng (ShopProvider)
- ✅ Quản lý trạng thái cửa hàng (ACTIVE/PENDING)
- ✅ Tải lên thông tin cửa hàng trong onboarding

---

## ⚠️ CÁC LỖI / THIẾU XÓT PHÁT HIỆN

### 1. **Thiếu: Bảng Kê Thu Mua Hàng Không Hóa Đơn (Mẫu 01/TNDN) - Chi Tiết Tối Ưu**
**Mức độ:** 🔴 CRITICAL

**Vấn đề:**
- File `purchases_without_invoice` có sẵn, nhưng **thiếu trường lưu danh sách hàng hóa mua**.
- Mẫu 01/TNDN thực tế cần: **Tên hàng hóa, số lượng, đơn giá, thành tiền**.
- Hiện tại chỉ lưu tổng tiền (`totalAmount`), không lưu chi tiết từng loại hàng.

**Gợi ý fix:**
```typescript
// Thêm entity cho chi tiết mua hàng không hóa đơn
@Entity('purchase_without_invoice_items')
export class PurchaseWithoutInvoiceItem {
    @PrimaryGeneratedColumn()
    id: number;
    
    @ManyToOne(() => PurchaseWithoutInvoice, (p) => p.items)
    @JoinColumn({ name: 'purchase_id' })
    purchase: PurchaseWithoutInvoice;
    
    @Column({ length: 200 }) // Tên hàng nông/lâm/thủy sản
    productName: string;
    
    @Column()
    quantity: number;
    
    @Column({ name: 'unit_price', type: 'decimal', precision: 18, scale: 2 })
    unitPrice: number;
    
    @Column({ type: 'decimal', precision: 18, scale: 2 })
    subtotal: number;
}
```

---

### 2. **Thiếu: Báo Cáo Kết Quả Kinh Doanh (P&L - Profit & Loss)**
**Mức độ:** 🔴 CRITICAL

**Vấn đề:**
- Không có entity hoặc API để tổng hợp Lãi/Lỗ theo kỳ báo cáo.
- Cần tính: **Doanh thu - Giá vốn hàng bán (COGS) - Chi phí vận hành = Lợi nhuận ròng**.
- Điều này khác với "Dòng tiền" - rất quan trọng cho kế toán.

**Gợi ý fix:**
```typescript
// Thêm entity Báo cáo lãi/lỗ
@Entity('profit_loss_reports')
export class ProfitLossReport {
    @PrimaryGeneratedColumn()
    id: number;
    
    @Column({ length: 20 }) // e.g., '04/2026'
    period: string;
    
    @Column({ name: 'total_revenue', type: 'decimal', precision: 18, scale: 2 })
    totalRevenue: number; // Tổng doanh thu bán hàng
    
    @Column({ name: 'cogs', type: 'decimal', precision: 18, scale: 2 })
    cogs: number; // Giá vốn hàng bán
    
    @Column({ name: 'operating_expenses', type: 'decimal', precision: 18, scale: 2 })
    operatingExpenses: number; // Chi phí vận hành (lương, thuê MP, điện nước...)
    
    @Column({ name: 'net_profit', type: 'decimal', precision: 18, scale: 2 })
    netProfit: number; // Lợi nhuận ròng
    
    @Column({ name: 'gross_margin_pct', type: 'decimal', precision: 5, scale: 2 })
    grossMarginPct: number; // %
}
```

**Cách tính tự động:**
- `totalRevenue` = SUM(sales_orders.total_amount) where orderDate in period
- `cogs` = SUM(sales_order_items.cost_price * quantity)
- `operatingExpenses` = SUM(cash_transactions.amount) where type='EXPENSE'
- `netProfit` = totalRevenue - cogs - operatingExpenses

---

### 3. **Thiếu: Báo Cáo Tồn Kho Chi Tiết (Stock Report)**
**Mức độ:** 🟡 HIGH

**Vấn đề:**
- Có `inventory_stocks` nhưng thiếu báo cáo phân tích tồn kho theo thời gian.
- Cần: **Tồn đầu kỳ, Nhập kỳ, Xuất kỳ, Tồn cuối kỳ, Tốc độ luân chuyển**.
- Cần phát hiện hàng chậm luân chuyển, hàng cận date để xả kho.

**Gợi ý fix:**
```typescript
// API endpoint: GET /inventory/stock-report?from=2026-04-01&to=2026-04-30
// Response: Chi tiết từng sản phẩm với metrics:
{
    productId: 1,
    productName: "Gạo thơm",
    openingQty: 100,       // Tồn đầu kỳ
    purchaseQty: 500,      // Nhập trong kỳ
    saleQty: 400,          // Bán trong kỳ
    closingQty: 200,       // Tồn cuối kỳ
    daysInStock: 25,       // Số ngày tồn kho
    turnoverRate: 2,       // Tốc độ luân chuyển (annual)
    avgValue: 50000,       // Giá trung bình
    totalValue: 10000000,  // Giá trị tồn kho cuối kỳ
    status: "FAST_MOVING" | "SLOW_MOVING" | "DEAD_STOCK"
}
```

---

### 4. **Thiếu: Báo Cáo Công Nợ Chi Tiết (Aging Report)**
**Mức độ:** 🟡 HIGH

**Vấn đề:**
- Có `receivables` nhưng thiếu "Phân tích tuổi nợ" (Aging Analysis).
- Cần phân nhóm: Nợ <30 ngày, 31-60 ngày, 61-90 ngày, >90 ngày.
- Quan trọng cho quyết định chiến lược thu nợ.

**Gợi ý fix:**
```typescript
// API endpoint: GET /customers/debt-aging?asOf=2026-04-21
// Response: Aging Analysis
{
    customers: [
        {
            customerId: 1,
            customerName: "Cửa hàng ABC",
            total: 10000000,
            current: 3000000,        // <30 ngày
            past30: 2000000,         // 31-60 ngày
            past60: 3000000,         // 61-90 ngày
            past90: 2000000,         // >90 ngày
            lastPaymentDate: "2026-04-10",
            overdueDays: 11
        }
    ],
    summary: {
        totalDebt: 50000000,
        currentRatio: 0.30,          // %
        overdueRatio: 0.60           // %
    }
}
```

---

### 5. **Thiếu: So Sánh Đầu Vào / Đầu Ra Hóa Đơn**
**Mức độ:** 🟡 HIGH

**Vấn đề:**
- Theo lưu ý trong tài liệu: **"Phải đối chiếu cân bằng giữa đầu vào và đầu ra"**.
- Nếu đầu vào cao hơn nhiều, cơ quan thuế nghi ngờ "tồn kho ảo".
- Nếu xuất hóa đơn mà không có đầu vào, bị phạt "xuất khống".
- Hiện tại không có báo cáo này.

**Gợi ý fix:**
```typescript
// API endpoint: GET /finance/invoice-reconciliation?month=04&year=2026
// Response:
{
    period: "04/2026",
    inbound: {
        count: 45,
        totalValue: 500000000,
        avgUnitPrice: 11111111
    },
    outbound: {
        count: 80,
        totalValue: 600000000,
        avgUnitPrice: 7500000
    },
    analysis: {
        inboundVsOutbound: "Đầu vào <= Đầu ra ✅",
        suspiciousPattern: null,
        recommendation: "Hợp lý"
    }
}
```

---

### 6. **Thiếu: Thông Báo & Nhắc Nhở (Reminders & Notifications)**
**Mức độ:** 🟡 HIGH

**Vấn đề:**
- Có field `reminderEnabled` & `lastReminderAt` trong Receivable, nhưng không thấy service xử lý.
- Cần: **Nhắc nhở nợ quá hạn, nhắc nhở hạn nộp thuế, cảnh báo hàng tồn kho lâu**.

**Gợi ý fix:**
- Thêm service `notification.service.ts` với scheduler:
  - **Hàng ngày 08:00:** Gửi thông báo nợ quá hạn (>7 ngày)
  - **Hàng tuần:** Cảnh báo hàng tồn kho >60 ngày
  - **Ngày 15 hàng tháng:** Nhắc nộp thuế (nếu sắp đến hạn)

---

### 7. **Thiếu: Kiểm Soát Tiền Mặt vs Tiền Ngân Hàng**
**Mức độ:** 🟡 HIGH

**Vấn đề:**
- Có `cash_accounts` nhưng chỉ lưu `balance`, không có "sao kê ngân hàng" thực tế.
- Theo Thông tư 25/2025/TT-NHNN: **Tên tài khoản phải khớp tên HKD**, nhưng không có xác thực này.
- Cần reconcile daily: `expected_balance` (từ sổ) vs `actual_balance` (từ ngân hàng).

**Gợi ý fix:**
```typescript
@Entity('bank_reconciliations')
export class BankReconciliation {
    @PrimaryGeneratedColumn()
    id: number;
    
    @Column({ name: 'account_id' })
    accountId: number;
    
    @Column({ name: 'reconciliation_date', type: 'date' })
    reconciliationDate: Date;
    
    @Column({ name: 'book_balance', type: 'decimal', precision: 18, scale: 2 })
    bookBalance: number; // Số dư theo sổ
    
    @Column({ name: 'bank_balance', type: 'decimal', precision: 18, scale: 2 })
    bankBalance: number; // Số dư theo ngân hàng
    
    @Column({ name: 'difference', type: 'decimal', precision: 18, scale: 2 })
    difference: number; // = bookBalance - bankBalance
    
    @Column({ type: 'json' })
    reconciliationItems: Array<{
        itemId: number,
        description: string,
        amount: number,
        type: 'OUTSTANDING_CHECK' | 'DEPOSIT_IN_TRANSIT' | 'BANK_ERROR' | 'BOOK_ERROR'
    }>;
}
```

---

### 8. **Thiếu: Audit Trail & Lịch Sử Thay Đổi**
**Mức độ:** 🟡 MEDIUM

**Vấn đề:**
- Hầu hết bảng có `created_by`, `updated_at`, nhưng **không có lịch sử thay đổi chi tiết**.
- Khi tranh chấp hoặc kiểm tra thuế, cần biết "ai đó thay đổi gì lúc nào".
- Hiện tại không lưu trữ các giá trị cũ.

**Gợi ý fix:**
```typescript
@Entity('audit_logs')
export class AuditLog {
    @PrimaryGeneratedColumn()
    id: number;
    
    @Column({ length: 100 })
    entity: string; // 'sales_order', 'invoice', 'receivable'...
    
    @Column()
    entityId: number;
    
    @Column({ length: 50 })
    action: string; // 'CREATE', 'UPDATE', 'DELETE'
    
    @Column({ type: 'json' })
    oldValue: any;
    
    @Column({ type: 'json' })
    newValue: any;
    
    @Column({ name: 'changed_by' })
    changedBy: number;
    
    @CreateDateColumn({ name: 'changed_at' })
    changedAt: Date;
}
```

---

### 9. **Thiếu: Export Báo Cáo (Excel / PDF)**
**Mức độ:** 🟡 MEDIUM

**Vấn đề:**
- Không có API hoặc tính năng xuất báo cáo ra Excel/PDF.
- HKD cần xuất "Báo cáo lãi lỗ", "Danh sách công nợ", "Sổ quỹ" để in hay gửi cơ quan thuế.

**Gợi ý fix:**
- Thêm dependencies: `npm install --save xlsx pdfkit`
- Tạo service `report-export.service.ts` với các hàm:
  - `exportPnLToExcel(period)`
  - `exportInventoryToExcel(warehouseId, asOf)`
  - `exportDebtAgingToPdf(asOf)`

---

### 10. **Thiếu: Xác Thực / Phê Duyệt Workflow**
**Mức độ:** 🟡 MEDIUM

**Vấn đề:**
- Các giao dịch quan trọng (nợ tây, mua hàng không hóa đơn) có field `approvedBy`, nhưng **không có workflow**.
- Cần: Tạo → Chờ duyệt → Duyệt/Từ chối → Ghi nhận.
- Không có API để "Phê duyệt" hoặc "Từ chối".

**Gợi ý fix:**
```typescript
// Thêm trạng thái approval:
@Entity('purchases_without_invoice')
export class PurchaseWithoutInvoice {
    // ...existing fields...
    
    @Column({ 
        name: 'approval_status',
        length: 20, 
        default: 'PENDING' 
    })
    approvalStatus: string; // PENDING, APPROVED, REJECTED
    
    @Column({ name: 'approval_notes', length: 500, nullable: true })
    approvalNotes: string;
    
    @Column({ name: 'approved_at', nullable: true })
    approvedAt: Date;
}

// API endpoint: POST /purchases/without-invoice/{id}/approve
// Body: { approvalNotes?: string }
```

---

### 11. **Thiếu: Cảnh báo Hạn mức Tín dụng (Credit Limit)**
**Mức độ:** 🟟 MEDIUM

**Vấn đề:**
- Có field `credit_limit` trong Customer, nhưng không validate khi bán hàng.
- Nên cảnh báo khi giao dịch vượt hạn mức.

**Gợi ý fix:**
```typescript
// Trong SalesOrderService.createOrder():
const customer = await customerRepo.findOne(customerId);
const totalDebt = customer.balance + newOrderAmount;

if (totalDebt > customer.creditLimit) {
    throw new BadRequestException(
        `Tổng nợ (${totalDebt}) vượt quá hạn mức tín dụng (${customer.creditLimit})`
    );
}
```

---

### 12. **Thiếu: Ảnh Hóa Đơn Chưa Được OCR / Extract**
**Mức độ:** 🟟 MEDIUM

**Vấn đề:**
- Có field `imageUrl` trong Invoice và CashTransaction, nhưng **không tự động extract dữ liệu**.
- Nên dùng Tesseract OCR để đọc số hóa đơn, tổng tiền từ ảnh tự động (nếu có thể).

**Gợi ý fix (Tương lai):**
- Thêm integration với service OCR (Google Cloud Vision hoặc Tesseract.js)
- Khi upload ảnh, tự động extract: số hóa đơn, ngày, tổng tiền, tên đối tác

---

### 13. **Thiếu: Báo Cáo Nhân Viên (Staff Performance)**
**Mức độ:** 🟟 LOW (Tùy chọn)

**Vấn đề:**
- Có `createdBy` nhưng không có báo cáo doanh số theo nhân viên.
- HKD có nhân viên thì cần biết "Nhân viên nào bán bao nhiêu, lợi nhuận bao nhiêu".

**Gợi ý fix:**
```typescript
// API endpoint: GET /reports/staff-performance?month=04&year=2026
// Response: Danh sách nhân viên với metrics
{
    staffId: 1,
    staffName: "Nguyễn Văn A",
    totalOrders: 50,
    totalSales: 100000000,
    avgOrderValue: 2000000,
    profitGenerated: 20000000,
    returnRate: 0.05  // 5%
}
```

---

## 📋 BẢNG TỔNG HỢP YÊU CẦU HKD vs TÍNH NĂNG

| Yêu cầu | Tính năng | Status | Ghi chú |
|--------|----------|--------|---------|
| **Quản lý Bán Hàng** | SalesOrder | ✅ | Hoàn thành |
| **Quản lý Kho** | Inventory | ✅ | Hoàn thành |
| **Quản lý Tiền Mặt** | CashTransaction | ✅ | Hoàn thành |
| **Quản lý Hóa Đơn** | Invoice | ✅ | Hoàn thành |
| **Quản lý Thuế** | TaxObligation | ✅ | Cơ bản |
| **Mua Hàng Không HĐ (Mẫu 01)** | PurchaseWithoutInvoice | ⚠️ | **Thiếu chi tiết hàng hóa** |
| **Báo Cáo Lãi/Lỗ (P&L)** | ProfitLossReport | ❌ | **KHÔNG CÓ** |
| **Báo Cáo Tồn Kho** | Stock Aging Report | ❌ | **KHÔNG CÓ** |
| **Phân Tích Tuổi Nợ** | Debt Aging Report | ❌ | **KHÔNG CÓ** |
| **Đối Chiếu Đầu Vào/Ra** | Invoice Reconciliation | ❌ | **KHÔNG CÓ** |
| **Thông Báo & Nhắc Nhở** | Notifications | ❌ | **KHÔNG CÓ** |
| **Kiểm Soát Ngân Hàng** | Bank Reconciliation | ❌ | **KHÔNG CÓ** |
| **Audit Trail** | Audit Logs | ⚠️ | Có `createdBy` nhưng **không lịch sử thay đổi chi tiết** |
| **Export Báo Cáo** | Report Export | ❌ | **KHÔNG CÓ** |
| **Phê Duyệt Workflow** | Approval Process | ⚠️ | Có field nhưng **không API** |
| **Cảnh Báo Tín Dụng** | Credit Limit Check | ❌ | **KHÔNG CÓ** |

---

## 🎯 ĐỀ XUẤT HƯỚNG ĐI CHÍNH XÁC

### **Phase 1: CẤP BÁCH (2-3 tuần)**
1. ✅ Thêm chi tiết hàng hóa cho mua không hóa đơn (`PurchaseWithoutInvoiceItem`)
2. ✅ Tạo API Báo cáo lãi/lỗ (P&L)
3. ✅ Tạo API Phân tích tuổi nợ (Debt Aging)
4. ✅ Validate hạn mức tín dụng khi tạo đơn hàng

**Lý do:** Những báo cáo này là yêu cầu **cơ bản nhất** để HKD hiểu rõ tình hình kinh doanh.

---

### **Phase 2: QUAN TRỌNG (3-4 tuần)**
1. ✅ Tạo Audit Trail (lưu lịch sử thay đổi)
2. ✅ Thêm Workflow phê duyệt (Pending → Approved/Rejected)
3. ✅ Tạo báo cáo tồn kho chi tiết (Stock Aging)
4. ✅ Thêm API so sánh đầu vào/đầu ra hóa đơn
5. ✅ Implement notification service (nhắc nợ, cảnh báo hạn thuế)

**Lý do:** Tính hợp pháp, kiểm soát, và tuân thủ thuế.

---

### **Phase 3: TĂNG CƯỜNG (4-6 tuần)**
1. ✅ Bank Reconciliation (đối chiếu tài khoản)
2. ✅ Export báo cáo (Excel/PDF)
3. ✅ Staff Performance Report (nếu có nhân viên)
4. ✅ OCR ảnh hóa đơn (nâng cao)

**Lý do:** Hoàn thiện hệ thống & trải nghiệm người dùng.

---

## 🔐 CÁC LƯU Ý VỀ PHÁP LÝ & TUÂN THỨ

### 1. **Thông tư 25/2025/TT-NHNN (Từ 01/03/2026)** ⚠️
- ✅ **Yêu cầu:** Tên tài khoản thanh toán **PHẢI khớp** với tên đăng ký HKD
- ✅ **Cách fix:** Thêm xác thực tên tài khoản khi setup account
- ✅ **Implement:** Trong `onboarding_screen` hoặc `settings`, yêu cầu user nhập tên HKD và xác minh với tên tài khoản ngân hàng

### 2. **Mẫu 01/TNDN (Mua Nông Sản Không HĐ)**
- ✅ **Yêu cầu:** Bắt buộc CCCD/CMT người bán, chữ ký, mức giá thị trường
- ✅ **Cách fix:** Đã có nhưng **cần thêm chi tiết hàng hóa**

### 3. **Lưu Trữ Hóa Đơn**
- ✅ **Yêu cầu:** Lưu trữ **tối thiểu 10 năm**
- ✅ **Cách fix:** Backend đã có, nhưng cần xác nhận độ bền dữ liệu (Supabase PostgreSQL)

### 4. **Tiền Công Lẫn Tiền Tư**
- ✅ **Yêu cầu:** Tách riêng tài khoản kinh doanh & tài khoản cá nhân
- ✅ **Cách fix:** Hướng dẫn user trong app: "Sử dụng tài khoản ngân hàng riêng cho kinh doanh"

---

## 💡 CÁC KHUYẾN NGHỊ THIẾT KẾ HỆ THỐNG

### 1. **Database Normalization**
- ✅ Schema hiện tại tốt, nhưng cần thêm views cho các báo cáo phức tạp
- Ví dụ: `v_monthly_sales_summary`, `v_inventory_movement_detail`

### 2. **Performance Optimization**
- ✅ Thêm indexes cho các trường tìm kiếm thường xuyên
  - `invoices.invoiceDate`
  - `receivables.dueDate`
  - `cash_transactions.transactionDate`
  - `sales_orders.orderDate`

### 3. **API Response Format**
- ✅ Đảm bảo consistent format (hiện tại có vẻ ổn)
- Khuyến nghị: Luôn include `metadata` (pagination, timestamp, etc.)

### 4. **Error Handling**
- ⚠️ Cần kiểm tra: Có xử lý lỗi cụ thể (VD: "Sản phẩm hết hàng", "Vượt hạn mức tín dụng") không?

### 5. **Real-time Updates**
- ⚠️ Nếu nhiều nhân viên dùng cùng lúc, cần WebSocket hoặc Polling để sync dữ liệu

---

## 📊 TÓMAI

| Khía cạch | Điểm |
|----------|------|
| **Quản lý bán hàng** | 9/10 ✅ |
| **Quản lý kho** | 8/10 ✅ |
| **Quản lý tài chính** | 6/10 ⚠️ |
| **Báo cáo & phân tích** | 4/10 ❌ |
| **Tuân thủ pháp lý** | 7/10 ⚠️ |
| **UX/Dễ sử dụng** | 8/10 ✅ |
| **Hiệu suất & bảo mật** | 7/10 ⚠️ |
| **---** | **---** |
| **TỔNG ĐIỂM** | **6.4/10** |

---

## 🚀 KẾT LUẬN

**Ứng dụng hiện tại đã đáp ứng ~70% yêu cầu cơ bản của HKD.** Tuy nhiên, còn thiếu các báo cáo phân tích quan trọng (P&L, Aging, Stock Report) mà HKD cần hàng ngày để quản lý kinh doanh.

**Khuyến nghị ưu tiên:** Hoàn thiện Phase 1 trong 2-3 tuần để ứng dụng trở nên có giá trị thực tế, sau đó tiếp tục Phase 2 & 3.

---

## 📝 DANH SÁCH CÔNG VIỆC CHI TIẾT (TODO)

- [ ] **Backend:**
  - [ ] Thêm entity `PurchaseWithoutInvoiceItem`
  - [ ] Thêm entity `ProfitLossReport` + API tính toán
  - [ ] Thêm API `/customers/debt-aging`
  - [ ] Thêm validation credit limit
  - [ ] Thêm API `/finance/invoice-reconciliation`
  - [ ] Thêm entity `AuditLog`
  - [ ] Thêm approval workflow
  - [ ] Thêm NotificationService (scheduler)
  
- [ ] **Frontend:**
  - [ ] Tạo screen "Báo cáo Lãi/Lỗ"
  - [ ] Tạo screen "Phân tích Công Nợ"
  - [ ] Tạo screen "Báo Cáo Tồn Kho"
  - [ ] Tạo screen "Xuất Báo Cáo"
  - [ ] Thêm push notification UI
  
- [ ] **Testing & Deployment:**
  - [ ] Unit test cho tính toán P&L
  - [ ] Integration test cho reconciliation
  - [ ] E2E test cho workflow phê duyệt
  - [ ] Performance test trên Vercel

---

**Đánh giá được thực hiện ngày 21/04/2026**
**Phiên bản ứng dụng: 1.0.0 (Initial Release)**


