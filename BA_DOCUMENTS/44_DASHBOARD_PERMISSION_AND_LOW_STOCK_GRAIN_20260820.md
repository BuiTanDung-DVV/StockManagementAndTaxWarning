# Quyền Dashboard và grain tồn dưới định mức — 20/08/2026

## 1. Đơn hàng gần đây

### Sai lệch

- Dashboard dùng quyền `finance` để quyết định tải danh sách đơn hàng gần đây.
- Backend `/sales-orders` yêu cầu quyền `sales`.
- Hệ quả: người có finance nhưng không có sales nhận lỗi; người có sales nhưng không có finance lại không thấy dữ liệu được phép xem.

### Đã sửa local

- Chỉ owner hoặc người có quyền sales ở một cửa hàng được tải danh sách đơn gần đây.
- Người chỉ có dashboard vẫn xem được số liệu tổng hợp theo route cho phép nhưng không được tải danh sách đơn chi tiết.
- Chế độ tất cả cửa hàng tiếp tục không mở chi tiết từ khối này.

## 2. Tồn dưới định mức

### Sai lệch

- API cũ trả từng dòng `inventory_stocks`, tức một sản phẩm có thể xuất hiện nhiều lần theo kho.
- KPI và nội dung lại gọi `items.length` là số sản phẩm, nên grain không nhất quán.

### Đã sửa local

- Backend nhóm theo `shop_id + product_id` và cộng `SUM(quantity)` trước khi so với `products.min_stock`.
- Mỗi sản phẩm/cửa hàng chỉ trả một dòng, kèm `warehouseCount`.
- UI ghi `Tổng tồn ... · ... kho`, tránh hiểu nhầm đây là tồn của một kho riêng lẻ.

## 3. Đối soát DB chỉ đọc

| Shop | Dòng cảnh báo cũ theo kho | Sản phẩm cảnh báo sau tổng hợp | Dòng service | Trùng service | Lệch thành viên | Lệch số lượng |
|---:|---:|---:|---:|---:|---:|---:|
| 34 | 0 | 0 | 0 | 0 | 0 | 0 |
| 35 | 0 | 0 | 0 | 0 | 0 | 0 |

DB hiện không có sản phẩm dưới định mức tổng. Vì vậy chỉ có thể xác minh trạng thái rỗng bằng DB; trường hợp nhiều kho có cảnh báo được khóa bằng test tự động, chưa tạo dữ liệu production.

Lệnh tái lập chỉ đọc: `npm run audit:low-stock -- --shop-ids=34,35`.

## 4. Trạng thái

- Logic grain và quyền: **Đã xác minh local**.
- DB hiện tại: **Đã xác minh trạng thái rỗng**.
- Cổng hồi quy mới nhất: backend lint/build và `181/181` test P0 đạt; Flutter analyze sạch và `133/133` unit/widget test đạt.
- Production và dữ liệu nhiều kho có cảnh báo: **Chưa xác minh**.
