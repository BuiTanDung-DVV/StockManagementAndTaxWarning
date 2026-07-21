# ĐẶC TẢ YÊU CẦU HỆ THỐNG CHI TIẾT (SYSTEM REQUIREMENT SPECIFICATION - SRS)
## Hệ thống SmartStock FinTech - Quản lý Bán hàng & Hỗ trợ Cảnh báo Thuế

---

## 1. Kiểm soát phiên bản (Version Control)

| Phiên bản | Ngày | Người thực hiện | Nội dung thay đổi | Trạng thái |
| :--- | :--- | :--- | :--- | :--- |
| v1.0.0 | 2026-07-21 | Senior Business Analyst | Khởi tạo tài liệu SRS chi tiết các màn hình cốt lõi | Hoàn thành |
| v1.1.0 | 2026-07-21 | Senior Business Analyst | Cập nhật 100% màn hình: Công nợ, Ví, Quỹ, OCR và XNT | Hoàn thành |

---

## 2. Đặc Tả Chi Tiết 7 Phân Hệ Giao Diện Hệ Thống (Frontend Screen Specifications)

---

### PHÂN HỆ 1: XÁC THỰC & BẢO MẬT (AUTHENTICATION)

#### 1.1. Màn hình Đăng Ký Tài Khoản (Register Screen)
- **Đường dẫn file Flutter:** [register_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/auth/presentation/register_screen.dart)
- **Đường dẫn Route GoRouter:** `/register`
- **Địa chỉ API kết nối:** `POST /auth/send-otp` (Gửi mã OTP về email)
- **Mô tả giao diện (UI Layout):**
  - SegmentedButton chọn vai trò đăng ký: *"Chủ cửa hàng (SHOP)"* hoặc *"Nhân viên (PERSONAL)"*.
  - Các trường nhập liệu: *Họ và tên của bạn*, *Địa chỉ Email (Gmail)*, *Mật khẩu*, *Xác nhận mật khẩu*.
  - Social Login Section: Nút liên kết nhanh qua Google (đỏ) và Facebook (xanh).
  - Nút hành động chính: *Đăng Ký & Nhận Mã OTP*.
- **Ràng buộc & Logic nghiệp vụ:**
  - **Kiểm tra định dạng Email:** Khớp Regex email tiêu chuẩn. Nếu sai, hiển thị báo lỗi: `"Địa chỉ Email không hợp lệ"`.
  - **Thanh đo độ mạnh mật khẩu:**
    - Gồm 5 thanh màu sắc nằm ngang và checklist 5 tiêu chí: *Từ 8 ký tự, Chữ hoa, Chữ thường, Chữ số, Ký tự đặc biệt*.
    - Hệ thống tính toán điểm số (0 - 5). Điểm $\le 2$ báo đỏ (Yếu), điểm $3$ báo vàng (Trung bình), điểm $4$ báo xanh dương (Mạnh), điểm $5$ báo xanh lá (Cực mạnh).
    - Nút Đăng ký chỉ khả dụng khi độ mạnh đạt $\ge 3$ điểm và độ dài $\ge 8$. Nếu không đạt, chặn lại và thông báo lỗi.
  - **Chỉ báo khớp mật khẩu:**
    - Đối chiếu real-time trường *Mật khẩu* và *Xác nhận mật khẩu*.
    - Trùng khớp: Hiện badge màu xanh lá `✓ Mật khẩu xác nhận trùng khớp`.
    - Lệch ký tự: Hiện badge màu đỏ `✗ Mật khẩu xác nhận chưa khớp`.
  - **Chống click spam (Double Submit Guard):** Khi bấm nút, trạng thái `_isLoading = true` sẽ vô hiệu hóa tương tác nút và hiển thị hoạt ảnh tải tròn.

