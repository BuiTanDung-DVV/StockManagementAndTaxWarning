# Độ mới dữ liệu và bảo vệ KPI bằng 0 — 20/08/2026

## Vấn đề

Dashboard, Tài chính và Kho mặc định hiển thị kỳ hiện tại. Khi dữ liệu production đã dừng từ kỳ trước, KPI có thể bằng 0 hoặc biểu đồ rỗng nhưng giao diện cũ vẫn ghi ngày hiện tại, dễ khiến người dùng hiểu rằng số liệu đã được cập nhật đầy đủ.

## Bằng chứng DB chỉ đọc

Ngày đối chiếu: 20/08/2026.

| Cửa hàng | Đơn bán gần nhất | Thu chi gần nhất | Biến động kho gần nhất | Hóa đơn gần nhất |
|---|---|---|---|---|
| 34 | 28/07/2026 (chậm 23 ngày) | 28/07/2026 (23 ngày) | 28/07/2026 (23 ngày) | 27/07/2026 (24 ngày) |
| 35 | 28/07/2026 (chậm 23 ngày) | 28/07/2026 (23 ngày) | 28/07/2026 (23 ngày) | 28/07/2026 (23 ngày) |

Lệnh kiểm tra: `npm run audit:freshness -- --shop-ids=<id,id> --as-of=YYYY-MM-DD`. Lệnh chỉ đọc PostgreSQL và không hiển thị thông tin kết nối.

## Thay đổi

- Summary bán hàng trả `latestOrderDate` từ `MAX(order_date)` theo đúng scope cửa hàng và không tính đơn hủy.
- Summary dòng tiền trả `latestTransactionDate` từ `MAX(transaction_date)` theo đúng scope.
- API tồn kho trả `latestMovementDate`; khi chọn kho cụ thể, ngày này cũng được lọc theo kho.
- Frontend tự đối chiếu ngày gần nhất từ backend với kỳ đang xem; không chứa ngày demo hoặc số liệu phát sinh nhập trực tiếp.
- Tổng quan, Tài chính và Kho hiển thị banner cảnh báo gọn khi kỳ thiếu dữ liệu. KPI bằng 0 được diễn giải là **có thể chưa có dữ liệu mới**, không khẳng định là kết quả kinh doanh bằng 0.
- Header Tổng quan đổi “cập nhật hôm nay” thành “đối chiếu đến hôm nay” để tránh khẳng định sai về độ mới DB.

## Trạng thái

- Cơ chế phát hiện/cảnh báo: **Đã sửa local, có kiểm thử**.
- Dữ liệu demo liên tục đến ngày hiện tại: **Đã đạt tại thời điểm 24/08/2026**.
  Hai cửa hàng 34/35 đã được nối dài từ 29/07 đến 24/08, mỗi cửa hàng thêm 81
  đơn bán, 27 hóa đơn, 27 khoản chi và 27 lần chốt quỹ.
- Chưa xác minh hình ảnh production vì thay đổi chưa được yêu cầu deploy.

## Đối soát sau khi nối dài

Ngày đối chiếu: 24/08/2026. Sales, cash transaction, inventory movement và invoice
của cả hai cửa hàng đều có ngày mới nhất 24/08/2026, độ trễ bằng 0 ngày. KPI tháng
08, sổ cái 511/632, chuỗi ngày, XNT và top sản phẩm đều có sai lệch bằng 0.

Bộ kiểm tra từng phát hiện 870 dòng shop 34 và 834 dòng shop 35 thiếu bút toán thu
công nợ qua tài khoản 112. Ngày 24/08/2026 đã bổ sung 1.704 bút toán cân bằng
`Nợ 112 / Có 131`, có bảng dấu vết để hoàn tác. Sau sửa, toàn bộ 32 nhóm kiểm tra
của từng cửa hàng đều PASS và sai lệch 111/112 bằng 0.

## Bằng chứng kiểm thử

- Backend lint/build và P0 tại cổng kiểm tra mới nhất: `181/181` đạt.
- Flutter analyze toàn dự án: không có lỗi.
- Flutter unit/widget tại cổng kiểm tra mới nhất: `133/133` đạt, gồm trạng thái thiếu kỳ, thiếu một phần, đủ kỳ và viewport mobile 390px.
