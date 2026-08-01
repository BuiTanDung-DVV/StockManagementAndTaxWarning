# Ma trận chụp và kiểm thử toàn bộ giao diện production — 01/08/2026

## 1. Mục đích

Ma trận này khóa phạm vi vòng kiểm tra lại production để không bỏ sót màn hình, màn con hoặc
trạng thái quan trọng. Phạm vi hiện tại gồm:

- 55 route được khai báo trong `app_router.dart`;
- 6 màn con mở bằng `Navigator` hoặc phụ thuộc hành động trước đó;
- các trạng thái dùng chung: chọn một cửa hàng/tất cả cửa hàng, AI đóng/mở/ẩn, loading, empty,
  error, bộ lọc, phân trang, upload ảnh và responsive.

Ảnh cũ ngày 30/07 chỉ dùng để so sánh lịch sử, không thay thế ảnh production của vòng này.

## 2. Trạng thái công cụ và bằng chứng

| Hạng mục | Kết quả |
|---|---|
| URL production | `https://smartstock-tax.vercel.app/#/login` |
| Kích thước đã quan sát | `1280×720` |
| Màn đã có ảnh hợp lệ | Đăng nhập desktop |
| Chụp tiếp bằng Browser | Bị chặn: canvas Flutter làm lệnh chụp hết thời gian hai lần |
| Trình duyệt Chrome dự phòng | Không khả dụng trong phiên hiện tại |
| Phiên đăng nhập test | Chưa có |

Không kết luận màn sau đăng nhập “đạt” khi chưa có ảnh và chưa thao tác trực tiếp.

## 3. Ma trận 55 route

Quy ước trạng thái ảnh: `Đã chụp`, `Chờ đăng nhập`, `Chờ dữ liệu`, `Bị chặn công cụ`.

### 3.1 Xác thực và khởi tạo

| # | Route | Màn hình/trạng thái phải kiểm tra | Desktop | Mobile |
|---:|---|---|---|---|
| 1 | `/login` | Mặc định, sai mật khẩu, hiện/ẩn mật khẩu, loading | Đã chụp mặc định | Bị chặn công cụ |
| 2 | `/register` | Form, validation, loại tài khoản, gửi OTP | Bị chặn công cụ | Bị chặn công cụ |
| 3 | `/verify-otp` | OTP đúng/sai/hết hạn, gửi lại, quay lại | Chờ luồng đăng ký | Chờ luồng đăng ký |
| 4 | `/forgot-password` | Gửi yêu cầu, lỗi email, thành công | Bị chặn công cụ | Bị chặn công cụ |
| 5 | `/onboarding` | Tạo cửa hàng, validation, hoàn tất | Chờ tài khoản mới | Chờ tài khoản mới |
| 6 | `/waiting-approval` | Chờ duyệt, refresh trạng thái, đăng xuất | Chờ tài khoản nhân viên | Chờ tài khoản nhân viên |

### 3.2 Dashboard và bán hàng

| # | Route | Màn hình/trạng thái phải kiểm tra | Desktop | Mobile |
|---:|---|---|---|---|
| 7 | `/` | Một cửa hàng, tất cả cửa hàng, các kỳ, chart/tooltip, empty/error | Chờ đăng nhập | Chờ đăng nhập |
| 8 | `/sales` | Chart, KPI, bộ lọc chỉ áp dụng danh sách, tìm kiếm, phân trang | Chờ đăng nhập | Chờ đăng nhập |
| 9 | `/pos` | Tìm SKU/barcode, giỏ hàng, khách, giảm giá, tiền mặt/QR/công nợ | Chờ đăng nhập | Chờ đăng nhập |
| 10 | `/sales/:id` | Chi tiết đơn, thanh toán, hoàn/hủy, chứng từ | Chờ bản ghi thật | Chờ bản ghi thật |
| 11 | `/sales/returns/:id` | Chi tiết phiếu trả, số lượng/tiền/giá vốn | Chờ deploy/test deep-link | Chờ deploy/test deep-link |
| 12 | `/customer-debts` | Aging, thu nợ, lọc, export toàn tập | Chờ đăng nhập | Chờ đăng nhập |

