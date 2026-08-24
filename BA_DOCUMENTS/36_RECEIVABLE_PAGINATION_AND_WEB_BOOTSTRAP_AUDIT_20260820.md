# Phân trang Sổ nợ và kiểm tra bootstrap web — 20/08/2026

## Vấn đề xác nhận

1. Màn Sổ nợ tải toàn bộ 453/473 khoản vào Flutter, làm chậm khi dữ liệu tăng.
2. KPI được tính từ danh sách frontend đang giữ nên sẽ sai nếu chỉ đổi sang phân trang đơn giản.
3. Xuất Excel dùng trang hiện tại thay vì toàn bộ tập dữ liệu phù hợp.
4. Khoản phải thu thủ công có endpoint thu nợ nhưng nút UI vẫn bị khóa khi không có `orderId`.
5. Web khai báo `removeSplashFromWeb` nhưng không gọi, khiến splash có thể che ứng dụng.

## Thiết kế đã triển khai local

- `GET /customer-receivables/paged`: tìm kiếm, trạng thái và sắp xếp tại PostgreSQL trước `skip/take`.
- `GET /customer-receivables/export`: tải toàn bộ tập phù hợp chỉ khi người dùng chủ động xuất.
- KPI `outstanding`, `overdue`, `customerCount`, `receivableCount` được tổng hợp độc lập trên toàn bộ khoản mở của cửa hàng.
- Bộ lọc đặt ngay phía trên danh sách và ghi rõ không tác động KPI.
- Tìm kiếm debounce 400 ms, chống response cũ ghi đè response mới.
- Desktop/mobile đều có phân trang và cho phép thu khoản thủ công bằng `receivableId`.
- Bootstrap web chờ `appRunner.runApp()` hoàn tất rồi xóa splash.

## Đối soát DB chỉ đọc tại ngày 20/08/2026

| Cửa hàng | Khoản mở | Khách còn nợ | Tổng phải thu | Quá hạn | Dòng trang 1 | Khoản lọc quá hạn |
|---|---:|---:|---:|---:|---:|---:|
| 34 | 453 | 24 | 904.500.000đ | 886.365.000đ | 20 | 439 |
| 35 | 473 | 24 | 1.208.989.000đ | 1.179.820.000đ | 20 | 459 |

- Tìm theo mã `SOY000006` tại shop 34 trả 1 dòng; export cùng bộ lọc trả đúng 1 dòng.
- KPI tổng phải thu vẫn là 904.500.000đ khi danh sách chỉ còn 1 dòng, chứng minh filter không làm sai KPI.
- Các tổng quá hạn khớp tổng bucket tuổi nợ đã đối soát trong tài liệu 33.

## Kiểm thử

- Backend TypeScript build và lint sạch.
- Backend P0: 166/166 đạt; nhóm query/reference mới: 4/4 đạt.
- Flutter analyze toàn dự án sạch; 111/111 unit/widget test đạt.
- Test bao phủ normalize query, filter không hợp lệ, query param frontend, routing thu nợ và thứ tự xóa splash.

## Chưa xác minh

- Chưa đăng nhập để chụp màn Sổ nợ local do thao tác trình duyệt cần xác nhận trước khi gửi mật khẩu test.
- Chưa kiểm tra viewport desktop/mobile sau đăng nhập.
- Chưa deploy; production vẫn dùng API/giao diện cũ.
- Không tạo hoặc cập nhật bản ghi công nợ production trong đợt kiểm tra này.
