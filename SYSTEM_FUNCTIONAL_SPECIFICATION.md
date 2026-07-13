# Đặc Tả Tính Năng Hệ Thống Chi Tiết (System Functional Specification)
## Dành Cho Giám Sát, Kiểm Thử & Hoàn Thiện Hệ Thống

Tài liệu này đặc tả chi tiết toàn bộ các chức năng (UI/UX, logic nghiệp vụ, API liên kết và các quy tắc kiểm thử) của từng màn hình trong hệ thống SmartStock FinTech.

---

## 1. Phân Hệ Xác Thực & Bảo Mật (Authentication & Security)

### 1.1. Màn Hình Đăng Ký Tài Khoản (`RegisterScreen`)
*   **Đường dẫn file:** `lib/features/auth/presentation/register_screen.dart`
*   **Đường dẫn Route:** `/register` (GoRouter)
*   **Luồng xử lý nghiệp vụ:**
    1. Người dùng nhập: *Họ và tên*, *Email (Gmail)*, *Mật khẩu*, *Xác nhận mật khẩu*.
    2. Nút Đăng ký bằng Google & Facebook kết nối luồng OAuth tương ứng.
    3. Khi nhấn nút "Đăng Ký & Nhận Mã OTP", hệ thống gọi API gửi mã xác thực OTP về Email của người dùng, đồng thời chuyển hướng sang màn hình `/verify-otp`.
*   **Quy tắc kiểm thử & Giám sát:**
    *   **Thanh đo độ mạnh mật khẩu (Password Strength Meter):** Phân tích mật khẩu nhập vào theo 5 tiêu chí:
        - Độ dài tối thiểu 8 ký tự.
        - Có ít nhất 1 chữ cái in hoa (A-Z).
        - Có ít nhất 1 chữ cái thường (a-z).
        - Có ít nhất 1 con số (0-9).
        - Có ít nhất 1 ký tự đặc biệt (ví dụ: `@`, `#`, `$`, v.v.).
        - *Phản hồi UI:* 5 thanh màu sắc thay đổi: Đỏ (Yếu, $\le 2$ tiêu chí), Vàng (Trung bình, 3 tiêu chí), Xanh dương (Mạnh, 4 tiêu chí), Xanh lá (Cực mạnh, 5 tiêu chí). Nếu $\le 2$ điểm, nút Đăng ký bị khóa và báo lỗi.
    *   **Đối chiếu mật khẩu xác nhận (Real-time Match Indicator):** Hiển thị badge tức thì:
        - Màu xanh kèm dấu `✓ Mật khẩu xác nhận trùng khớp` khi trùng khớp hoàn toàn.
        - Màu đỏ kèm dấu `✗ Mật khẩu xác nhận chưa khớp` khi lệch ký tự.
    *   **Chặn gửi đúp (Double Submission Guard):** Trạng thái `_isLoading = true` sẽ vô hiệu hóa tương tác nút và hiển thị hoạt ảnh tải tròn.

### 1.2. Màn Hình Xác Thực Mã OTP (`OtpVerificationScreen`)
*   **Đường dẫn file:** `lib/features/auth/presentation/otp_verification_screen.dart`
*   **Đường dẫn Route:** `/verify-otp` (GoRouter - nhận tham số đăng ký qua `extra`)
*   **Luồng xử lý nghiệp vụ:**
    1. Giao diện hiển thị Email của người dùng đã đăng ký và ô nhập OTP 6 chữ số chuyên biệt.
    2. Tự động đếm ngược 60 giây. Khi kết thúc, cho phép bấm nút "Gửi lại mã ngay".
    3. Khi người dùng nhập đủ 6 chữ số hoặc bấm nút "Xác nhận & Hoàn tất", hệ thống gọi API `POST /auth/register` truyền đầy đủ thông tin tài khoản và mã OTP.
    4. Đăng ký thành công, tự động cập nhật token và chuyển hướng tới màn hình Onboarding cập nhật thông tin cửa hàng (`/onboarding`).
*   **Quy tắc kiểm thử & Giám sát:**
    *   **Liveness Check:** Không được phép để trống `state.extra` (GoRouter parameter loss). Nếu người dùng tải lại trang gây mất tham số, hệ thống phải tự động điều hướng quay lại trang `/register` kèm cảnh báo Toast.
    *   Kiểm tra cơ chế chặn gửi đúp khi độ dài OTP đạt đúng 6 ký tự để tránh tạo nhiều request đồng thời lên database.

