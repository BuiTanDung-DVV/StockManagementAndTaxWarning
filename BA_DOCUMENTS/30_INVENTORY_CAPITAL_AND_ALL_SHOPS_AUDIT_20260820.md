# Đối soát vốn tồn kho và chế độ tất cả cửa hàng — 20/08/2026

## 1. Phạm vi

- Màn `/#/inventory` và các API tổng quan kho.
- Grain kiểm tra: một SKU trong một cửa hàng; tồn được cộng từ các kho thuộc đúng cửa hàng.
- Nguồn: `products`, `categories`, `inventory_stocks`, `product_batches`,
  `sales_orders`, `sales_order_items` qua backend.
- Chỉ đọc dữ liệu. Không migration, không backfill và không ghi production.

## 2. Sai lệch đã sửa local

| Hạng mục | Trước sửa | Sau sửa local | Trạng thái |
|---|---|---|---|
| Tất cả cửa hàng | Màn Kho gọi ba API chỉ nhận một `shopId`, gây lỗi từng phần | Tồn, lô sắp hết hạn và hàng chậm nhận danh sách shop đã được middleware phân quyền | Đã sửa, có test |
| Tổng sản phẩm | `total` là số dòng tồn; có thể lặp SKU khi có nhiều kho | API trả thêm `productTotal = COUNT(DISTINCT product_id)` | Đã sửa, có test |
| KPI thứ tư | Hiển thị số kho/cửa hàng, chưa phản ánh vốn hàng | Hiển thị tổng giá trị tồn theo giá vốn từ API phân bổ danh mục | Đã sửa, có test |
| Hàng chậm | Chỉ có tồn và số ngày chưa bán | Thêm giá vốn, giá trị tồn, danh mục và ưu tiên theo vốn bị giữ | Đã sửa, có test |
| Phạm vi kho | Có thể gửi `warehouseId` khi đang tổng hợp chuỗi | Backend yêu cầu chọn một cửa hàng trước khi lọc kho | Đã sửa, có test |

## 3. Định nghĩa KPI

- **Giá trị tồn hiện tại** = tổng `inventory_stocks.quantity × products.cost_price`
  của các dòng tồn dương trong phạm vi được phép xem.
- **Hàng chậm luân chuyển 30 ngày** = SKU còn tồn nhưng không xuất hiện trong đơn bán
  không bị hủy trong 30 ngày gần nhất.
- **Vốn tồn chậm** = tồn hiện tại của SKU chậm luân chuyển × giá vốn hiện tại của SKU.
- Không cộng số lượng giữa các đơn vị như Bao, Kg, Bộ; giao diện dùng giá trị tiền để so sánh.

Đây là giá trị theo `products.cost_price` hiện tại, chưa phải định giá tồn lịch sử theo
FIFO/bình quân tại một ngày quá khứ. Muốn có biểu đồ vòng quay hoặc valuation tại ngày cần
snapshot tồn ngày hoặc tái dựng từ sổ kho đã được đối soát.

## 4. Bằng chứng DB chỉ đọc

Chạy `backend/src/scripts/audit-inventory-capital.ts` cho shop 34 và 35, ngưỡng 30 ngày:

| Chỉ tiêu | Kết quả |
|---|---:|
| Dòng tồn | 500 |
| SKU duy nhất | 500 |
| SKU chậm luân chuyển | 299 |
| Vốn tồn chậm theo giá vốn hiện tại | 1.383.509.000 đ |
| Dòng chậm thiếu tên/đơn vị hoặc có số âm | 0 |

Top SKU được sắp theo vốn tồn chậm; dòng đứng đầu có 25 Bao, giá trị 25.950.000 đ
và 37 ngày chưa bán. Số liệu phản ánh dữ liệu DB tại thời điểm chạy, không phải dữ liệu nhập
trực tiếp trong Flutter.

## 5. Rủi ro còn lại

1. Dữ liệu nghiệp vụ gần nhất dừng ở 28/07/2026; số ngày chưa bán sẽ tiếp tục tăng nếu bộ
   demo không được nạp giao dịch mới.
2. Chưa có `inventory_daily_snapshots`, vì vậy chưa đủ bằng chứng để công bố vòng quay tồn,
   days-on-hand hoặc xu hướng giá trị tồn lịch sử là chính xác.
3. Chưa chụp lại màn Kho sau đăng nhập trong vòng này; trạng thái UI mới chỉ được xác minh
   bằng phân tích code và unit test, chưa phải visual audit production.

## 6. Kiểm thử

- Backend build/lint: đạt; toàn bộ P0 `161/161` test đạt.
- Flutter analyze toàn dự án: không lỗi; toàn bộ `101/101` test đạt.
- Không deploy theo yêu cầu hiện tại.