### 3.3 Sản phẩm, khách hàng và nhà cung cấp

| # | Route | Màn hình/trạng thái phải kiểm tra | Desktop | Mobile |
|---:|---|---|---|---|
| 13 | `/products` | Ảnh, SKU, đơn vị, giá, tồn, tag, lọc, đủ >20 dòng | Chờ đăng nhập | Chờ đăng nhập |
| 14 | `/products/tags` | Tạo/sửa/xóa tag, cấu hình bộ lọc | Chờ quyền chủ shop | Chờ quyền chủ shop |
| 15 | `/products/form` | Tạo/sửa, giá nhập/bán, đơn vị, upload/thay/xóa ảnh | Chờ quyền ghi | Chờ quyền ghi |
| 16 | `/products/:id` | Ảnh thật, giá, tồn, lịch sử, sửa sản phẩm | Chờ bản ghi thật | Chờ bản ghi thật |
| 17 | `/customers` | Tìm/lọc, công nợ, đủ >20 dòng | Chờ đăng nhập | Chờ đăng nhập |
| 18 | `/customers/form` | Tạo/sửa, validation, ảnh định danh | Chờ quyền ghi | Chờ quyền ghi |
| 19 | `/customers/:id` | Hồ sơ, đơn hàng, công nợ, thanh toán | Chờ bản ghi thật | Chờ bản ghi thật |
| 20 | `/suppliers` | Tìm/lọc, công nợ, đủ >20 dòng | Chờ đăng nhập | Chờ đăng nhập |
| 21 | `/suppliers/form` | Tạo/sửa và validation | Chờ quyền ghi | Chờ quyền ghi |
| 22 | `/suppliers/:id` | Hồ sơ, đơn nhập, phải trả | Chờ bản ghi thật | Chờ bản ghi thật |

### 3.4 Kho và nhập hàng

| # | Route | Màn hình/trạng thái phải kiểm tra | Desktop | Mobile |
|---:|---|---|---|---|
| 23 | `/inventory` | KPI, cảnh báo, nhóm hàng, link nghiệp vụ, đơn vị | Chờ đăng nhập | Chờ đăng nhập |
| 24 | `/stock-take` | Tạo phiếu, lịch sử, trạng thái phiếu | Chờ đăng nhập | Chờ đăng nhập |
| 25 | `/purchase-orders` | Danh sách, tạo đơn, nhận hàng, thanh toán | Chờ đăng nhập | Chờ đăng nhập |
| 26 | `/xnt-report` | Khoảng ngày, bảng đủ cột, tổng kiểm soát, export | Chờ đăng nhập | Chờ đăng nhập |
| 27 | `/purchase-orders/detail` | Chi tiết, dòng hàng, nhận hàng, công nợ | Chờ bản ghi từ danh sách | Chờ bản ghi từ danh sách |

### 3.5 Tài chính, hóa đơn và thuế

