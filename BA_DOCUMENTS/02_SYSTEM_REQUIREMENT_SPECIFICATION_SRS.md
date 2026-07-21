# ĐẶC TẢ YÊU CẦU HỆ THỐNG CHI TIẾT (SYSTEM REQUIREMENT SPECIFICATION - SRS)
## Hệ thống SmartStock FinTech - Quản lý Bán hàng & Hỗ trợ Cảnh báo Thuế

---

## 1. Kiểm soát phiên bản (Version Control)

| Phiên bản | Ngày | Người thực hiện | Nội dung thay đổi | Trạng thái |
| :--- | :--- | :--- | :--- | :--- |
| v1.0.0 | 2026-07-21 | Senior Business Analyst | Khởi tạo tài liệu SRS chi tiết từng màn hình | Hoàn thành |

---

## 2. Tổng Quan Kiến Trúc Kỹ Thuật (Technical Architecture Overview)

Hệ thống được thiết kế theo mô hình client-server tách biệt:
- **Frontend (Mobile & Web):** Phát triển trên nền tảng **Flutter** sử dụng mô hình quản lý trạng thái **Riverpod**, giao tiếp API thông qua thư viện **Dio**, vẽ biểu đồ bằng **fl_chart** và quản lý luồng màn hình bằng **GoRouter**.
- **Backend (API Server):** Sử dụng framework **Express** (Node.js/TypeScript) kết hợp **TypeORM** để quản trị cơ sở dữ liệu **PostgreSQL** (lưu trữ trên nền tảng Supabase Cloud).

---

## 3. Đặc Tả Chi Tiết Từng Màn Hình & Chức Năng (Detailed Screen Specifications)

---

### PHÂN HỆ 1: XÁC THỰC & BẢO MẬT (AUTHENTICATION & SECURITY)

#### 1.1. Màn hình Đăng Ký Tài Khoản (Register Screen)
- **Đường dẫn file Flutter:** [register_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/auth/presentation/register_screen.dart)
- **Đường dẫn Route GoRouter:** `/register`
- **Địa chỉ API kết nối:** `POST /auth/send-otp` (Gửi mã OTP qua email)
- **Mô tả giao diện (UI Layout):**
  - SegmentedButton chọn vai trò đăng ký: *"Chủ cửa hàng (SHOP)"* hoặc *"Nhân viên (PERSONAL)"*.
  - Các trường nhập liệu: *Họ và tên của bạn*, *Địa chỉ Email (Gmail)*, *Mật khẩu*, *Xác nhận mật khẩu*.
  - Social Login Section: Nút liên kết Google (đỏ) và Facebook (xanh).
  - Nút hành động chính: *Đăng Ký & Nhận Mã OTP*.
- **Quy tắc kiểm thử & Ràng buộc (Validation & Business Rules):**
  - **Kiểm tra định dạng Email:** Phải khớp Regex định dạng email tiêu chuẩn. Nếu sai, hiển thị thông báo: `"Địa chỉ Email không hợp lệ"`.
  - **Thanh đo độ mạnh mật khẩu:**
    - Gồm 5 thanh màu sắc nằm ngang và checklist 5 tiêu chí: *Từ 8 ký tự, Chữ hoa, Chữ thường, Chữ số, Ký tự đặc biệt*.
    - Hệ thống tính toán điểm số (0 - 5). Điểm $\le 2$ báo đỏ (Yếu), điểm $3$ báo vàng (Trung bình), điểm $4$ báo xanh dương (Mạnh), điểm $5$ báo xanh lá (Cực mạnh).
    - Nút Đăng ký chỉ khả dụng (Enable) khi độ mạnh đạt $\ge 3$ điểm và độ dài $\ge 8$. Nếu không, báo lỗi: `"Mật khẩu chưa đạt tiêu chuẩn bảo mật quốc tế..."`.
  - **Chỉ báo khớp mật khẩu:**
    - Đối chiếu real-time trường *Mật khẩu* và *Xác nhận mật khẩu*.
    - Trùng khớp: Hiện badge màu xanh lá `✓ Mật khẩu xác nhận trùng khớp`.
    - Lệch ký tự: Hiện badge màu đỏ `✗ Mật khẩu xác nhận chưa khớp`.
  - **Chống click spam (Double Submit Guard):** Khi bấm nút, biến `_isLoading = true` sẽ vô hiệu hóa tương tác nút và hiển thị hoạt ảnh tải tròn.

