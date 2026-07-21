# MA TRẬN PHÂN QUYỀN TRUY CẬP (ROLE-BASED ACCESS CONTROL - RBAC)
## Hệ thống SmartStock FinTech - Quản lý Bán hàng & Hỗ trợ Cảnh báo Thuế

---

## 1. Kiểm soát phiên bản (Version Control)

| Phiên bản | Ngày | Người thực hiện | Nội dung thay đổi | Trạng thái |
| :--- | :--- | :--- | :--- | :--- |
| v1.0.0 | 2026-07-21 | Senior Business Analyst | Khởi tạo tài liệu Ma trận Phân quyền RBAC | Hoàn thành |
| v1.1.0 | 2026-07-21 | Senior Business Analyst | Cập nhật 100% route và API: Công nợ, Chốt ca, OCR, Quỹ | Hoàn thành |

---

## 2. Nguyên Tắc Thiết Kế Phân Quyền (RBAC Design Principles)

Kiểm soát truy cập trong hệ thống SmartStock FinTech tuân thủ hai chốt chặn bảo mật chặt chẽ:
1. **Phân quyền tại Frontend (Client-side Router Guard):** Ứng dụng Flutter dựa trên vai trò của tài khoản thành viên (`ShopMember`) để hiển thị hoặc ẩn các tab danh mục, chặn điều hướng sang các Route không được phép của GoRouter.
2. **Phân quyền tại Backend (Server-side API Middleware):** Middleware `requirePermission` và `requireOwner` (Định nghĩa tại: [permission.middleware.ts](file:///d:/StockManagementAndTaxWarning/backend/src/middleware/permission.middleware.ts)) kiểm tra thông tin JWT Token và Header `x-shop-id` để xác thực quyền trước khi thực thi Controller.

---

## 3. Vai Trò Nghiệp Vụ & Quyền Hạn Chi Tiết (Role Permission Definitions)

### 3.1. Chủ cửa hàng (OWNER)
- **Cấp độ:** Cao nhất.
- **Quy tắc:** Vượt qua tất cả các chốt chặn kiểm tra quyền tự động tại backend. Có toàn quyền Đọc (View), Thêm/Sửa (Edit) và Xóa (Delete) trên toàn hệ thống.
- **Quyền độc quyền (Chỉ Owner mới có):**
  - Quản lý thông tin tài chính chuỗi, cấu hình tài khoản ngân hàng thụ hưởng nhận QR Code.
  - Phê duyệt/từ chối nhân viên xin gia nhập shop, gán vai trò nhân sự.
  - Cấu hình tỷ lệ thuế suất, tỷ lệ giảm VAT của cửa hàng và xuất tệp tờ khai thuế XML.

### 3.2. Quản lý chi nhánh (MANAGER)
- **Cấp độ:** Trung cấp.
- **Quy tắc:** Có quyền quản lý hàng hóa, đơn hàng và kho vận chi nhánh.
- **Quyền hạn chính:**
  - Thêm mới, chỉnh sửa thông tin hàng hóa, nhãn dán phân loại (Tags).
  - Lập đơn đặt hàng PO và nhấn phê duyệt đơn PO chuyển trạng thái sang "Đã nhập kho" để tăng tồn kho.
  - Xem danh sách khách hàng và nhà cung cấp.
- **Bị giới hạn:** Không được xem sổ sách quỹ tiền, lương nhân sự, cấu hình thuế và không có quyền xuất XML HTKK.

### 3.3. Thủ kho (STOREKEEPER)
- **Cấp độ:** Nhân viên kho.
- **Quy tắc:** Chỉ được phép tương tác với các nghiệp vụ lưu trữ kho hàng.
- **Quyền hạn chính:**
  - Lập phiếu kiểm kê kho thực tế (Stocktake), ghi nhận chênh lệch thừa thiếu.
  - Tạo yêu cầu nhập kho (đơn PO nháp).
- **Bị giới hạn:** Bị chặn hoàn toàn quyền truy cập các API về tài chính, POS bán hàng, cấu hình nhân sự, cấu hình thuế và xuất XML.

### 3.4. Nhân viên thu ngân (CASHIER)
- **Cấp độ:** Nhân viên bán hàng.
- **Quy tắc:** Chỉ được phép tương tác với màn hình POS để tạo hóa đơn bán lẻ.
- **Quyền hạn chính:**
  - Xem danh mục sản phẩm, quét mã vạch bán hàng, tính tổng tiền.
  - Tạo nhanh khách hàng mới ngay tại quầy POS.
  - Xuất hóa đơn bán lẻ và kích hoạt hiển thị QR thanh toán.
- **Bị giới hạn:** Bị chặn truy cập các đơn PO nhập kho, phiếu kiểm kho, cài đặt nhân viên, cấu hình thuế, sổ sách chi phí quỹ tiền.

---

## 4. Ma Trận Quyền Truy Cập Giao Diện (Frontend Routes Matrix)

| Đường dẫn Route | Tên màn hình (Flutter UI) | Chủ Shop (Owner) | Quản Lý (Manager) | Thủ Kho (Storekeeper) | Thu Ngân (Cashier) |
| :--- | :--- | :---: | :---: | :---: | :---: |
| `/login` / `/register` | Giao diện đăng nhập/đăng ký | `Allow` | `Allow` | `Allow` | `Allow` |
| `/onboarding` | Khởi tạo shop ban đầu | `Allow` | `Deny` | `Deny` | `Deny` |
| `/dashboard` | Dashboard tổng quan báo cáo | `Full` | `Limited` | `Deny` | `Deny` |
| `/pos` | Giao diện bán lẻ tại quầy | `Allow` | `Allow` | `Deny` | `Allow` |
| `/products` | Danh sách/Thêm sửa sản phẩm | `Full` | `Full` | `View Only` | `View Only`|
| `/purchases` | Đơn PO mua hàng nhà cung cấp | `Full` | `Full` | `Draft Only` | `Deny` |
| `/stocktake` | Lập phiếu kiểm kho | `Full` | `Full` | `Full` | `Deny` |
| `/finance` | Sổ quỹ tiền, thu chi, dự phóng | `Full` | `Deny` | `Deny` | `Deny` |
| `/purchases-no-invoice`| Bảng kê mua hàng không hóa đơn | `Full` | `Full` | `Deny` | `Deny` |
| `/tax-config` | Cấu hình biểu thuế VAT/TNCN | `Full` | `Deny` | `Deny` | `Deny` |
| `/tax-estimate` | Xem tờ khai & kết xuất XML HTKK| `Full` | `Deny` | `Deny` | `Deny` |
| `/staff` | Duyệt gia nhập, gán vai trò | `Full` | `Deny` | `Deny` | `Deny` |
| `/change-password` | Đổi mật khẩu tài khoản | `Allow` | `Allow` | `Allow` | `Allow` |
| `/customers` | Quản lý sổ nợ khách hàng | `Full` | `Full` | `Deny` | `View Only`|
| `/daily-closing` | Phiếu chốt ca/chốt quỹ | `Full` | `Full` | `Deny` | `Limited` |
| `/invoice-scan` | Quét hóa đơn OCR | `Full` | `Full` | `Deny` | `Deny` |

---

## 5. Ma Trận Quyền API (Backend Endpoints Matrix)

| API Endpoint | HTTP Method | Mục tiêu nghiệp vụ | Owner | Manager | Storekeeper | Cashier |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: |
| `/api/auth/register` | `POST` | Đăng ký tài khoản mới | `Yes` | `Yes` | `Yes` | `Yes` |
| `/api/shop-members/pending` | `GET` | Xem danh sách chờ duyệt HR | `Yes` | `No` | `No` | `No` |
| `/api/shop-members/:id/approve` | `PUT` | Phê duyệt & phân quyền nhân viên| `Yes` | `No` | `No` | `No` |
| `/api/products` | `GET` | Xem danh sách hàng hóa | `Yes` | `Yes` | `Yes` | `Yes` |
| `/api/products` | `POST`/`PUT` | Thêm mới/chỉnh sửa hàng hóa | `Yes` | `Yes` | `No` | `No` |
| `/api/products/:id` | `DELETE` | Xóa hàng hóa khỏi danh mục | `Yes` | `Yes` | `No` | `No` |
| `/api/purchase-orders` | `POST` | Lập đơn mua hàng PO | `Yes` | `Yes` | `Yes` | `No` |
| `/api/purchase-orders/:id/approve`| `PUT` | Phê duyệt đơn hàng PO nhập kho | `Yes` | `Yes` | `No` | `No` |
| `/api/stocktakes` | `POST` | Lưu phiếu kiểm kê kho | `Yes` | `Yes` | `Yes` | `No` |
| `/api/orders` | `POST` | Tạo đơn hàng POS bán lẻ | `Yes` | `Yes` | `No` | `Yes` |
| `/api/customers/receivables` | `GET` | Lấy sổ công nợ khách hàng | `Yes` | `Yes` | `No` | `Yes` |
| `/api/receivables/:id/payments` | `POST` | Ghi nhận thanh toán thu nợ | `Yes` | `Yes` | `No` | `No` |
| `/api/finance/cashflows` | `GET` | Xem quỹ tiền, báo cáo thu chi | `Yes` | `No` | `No` | `No` |
| `/api/finance/scan-ocr` | `POST` | Chạy phân tích hóa đơn OCR | `Yes` | `Yes` | `No` | `No` |
| `/api/daily-closing/close` | `POST` | Ghi nhận chốt ca cuối ngày | `Yes` | `Yes` | `No` | `Yes` |
| `/api/purchases/no-invoice` | `POST` | Lưu bảng kê Mẫu 01/TNDN | `Yes` | `Yes` | `No` | `No` |
| `/api/tax/config` | `PUT`/`GET` | Cập nhật cấu hình thuế suất | `Yes` | `No` | `No` | `No` |
| `/api/tax/export-xml` | `GET` | Tải về tệp XML HTKK tờ khai thuế| `Yes` | `No` | `No` | `No` |