### 1.3. Màn Hình Quên Mật Khẩu (`ForgotPasswordScreen`)
*   **Đường dẫn file:** `lib/features/auth/presentation/forgot_password_screen.dart`
*   **Đường dẫn Route:** `/forgot-password`
*   **Luồng xử lý nghiệp vụ:** Người dùng nhập Email -> Bấm gửi mã OTP đặt lại mật khẩu -> Nhập mã OTP 6 số và đặt lại mật khẩu mới.
*   **Quy tắc kiểm thử & Giám sát:** 
    *   Xác minh Regex định dạng Email nhập vào.
    *   Thông báo lỗi hiển thị chính xác là "Gửi về địa chỉ email của bạn" thay vì báo lỗi liên quan đến SĐT.

### 1.4. Màn Hình Đổi Mật Khẩu Tài Khoản (`ChangePasswordScreen`)
*   **Đường dẫn file:** `lib/features/settings/presentation/change_password_screen.dart`
*   **Đường dẫn Route:** `/change-password`
*   **Luồng xử lý nghiệp vụ:** Người dùng trong phiên đăng nhập muốn đổi mật khẩu. Nhập mật khẩu hiện tại, nhập mật khẩu mới và xác nhận mật khẩu mới. Gọi API `PUT /profile/password`.
*   **Quy tắc kiểm thử & Giám sát:**
    *   Áp dụng đầy đủ thanh đo độ mạnh mật khẩu và badge đối chiếu trùng khớp giống màn hình Đăng ký.
    *   Kiểm tra mật khẩu mới không được trùng khớp với mật khẩu cũ đang sử dụng.

---

## 2. Phân Hệ Quản Lý Cửa Hàng & Thành Viên (Shop & Staff Management)

### 2.1. Màn Hình Cửa Hàng Hiện Tại & Chuyển Shop (`SettingsScreen` / Shop Switcher)
*   **Đường dẫn file:** `lib/features/settings/presentation/settings_screen.dart`
*   **Luồng xử lý nghiệp vụ:**
    1. Khi click vào thanh chuyển shop ở đầu danh mục Cài đặt, hiển thị danh sách các cửa hàng người dùng sở hữu hoặc là nhân viên.
    2. Cho phép chọn chi nhánh cụ thể hoặc chọn chế độ *"Tất cả cửa hàng (Tổng quát)"*.
    3. Khi chọn xong, dữ liệu toàn bộ ứng dụng (Dashboard, doanh thu, đơn hàng, sản phẩm) tự động refetch theo `shopId` mới.
*   **Quy tắc kiểm thử & Giám sát:**
    *   **Chế độ Tất cả cửa hàng:** Kiểm tra tính chính xác của thuật toán SQL cộng dồn dữ liệu tại Backend (không bị crash do biến `shopId` truyền lên là `undefined`).
    *   **Quyền hạn (RBAC):** Nhân viên của Shop A không được quyền nhìn thấy Shop B trong danh sách chuyển đổi.

### 2.2. Màn Hình Quản Lý Danh Sách Nhân Viên (`StaffManagementScreen`)
*   **Đường dẫn file:** `lib/features/settings/presentation/staff_management_screen.dart`
*   **Đường dẫn Route:** `/staff`
*   **Luồng xử lý nghiệp vụ:**
    1. Tab **"Danh sách nhân viên"**: Hiển thị danh sách nhân viên hiện tại kèm chức vụ. Cho phép chỉnh sửa vai trò (Quản lý, Thủ kho, Thu ngân) hoặc xóa nhân viên khỏi shop.
    2. Tab **"Chờ duyệt"**: Hiển thị danh sách nhân viên đã gửi yêu cầu gia nhập shop. Owner bấm nút "Đồng ý" để phê duyệt hoặc "Từ chối".
*   **Quy tắc kiểm thử & Giám sát:**
    *   Quy trình phê duyệt nhân viên mới phải cập nhật tức thì trạng thái hoạt động của nhân viên trên cơ sở dữ liệu.
    *   Khi xóa nhân viên, hệ thống bắt buộc hiển thị Modal xác nhận cảnh báo.

---

## 3. Phân Hệ Hàng Hóa & Kho Vận (Products & Inventory)

### 3.1. Màn Hình Danh Sách & Chi Tiết Sản Phẩm (`ProductListScreen` / `ProductDetailScreen`)
*   **Đường dẫn file:** 
    - Danh sách: `lib/features/products/presentation/product_list_screen.dart`
    - Chi tiết: `lib/features/products/presentation/product_detail_screen.dart`