| # | Route | Màn hình/trạng thái phải kiểm tra | Desktop | Mobile |
|---:|---|---|---|---|
| 28 | `/finance` | KPI, thu/chi, chart, kỳ, đơn vị, drill-down | Chờ đăng nhập | Chờ đăng nhập |
| 29 | `/daily-closing` | Tiền hệ thống/thực đếm/chênh lệch, khóa sổ | Chờ dữ liệu ngày | Chờ dữ liệu ngày |
| 30 | `/profit-loss` | Doanh thu, giảm trừ, giá vốn, chi phí, lợi nhuận | Chờ đăng nhập | Chờ đăng nhập |
| 31 | `/cashflow-forecast` | Số dư đầu kỳ, dự báo, thu/chi, giả định | Chờ đăng nhập | Chờ đăng nhập |
| 32 | `/debt-aging` | Phải thu/phải trả theo bucket, drill-down | Chờ đăng nhập | Chờ đăng nhập |
| 33 | `/invoices` | Danh sách, ảnh, trạng thái, tìm/lọc, đủ >20 dòng | Chờ đăng nhập | Chờ đăng nhập |
| 34 | `/purchases-no-invoice` | Chứng từ, duyệt/từ chối, lý do | Chờ dữ liệu phù hợp | Chờ dữ liệu phù hợp |
| 35 | `/tax-calculator` | Kỳ, ngưỡng, công thức, nguồn pháp lý, responsive | Chờ đăng nhập | Chờ đăng nhập |
| 36 | `/expense-ledger` | Nhóm chi phí Việt hóa, chart, danh sách, export | Chờ đăng nhập | Chờ đăng nhập |
| 37 | `/tax-obligations` | Nghĩa vụ, hạn, trạng thái, thanh toán | Chờ đăng nhập | Chờ đăng nhập |
| 38 | `/salary-ledger` | Kỳ lương, nhân viên, gross/net, trạng thái trả | Chờ đăng nhập | Chờ đăng nhập |
| 39 | `/tax-declaration` | Kỳ, chỉ tiêu, XML, lỗi validation/import HTKK | Chờ dữ liệu khai báo | Chờ dữ liệu khai báo |
| 40 | `/transactions` | Thu/chi, lọc, phân trang, export toàn tập | Chờ đăng nhập | Chờ đăng nhập |
| 41 | `/transactions/detail` | Chứng từ, tài khoản, liên kết nguồn, ảnh | Chờ bản ghi từ danh sách | Chờ bản ghi từ danh sách |
| 42 | `/tax-estimate` | Kỳ hiện tại, doanh thu, thuế ước tính, nguồn | Chờ đăng nhập | Chờ đăng nhập |

### 3.6 Cài đặt và quản trị

| # | Route | Màn hình/trạng thái phải kiểm tra | Desktop | Mobile |
|---:|---|---|---|---|
| 43 | `/settings` | Menu theo quyền, chọn một/tất cả cửa hàng, đăng xuất | Chờ đăng nhập | Chờ đăng nhập |
| 44 | `/settings/ai-knowledge` | Danh sách nguồn, upload, trạng thái xử lý, xóa | Chờ quyền chủ shop | Chờ quyền chủ shop |
| 45 | `/activity-logs` | Actor, hành động, đối tượng, thời gian, lọc | Chờ quyền chủ shop | Chờ quyền chủ shop |
| 46 | `/tax-config` | Phiên bản hiệu lực, nguồn, ngưỡng, audit thay đổi | Chờ quyền chủ shop | Chờ quyền chủ shop |
| 47 | `/tax-support` | Nội dung hướng dẫn, liên kết nguồn | Chờ đăng nhập | Chờ đăng nhập |
| 48 | `/payment-config` | QR/logo theo cửa hàng, thay/xóa ảnh | Chờ một cửa hàng | Chờ một cửa hàng |
| 49 | `/notifications` | Đọc/chưa đọc, gom nhóm, xử lý yêu cầu | Chờ đăng nhập | Chờ đăng nhập |
| 50 | `/staff` | Danh sách, mời, duyệt, quyền, trạng thái | Chờ quyền chủ shop | Chờ quyền chủ shop |
| 51 | `/employees` | Hiện trùng `/staff`; xác minh quyết định gộp/tách | Chờ quyền chủ shop | Chờ quyền chủ shop |
| 52 | `/roles` | Ma trận quyền, quyền nguy hiểm, responsive | Chờ quyền chủ shop | Chờ quyền chủ shop |
| 53 | `/profile` | Thông tin cá nhân, avatar/định danh | Chờ đăng nhập | Chờ đăng nhập |
| 54 | `/change-password` | Mật khẩu cũ/mới, validation, hết phiên | Chờ tài khoản mật khẩu | Chờ tài khoản mật khẩu |
| 55 | `/shop-profile` | Logo, thông tin thuế, địa chỉ, validation | Chờ một cửa hàng | Chờ một cửa hàng |

## 4. Màn con và trạng thái bắt buộc

