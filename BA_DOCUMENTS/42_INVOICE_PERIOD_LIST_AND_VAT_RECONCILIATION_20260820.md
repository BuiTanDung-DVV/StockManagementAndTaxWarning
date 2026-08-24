# Đồng bộ kỳ danh sách hóa đơn và KPI VAT — 20/08/2026

## Sai lệch As-Is

- KPI VAT trên Sổ hóa đơn dùng kỳ từ đầu tháng đến ngày hiện tại.
- Danh sách hóa đơn bên dưới không gửi `from/to`, nên tải toàn bộ lịch sử.
- Bộ lọc loại nằm sát bảng nhưng không ghi phạm vi, làm người dùng dễ hiểu rằng các dòng đang nhìn thấy tạo ra KPI VAT phía trên.

## To-Be đã triển khai local

- Danh sách mặc định dùng cùng `from/to` với KPI VAT.
- Backend yêu cầu đủ cặp ngày, validate loại `IN/OUT` và lọc tại PostgreSQL trước phân trang.
- Người dùng có thể chuyển rõ ràng giữa **Kỳ hiện tại** và **Toàn bộ thời gian**.
- Khối lọc được đặt ngay dưới tiêu đề danh sách, có chú thích “chỉ áp dụng cho các hóa đơn bên dưới”.
- Empty state của kỳ hiện tại hướng dẫn chuyển sang toàn bộ thay vì làm người dùng tưởng mất dữ liệu.
- API trả lại `filters` thực tế để phục vụ truy vết và kiểm thử.

## Đối soát DB/API chỉ đọc

| Kỳ | Cửa hàng | Tổng danh sách | Tổng DB | Chênh tổng | Chênh tổng theo loại | Chênh VAT vào | Chênh VAT ra |
|---|---:|---:|---:|---:|---:|---:|---:|
| 01–28/07/2026 | 34 | 71 | 71 | 0 | 0 | 0đ | 0đ |
| 01–28/07/2026 | 35 | 64 | 64 | 0 | 0 | 0đ | 0đ |
| 01–20/08/2026 | 34 | 0 | 0 | 0 | 0 | 0đ | 0đ |
| 01–20/08/2026 | 35 | 0 | 0 | 0 | 0 | 0đ | 0đ |

Lệnh kiểm tra: `npm run audit:invoice-period -- --shop-ids=<id,id> --from=YYYY-MM-DD --to=YYYY-MM-DD`. Lệnh chỉ đọc DB.

## Trạng thái

- Logic kỳ, loại, phân trang và VAT: **Đã xác minh local bằng DB/API**.
- Cổng hồi quy toàn dự án mới nhất: backend lint/build và `181/181` test P0 đạt; Flutter analyze sạch và `133/133` unit/widget test đạt.
- Responsive: đã có unit/widget gate chung; production screenshot chưa xác minh vì chưa deploy.
- Dữ liệu tháng 8 rỗng là trạng thái thật của DB hiện tại, không phải lỗi tải danh sách.