*   **Luồng xử lý nghiệp vụ:** Hiển thị danh sách sản phẩm của cửa hàng kèm hình ảnh, giá bán, tồn kho và các thẻ nhãn (tags). Nhấp vào một sản phẩm để xem chi tiết thông số, mã vạch và mô tả sản phẩm.
*   **Quy tắc kiểm thử & Giám sát:**
    *   **Độc nhất Barcode:** Khi thêm mới sản phẩm trùng barcode hiện tại, Backend phải chặn lại và trả về lỗi `Mã vạch này đã tồn tại` (Status Code 400).
    *   **Hiển thị Tag:** Các tag đính kèm sản phẩm phải hiển thị dưới dạng badge màu sắc trực quan. Lọc sản phẩm theo tag phải lọc chính xác (tránh lỗi substring collision, ví dụ lọc "VIP" không được ra sản phẩm mang tag "VIPER").
    *   **Mô tả sản phẩm:** Thẻ card "Mô tả sản phẩm" phải hiển thị đầy đủ văn bản định dạng chi tiết tại trang chi tiết.

### 3.2. Màn Hình Đặt Hàng Nhà Cung Cấp (`PurchaseOrderScreen`)
*   **Đường dẫn file:** `lib/features/inventory/presentation/purchase_order_screen.dart`
*   **Đường dẫn Route:** `/purchases`
*   **Luồng xử lý nghiệp vụ:** Lập đơn đặt hàng (PO) gửi nhà cung cấp. Đơn hàng khi tạo ở trạng thái Chờ duyệt. Khi người quản lý duyệt đơn hàng PO, số lượng tồn kho của các sản phẩm tương ứng trong kho tự động tăng lên.
*   **Quy tắc kiểm thử & Giám sát:**
    *   Đảm bảo toàn bộ thẻ Card PO trong danh sách có thể click bình thường để xem thông tin chi tiết (không bị đóng băng hay đơ giao diện).
    *   Kiểm tra lịch sử thay đổi tồn kho tương ứng của sản phẩm sau khi đơn PO được duyệt thành công.

### 3.3. Màn Hình Phiếu Kiểm Kho (`StockTakeScreen`)
*   **Đường dẫn file:** `lib/features/inventory/presentation/stock_take_screen.dart`
*   **Luồng xử lý nghiệp vụ:** Nhân viên thủ kho tạo phiếu kiểm kê số lượng sản phẩm thực tế tại cửa hàng, ghi nhận chênh lệch (thừa/thiếu). Khi lưu phiếu kiểm kê, hệ thống ghi đè số lượng tồn kho mới vào cơ sở dữ liệu.
*   **Quy tắc kiểm thử & Giám sát:**
    *   Yêu cầu hiển thị Modal xác nhận cảnh báo trước khi lưu phiếu kiểm kê kho vì đây là hành động làm thay đổi trực tiếp số lượng tồn kho hệ thống.

---

## 4. Bán Hàng POS & Thanh Toán (POS & Payment)

### 4.1. Màn Hình Bán Hàng Tại Quầy (`PosScreen`)
*   **Đường dẫn file:** `lib/features/sales/presentation/pos_screen.dart`
*   **Đường dẫn Route:** `/pos`
*   **Luồng xử lý nghiệp vụ:**
    1. Nhân viên quét mã vạch sản phẩm hoặc click chọn sản phẩm từ danh sách bên trái để đưa vào giỏ hàng.
    2. Giỏ hàng tự động cập nhật số tiền khách cần trả, chiết khấu hóa đơn và thuế VAT tương ứng.
    3. Bấm Thanh toán để hiển thị giao diện chọn phương thức thanh toán.
*   **Quy tắc kiểm thử & Giám sát:**
    *   **Tạo nhanh Khách hàng:** Nút tạo nhanh khách hàng trong POS phải hoạt động độc lập, sau khi tạo xong, ID của khách hàng mới phải được tự động gán thẳng vào giỏ hàng hiện tại mà không làm mất phiên bán hàng.
    *   **Hủy đơn hàng:** Nút hủy đơn hàng/xóa giỏ hàng phải hiển thị Modal xác nhận màu đỏ cảnh báo nhân viên.
    *   **Tính toán tiền:** Kiểm tra độ chính xác của tổng số tiền khi thay đổi số lượng sản phẩm lớn hoặc áp dụng giảm thuế VAT động.

### 4.2. Màn Hình Thanh Toán QR Code (`QrPaymentScreen`)
*   **Đường dẫn file:** `lib/features/sales/presentation/qr_payment_screen.dart`
*   **Luồng xử lý nghiệp vụ:** Hiển thị mã QR Code tương ứng với hóa đơn để khách hàng quét chuyển khoản qua ứng dụng ngân hàng.
*   **Quy tắc kiểm thử & Giám sát:** Mã QR Code động hiển thị phải chứa chính xác số tiền cần thanh toán và thông tin chuyển khoản cấu hình của cửa hàng.

---

## 5. Phân Hệ Tài Chính & Báo Cáo Thuế (Finance & Tax)