#### 1.2. Màn hình Xác Thực Mã OTP (OTP Verification Screen)
- **Đường dẫn file Flutter:** [otp_verification_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/auth/presentation/otp_verification_screen.dart)
- **Đường dẫn Route GoRouter:** `/verify-otp` (GoRouter - nhận tham số qua `state.extra`)
- **Địa chỉ API kết nối:** `POST /auth/register` (Hoàn tất đăng ký) và `POST /auth/send-otp` (Gửi lại OTP)
- **Mô tả giao diện (UI Layout):**
  - Tiêu đề màn hình "Xác Thực Tài Khoản" kèm icon hộp thư lớn màu xanh thương hiệu.
  - Hiển thị văn bản chứa email người nhận: `"Mã xác thực gồm 6 chữ số đã được gửi đến hộp thư [email_của_bạn]"`.
  - Ô nhập mã OTP gồm 6 ô số căn giữa, hỗ trợ tự động nhảy focus khi gõ.
  - Bộ đếm ngược 60 giây. Khi đếm ngược về 0, cho phép bấm nút: `"Gửi lại mã ngay"`.
  - Nút hành động: *Xác nhận & Hoàn tất*.
- **Ràng buộc & Logic nghiệp vụ:**
  - **Bảo vệ rò rỉ trạng thái (Liveness Check):** Nếu người dùng tải lại trang khiến `state.extra` bị `null`, hệ thống lập tức điều hướng quay lại trang `/register` và hiển thị Toast báo lỗi mất dữ liệu phiên làm việc.
  - **Tự động gửi khi đủ 6 chữ số:** Khi nhập đủ 6 chữ số, hệ thống tự động gọi hàm gửi yêu cầu đăng ký lên server mà không cần bấm nút xác nhận.

#### 1.3. Màn hình Đổi Mật Khẩu (Change Password Screen)
- **Đường dẫn file Flutter:** [change_password_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/settings/presentation/change_password_screen.dart)
- **Đường dẫn Route GoRouter:** `/change-password`
- **Địa chỉ API kết nối:** `PUT /profile/password`
- **Mô tả giao diện (UI Layout):**
  - Các trường nhập liệu: *Mật khẩu hiện tại*, *Mật khẩu mới*, *Xác nhận mật khẩu mới*.
  - Nút hành động: *Cập nhật mật khẩu bảo mật*.
- **Ràng buộc & Logic nghiệp vụ:**
  - Áp dụng đầy đủ thanh đo độ mạnh mật khẩu và chỉ báo đối chiếu trùng khớp giống màn hình Đăng ký.
  - Kiểm tra mật khẩu mới không được trùng khớp với mật khẩu cũ đang sử dụng.

---

### PHÂN HỆ 2: CỬA HÀNG & NHÂN SỰ (SHOP & STAFF)

#### 2.1. Thanh chuyển đổi cửa hàng (Shop Switcher)
- **Đường dẫn file Flutter:** Tích hợp trong [settings_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/settings/presentation/settings_screen.dart)
- **Địa chỉ API kết nối:** `GET /auth/user-shops` (Lấy danh sách shop mà user tham gia)
- **Mô tả giao diện (UI Layout):**
  - Một Dropdown/Popup danh sách ở đầu trang cài đặt hiển thị tên tất cả các shop.
  - Dòng cuối cùng của danh sách hiển thị lựa chọn đặc biệt: `"Tất cả cửa hàng (Tổng quát)"`.
- **Ràng buộc & Logic nghiệp vụ:**
  - Khi người dùng thay đổi lựa chọn shop, hệ thống lưu `shop_id` mới vào `SharedPreferences` và kích hoạt refetch dữ liệu của các provider Riverpod liên quan.
  - **Chế độ Tổng quát:** Khi chọn Tất cả cửa hàng, header `x-shop-id` sẽ truyền giá trị là `'all'`. Backend sẽ thực hiện cộng dồn báo cáo thay vì lọc theo một ID cụ thể.