#### 1.2. Màn hình Xác Thực Mã OTP (OTP Verification Screen)
- **Đường dẫn file Flutter:** [otp_verification_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/auth/presentation/otp_verification_screen.dart)
- **Đường dẫn Route GoRouter:** `/verify-otp` (Nhận thông tin đăng ký truyền qua `state.extra`)
- **Địa chỉ API kết nối:** `POST /auth/register` (Hoàn tất đăng ký) và `POST /auth/send-otp` (Gửi lại OTP)
- **Mô tả giao diện (UI Layout):**
  - Tiêu đề màn hình "Xác Thực Tài Khoản" kèm icon hộp thư lớn màu xanh thương hiệu.
  - Hiển thị văn bản động chứa email người nhận: `"Mã xác thực gồm 6 chữ số đã được gửi đến hộp thư [email_của_bạn]"`.
  - Ô nhập mã OTP gồm 6 ô số căn giữa, hỗ trợ tự động nhảy focus khi gõ.
  - Bộ đếm ngược 60 giây và dòng chữ: `"Gửi lại mã ngay"` (chỉ nhấn được khi đếm ngược về 0).
  - Nút hành động: *Xác nhận & Hoàn tất*.
- **Quy tắc kiểm thử & Ràng buộc (Validation & Business Rules):**
  - **Bảo vệ rò rỉ trạng thái (Liveness Check):** Nếu người dùng tải lại trang khiến `state.extra` bị `null`, hệ thống lập tức điều hướng quay lại trang `/register` và hiển thị Toast báo lỗi mất dữ liệu phiên làm việc.
  - **Tự động gửi khi đủ 6 chữ số:** Khi người dùng nhập đủ 6 chữ số, hệ thống tự động kích hoạt hàm gửi yêu cầu đăng ký lên server giống như khi bấm nút.

#### 1.3. Màn hình Đổi Mật Khẩu (Change Password Screen)
- **Đường dẫn file Flutter:** [change_password_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/settings/presentation/change_password_screen.dart)
- **Đường dẫn Route GoRouter:** `/change-password`
- **Địa chỉ API kết nối:** `PUT /profile/password`
- **Mô tả giao diện (UI Layout):**
  - Các trường nhập liệu: *Mật khẩu hiện tại*, *Mật khẩu mới*, *Xác nhận mật khẩu mới*.
  - Nút hành động: *Cập nhật mật khẩu bảo mật*.
- **Quy tắc kiểm thử & Ràng buộc (Validation & Business Rules):**
  - Áp dụng đầy đủ thanh đo độ mạnh mật khẩu và chỉ báo đối chiếu trùng khớp giống màn hình Đăng ký.
  - Phải kiểm tra mật khẩu mới không được trùng với mật khẩu hiện tại (trả về lỗi từ backend/frontend nếu trùng).

---

### PHÂN HỆ 2: QUẢN LÝ CỬA HÀNG & NHÂN SỰ (SHOP & STAFF MANAGEMENT)

#### 2.1. Thanh chuyển đổi cửa hàng (Shop Switcher)
- **Đường dẫn file Flutter:** Tích hợp trong [settings_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/settings/presentation/settings_screen.dart)
- **Địa chỉ API kết nối:** `GET /auth/user-shops` (Lấy danh sách shop mà user tham gia)
- **Mô tả giao diện (UI Layout):**
  - Một Dropdown/Popup danh sách ở đầu trang cài đặt hiển thị tên tất cả các shop.
  - Dòng cuối cùng của danh sách hiển thị lựa chọn đặc biệt: `"Tất cả cửa hàng (Tổng quát)"`.
