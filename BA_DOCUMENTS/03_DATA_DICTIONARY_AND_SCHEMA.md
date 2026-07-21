# THIẾT KẾ CƠ SỞ DỮ LIỆU & TÀI LIỆU TỪ ĐIỂN DỮ LIỆU (DATA DICTIONARY & SCHEMA)
## Hệ thống SmartStock FinTech - Quản lý Bán hàng & Hỗ trợ Cảnh báo Thuế

---

## 1. Kiểm soát phiên bản (Version Control)

| Phiên bản | Ngày | Người thực hiện | Nội dung thay đổi | Trạng thái |
| :--- | :--- | :--- | :--- | :--- |
| v1.0.0 | 2026-07-21 | Senior Business Analyst | Khởi tạo tài liệu Từ điển dữ liệu & Database Schema | Hoàn thành |
| v1.1.0 | 2026-07-21 | Senior Business Analyst | Cập nhật bổ sung 100% bảng nghiệp vụ: Công nợ, Quỹ tiền, Chốt ca | Hoàn thành |

---

## 2. Sơ Đồ Mối Quan Hệ Thực Thể Hệ Thống (Exhaustive ERD)

```
                       [users] ──(1:N)── [shop_members] ──(N:1)── [shop_profiles]
                                              │ (N:1)
                                         [shop_roles]
                       
[shop_profiles] ──(1:N)── [products] ──(N:1)── [categories]
                                │ (1:N)
                         [product_batches]
                         [product_cost_items] ──(N:1)── [cost_types]
                         [unit_conversions]
                         [product_price_history]

[shop_profiles] ──(1:N)── [customers] ──(1:N)── [receivables] ──(1:N)── [debt_evidences]
                                                     │ (1:N)
                                                [debt_payment_history]

[shop_profiles] ──(1:N)── [invoices] ──(1:N)── [invoice_items] ──(N:1)── [products]
[shop_profiles] ──(1:N)── [purchases_without_invoice] ──(1:N)── [purchase_without_invoice_items]

[shop_profiles] ──(1:N)── [cash_accounts] ──(1:N)── [cash_transactions]
[shop_profiles] ──(1:N)── [budget_plans]
[shop_profiles] ──(1:N)── [cashflow_forecasts]
[shop_profiles] ──(1:N)── [daily_closings]
[shop_profiles] ──(1:N)── [tax_obligations]
[shop_profiles] ──(1:N)── [activity_logs]
[shop_profiles] ──(1:N)── [invoice_scans]
[shop_profiles] ──(1:N)── [tags]
```

---

## 3. Danh Sách Chi Tiết Từ Điển Dữ Liệu 18 Bảng Hệ Thống

---

### PHÂN HỆ 1: TÀI KHOẢN & HR (AUTH & MEMBERS)