#### 2.2. Màn hình Quản Lý Danh Sách Nhân Viên & Duyệt Gia Nhập (Staff Management Screen)
- **Đường dẫn file Flutter:** [staff_management_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/settings/presentation/staff_management_screen.dart)
- **Đường dẫn Route GoRouter:** `/staff`
- **Địa chỉ API kết nối:**
  - `GET /shop-members/pending` (Lấy danh sách chờ duyệt)
  - `PUT /shop-members/:id/approve` (Phê duyệt gia nhập và gán vai trò)
  - `DELETE /shop-members/:id` (Xóa nhân viên khỏi shop)
- **Mô tả giao diện (UI Layout):**
  - Gồm 2 Tab: **"Danh sách nhân viên"** và **"Chờ duyệt"**.
  - Tab "Chờ duyệt" hiển thị danh sách nhân viên chờ duyệt kèm 2 nút hành động: *Đồng ý* và *Từ chối*.
  - Khi bấm *Đồng ý*, hiển thị Dialog chọn vai trò: *Quản lý (MANAGER)*, *Thủ kho (STOREKEEPER)*, *Thu ngân (CASHIER)*.

---

### PHÂN HỆ 3: DANH MỤC SẢN PHẨM & KHO VẬN (PRODUCTS & INVENTORY)

#### 3.1. Thêm mới & Chỉnh sửa sản phẩm
- **Đường dẫn file Flutter:** [product_list_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/products/presentation/product_list_screen.dart) (Chứa Dialog thêm mới/sửa)
- **Địa chỉ API kết nối:** `POST /products` (Thêm mới) và `PUT /products/:id` (Cập nhật)
- **Ràng buộc & Logic nghiệp vụ:**
  - **Độc nhất mã vạch (Unique Barcode constraint):** Hệ thống kiểm tra tính duy nhất của mã vạch trên phạm vi cửa hàng (`shop_id`). Nếu trùng mã vạch, API backend trả về lỗi HTTP 409: `"Mã vạch này đã tồn tại"`.
  - **Phân loại thẻ nhãn (Tags):** Hỗ trợ đính kèm mảng các chuỗi thẻ phân loại (ví dụ: `["VIP", "Dễ vỡ"]`). Bộ lọc sản phẩm theo nhãn phải thực hiện truy vấn chuẩn xác (PostgreSQL array operators) để tránh trường hợp tìm kiếm nhãn `"VIP"` nhưng hiển thị cả sản phẩm chứa nhãn `"VIPER"`.

#### 3.2. Quản lý Đơn Đặt Hàng Nhà Cung Cấp (Purchase Orders)
- **Đường dẫn file Flutter:** [purchase_order_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/inventory/presentation/purchase_order_screen.dart)
- **Đường dẫn Route GoRouter:** `/purchases`
- **Địa chỉ API kết nối:** `GET /purchase-orders` và `PUT /purchase-orders/:id/approve`
- **Mô tả giao diện (UI Layout):**
  - Danh sách các thẻ Card hiển thị mã PO, nhà cung cấp, tổng giá trị, và trạng thái màu sắc (*Nháp*, *Đang chờ duyệt*, *Đã nhập kho*).
  - Nhấp vào Card để mở trang chi tiết đơn đặt hàng PO.
- **Ràng buộc & Logic nghiệp vụ:**
  - Đơn hàng PO khi tạo ở trạng thái Chờ duyệt không được làm thay đổi tồn kho sản phẩm.
  - Khi chủ shop bấm nút **"Duyệt nhập kho"**, hệ thống gọi API duyệt, tự động cộng thêm số lượng sản phẩm trong đơn PO vào trường tồn kho (`stock_quantity`) của từng sản phẩm tương ứng trong cơ sở dữ liệu.