- **Quy tắc kiểm thử & Ràng buộc (Validation & Business Rules):**
  - Khi người dùng thay đổi lựa chọn shop, hệ thống lưu `shop_id` mới vào `SharedPreferences` và kích hoạt làm mới trạng thái (refetch) toàn bộ dữ liệu trên các provider Riverpod liên quan.
  - **Chế độ Tổng quát:** Khi chọn Tất cả cửa hàng, header `x-shop-id` sẽ truyền giá trị là `'all'`. Backend sẽ thực hiện cộng dồn báo cáo thay vì lọc theo một ID cụ thể.

#### 2.2. Màn hình Danh Sách Nhân Viên & Duyệt Gia Nhập (Staff Management Screen)
- **Đường dẫn file Flutter:** [staff_management_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/settings/presentation/staff_management_screen.dart)
- **Đường dẫn Route GoRouter:** `/staff`
- **Địa chỉ API kết nối:**
  - `GET /shop-members/pending` (Lấy danh sách chờ duyệt)
  - `PUT /shop-members/:id/approve` (Phê duyệt gia nhập và gán vai trò)
  - `DELETE /shop-members/:id` (Xóa nhân viên khỏi shop)
- **Mô tả giao diện (UI Layout):**
  - Gồm 2 Tab: **"Danh sách nhân viên"** và **"Chờ duyệt"**.
  - Tab "Chờ duyệt" hiển thị card thông tin nhân viên (Họ tên, Email, ngày yêu cầu) kèm 2 nút hành động: *Đồng ý* và *Từ chối*.
  - Khi bấm *Đồng ý*, hiển thị Dialog chọn vai trò: *Quản lý (MANAGER)*, *Thủ kho (STOREKEEPER)*, *Thu ngân (CASHIER)*.
- **Quy tắc kiểm thử & Ràng buộc (Validation & Business Rules):**
  - **Bảo mật TypeORM:** Khi lấy danh sách chờ duyệt, backend không được phép gọi nạp quan hệ `'shop'` không tồn tại trên Entity `ShopMember`, mà phải sử dụng cơ chế map thủ công qua ID để tránh lỗi crash HTTP 500.

---

### PHÂN HỆ 3: HÀNG HÓA & KHO VẬN (PRODUCTS & INVENTORY)

#### 3.1. Thêm mới & Chỉnh sửa sản phẩm
- **Đường dẫn file Flutter:** [product_list_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/products/presentation/product_list_screen.dart) (Chứa Dialog thêm mới/sửa)
- **Địa chỉ API kết nối:** `POST /products` (Thêm mới) và `PUT /products/:id` (Cập nhật)
- **Quy tắc kiểm thử & Ràng buộc (Validation & Business Rules):**
  - **Độc nhất mã vạch (Unique Barcode constraint):** Hệ thống kiểm tra tính duy nhất của mã vạch trên phạm vi cửa hàng (`shop_id`). Nếu người dùng nhập mã vạch đã thuộc sản phẩm khác cùng shop, API backend trả về lỗi HTTP 409: `"Mã vạch này đã tồn tại"`. Frontend phải hiển thị hộp thoại cảnh báo lỗi thay vì crash ứng dụng.
  - **Phân loại thẻ nhãn (Tags):** Hỗ trợ đính kèm mảng các chuỗi thẻ phân loại (ví dụ: `["VIP", "Dễ vỡ"]`). Bộ lọc sản phẩm theo nhãn phải thực hiện truy vấn chuẩn xác (PostgreSQL array operators) để tránh trường hợp tìm kiếm nhãn `"VIP"` nhưng hiển thị cả sản phẩm chứa nhãn `"VIPER"` (Lỗi Substring Collision).

