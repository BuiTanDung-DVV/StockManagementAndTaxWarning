# Đối soát tuổi nợ phải thu và nâng cấp giao diện — 20/08/2026

## 1. Phạm vi

- Màn hình: `/#/debt-aging`.
- Nguồn: `receivables`, `customers`, `debt_payment_history` qua
  `GET /customers/debt-aging?asOf=YYYY-MM-DD`.
- Grain KPI: một khoản phải thu còn mở; grain khách hàng: một khách duy nhất trong cửa hàng.
- Ngày đối soát: cuối ngày nghiệp vụ Việt Nam 20/08/2026.

## 2. Sai lệch đã sửa

Màn cũ ghép báo cáo tuổi nợ theo tham số `asOf` với danh sách quá hạn dùng thời gian hệ thống
hiện tại. Hai nguồn có thể khác nhóm tuổi nợ, đặc biệt khi xem một ngày lịch sử. Màn mới chỉ
dùng một response báo cáo theo cùng ngày. Backend dùng chung hàm phân nhóm và trả thêm tổng
nợ quá hạn, số khoản đang mở, số khách duy nhất và dư nợ quá hạn theo khách.

Các nhóm chuẩn:

- `current`: chưa đến hạn hoặc đến hạn trong ngày đối soát.
- `past30`: quá hạn 1–30 ngày.
- `past60`: quá hạn 31–60 ngày.
- `past90`: quá hạn trên 60 ngày.

## 3. Đối soát PostgreSQL chỉ đọc

Script tái lập:
`backend/src/scripts/audit-receivables-quality.ts --shop-ids=34,35 --as-of=2026-08-20`.

| Shop | Tổng phải thu | Chưa hạn | 1–30 ngày | 31–60 ngày | Trên 60 ngày | Khoản | Khách |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 34 | 904.500.000đ | 18.135.000đ | 83.546.000đ | 48.998.000đ | 753.821.000đ | 453 | 24 |
| 35 | 1.208.989.000đ | 29.169.000đ | 101.124.000đ | 45.696.000đ | 1.033.000.000đ | 473 | 24 |

Chênh lệch service với SQL độc lập bằng `0` cho tổng tiền, bốn bucket, số khoản và số khách
ở cả hai cửa hàng. Không có khoản mồ côi, số tiền âm hoặc `paid_amount > amount` trong phạm
vi kiểm tra.

## 4. Giao diện local đã nâng cấp

- Đồng bộ design system với báo cáo tuổi nợ nhà cung cấp.
- Bốn KPI nhỏ gọn: tổng phải thu, quá hạn, số khoản và số khách.
- Biểu đồ được ưu tiên ở vùng trên, ghi rõ đơn vị đồng và màu theo mức độ rủi ro.
- Panel ưu tiên sắp theo nợ quá hạn rồi tổng dư nợ.
- Desktop dùng bảng; mobile dùng card, không ép bảng ngang.
- Loading, empty, error và kéo làm mới có trạng thái riêng.
- Bỏ nút SMS/Email gây hiểu nhầm vì thực tế chỉ sao chép; chỉ giữ thao tác “Sao chép”.

## 5. Kiểm thử và giới hạn

- Backend build/lint sạch; `163/163` kiểm thử P0 đạt.
- Flutter analyze sạch; `106/106` unit/widget test đạt.
- Script đối soát DB thoát mã `0`.
- Không ghi DB, không migration, không deploy.
- Chưa có ảnh visual audit mới: tab production bị chuyển về đăng nhập và chức năng chụp ảnh
  của trình duyệt Codex tiếp tục báo lỗi. Vì vậy tài liệu không tuyên bố đã kiểm tra trực quan
  production hoặc đạt accessibility.