#### 3.3. Màn hình Phiếu Kiểm Kho (Stocktake Screen)
- **Đường dẫn file Flutter:** [stock_take_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/inventory/presentation/stock_take_screen.dart)
- **Mô tả giao diện (UI Layout):**
  - Bảng kê danh sách sản phẩm gồm: Tồn kho hệ thống, Số lượng kiểm thực tế, Số lượng chênh lệch (tự động tính).
  - Nút hành động chính: *Lưu phiếu kiểm kho*.
- **Ràng buộc & Logic nghiệp vụ:**
  - Hệ thống bắt buộc phải hiển thị Modal xác nhận cảnh báo an toàn màu đỏ trước khi lưu phiếu, do đây là tác vụ làm thay đổi trực tiếp và vĩnh viễn số lượng tồn kho trên DB.

#### 3.4. Báo cáo Xuất - Nhập - Tồn (XNT Report)
- **Đường dẫn file Flutter:** [xnt_report_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/inventory/presentation/xnt_report_screen.dart)
- **Địa chỉ API kết nối:** `GET /reports/xnt`
- **Mô tả giao diện (UI Layout):**
  - Bảng hiển thị các cột: *Mã hàng*, *Tên hàng*, *Tồn đầu kỳ*, *Nhập trong kỳ*, *Xuất trong kỳ*, *Tồn cuối kỳ*, *Giá trị tồn kho*.
  - Bộ chọn khoảng thời gian (Từ ngày - Đến ngày) sử dụng widget CustomDateRangePicker.
  - Nút *Xuất Excel Báo cáo XNT*.

---

### PHÂN HỆ 4: BÁN HÀNG POS & GIAO DỊCH (POS SALES & TRANSACTION)

#### 4.1. Màn hình Bán Hàng Tại Quầy (POS Screen)
- **Đường dẫn file Flutter:** [pos_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/sales/presentation/pos_screen.dart)
- **Đường dẫn Route GoRouter:** `/pos`
- **Địa chỉ API kết nối:** `POST /orders` (Tạo hóa đơn bán hàng)
- **Mô tả giao diện (UI Layout):**
  - Bên trái: Thanh tìm kiếm sản phẩm & Danh mục sản phẩm dạng lưới hoặc list.
  - Bên phải: Giỏ hàng hiện hành hiển thị Tên sản phẩm, Đơn giá, Thuế VAT động, Số lượng, và tổng thanh toán.
  - Nút **"Tạo khách hàng mới"** (icon dấu cộng cạnh trường chọn khách hàng).
  - Nút hành động chính: *Thanh toán* (màu xanh lá) và *Hủy đơn* (màu đỏ).
- **Ràng buộc & Logic nghiệp vụ:**
  - **Tạo nhanh khách hàng:** Bấm nút dấu cộng sẽ mở Dialog nhập thông tin khách hàng (Họ tên, SĐT, Địa chỉ). Sau khi tạo thành công qua API `POST /customers`, hệ thống tự động gán ID khách hàng mới vào đơn hàng hiện hành mà không được làm sạch (clear) giỏ hàng đang bán dở.
  - **Mã QR Code động:** Khi chọn thanh toán bằng chuyển khoản, hệ thống tạo mã VietQR động chứa mã tài khoản nhận tiền của cửa hàng và số tiền chính xác đến từng chữ số của hóa đơn để tránh khách gõ sai số tiền.

---

### PHÂN HỆ 5: KHÁCH HÀNG & CÔNG NỢ (CUSTOMERS & DEBT)

#### 5.1. Màn hình Sổ Nợ Khách Hàng (Customer Receivable List)
- **Đường dẫn file Flutter:** [customer_list_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/customers/presentation/customer_list_screen.dart)
- **Địa chỉ API kết nối:** `GET /customers/receivables`
- **Mô tả giao diện (UI Layout):**
  - Danh sách khách hàng kèm số dư công nợ (`balance`) hiện tại.
  - Thanh tìm kiếm nhanh theo Tên hoặc Số điện thoại.
  - Huy hiệu (Badge) cảnh báo đối với các khách hàng có số nợ vượt quá hạn mức tín dụng (`credit_limit`).

