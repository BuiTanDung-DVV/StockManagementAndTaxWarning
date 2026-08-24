# Đối soát kỳ, KPI và danh sách bán hàng

**Ngày kiểm tra:** 20/08/2026
**Trạng thái:** Đã sửa và xác minh local; chưa deploy production

## Sai lệch

Tổng quan bán hàng dùng kỳ từ đầu tháng đến ngày hiện tại, nhưng bảng đơn không gửi
ngày bắt đầu/kết thúc. Vì vậy người dùng nhìn thấy KPI theo tháng và danh sách toàn
bộ lịch sử trong cùng màn hình nhưng không thể đối chiếu.

## Thay đổi

- Bộ lọc kỳ được đặt trong khối “Danh sách đơn hàng”, ngay phía trên tìm kiếm và trạng thái.
- Mặc định danh sách dùng đúng kỳ của KPI; người dùng có thể chọn “Toàn bộ”.
- Flutter luôn gửi đồng thời `from` và `to`, hoặc không gửi cả hai.
- Backend từ chối kỳ thiếu một đầu và lọc theo `sales_orders.order_date` tại PostgreSQL
  trước khi phân trang.
- Các bộ lọc chỉ tác động bảng bên dưới, không gây hiểu nhầm là thay đổi biểu đồ/KPI.

## Đối soát DB kỳ 01–28/07/2026

| Chỉ tiêu | Kết quả |
|---|---:|
| Chờ xử lý | 81 đơn |
| Đã xác nhận | 0 đơn |
| Hoàn thành (`COMPLETED` + `DELIVERED`) | 347 đơn |
| Tổng không hủy/KPI | 428 đơn |
| Đã hủy | 9 đơn |
| Tổng bảng mọi trạng thái | 437 đơn |

Kiểm soát: `81 + 0 + 347 = 428`; `428 + 9 = 437`.

## Đối soát sổ cái

| Cửa hàng | Doanh thu thuần | Giá vốn | Lợi nhuận gộp | Chênh sổ cái |
|---|---:|---:|---:|---:|
| 34 | 649.165.000đ | 498.135.000đ | 151.030.000đ | 0đ |
| 35 | 785.480.000đ | 647.082.000đ | 138.398.000đ | 0đ |

Tổng doanh thu biểu đồ ngày và tổng số đơn theo ngày cũng chênh KPI `0`.

## Kiểm thử

- Backend build đạt; 15/15 kiểm thử mục tiêu bán hàng đạt.
- Flutter analyze các tệp liên quan không có lỗi; 5/5 kiểm thử bố cục/kỳ đạt.
- Web release local build thành công. Cảnh báo WASM thuộc `flutter_tts` bên thứ ba,
  không ảnh hưởng bản JavaScript hiện tại.

## Chưa xác minh

- Chưa chụp màn bán hàng sau đăng nhập vì chưa được phép truyền thông tin tài khoản
  kiểm thử qua trình duyệt.
- Chưa deploy/smoke test production.
