# Kiểm soát dữ liệu runtime và ranh giới bí mật — 20/08/2026

## Phạm vi

- Số liệu nghiệp vụ phải theo luồng `PostgreSQL → backend API → Flutter`.
- Không dùng dữ liệu mẫu/dự phòng khi API hoặc DB lỗi.
- Secret của DB, Cloudinary, Gemini, JWT và OTP chỉ được đọc từ môi trường backend.

## Kết quả xác minh

| Nhóm | Trạng thái | Bằng chứng |
|---|---|---|
| Bán hàng, kho, tài chính, công nợ | Đã xác minh ở source | Provider Flutter gọi API; backend truy vấn repository/SQL theo phạm vi cửa hàng |
| AI và kho tri thức | Đã xác minh ở source | Ngữ cảnh cửa hàng và tài liệu lấy từ DB; Gemini key chỉ được đọc trong backend |
| Ảnh sản phẩm, QR, chứng từ | Đã xác minh ở source | Flutter gửi bytes đến backend; Cloudinary key/signature không trả về client; DB lưu URL/object key đã xác nhận |
| Biểu mẫu kê khai thuế | Đã sửa local | Chuyển từ danh sách trong widget sang `system_configs.TAX_DECLARATION_FORMS` |
| Liên kết hỗ trợ thuế | Đã sửa local | Chuyển sang `system_configs.TAX_SUPPORT_LINKS`; backend kiểm tra HTTPS và allowlist tên miền |
| Google OAuth Client ID | Cấu hình public, đúng giao thức | Client ID bắt buộc có ở client để khởi tạo Google SDK; không phải secret. Google Client Secret không xuất hiện ở Flutter |
| Danh sách bán hàng đa cửa hàng | Đã sửa local, đối soát DB chỉ đọc | API nhận danh sách shop đã phân quyền và lọc tại PostgreSQL; 15.378 = 7.595 + 7.783, không có dòng ngoài phạm vi |

## Hành vi khi thiếu dữ liệu

- Backend từ chối JSON cấu hình sai, danh sách rỗng, trạng thái/màu không hợp lệ hoặc URL ngoài allowlist.
- Flutter hiển thị loading/error; không tự chèn dữ liệu mẫu.
- Hai màn thuế chỉ hiển thị danh mục sau khi API trả dữ liệu DB hợp lệ.
- Khi API kho tri thức AI lỗi, provider giữ trạng thái DB tải thành công gần nhất hoặc rỗng; không thay bằng tài liệu mẫu cục bộ.

## Dữ liệu nào được phép nằm trong frontend

- Được phép: nhãn nút, tiêu đề, trạng thái trình bày, màu sắc, breakpoint và quy tắc bố cục.
- Không được phép: đơn hàng, sản phẩm, khách hàng, số tiền, tồn kho, cấu hình thuế, ngân hàng, liên kết nghiệp vụ hoặc tài liệu AI giả lập.
- `DUMMY_PASSWORD_HASH` trong backend là hash cố định dùng cân bằng thời gian kiểm tra đăng nhập khi không tìm thấy tài khoản; không phải mật khẩu người dùng hay dữ liệu nghiệp vụ.

## Thay đổi kỹ thuật

- API mới: `GET /api/tax-reference-data`, yêu cầu đăng nhập, cửa hàng hợp lệ và quyền xem tài chính.
- Migration chuẩn bị: `backend/database/20260820_seed_tax_reference_data.sql`.
- Migration dùng `UPSERT` trên hai khóa global, không đổi schema và không xóa dữ liệu khác.

## Kiểm thử

- Backend build và lint đạt.
- 6/6 test mục tiêu đạt: ranh giới secret frontend, nguồn cấu hình backend, parser JSON và chặn URL giả mạo.
- Flutter analyze bốn file liên quan đạt, 2/2 unit test parser/fail-closed đạt.
- Sau bản đối soát giá vốn: backend lint/build và `181/181` kiểm thử P0 đạt; Flutter analyze toàn dự án và `133/133` kiểm thử đạt.

## Phần chưa xác minh

- Chưa chạy migration trên production và chưa deploy theo nguyên tắc chỉ triển khai khi người dùng yêu cầu.
- Chưa smoke test hai màn trên production vì hai khóa DB mới chưa tồn tại.
- Nội dung/tính hiệu lực pháp lý của từng mã biểu mẫu cần được đối chiếu nguồn chính thức trước khi coi là quy định hiện hành.