#### 5.2. Màn hình Lịch sử Giao dịch và Trả Nợ (Receivable Detail & Payments)
- **Đường dẫn file Flutter:** [customer_detail_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/customers/presentation/customer_detail_screen.dart)
- **Địa chỉ API kết nối:**
  - `GET /customers/:id/payments` (Lấy lịch sử thanh toán nợ)
  - `POST /receivables/:id/payments` (Ghi nhận lượt trả nợ mới)
- **Mô tả giao diện (UI Layout):**
  - Danh sách các khoản nợ phải thu của khách hàng kèm ngày hết hạn (Due Date).
  - Bảng lịch sử thu hồi nợ (Ngày thanh toán, số tiền, phương thức, người ghi nhận).
  - Dialog **"Ghi nhận thanh toán nợ"**: Ô nhập số tiền trả, phương thức thanh toán, ghi chú và trường tải lên ảnh minh chứng giao dịch (Hóa đơn ngân hàng).

#### 5.3. Báo cáo Tuổi Nợ (Debt Aging Report)
- **Đường dẫn file Flutter:** [debt_aging_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/finance/presentation/debt_aging_screen.dart)
- **Địa chỉ API kết nối:** `GET /reports/debt-aging`
- **Mô tả giao diện (UI Layout):**
  - Biểu đồ cột biểu diễn phân bổ nợ theo các nhóm tuổi nợ: *Trong hạn*, *Quá hạn 1-30 ngày*, *Quá hạn 31-60 ngày*, *Quá hạn 61-90 ngày*, *Quá hạn trên 90 ngày*.
  - Bảng danh sách chi tiết các khoản nợ quá hạn xếp theo thứ tự giảm dần của số tiền nợ.

---

### PHÂN HỆ 6: TÀI CHÍNH & QUỸ TIỀN (FINANCE & CASH)

#### 6.1. Bảng Kê Mua Hàng Không Hóa Đơn (Mẫu số 01/TNDN)
- **Đường dẫn file Flutter:** [purchase_no_invoice_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/finance/presentation/purchase_no_invoice_screen.dart)
- **Đường dẫn Route GoRouter:** `/purchases-no-invoice`
- **Địa chỉ API kết nối:** `POST /purchases/no-invoice`
- **Mô tả giao diện (UI Layout):**
  - Form thông tin người bán: *Họ tên*, *Địa chỉ*, *SĐT/Số CCCD*.
  - Bảng chi tiết mặt hàng thu mua gồm các dòng nhập liệu: Tên nông sản/dịch vụ, Số lượng, Đơn giá, Thành tiền.
- **Ràng buộc & Logic nghiệp vụ:**
  - **Tự động hoàn thiện dòng đang nhập dở (Auto-Complete):** Khi người dùng đang nhập dở tên hoặc số lượng mặt hàng ở dòng cuối cùng nhưng chưa kịp bấm nút "Thêm vào bảng" mà đã nhấn nút lưu lớn ở cuối màn hình, hệ thống bắt buộc phải tự động nạp dòng đang nhập dở đó vào mảng danh sách trước khi gửi API lên server.

#### 6.2. Màn hình Chốt Sổ Hàng Ngày (Daily Closing Screen)
- **Đường dẫn file Flutter:** [daily_closing_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/finance/presentation/daily_closing_screen.dart)
- **Địa chỉ API kết nối:** `GET /daily-closing/status` và `POST /daily-closing/close`
- **Mô tả giao diện (UI Layout):**
  - Biểu mẫu đối chiếu dòng tiền mặt cuối ca/ngày:
    - *Tiền mặt đầu ngày* (hệ thống tự lấy ca trước).
    - *Doanh thu tiền mặt hệ thống* (tự động cộng dồn từ hóa đơn).
    - *Chi phí tiền mặt hệ thống* (tự động trừ đi từ sổ quỹ chi).
    - *Tiền mặt lý thuyết trên két* (Expected Cash).
    - *Tiền mặt kiểm đếm thực tế* (Input field để thủ quỹ điền).
    - *Chênh lệch tiền mặt* (Tự động tính: Thực tế - Lý thuyết).