### 5.1. Mua Hàng Không Hóa Đơn (`PurchaseNoInvoiceScreen`)
*   **Đường dẫn file:** `lib/features/finance/presentation/purchase_no_invoice_screen.dart`
*   **Đường dẫn Route:** `/purchases-no-invoice`
*   **Luồng xử lý nghiệp vụ:** Lập bảng kê mua hàng hóa dịch vụ mua của người dân tự khai thác không có hóa đơn đỏ (Mẫu 01/TNDN).
*   **Quy tắc kiểm thử & Giám sát:**
    *   **Auto-Complete Dòng Đang Nhập:** Khi người dùng đang gõ dở thông tin tên sản phẩm, số lượng, đơn giá ở hàng cuối cùng nhưng chưa kịp bấm nút "Thêm vào danh sách" mà đã bấm nút "Lưu bảng kê", hệ thống phải tự động hoàn thiện nốt dòng đang nhập dở đó vào danh sách lưu để tránh mất dữ liệu của khách hàng.

### 5.2. Màn Hình Cấu Hình Thuế & Xuất XML HTKK (`TaxConfigScreen` / `TaxEstimateScreen`)
*   **Đường dẫn file:** 
    - Cấu hình: `lib/features/settings/presentation/tax_config_screen.dart`
    - Xuất tờ khai: `lib/features/tax/screens/tax_estimate_screen.dart`
*   **Luồng xử lý nghiệp vụ:**
    1. Trang Cấu hình Thuế: Cho phép chỉnh sửa tỷ lệ thuế suất áp dụng cho từng danh mục ngành hàng và lưu cấu hình xuống Database.
    2. Trang Xuất tờ khai: Hệ thống tổng hợp toàn bộ doanh thu hóa đơn bán ra và bảng kê mua vào, tự động tính nghĩa vụ thuế và kết xuất tệp XML tờ khai.
*   **Quy tắc kiểm thử & Giám sát:**
    *   Kiểm tra nút lưu cấu hình Thuế ghi nhận đúng giá trị xuống cơ sở dữ liệu và hiển thị Toast thông báo.
    *   Tệp XML tải xuống máy người dùng phải khớp định dạng chuẩn của phần mềm HTKK (Hỗ trợ Kê khai) và mở được bằng XML Viewer của HTKK.

### 5.3. Biểu Đồ Dự Phong Dòng Tiền (`CashflowForecastScreen`)
*   **Đường dẫn file:** `lib/features/finance/presentation/cashflow_forecast_screen.dart`
*   **Luồng xử lý nghiệp vụ:** Tổng hợp dòng tiền ra/vào từ bán hàng, chi phí cố định, quỹ lương để vẽ biểu đồ đường biểu diễn sự thay đổi dòng tiền trong tương lai.
*   **Quy tắc kiểm thử & Giám sát:**
    *   **Layout Chart Crash Guard:** Khi cơ sở dữ liệu chỉ có duy nhất 1 mốc dữ liệu dòng tiền (Ví dụ: ngày hôm nay), hệ thống bắt buộc phải gán giá trị $maxX = 1$ để tránh việc $maxX == minX == 0$ gây crash thư viện biểu đồ `fl_chart`.

---

## 6. Các Tính Năng Hệ Thống Khác (System-wide Features)

### 6.1. Hiển Thị Tiếng Việt UTF-8
*   **Quy tắc kiểm thử:** Toàn bộ các tiêu đề hiển thị trên Dashboard, nhãn biểu đồ tròn thanh toán, biểu đồ cột doanh thu phải hiển thị chuẩn xác tiếng Việt UTF-8 (ví dụ: hiển thị "Tổng quan hôm nay", không được bị lỗi font vỡ ký tự như `Tá»•ng quan`). Chart labels bắt buộc phải sử dụng font GoogleFonts Outfit/Inter thay vì TextStyle thô mặc định.

### 6.2. Dropdown Địa Chỉ Tỉnh/Thành
*   **Quy tắc kiểm thử:** Trường nhập Địa chỉ tại Thông tin cửa hàng, thông tin Khách hàng và Nhà cung cấp bắt buộc phải hiển thị dạng Dropdown lựa chọn Tỉnh/Thành thay vì cho phép gõ tự do, nhằm chuẩn hóa dữ liệu địa lý bán hàng phục vụ báo cáo thuế địa phương.

### 6.3. Giao Diện Toast Notification (`ToastService`)
*   **Quy tắc kiểm thử:** Toàn bộ thông báo hệ thống (thành công, lỗi, cảnh báo) phải hiển thị dưới dạng Custom Card Toast có màu sắc nền tương ứng (Xanh: thành công, Đỏ: lỗi) kèm icon minh họa trực quan thay vì hiển thị text đen thô sơ.
