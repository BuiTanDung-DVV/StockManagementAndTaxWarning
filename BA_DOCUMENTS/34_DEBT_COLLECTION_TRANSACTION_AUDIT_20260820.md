# Audit transaction thu nợ khách hàng — 20/08/2026

## 1. Lỗi gốc

Màn sổ nợ trước đây luôn gửi thao tác thu nợ tới
`POST /sales-orders/:orderId/payments`. Khoản phải thu được tạo thủ công không có
`orderId`, nên giao diện tạo URL với ID không hợp lệ và không thể thu nợ.

## 2. Luồng đã sửa local

- Nợ liên kết đơn tiếp tục dùng workflow thanh toán đơn hàng.
- Nợ thủ công dùng endpoint mới
  `POST /customers/receivables/:receivableId/payments`.
- Backend kiểm tra số tiền, phương thức, trạng thái, cửa hàng sở hữu và khóa dòng
  `pessimistic_write` để ngăn hai yêu cầu đồng thời thu vượt số dư.
- Trong cùng một transaction PostgreSQL, backend cập nhật:
  1. `receivables.paid_amount/status`;
  2. `debt_payment_history`;
  3. `customers.balance`;
  4. `cash_transactions`;
  5. `journal_entries/journal_lines` với Nợ 111 hoặc 112, Có 131.
- `DEBT_COLLECTION` được đánh dấu là giao dịch liên kết để FinanceService không tự tạo
  thêm bút toán thu nhập khác/doanh thu, tránh hạch toán hai lần.

## 3. Đối soát dữ liệu hiện tại

| Shop | Khoản mở | Liên kết đơn | Thủ công | `orderId` trùng | Số dư khách lệch |
|---:|---:|---:|---:|---:|---:|
| 34 | 453 | 453 | 0 | 0 | 0đ |
| 35 | 473 | 473 | 0 | 0 | 0đ |

Dữ liệu hiện tại chưa có khoản thủ công, nên nhánh mới đã có test code nhưng chưa thể smoke
test bằng bản ghi production nếu không tạo dữ liệu. Không tự tạo hoặc sửa DB trong đợt audit.

## 4. Sai lệch lịch sử còn tồn tại

Validator toàn hệ thống vẫn phát hiện:

- Shop 34: 870 đơn có payment không khớp phát sinh Nợ 111/112.
- Shop 35: 834 đơn có payment không khớp phát sinh Nợ 111/112.
- Mỗi shop có 30 hóa đơn thiếu dòng; 268/290 hóa đơn chưa mô hình hóa chiết khấu.
- Dữ liệu bán hàng dừng ngày 28/07/2026 nên freshness không đạt.

Đây là dữ liệu lịch sử, không được sửa tự động. Backlog `P0-23` yêu cầu snapshot, backfill
transactional, validator trước/sau và phương án rollback riêng.

## 5. Bằng chứng kiểm thử

- Backend build/lint sạch; `165/165` kiểm thử P0 đạt.
- Flutter analyze sạch; `107/107` unit/widget test đạt.
- Test tập trung xác nhận route, transaction, row lock, bút toán 111/112–131 và điều hướng
  đúng endpoint cho khoản liên kết/thủ công.
- Không migration, không ghi production, không deploy.
