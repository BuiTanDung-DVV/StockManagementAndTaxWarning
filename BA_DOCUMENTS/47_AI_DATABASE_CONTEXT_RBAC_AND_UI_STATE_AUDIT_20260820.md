# Nguồn dữ liệu, RBAC và trạng thái giao diện AI — 20/08/2026

## Sai lệch As-Is

- Kho tài liệu AI gọi backend nhưng khi API lỗi lại hiển thị như DB rỗng.
- `/ai/knowledge` cho phép thành viên cửa hàng thêm/sửa/xóa tài liệu mà chưa kiểm tra quyền `settings`.
- Ngữ cảnh doanh thu AI tự tính công thức riêng và trừ giá trị đơn gốc theo phiếu hoàn, có nguy cơ lệch báo cáo bán hàng.
- Khi truy vấn dữ liệu cửa hàng lỗi, các biến khởi tạo bằng `0` hoặc câu “không có cảnh báo”, khiến lỗi DB có thể bị hiểu nhầm là tình hình thực tế.
- Tiêu đề màn Kho tài liệu AI có cấu trúc flex không hợp lệ, widget test phát hiện lỗi layout.

## To-Be đã triển khai local

- Flutter dùng `AsyncNotifier`: phân biệt `đang tải`, `DB rỗng`, `lỗi có Thử lại`; không có tài liệu mẫu/fallback cục bộ.
- Frontend dùng endpoint chuẩn `/ai-knowledge` đã có validation và quyền `settings`.
- Endpoint tương thích `/ai/knowledge` được giữ lại nhưng áp dụng `settings:view` khi đọc và `settings:edit` khi ghi/xóa.
- Doanh thu 30 ngày của AI dùng `SalesService.summary()`, cùng nguồn PostgreSQL và công thức hoàn hàng đã đối soát.
- Truy vấn lỗi được ghi rõ `CHƯA THỂ TRUY VẤN DB`; prompt cấm suy diễn thành 0 hoặc trạng thái an toàn.
- Truy vấn kho tài liệu lỗi không còn trả chuỗi rỗng; AI phải thông báo chưa đủ nguồn pháp lý.
- Tiêu đề màn hình được cấp chiều rộng hữu hạn, không còn lỗi flex.
- Khóa Gemini chỉ được đọc trong backend; frontend không chứa tên hoặc giá trị secret.

## Bằng chứng DB chỉ đọc

| Chỉ số | Shop 34 | Shop 35 |
|---|---:|---:|
| Tài liệu AI trong DB | 3 | 3 |
| Doanh thu thuần 22/07–20/08/2026 | 159.393.000đ | 192.050.000đ |
| Lệch so với sổ cái | 0đ | 0đ |
| Lệch giá vốn/lợi nhuận/biểu đồ ngày/số đơn | 0 | 0 |

Nguồn tái lập: `audit-store-data` và `audit-kpi-reconciliation` chỉ đọc.

## Kiểm thử

- Backend lint/build và `181/181` test P0 đạt.
- Flutter analyze sạch và `133/133` unit/widget test đạt.
- Hai widget test xác nhận lỗi DB không hiển thị thành thư viện rỗng và trạng thái rỗng chỉ xuất hiện khi API trả danh sách rỗng thật.
- Source contract test khóa endpoint backend, secret boundary và RBAC cho route tương thích.

## Trạng thái

- Code/API/DB local: **Đã xác minh**.
- Gọi Gemini thật và negative test bằng tài khoản nhân viên production: **Chưa xác minh**, chờ deploy và thông tin đăng nhập được người dùng cho phép sử dụng.
- Production hiện tại chưa chứa các sửa đổi này.