#### 3.1. Bảng `users` (Thông tin tài khoản)
- **Tên Entity:** `User` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/auth/entities.ts))
- **Mô tả:** Lưu trữ thông tin định danh, tài khoản người dùng đăng nhập hệ thống.

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK`, `AUTO_INCREMENT` | Mã định danh duy nhất. |
| `username` | `VARCHAR(255)` | `UNIQUE`, `NOT NULL` | Tên đăng nhập độc nhất. |
| `password` | `VARCHAR(255)` | `NOT NULL` | Chuỗi mã hóa bcrypt mật khẩu. |
| `full_name` | `VARCHAR(255)` | `NOT NULL` | Họ và tên người dùng. |
| `email` | `VARCHAR(255)` | `NULLABLE` | Địa chỉ email đăng ký nhận OTP. |
| `phone` | `VARCHAR(255)` | `NULLABLE` | Số điện thoại liên lạc. |
| `role` | `VARCHAR(50)` | `DEFAULT 'STAFF'` | Vai trò hệ thống chung. |
| `avatar_url` | `VARCHAR(1000)` | `NULLABLE` | Đường dẫn ảnh đại diện. |
| `is_active` | `BOOLEAN` | `DEFAULT true` | Kích hoạt hay bị khóa. |
| `is_onboarded` | `BOOLEAN` | `DEFAULT false` | Đã qua bước onboarding. |
| `account_type` | `VARCHAR(20)` | `DEFAULT 'PERSONAL'` | Phân loại (`SHOP` chủ \| `PERSONAL` nhân viên). |

#### 3.2. Bảng `shop_profiles` (Thông tin hộ kinh doanh/cửa hàng)
- **Tên Entity:** `ShopProfile` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/system/entities.ts))
- **Mô tả:** Lưu trữ thông tin pháp lý và cấu hình thuế của cửa hàng.

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK`, `AUTO_INCREMENT` | Mã định danh cửa hàng. |
| `shop_name` | `VARCHAR(200)` | `NOT NULL` | Tên cửa hàng/Hộ kinh doanh. |
| `shop_code` | `VARCHAR(20)` | `UNIQUE`, `NULLABLE` | Mã định danh duy nhất của shop để gia nhập. |
| `tax_code` | `VARCHAR(20)` | `NULLABLE` | Mã số thuế hộ kinh doanh. |
| `address` | `VARCHAR(500)` | `NULLABLE` | Địa chỉ đăng ký (dropdown chuẩn hóa). |
| `bank_account` | `VARCHAR(30)` | `NULLABLE` | Số tài khoản ngân hàng nhận tiền. |
| `bank_id` | `VARCHAR(20)` | `NULLABLE` | Mã ngân hàng nhận. |
| `bank_name` | `VARCHAR(100)` | `NULLABLE` | Tên ngân hàng giao dịch. |
| `account_holder` | `VARCHAR(200)` | `NULLABLE` | Tên chủ sở hữu tài khoản. |
| `owner_name` | `VARCHAR(200)` | `NULLABLE` | Họ tên chủ hộ đăng ký (theo TT 88). |
| `owner_identity_number`| `VARCHAR(20)` | `NULLABLE` | Số CCCD chủ hộ kinh doanh. |
| `costing_method` | `VARCHAR(10)` | `DEFAULT 'AVG'` | Phương pháp tính giá vốn (`FIFO` \| `AVG`). |
| `business_sector` | `VARCHAR(50)` | `DEFAULT 'TRADE'` | Ngành nghề kinh doanh (`TRADE` \| `SERVICE` \| `PRODUCTION`). |
| `apply_vat_reduction` | `BOOLEAN` | `DEFAULT false` | Có áp dụng giảm VAT 20% của nhà nước. |
| `custom_vat_rate` | `DECIMAL(5,2)` | `NULLABLE` | Thuếu suất VAT tùy biến. |
| `custom_pit_rate` | `DECIMAL(5,2)` | `NULLABLE` | Thuếu suất PIT tùy biến. |

#### 3.3. Bảng `shop_members` (Quan hệ nhân sự)
- **Tên Entity:** `ShopMember` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/shop/entities.ts))

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK`, `AUTO_INCREMENT` | Mã định danh quan hệ. |
| `shop_id` | `INT` | `FK` -> `shop_profiles(id)` | Liên kết tới shop. |
| `user_id` | `INT` | `FK` -> `users(id)` | Liên kết tới user. |
| `role_id` | `INT` | `FK` -> `shop_roles(id)` | Liên kết tới vai trò chi tiết. |
| `member_type` | `VARCHAR(20)` | `DEFAULT 'EMPLOYEE'` | Phân loại (`OWNER` \| `EMPLOYEE`). |
| `status` | `VARCHAR(20)` | `DEFAULT 'PENDING'` | Trạng thái xét duyệt (`PENDING` \| `ACTIVE`). |

---

### PHÂN HỆ 2: HÀNG HÓA & KHO VẬN (PRODUCTS & INVENTORY)

#### 3.4. Bảng `products` (Danh mục hàng hóa)
- **Tên Entity:** `Product` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/product/entities.ts))

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK`, `AUTO_INCREMENT` | Mã định danh sản phẩm. |
| `sku` | `VARCHAR(50)` | `UNIQUE`, `NOT NULL` | Mã quản lý nội bộ. |
| `shop_id` | `INT` | `FK` -> `shop_profiles(id)` | Thuộc shop nào. |
| `name` | `VARCHAR(200)` | `NOT NULL` | Tên sản phẩm. |
| `cost_price` | `DECIMAL(18,2)` | `DEFAULT 0.00` | Giá vốn trung bình. |
| `selling_price` | `DECIMAL(18,2)` | `DEFAULT 0.00` | Giá bán lẻ mặc định. |
| `tax_rate` | `DECIMAL(5,2)` | `DEFAULT 0.00` | Thuế suất áp dụng (%) |
| `min_stock` | `INT` | `DEFAULT 0` | Ngưỡng cảnh báo tồn kho tối thiểu. |
| `barcode` | `VARCHAR(50)` | `NULLABLE` | Mã vạch sản phẩm (độc nhất). |
| `tags` | `TEXT` | `NULLABLE` | Mảng nhãn phân loại (comma-separated). |

