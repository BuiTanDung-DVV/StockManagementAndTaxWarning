# Toàn vẹn giá vốn, lô và tồn kho — 20/08/2026

## Sai lệch As-Is

- Khi `calculateCOGS()` lỗi, luồng bán bắt lỗi rồi tự dùng `products.cost_price`; lỗi DB/lô có thể bị che thành một giá vốn hợp lệ giả.
- Trừ lô có điều kiện `remaining_qty >= qty` nhưng không kiểm tra số dòng đã cập nhật. Hai giao dịch đồng thời có thể cùng tính trên một lô; giao dịch sau không trừ được lô nhưng vẫn tiếp tục.
- Hoàn tất kiểm kê đang sửa `inventory_stocks` và movement nhưng không điều chỉnh `inventory_lots` hoặc bút toán chênh lệch. Đây là blocker nghiệp vụ cho lần kiểm kê có chênh lệch.

## To-Be đã triển khai local

- Lỗi tính giá vốn không còn bị bắt rồi thay bằng `product.costPrice`; lỗi làm rollback toàn bộ giao dịch bán.
- `commitLotDeductions()` yêu cầu đúng một dòng lô được cập nhật; nếu lô đã bị giao dịch khác tiêu thụ, giao dịch hiện tại dừng và rollback.
- Thêm script audit chỉ đọc đối chiếu tổng tồn–tổng lô theo từng sản phẩm, header COGS–dòng bán và dòng bán giá vốn 0.
- Không tự đặt chính sách định giá/bút toán cho chênh lệch kiểm kê.

## Đối soát DB chỉ đọc

| Chỉ số | Shop 34 | Shop 35 |
|---|---:|---:|
| Sản phẩm có tồn | 250 | 250 |
| Sản phẩm có lô | 250 | 250 |
| Tổng tồn | 22.380 | 5.430 |
| Tổng lô còn lại | 22.380 | 5.430 |
| Sản phẩm lệch tồn–lô | 0 | 0 |
| Có tồn nhưng thiếu lô / có lô nhưng thiếu tồn | 0 / 0 | 0 / 0 |
| Đơn lệch header COGS–tổng dòng | 0 | 0 |
| Dòng bán có giá vốn 0 | 0 | 0 |

Lệnh tái lập chỉ đọc: `node dist/scripts/audit-cogs-inventory-integrity.js --shop-ids=34,35`.

## Blocker cần duyệt nghiệp vụ

Khi kiểm kê thừa/thiếu, cần chọn và tài liệu hóa:

1. Giá trị lô tăng thêm dùng giá bình quân hiện tại, giá vốn sản phẩm hay giá nhập gần nhất.
2. Thiếu kho trừ lô theo FIFO hay theo phương pháp cấu hình của cửa hàng.
3. Tài khoản kế toán ghi nhận chênh lệch kiểm kê và bước phê duyệt.

Chưa sửa luồng này vì việc tự chọn sẽ thay đổi công thức giá vốn và bút toán.

## Kiểm thử và trạng thái

- Backend lint/build và `181/181` test P0 đạt.
- Flutter analyze sạch và `133/133` unit/widget test đạt từ cổng gần nhất; lát cắt này không đổi Flutter.
- Dữ liệu hiện tại: **Đã xác minh, chưa có sai lệch**.
- Chống che lỗi và xung đột trừ lô: **Đã sửa local, có test**.
- Kiểm kê có chênh lệch: **Bị chặn chờ quyết định nghiệp vụ**.
- Production: **Chưa xác minh**.
