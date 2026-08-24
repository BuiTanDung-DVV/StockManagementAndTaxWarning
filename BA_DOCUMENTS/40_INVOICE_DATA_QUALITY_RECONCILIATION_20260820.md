# Đối soát chất lượng dữ liệu hóa đơn — 20/08/2026

## Phạm vi

- Nguồn duy nhất: bảng `invoices` và `invoice_items` trong PostgreSQL.
- Kiểm tra header có dòng chi tiết, công thức tổng header, tổng tiền hàng/thuế giữa header và các dòng, số lượng và công thức từng dòng.
- Không sửa, xóa, backfill hoặc tạo dữ liệu production.
- API chỉ trả số đếm và khoảng ngày; không đưa khóa hoặc chuỗi kết nối xuống frontend.

## Kết quả đọc trực tiếp DB

| Cửa hàng | Hóa đơn kiểm tra | Thiếu dòng chi tiết | Chiết khấu đơn bán chưa phân bổ vào dòng | Sai lệch tiền hàng chưa giải thích | Lệch tổng header | Dòng sai số lượng/thành tiền/thuế |
|---|---:|---:|---:|---:|---:|---:|
| 34 | 2.380 | 30 | 268 | 0 | 0 | 0 |
| 35 | 2.521 | 30 | 290 | 0 | 0 | 0 |

Khoảng dữ liệu hóa đơn là 29/07/2023–28/07/2026. Kết quả xác nhận 60 hóa đơn
nhập thiếu dòng và 558 hóa đơn bán có tổng dòng lớn hơn header đúng bằng
`sales_orders.discount_amount`. Vì vậy 558 bản ghi được phân loại chính xác là
**chiết khấu chưa phân bổ vào dòng**, không còn gộp nhầm vào “sai tổng chưa rõ
nguyên nhân”. Công thức `total_amount = subtotal + tax_amount` không lệch.

Riêng kỳ 01–28/07/2026, shop 34 có 10 hóa đơn chưa phân bổ chiết khấu và 1 hóa
đơn nhập thiếu dòng; shop 35 lần lượt là 11 và 1. Các nhóm sai công thức khác đều 0.

## Thay đổi ứng dụng

- Endpoint đối soát hỗ trợ `scope=ALL` và tính toàn bộ chỉ số bằng truy vấn PostgreSQL theo cửa hàng đang chọn.
- Sổ hóa đơn có khối **Chất lượng dữ liệu hóa đơn** đặt ngay sau KPI VAT, dùng màu cảnh báo mạnh khi có lỗi.
- Giao diện hiển thị số hóa đơn đã kiểm tra, khoảng ngày thật và từng nhóm sai lệch; khi API lỗi ghi rõ “chưa thể xác minh”, không coi là đạt.
- Cảnh báo chiết khấu được tách riêng khỏi sai lệch tiền hàng không giải thích được,
  giúp người dùng biết đúng việc cần xử lý.
- Sau khi thêm, sửa hoặc xóa hóa đơn, dữ liệu đối soát được tải lại từ backend.

## Trạng thái và hướng xử lý

- Trạng thái: **Đúng một phần**. Validator cho hóa đơn mới đã có, nhưng dữ liệu lịch sử chưa được sửa.
- P0-15 và P0-16 vẫn mở. Cần thiết kế backfill từ chứng từ gốc, chạy thử trên bản sao, đối soát trước/sau và có phương án rollback.
- Chưa được phép dùng các hóa đơn bị cảnh báo để chốt báo cáo/thuế trước khi rà soát chứng từ gốc.

## Lệnh kiểm tra chỉ đọc

`npm run audit:invoices -- --shop-ids=<id,id> --from=YYYY-MM-DD --to=YYYY-MM-DD`

Lệnh trả mã khác 0 khi phát hiện sai lệch để có thể dùng làm data-quality gate; lệnh không ghi DB.