#### 3.2. Quản lý Đơn Đặt Hàng Nhà Cung Cấp (Purchase Orders)
- **Đường dẫn file Flutter:** [purchase_order_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/inventory/presentation/purchase_order_screen.dart)
- **Đường dẫn Route GoRouter:** `/purchases`
- **Địa chỉ API kết nối:** `GET /purchase-orders` và `PUT /purchase-orders/:id/approve`
- **Mô tả giao diện (UI Layout):**
  - Danh sách các thẻ Card hiển thị mã PO, nhà cung cấp, tổng giá trị, và trạng thái màu sắc (*Nháp*, *Đang chờ duyệt*, *Đã nhập kho*).
  - Nhấp vào Card để mở trang chi tiết đơn đặt hàng PO.
- **Quy tắc kiểm thử & Ràng buộc (Validation & Business Rules):**
  - Đơn hàng PO khi tạo ở trạng thái Chờ duyệt không được làm thay đổi tồn kho sản phẩm.
  - Khi chủ shop bấm nút **"Duyệt nhập kho"**, hệ thống gọi API duyệt, tự động cộng thêm số lượng sản phẩm trong đơn PO vào trường tồn kho (`stock_quantity`) của từng sản phẩm tương ứng trong cơ sở dữ liệu.

#### 3.3. Màn hình Phiếu Kiểm Kho (Stocktake Screen)
- **Đường dẫn file Flutter:** [stock_take_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/inventory/presentation/stock_take_screen.dart)
- **Mô tả giao diện (UI Layout):**
  - Bảng kê danh sách sản phẩm gồm: Tồn kho hệ thống, Số lượng kiểm thực tế, Số lượng chênh lệch (tự động tính).
  - Nút hành động chính: *Lưu phiếu kiểm kho*.
- **Quy tắc kiểm thử & Ràng buộc (Validation & Business Rules):**
  - Hệ thống bắt buộc phải hiển thị Modal xác nhận cảnh báo an toàn màu đỏ trước khi lưu phiếu, do đây là tác vụ làm thay đổi trực tiếp và vĩnh viễn số lượng tồn kho trên DB.

---

### PHÂN HỆ 4: BÁN HÀNG POS & THANH TOÁN (POS SALES & PAYMENT)

#### 4.1. Màn hình Bán Hàng Tại Quầy (POS Screen)
- **Đường dẫn file Flutter:** [pos_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/sales/presentation/pos_screen.dart)
- **Đường dẫn Route GoRouter:** `/pos`
- **Địa chỉ API kết nối:** `POST /orders` (Tạo hóa đơn bán hàng)
- **Mô tả giao diện (UI Layout):**
  - Bên trái: Thanh tìm kiếm sản phẩm & Danh mục sản phẩm dạng lưới hoặc list.
  - Bên phải: Giỏ hàng hiện hành hiển thị Tên sản phẩm, Đơn giá, Thuế VAT động, Số lượng, và tổng thanh toán.
  - Nút **"Tạo khách hàng mới"** (icon dấu cộng cạnh trường chọn khách hàng).
  - Nút hành động chính: *Thanh toán* (màu xanh lá) và *Hủy đơn* (màu đỏ).
- **Quy tắc kiểm thử & Ràng buộc (Validation & Business Rules):**
  - **Tạo nhanh khách hàng:** Bấm nút dấu cộng sẽ mở Dialog nhập thông tin khách hàng (Họ tên, SĐT, Địa chỉ). Sau khi tạo thành công qua API `POST /customers`, hệ thống tự động gán ID khách hàng mới vào đơn hàng hiện hành mà không được làm sạch (clear) giỏ hàng đang bán dở.
  - **Mã QR Code động:** Khi chọn thanh toán bằng chuyển khoản, hệ thống tạo mã VietQR động chứa mã tài khoản nhận tiền của cửa hàng và số tiền chính xác đến từng chữ số của hóa đơn để tránh khách gõ sai số tiền.