#### 3.5. Bảng `purchase_orders` (Đơn đặt hàng nhà cung cấp)
- **Tên Entity:** `PurchaseOrder` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/inventory/entities.ts))

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK`, `AUTO_INCREMENT` | Mã định danh đơn PO. |
| `shop_id` | `INT` | `FK` -> `shop_profiles(id)` | Thuộc shop nào. |
| `po_number` | `VARCHAR(50)` | `UNIQUE`, `NOT NULL` | Số chứng từ đặt hàng. |
| `supplier_id` | `INT` | `FK` -> `suppliers(id)` | Liên kết nhà cung cấp. |
| `total_amount` | `DECIMAL(18,2)` | `DEFAULT 0.00` | Tổng giá trị đơn hàng. |
| `status` | `VARCHAR(20)` | `DEFAULT 'PENDING'` | Trạng thái (`PENDING` \| `APPROVED` \| `RECEIVED`). |

#### 3.6. Bảng `stocktakes` (Phiếu kiểm kê kho)
- **Tên Entity:** `Stocktake` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/inventory/entities.ts))

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK`, `AUTO_INCREMENT` | Mã định danh phiếu kiểm kho. |
| `shop_id` | `INT` | `FK` -> `shop_profiles(id)` | Thuộc shop nào. |
| `recorded_at` | `TIMESTAMP` | `NOT NULL` | Ngày kiểm kê. |
| `notes` | `VARCHAR(500)` | `NULLABLE` | Ghi chú lý do kiểm kho. |

---

### PHÂN HỆ 3: GIAO DỊCH & HÓA ĐƠN (SALES & INVOICES)

#### 3.7. Bảng `invoices` (Hóa đơn mua/bán)
- **Tên Entity:** `Invoice` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/system/entities.ts))

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK` | Mã định danh hóa đơn. |
| `invoice_number` | `VARCHAR(50)` | `NOT NULL` | Số hóa đơn chính thức. |
| `invoice_symbol` | `VARCHAR(20)` | `NULLABLE` | Ký hiệu hóa đơn. |
| `shop_id` | `INT` | `FK` | Thuộc cửa hàng. |
| `invoice_type` | `VARCHAR(10)` | `NOT NULL` | Phân loại (`IN` mua vào \| `OUT` bán ra). |
| `partner_name` | `VARCHAR(200)` | `NOT NULL` | Tên đối tác (Khách hàng/NCC). |
| `total_amount` | `DECIMAL(18,2)` | `DEFAULT 0.00` | Tổng thanh toán hóa đơn. |
| `payment_method` | `VARCHAR(20)` | `NULLABLE` | `CASH` (Tiền mặt) \| `TRANSFER` (Chuyển khoản). |

#### 3.8. Bảng `invoice_items` (Mặt hàng hóa đơn chi tiết)
- **Tên Entity:** `InvoiceItem` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/system/entities.ts))

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK` | Mã chi tiết dòng. |
| `invoice_id` | `INT` | `FK` -> `invoices(id)` | Thuộc hóa đơn nào. |
| `product_id` | `INT` | `FK` -> `products(id)` | Liên kết tới sản phẩm hệ thống. |
| `quantity` | `INT` | `NOT NULL` | Số lượng mua/bán. |
| `unit_price` | `DECIMAL(18,2)` | `NOT NULL` | Đơn giá dòng hàng. |

---

### PHÂN HỆ 4: CÔNG NỢ KHÁCH HÀNG (RECEIVABLES)

