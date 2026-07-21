# THIẾT KẾ CƠ SỞ DỮ LIỆU & TỪ ĐIỂN DỮ LIỆU (DATA DICTIONARY & SCHEMA)
## Hệ thống SmartStock FinTech - Quản lý Bán hàng & Hỗ trợ Cảnh báo Thuế

---

## 1. Kiểm soát phiên bản (Version Control)

| Phiên bản | Ngày | Người thực hiện | Nội dung thay đổi | Trạng thái |
| :--- | :--- | :--- | :--- | :--- |
| v1.0.0 | 2026-07-21 | Senior Business Analyst | Khởi tạo tài liệu Từ điển dữ liệu & Database Schema | Hoàn thành |

---

## 2. Mô Hình Mối Quan Hệ Thực Thể (Entity Relationship Diagram - ERD)

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

[shop_profiles] ──(1:N)── [invoices] ──(1:N)── [invoice_items]
                                                 │ (N:1)
                                            [products]

[shop_profiles] ──(1:N)── [activity_logs]
[shop_profiles] ──(1:N)── [invoice_scans]
[shop_profiles] ──(1:N)── [tags]
```

---

## 3. Danh Sách Các Bảng Chi Tiết (Detailed Data Dictionary)

---

### BẢNG 1: users (Thông tin tài khoản hệ thống)
- **Mô tả:** Lưu trữ thông tin định danh, mật khẩu băm và cấu hình cơ bản của toàn bộ người dùng trong hệ thống.
- **Tên Entity trong TypeORM:** `User` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/auth/entities.ts))

| Tên Cột (Database) | Tên Thuộc Tính (Code) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả Chi Tiết |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `id` | `INT` | `PK`, `AUTO_INCREMENT` | Định danh duy nhất người dùng. |
| `username` | `username` | `VARCHAR(255)` | `UNIQUE`, `NOT NULL` | Tên đăng nhập độc nhất. |
| `password` | `passwordHash` | `VARCHAR(255)` | `NOT NULL` | Chuỗi hash mật khẩu (băm bảo mật bcrypt). |
| `full_name` | `fullName` | `VARCHAR(255)` | `NOT NULL` | Họ và tên đầy đủ của người dùng. |
| `email` | `email` | `VARCHAR(255)` | `NULLABLE` | Địa chỉ email đăng ký/nhận OTP. |
| `phone` | `phone` | `VARCHAR(255)` | `NULLABLE` | Số điện thoại liên hệ. |
| `role` | `role` | `VARCHAR(50)` | `DEFAULT 'STAFF'` | Vai trò hệ thống chung (`ADMIN` \| `MANAGER` \| `STAFF`). |
| `avatar_url` | `avatarUrl` | `VARCHAR(1000)` | `NULLABLE` | Đường dẫn ảnh đại diện. |
| `is_active` | `isActive` | `BOOLEAN` | `DEFAULT true` | Trạng thái tài khoản (Kích hoạt / Khóa). |
| `is_onboarded` | `isOnboarded` | `BOOLEAN` | `DEFAULT false` | Đã điền thông tin shop ban đầu chưa. |
| `account_type` | `accountType` | `VARCHAR(20)` | `DEFAULT 'PERSONAL'` | Loại tài khoản (`SHOP` - Chủ shop \| `PERSONAL` - Nhân viên). |
| `created_at` | `createdAt` | `TIMESTAMP` | `DEFAULT CURRENT_TIMESTAMP`| Thời điểm khởi tạo tài khoản. |
| `updated_at` | `updatedAt` | `TIMESTAMP` | `DEFAULT CURRENT_TIMESTAMP`| Thời điểm cập nhật tài khoản gần nhất. |

---

### BẢNG 2: shop_profiles (Thông tin cửa hàng/Hộ kinh doanh)
- **Mô tả:** Lưu trữ thông tin pháp lý, mã số thuế, tài khoản ngân hàng, phương thức tính giá vốn và cấu hình tính thuế của cửa hàng/hộ kinh doanh.
- **Tên Entity trong TypeORM:** `ShopProfile` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/system/entities.ts))

| Tên Cột (Database) | Tên Thuộc Tính (Code) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả Chi Tiết |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `id` | `INT` | `PK`, `AUTO_INCREMENT` | Định danh duy nhất cửa hàng. |
| `shop_name` | `shopName` | `VARCHAR(200)` | `NOT NULL` | Tên của cửa hàng/thương hiệu. |
| `shop_id` | `shopId` | `INT` | `NULLABLE` | Liên kết nhóm shop (nếu có). |
| `shop_code` | `shopCode` | `VARCHAR(20)` | `UNIQUE`, `NULLABLE` | Mã số định danh duy nhất của shop để nhân viên tìm kiếm. |
| `logo_url` | `logoUrl` | `VARCHAR(1000)` | `NULLABLE` | Đường dẫn logo thương hiệu shop. |
| `phone` | `phone` | `VARCHAR(20)` | `NULLABLE` | Số điện thoại liên hệ của cửa hàng. |
| `address` | `address` | `VARCHAR(500)` | `NULLABLE` | Địa chỉ cụ thể (chuẩn hóa dạng Tỉnh/Thành dropdown). |
| `tax_code` | `taxCode` | `VARCHAR(20)` | `NULLABLE` | Mã số thuế hộ kinh doanh (để xuất XML HTKK). |
| `bank_account` | `bankAccount` | `VARCHAR(30)` | `NULLABLE` | Số tài khoản ngân hàng nhận tiền. |
| `bank_id` | `bankId` | `VARCHAR(20)` | `NULLABLE` | Mã định danh ngân hàng (theo Napas). |
| `bank_name` | `bankName` | `VARCHAR(100)` | `NULLABLE` | Tên ngân hàng giao dịch. |
| `account_holder` | `accountHolder` | `VARCHAR(200)` | `NULLABLE` | Tên chủ sở hữu tài khoản ngân hàng. |
| `qr_payment_url` | `qrPaymentUrl` | `VARCHAR(1000)` | `NULLABLE` | Đường dẫn QR tĩnh (nếu có). |
| `receipt_footer` | `receiptFooter` | `VARCHAR(500)` | `NULLABLE` | Dòng chữ chân hóa đơn in cho khách. |
| `email` | `email` | `VARCHAR(100)` | `NULLABLE` | Email liên hệ. |
| `website` | `website` | `VARCHAR(500)` | `NULLABLE` | Website kinh doanh. |
| `owner_name` | `ownerName` | `VARCHAR(200)` | `NULLABLE` | Họ và tên chủ hộ kinh doanh (áp dụng theo TT 88). |
| `owner_identity_number`| `ownerIdentityNumber`| `VARCHAR(20)` | `NULLABLE` | Số CCCD/CMND của chủ hộ kinh doanh. |
| `business_license_number`| `businessLicenseNumber`| `VARCHAR(50)` | `NULLABLE` | Số giấy chứng nhận đăng ký kinh doanh. |
| `costing_method` | `costingMethod` | `VARCHAR(10)` | `DEFAULT 'AVG'` | Phương pháp tính giá vốn (`FIFO` \| `AVG` - Bình quân gia quyền).|
| `business_sector` | `businessSector` | `VARCHAR(50)` | `DEFAULT 'TRADE'` | Ngành nghề kinh doanh chính (`TRADE` \| `SERVICE` \| `PRODUCTION`). |
| `apply_vat_reduction` | `applyVatReduction` | `BOOLEAN` | `DEFAULT false` | Cấu hình giảm 20% tỷ lệ tính thuế GTGT của nhà nước. |
| `custom_vat_rate` | `customVatRate` | `DECIMAL(5,2)`| `NULLABLE` | Tỷ lệ thuế GTGT tùy biến riêng của shop. |
| `custom_pit_rate` | `customPitRate` | `DECIMAL(5,2)`| `NULLABLE` | Tỷ lệ thuế TNCN tùy biến riêng của shop. |

---

### BẢNG 3: shop_members (Liên kết nhân sự ↔ cửa hàng)
- **Mô tả:** Quản lý mối quan hệ giữa người dùng và cửa hàng, lưu trữ trạng thái xin gia nhập, phê duyệt và vai trò gán cụ thể.
- **Tên Entity trong TypeORM:** `ShopMember` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/shop/entities.ts))

| Tên Cột (Database) | Tên Thuộc Tính (Code) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả Chi Tiết |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `id` | `INT` | `PK`, `AUTO_INCREMENT` | Định danh liên kết. |
| `shop_id` | `shopId` | `INT` | `FK` -> `shop_profiles(id)` | Liên kết tới cửa hàng đích. |
| `user_id` | `userId` | `INT` | `FK` -> `users(id)` | Liên kết tới tài khoản người dùng. |
| `role_id` | `roleId` | `INT` | `FK` -> `shop_roles(id)` | Liên kết tới vai trò quyền hạn cụ thể. |
| `member_type` | `memberType` | `VARCHAR(20)` | `DEFAULT 'EMPLOYEE'` | Phân cấp thành viên (`OWNER` - Chủ shop \| `EMPLOYEE`). |
| `is_active` | `isActive` | `BOOLEAN` | `DEFAULT true` | Nhân viên còn đang làm việc không. |
| `status` | `status` | `VARCHAR(20)` | `DEFAULT 'PENDING'` | Trạng thái xét duyệt (`PENDING` \| `ACTIVE` \| `REJECTED`). |
| `created_at` | `createdAt` | `TIMESTAMP` | `DEFAULT CURRENT_TIMESTAMP`| Thời điểm gửi yêu cầu xin gia nhập. |

---

### BẢNG 4: products (Danh mục hàng hóa/sản phẩm)
- **Mô tả:** Lưu trữ thông tin sản phẩm, giá bán, giá vốn, thuế suất mặc định và số lượng tồn kho tối thiểu.
- **Tên Entity trong TypeORM:** `Product` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/product/entities.ts))

| Tên Cột (Database) | Tên Thuộc Tính (Code) | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả Chi Tiết |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `id` | `INT` | `PK`, `AUTO_INCREMENT` | Định danh sản phẩm. |
| `sku` | `sku` | `VARCHAR(50)` | `UNIQUE`, `NOT NULL` | Mã định danh quản lý nội bộ hàng hóa (độc nhất). |
| `shop_id` | `shopId` | `INT` | `FK` -> `shop_profiles(id)` | Thuộc cửa hàng nào. |
| `name` | `name` | `VARCHAR(200)` | `NOT NULL` | Tên gọi sản phẩm. |
| `category_id` | `category` | `INT` | `FK` -> `categories(id)` | Thuộc nhóm hàng nào. |
| `unit` | `unit` | `VARCHAR(20)` | `DEFAULT 'Cái'` | Đơn vị tính cơ bản (ví dụ: cái, mét, bao, kg). |
| `cost_price` | `costPrice` | `DECIMAL(18,2)`| `DEFAULT 0.00` | Giá nhập kho trung bình. |
| `selling_price` | `sellingPrice` | `DECIMAL(18,2)`| `DEFAULT 0.00` | Giá bán lẻ mặc định. |
| `wholesale_price` | `wholesalePrice` | `DECIMAL(18,2)`| `NULLABLE` | Giá bán sỉ (nếu có). |
| `wholesale_min_qty` | `wholesaleMinQty`| `INT` | `NULLABLE` | Số lượng mua tối thiểu để hưởng giá sỉ. |
| `tax_rate` | `taxRate` | `DECIMAL(5,2)`| `DEFAULT 0.00` | Thuế suất áp dụng (0%, 1%, 2%, 5%...). |
| `min_stock` | `minStock` | `INT` | `DEFAULT 0` | Ngưỡng tồn kho tối thiểu để kích hoạt cảnh báo. |
| `barcode` | `barcode` | `VARCHAR(50)` | `NULLABLE` | Mã vạch in trên bao bì sản phẩm (độc nhất cùng shop). |
| `tags` | `tags` | `TEXT` (simple-array)| `NULLABLE` | Danh sách tag đính kèm (comma-separated string). |
| `is_active` | `isActive` | `BOOLEAN` | `DEFAULT true` | Sản phẩm còn đang kinh doanh không. |

---

### BẢNG 5: invoices & invoice_items (Hóa đơn đầu vào/đầu ra)
- **Mô tả:** Lưu trữ thông tin chi tiết các hóa đơn mua bán phát sinh làm cơ sở tính doanh thu và kê khai thuế.
- **Tên Entity trong TypeORM:** `Invoice` & `InvoiceItem` (Định nghĩa tại: [entities.ts](file:///d:/StockManagementAndTaxWarning/backend/src/system/entities.ts))

**Chi tiết các cột trong bảng invoices (Hóa đơn chính):**
- `id` (PK, INT)
- `invoice_number` (VARCHAR(50)): Số hóa đơn pháp lý.
- `invoice_symbol` (VARCHAR(20)): Ký hiệu hóa đơn.
- `shop_id` (FK -> `shop_profiles`): Thuộc cửa hàng.
- `invoice_type` (VARCHAR(10)): `IN` (Đầu vào/mua hàng) hoặc `OUT` (Đầu ra/bán hàng).
- `invoice_date` (DATE): Ngày lập hóa đơn.
- `partner_name` (VARCHAR(200)): Tên đối tác (Khách hàng hoặc Nhà cung cấp).
- `partner_tax_code` (VARCHAR(20)): Mã số thuế đối tác (nếu có).
- `partner_address` (VARCHAR(500)): Địa chỉ đối tác.
- `partner_identity_number` (VARCHAR(20)): Số CCCD đối tác (áp dụng bảng kê không hóa đơn).
- `subtotal` (DECIMAL(18,2)): Cộng tiền hàng (chưa VAT).
- `tax_amount` (DECIMAL(18,2)): Tiền thuế VAT phát sinh.
- `total_amount` (DECIMAL(18,2)): Tổng cộng tiền thanh toán trên hóa đơn.
- `payment_method` (VARCHAR(20)): `CASH` (Tiền mặt) hoặc `TRANSFER` (Chuyển khoản).
- `payment_status` (VARCHAR(20)): `PAID`, `PARTIAL`, `UNPAID`.

**Chi tiết các cột trong bảng invoice_items (Dòng mặt hàng chi tiết):**
- `id` (PK, INT)
- `invoice_id` (FK -> `invoices`): Thuộc hóa đơn nào.
- `product_id` (FK -> `products`): Liên kết tới sản phẩm hệ thống (nếu có).
- `item_name` (VARCHAR(200)): Tên chi tiết của mặt hàng được ghi trên hóa đơn.
- `unit` (VARCHAR(20)): Đơn vị tính dòng hàng.
- `quantity` (INT): Số lượng.
- `unit_price` (DECIMAL(18,2)): Đơn giá dòng hàng.
- `subtotal` (DECIMAL(18,2)): Thành tiền hàng.
- `tax_rate` (DECIMAL(5,2)): Tỷ lệ thuế dòng hàng.
- `tax_amount` (DECIMAL(18,2)): Tiền thuế GTGT dòng hàng.