| # | Màn/luồng | Cách mở đúng | Trạng thái |
|---:|---|---|---|
| 56 | QR thanh toán | Từ POS, chọn phương thức QR | Chờ đăng nhập |
| 57 | Form đơn nhập | Từ danh sách đơn nhập | Chờ đăng nhập |
| 58 | Form kiểm kê | Từ màn kiểm kê | Chờ đăng nhập |
| 59 | Lịch sử kiểm kê | Từ màn kiểm kê | Chờ đăng nhập |
| 60 | Kế hoạch ngân sách | Chưa có route/điểm vào được xác minh | Màn mồ côi |
| 61 | Quét hóa đơn | Chưa có route/điểm vào được xác minh | Màn mồ côi |
| 62 | Trợ lý AI | Header, floating, mở/đóng/ẩn/di chuyển | Chờ đăng nhập |
| 63 | QR cửa hàng ở header | Một cửa hàng/cửa hàng chưa có QR/tất cả cửa hàng | Chờ đăng nhập |
| 64 | Chọn phạm vi cửa hàng | Một cửa hàng → tất cả → quay lại một cửa hàng | Chờ đăng nhập |

## 5. Lỗi route và trạng thái sửa local

### NAV-01 — Nút “Nhập kho” đã có route local

Router hiện đã khai báo `/purchase-orders/form` và mở cùng `PurchaseOrderFormScreen`.

**Trạng thái:** static route registry test đạt; chờ smoke test production sau deploy.

**Còn cần:** widget/integration test cho CTA và reload trực tiếp URL.

### NAV-02 — Nút chi tiết phiếu trả đã dùng route hợp lệ local

Chi tiết đơn hiện gọi `/sales/returns/:id`; static route registry test đạt. Màn đích vẫn phụ thuộc
`state.extra`, nên refresh/deep-link chưa dựng lại được dữ liệu chỉ từ `:id`.

**Ảnh hưởng còn lại:** reload URL chi tiết hoàn trả có thể mất dữ liệu.

**Sửa tiếp:** đọc `id` để gọi API, chỉ dùng `extra` làm dữ liệu tạm; test click từ đơn và reload URL.

### NAV-03 — Route chi tiết phụ thuộc dữ liệu tạm trong bộ nhớ

`/purchase-orders/detail` và `/transactions/detail` nhận object qua `state.extra`. Mở URL trực tiếp,
refresh trình duyệt hoặc chia sẻ link có thể tạo object rỗng.

**Sửa tối thiểu:** chuyển thành route có `:id`, tải bản ghi từ API và chỉ dùng `extra` làm dữ liệu
tạm để hiển thị nhanh.

### NAV-04 — Hai route nhân viên trùng cùng một màn

`/staff` và `/employees` cùng mở `StaffManagementScreen`. Giữ hai route chỉ hợp lý nếu một route là
alias không xuất hiện trong menu; nếu cả hai cùng hiển thị, người dùng hiểu nhầm thành hai nghiệp vụ.

### NAV-05 — Guard route và quyền API không cùng ma trận

`/tax-estimate`, `/activity-logs`, `/settings/ai-knowledge` và `/tax-config` đang có mapping quyền
frontend khác với middleware backend. Kết quả dự kiến là màn mở được nhưng API trả 403, hoặc frontend
chặn người có quyền backend hợp lệ.

**Sửa tối thiểu:** định nghĩa một `RouteAccessPolicy` theo module/action, dùng cho menu và router;
backend giữ quyền là nguồn quyết định cuối cùng. Thêm test theo từng vai trò cho cả route và API.

## 6. Quy tắc chụp và nghiệm thu

Mỗi màn cần hai ảnh hợp lệ: desktop `1440×900` và mobile `390×844`. Với màn có dữ liệu, ảnh chỉ
được chấp nhận khi:

1. Không còn loading hoặc skeleton.
2. Không bị crop, co toàn canvas hoặc che bởi AI/FAB.
3. Header, thao tác chính, filter, bảng/biểu đồ và trạng thái cuối đều nhìn thấy.
4. Ảnh ghi đúng cửa hàng, kỳ dữ liệu và vai trò đang kiểm tra.
5. Tooltip/đơn vị được kiểm tra riêng cho biểu đồ.
6. Danh sách có hơn 20 bản ghi phải chứng minh chuyển trang/tải tiếp hoạt động.
7. Màn chi tiết phải reload được bằng URL hoặc ghi rõ thiết kế không hỗ trợ deep-link.
8. Accessibility chỉ ghi nhận sau kiểm thử keyboard, focus, zoom 200% và screen reader riêng.