#### 3.9. Bảng `customers` (Danh sách khách hàng)
- **Tên Entity:** `Customer` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/customer/entities.ts))

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK`, `AUTO_INCREMENT` | Mã định danh khách hàng. |
| `code` | `VARCHAR(20)` | `UNIQUE` | Mã khách hàng quản lý. |
| `shop_id` | `INT` | `FK` -> `shop_profiles(id)` | Thuộc shop nào. |
| `name` | `VARCHAR(200)` | `NOT NULL` | Họ tên khách hàng. |
| `balance` | `DECIMAL(18,2)` | `DEFAULT 0.00` | Số dư công nợ lũy kế hiện tại (Nợ cần thu). |

#### 3.10. Bảng `receivables` (Sổ theo dõi nợ phải thu)
- **Tên Entity:** `Receivable` (Định nghĩa tại: [entities.ts:///d:/StockManagementAndTaxWarning/backend/src/customer/entities.ts])

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK` | Mã khoản nợ. |
| `customer_id` | `INT` | `FK` -> `customers(id)` | Thuộc khách hàng nào nợ. |
| `amount` | `DECIMAL(18,2)` | `NOT NULL` | Tổng tiền nợ phát sinh. |
| `paid_amount` | `DECIMAL(18,2)` | `DEFAULT 0.00` | Số tiền đã trả. |
| `status` | `VARCHAR(20)` | `DEFAULT 'UNPAID'` | Trạng thái (`UNPAID` \| `PARTIAL` \| `PAID`). |

#### 3.11. Bảng `debt_evidences` (Minh chứng công nợ)
- **Tên Entity:** `DebtEvidence` (Định nghĩa tại: [entities.ts:///d:/StockManagementAndTaxWarning/backend/src/customer/entities.ts])

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK` | Mã minh chứng. |
| `receivable_id` | `INT` | `FK` -> `receivables(id)` | Thuộc khoản nợ nào. |
| `type` | `VARCHAR(20)` | `NOT NULL` | Loại minh chứng (`PHOTO` \| `SIGNATURE` \| `AUDIO` \| `CONTRACT`). |
| `file_url` | `VARCHAR(1000)` | `NOT NULL` | Đường dẫn tệp minh chứng lưu trữ. |

#### 3.12. Bảng `debt_payment_history` (Lịch sử thanh toán nợ)
- **Tên Entity:** `DebtPaymentHistory` (Định nghĩa tại: [entities.ts:///d:/StockManagementAndTaxWarning/backend/src/customer/entities.ts])

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK` | Mã lượt trả nợ. |
| `receivable_id` | `INT` | `FK` -> `receivables(id)` | Trả cho khoản nợ nào. |
| `amount` | `DECIMAL(18,2)` | `NOT NULL` | Số tiền trả lần này. |
| `payment_date` | `DATE` | `NOT NULL` | Ngày trả. |

---

### PHÂN HỆ 5: QUỸ TIỀN & BÁO CÁO THUẾ (FINANCE & TAX)

#### 3.13. Bảng `cash_accounts` (Tài khoản/Quỹ tiền mặt)
- **Tên Entity:** `CashAccount` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/finance/entities.ts))

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK` | Mã quỹ tiền. |
| `name` | `VARCHAR(100)` | `NOT NULL` | Tên ví/Quỹ (Ví dụ: Két tiền mặt, Ví ngân hàng). |
| `balance` | `DECIMAL(18,2)` | `DEFAULT 0.00` | Số dư khả dụng hiện tại. |

#### 3.14. Bảng `cash_transactions` (Lịch sử giao dịch quỹ tiền)
- **Tên Entity:** `CashTransaction` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/finance/entities.ts))

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK` | Mã giao dịch. |
| `transaction_code` | `VARCHAR(20)` | `UNIQUE` | Mã chứng từ thu/chi. |
| `type` | `VARCHAR(10)` | `NOT NULL` | Phân loại (`INCOME` Thu \| `EXPENSE` Chi). |
| `category` | `VARCHAR(50)` | `NOT NULL` | Nhóm (`SALES`, `PURCHASE`, `SALARY`, `RENT`...). |
| `amount` | `DECIMAL(18,2)` | `NOT NULL` | Số tiền giao dịch. |
| `account_id` | `INT` | `FK` -> `cash_accounts(id)` | Thuộc quỹ nào bị biến động số dư. |

#### 3.15. Bảng `purchases_without_invoice` & `items` (Bảng kê Mẫu 01/TNDN)
- **Tên Entity:** `PurchaseWithoutInvoice` & `PurchaseWithoutInvoiceItem` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/finance/entities.ts))
- **Mô tả:** Ghi nhận bảng kê mua hàng nông, lâm, thủy sản tự khai thác không có hóa đơn GTGT.

