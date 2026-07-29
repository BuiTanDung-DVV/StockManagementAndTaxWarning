# Audit thứ bậc thị giác — Dashboard production

Ngày đánh giá: 29/07/2026
Phạm vi: Dashboard trên màn hình hẹp, dữ liệu production.

## Bằng chứng

1. [Phần tổng quan và biểu đồ](screenshots/03-current-summary.png)
2. [Khối ưu tiên và sản phẩm bán chạy](screenshots/02-current-top.png)
3. [Cuối danh sách và trạng thái lỗi](screenshots/01-current-inventory.png)

## Kết luận

- Chỉ số doanh thu và số dư quỹ đang có trọng lượng gần như ngang nhau, khiến
  người dùng khó xác định chỉ số chính.
- `Ưu tiên hôm nay` nằm sau biểu đồ trên màn hình hẹp và trạng thái chỉ được thể
  hiện bằng chữ màu nhỏ, chưa phản ánh đúng mức độ cần xử lý.
- Nút hành động `Bán hàng` che một phần nội dung khi cuộn.
- Các hàng dữ liệu, thông báo lỗi và nội dung tham khảo dùng độ tương phản gần
  nhau nên trạng thái cần chú ý chưa nổi bật.

## Điều chỉnh local

- Chuyển `Ưu tiên hôm nay` lên trước biểu đồ trên màn hình hẹp.
- Thêm dải màu trạng thái, nền nhấn nhẹ, số thứ tự và badge trạng thái cho từng
  việc ưu tiên.
- Nhấn mạnh doanh thu thuần là chỉ số chính bằng màu ngữ nghĩa và viền nhấn.
- Chuyển hành động `Bán hàng` lên cụm hành động đầu trang trên màn hình hẹp.
- Giữ nguyên biểu đồ, dữ liệu, route và API.

## Giới hạn xác minh

- Ảnh chỉ cho phép đánh giá trạng thái hiển thị hiện tại; chưa đủ để kết luận
  đạt chuẩn accessibility.
- Bản local chưa được deploy nên chưa có ảnh production sau điều chỉnh.
