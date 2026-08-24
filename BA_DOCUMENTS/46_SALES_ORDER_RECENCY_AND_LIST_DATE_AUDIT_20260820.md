# Thứ tự đơn hàng và ngày giao dịch trên danh sách — 20/08/2026

## Sai lệch As-Is

- API danh sách sắp theo `createdAt`, tức thời điểm bản ghi được tạo/import vào DB.
- Với bộ dữ liệu nhập lịch sử ba năm, đơn cũ được import sau có thể bị hiểu nhầm là đơn gần đây.
- Danh sách Bán hàng không hiển thị ngày giao dịch, nên người dùng không thể kiểm tra thứ tự.
- Thẻ “Đơn hàng gần đây” chỉ tải tối đa 5 dòng nhưng có nút `Xuất Excel`, dễ bị hiểu là xuất toàn bộ lịch sử.

## To-Be đã triển khai local

- API sắp theo `orderDate DESC, id DESC`: ưu tiên ngày nghiệp vụ và ổn định khi hai đơn trùng thời điểm.
- Danh sách Bán hàng hiển thị `Ngày giao dịch` trên desktop và mobile, lấy từ trường `orderDate` của API.
- Thẻ Dashboard đổi nhãn `Ngày đặt` thành `Ngày giao dịch`, chỉ hiển thị ngày thay vì giờ import/UTC.
- Bỏ nút xuất dữ liệu một phần khỏi thẻ tóm tắt; giữ `Xem tất cả` để chuyển đến danh sách có bộ lọc.
- Không tạo dữ liệu dự phòng và không dùng `createdAt` để thay thế khi thiếu ngày nghiệp vụ.

## Đối soát DB/API chỉ đọc

| Shop | Số dòng kiểm tra | ID đầu API | ID đầu SQL | Dòng lệch | Ngày giao dịch mới nhất |
|---:|---:|---:|---:|---:|---|
| 34 | 20 | 175338 | 175338 | 0 | 28/07/2026 |
| 35 | 20 | 183124 | 183124 | 0 | 28/07/2026 |

SQL độc lập dùng `ORDER BY order_date DESC, id DESC`. Lệnh tái lập chỉ đọc:

`node dist/scripts/audit-sales-order-recency.js --shop-ids=34,35 --limit=20`

## Kiểm thử

- Backend lint/build và `181/181` kiểm thử P0 đạt.
- Flutter analyze sạch và `133/133` unit/widget test đạt.
- Test khóa thứ tự DB, nhãn ngày giao dịch, định dạng ngày và việc không xuất Excel từ tập dữ liệu tóm tắt.

## Trạng thái

- Code/API/DB local: **Đã xác minh**.
- Dữ liệu tháng 08 rỗng: **Phù hợp DB hiện tại**, vì đơn mới nhất là 28/07/2026.
- Production: **Chưa xác minh**, chờ lệnh deploy của người dùng.