---

### PHÂN HỆ 5: TÀI CHÍNH & QUỸ TIỀN (FINANCE & CASHFLOW)

#### 5.1. Bảng Kê Mua Hàng Không Hóa Đơn (Mẫu số 01/TNDN)
- **Đường dẫn file Flutter:** [purchase_no_invoice_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/finance/presentation/purchase_no_invoice_screen.dart)
- **Đường dẫn Route GoRouter:** `/purchases-no-invoice`
- **Địa chỉ API kết nối:** `POST /purchases/no-invoice`
- **Mô tả giao diện (UI Layout):**
  - Form thông tin người bán: *Họ tên*, *Địa chỉ*, *SĐT/Số CCCD*.
  - Bảng chi tiết mặt hàng thu mua gồm các dòng nhập liệu: Tên nông sản/dịch vụ, Số lượng, Đơn giá, Thành tiền.
- **Quy tắc kiểm thử & Ràng buộc (Validation & Business Rules):**
  - **Tự động hoàn thiện dòng đang nhập dở (Auto-Complete):** Khi người dùng đang nhập dở tên hoặc số lượng mặt hàng ở dòng cuối cùng nhưng chưa kịp bấm nút "Thêm vào bảng" mà đã nhấn nút lưu lớn ở cuối màn hình, hệ thống bắt buộc phải tự động nạp dòng đang nhập dở đó vào mảng danh sách trước khi gửi API lên server, ngăn chặn việc thất thoát dữ liệu của người dùng.

#### 5.2. Biểu đồ Dự Phóng Dòng Tiền (Cashflow Forecast Screen)
- **Đường dẫn file Flutter:** [cashflow_forecast_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/finance/presentation/cashflow_forecast_screen.dart)
- **Địa chỉ API kết nối:** `GET /reports/cashflow`
- **Mô tả giao diện (UI Layout):**
  - Biểu đồ đường (Line Chart) biểu diễn biến động quỹ tiền theo thời gian (các ngày trong tháng).
  - Trục hoành biểu thị thời gian, trục tung biểu thị số dư quỹ (VND).
- **Quy tắc kiểm thử & Ràng buộc (Validation & Business Rules):**
  - **Chốt chặn crash biểu đồ (fl_chart crash guard):** Nếu khoảng thời gian lọc chỉ trả về 1 điểm dữ liệu dòng tiền (Ví dụ: ngày hôm nay), hệ thống tự động gán giá trị biên $maxX = 1.0$ (với $minX = 0$), không được phép để $maxX == minX$ vì thư viện `fl_chart` sẽ ném ngoại lệ xác thực gây lỗi màn hình đỏ (Red Screen).

---

### PHÂN HỆ 6: BÁO CÁO THUẾ & CẢNH BÁO THUẾ (TAX & WARNINGS)

#### 6.1. Màn hình Kết Xuất Tờ Khai Thuế XML HTKK
- **Đường dẫn file Flutter:** [tax_estimate_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/tax/screens/tax_estimate_screen.dart)
- **Địa chỉ API kết nối:** `GET /tax/export-xml`
- **Mô tả giao diện (UI Layout):**
  - Bảng tổng hợp các chỉ tiêu thuế: Doanh thu tính thuế, Thuế suất GTGT, Thuế suất TNCN, Tiền thuế phát sinh.
  - Nút hành động chính: *Xuất tờ khai thuế XML*.
- **Quy tắc kiểm thử & Ràng buộc (Validation & Business Rules):**
  - Tệp tin `.xml` tải xuống máy người dùng bắt buộc phải khớp cấu trúc định dạng thẻ của phần mềm **HTKK (Hỗ trợ Kê khai)** của Tổng cục Thuế Việt Nam để có thể nhập (Import) trực tiếp vào phần mềm mà không báo lỗi cú pháp.