**Chi tiết các cột trong bảng purchases_without_invoice (Bảng kê gốc):**
- `id` (PK, INT)
- `record_code` (VARCHAR(20), UNIQUE): Số bảng kê quản lý.
- `seller_name` (VARCHAR(200)): Họ tên người sản xuất trực tiếp bán.
- `seller_identity_number` (VARCHAR(20)): Số CCCD người bán.
- `seller_address` (VARCHAR(500)): Địa chỉ người bán.
- `total_amount` (DECIMAL(18,2)): Tổng số tiền thanh toán thu mua.

**Chi tiết các cột trong bảng purchase_without_invoice_items (Mặt hàng chi tiết):**
- `id` (PK, INT)
- `purchase_id` (FK -> `purchases_without_invoice(id)`): Thuộc bảng kê nào.
- `product_name` (VARCHAR(200)): Tên loại nông, lâm, thủy sản mua.
- `quantity` (DECIMAL(18,3)): Số lượng mua.
- `unit_price` (DECIMAL(18,2)): Đơn giá thu mua.

#### 3.16. Bảng `daily_closings` (Chốt sổ hàng ngày)
- **Tên Entity:** `DailyClosing` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/finance/entities.ts))
- **Mô tả:** Kết ca, chốt doanh thu và quỹ tiền cuối ngày, đối chiếu chênh lệch tiền mặt thực tế và hệ thống.

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK` | Mã phiên chốt sổ. |
| `closing_date` | `DATE` | `NOT NULL` | Ngày chốt sổ kế toán. |
| `shop_id` | `INT` | `FK` | Thuộc cửa hàng. |
| `opening_cash` | `DECIMAL(18,2)` | `DEFAULT 0.00` | Số dư tiền đầu ngày. |
| `closing_cash` | `DECIMAL(18,2)` | `DEFAULT 0.00` | Số tiền mặt thực tế kiểm đếm cuối ngày. |
| `expected_cash` | `DECIMAL(18,2)` | `DEFAULT 0.00` | Số tiền mặt lý thuyết trên hệ thống. |
| `cash_difference` | `DECIMAL(18,2)` | `DEFAULT 0.00` | Số tiền chênh lệch thừa/thiếu. |
| `total_sales` | `DECIMAL(18,2)` | `DEFAULT 0.00` | Tổng doanh thu bán hàng trong ngày. |

#### 3.17. Bảng `tax_obligations` (Nghĩa vụ thuế declared)
- **Tên Entity:** `TaxObligation` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/finance/entities.ts))

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK` | Mã bản ghi. |
| `period` | `VARCHAR(20)` | `NOT NULL` | Kỳ tính thuế (Ví dụ: `Q1/2026`). |
| `vat_declared` | `DECIMAL(18,2)` | `DEFAULT 0.00` | Tiền thuế GTGT đã kê khai. |
| `pit_declared` | `DECIMAL(18,2)` | `DEFAULT 0.00` | Tiền thuế TNCN đã kê khai. |
| `vat_paid` | `DECIMAL(18,2)` | `DEFAULT 0.00` | Tiền thuế GTGT thực tế đã nộp kho bạc. |
| `status` | `VARCHAR(20)` | `DEFAULT 'pending'` | Trạng thái nộp thuế (`pending` \| `done`). |

#### 3.18. Bảng `activity_logs` (Nhật ký hệ thống)
- **Tên Entity:** `ActivityLog` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/system/entities.ts))

| Tên Cột (Database) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `INT` | `PK` | Mã nhật ký. |
| `user_id` | `INT` | `NOT NULL` | ID người thực hiện hành động. |
| `action` | `VARCHAR(50)` | `NOT NULL` | Thao tác (`CREATE` \| `UPDATE` \| `DELETE`...). |
| `entity_type` | `VARCHAR(50)` | `NOT NULL` | Loại bảng bị thay đổi (Ví dụ: `Product`). |
| `entity_name` | `VARCHAR(200)` | `NULLABLE` | Tên của bản ghi bị thay đổi (Ví dụ tên SP). |
| `description` | `VARCHAR(500)` | `NULLABLE` | Mô tả thân thiện bằng tiếng Việt (được xuất ra log cài đặt). |
| `created_at` | `TIMESTAMP` | `DEFAULT CURRENT` | Thời điểm phát sinh hành động. |