- **Ràng buộc & Logic nghiệp vụ:**
  - Nếu số tiền chênh lệch khác 0, bắt buộc người dùng nhập trường **"Lý do chênh lệch"** trước khi bấm nút "Xác nhận chốt sổ".

#### 6.3. Quét và Nhận diện Hóa đơn bằng OCR
- **Đường dẫn file Flutter:** [invoice_scan_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/finance/presentation/invoice_scan_screen.dart)
- **Địa chỉ API kết nối:** `POST /finance/scan-ocr`
- **Mô tả giao diện (UI Layout):**
  - Khung camera chụp ảnh hóa đơn hoặc nút chọn ảnh từ thư viện thiết bị.
  - Hoạt ảnh quét (Scanner line) trong khi backend chạy nhận diện OCR.
  - Bảng hiển thị kết quả phân tích: *Số hóa đơn*, *Ngày lập*, *Mã số thuế bên bán*, *Mã số thuế bên mua*, *Tổng tiền*, và bảng chi tiết các dòng mặt hàng.
  - Nút *Xác nhận thông tin & Nạp vào cơ sở dữ liệu*.

#### 6.4. Biểu đồ Dự Phong Dòng Tiền (Cashflow Forecast Screen)
- **Đường dẫn file Flutter:** [cashflow_forecast_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/finance/presentation/cashflow_forecast_screen.dart)
- **Địa chỉ API kết nối:** `GET /reports/cashflow`
- **Mô tả giao diện (UI Layout):**
  - Biểu đồ đường (Line Chart) biểu diễn biến động quỹ tiền theo thời gian (các ngày trong tháng).
  - Trục hoành biểu thị thời gian, trục tung biểu thị số dư quỹ (VND).
- **Ràng buộc & Logic nghiệp vụ:**
  - **Chốt chặn crash biểu đồ (fl_chart crash guard):** Nếu khoảng thời gian lọc chỉ trả về 1 điểm dữ liệu dòng tiền (Ví dụ: ngày hôm nay), hệ thống tự động gán giá trị biên $maxX = 1.0$ (với $minX = 0$), không được phép để $maxX == minX$ vì thư viện `fl_chart` sẽ ném ngoại lệ xác thực gây lỗi màn hình đỏ (Red Screen).

---

### PHÂN HỆ 7: BÁO CÁO THUẾ & TUÂN THỦ (TAX & COMPLIANCE)

#### 7.1. Màn hình Kê Khai Thuế Mẫu 01/CNKD & Xuất XML
- **Đường dẫn file Flutter:** [tax_declaration_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/finance/presentation/tax_declaration_screen.dart)
- **Địa chỉ API kết nối:** `GET /tax/declaration` và `GET /tax/export-xml`
- **Mô tả giao diện (UI Layout):**
  - Biểu mẫu mô phỏng 100% tờ khai thuế 01/CNKD của Tổng cục Thuế Việt Nam gồm các chỉ tiêu doanh thu và thuế GTGT, TNCN phân chia theo 4 nhóm ngành nghề:
    1. Phân phối, cung cấp hàng hóa (tỷ lệ 1.5%).
    2. Dịch vụ, xây dựng không bao thầu nguyên vật liệu (tỷ lệ 7.0%).
    3. Sản xuất, vận tải, dịch vụ có gắn với hàng hóa, xây dựng có bao thầu (tỷ lệ 4.5%).
    4. Hoạt động kinh doanh khác (tỷ lệ 3.0%).
  - Nút *Kiểm tra dữ liệu tờ khai*.
  - Nút *Xuất tờ khai XML nạp HTKK*.
