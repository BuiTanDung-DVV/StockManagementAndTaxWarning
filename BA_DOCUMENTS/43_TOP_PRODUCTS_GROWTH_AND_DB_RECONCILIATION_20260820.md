# Top sản phẩm, tăng trưởng và đối soát DB — 20/08/2026

## Sai lệch As-Is

- Backend đã trả doanh thu hiện tại và kỳ trước nhưng Flutter tự tính lại phần trăm tăng trưởng.
- Cột chỉ ghi “Tăng trưởng”, chưa nêu rõ kỳ dùng để so sánh.
- Trường hợp sản phẩm mới và kỳ trước có doanh thu bằng 0 chưa được phân biệt rõ.

## To-Be đã triển khai local

- PostgreSQL và backend là nguồn duy nhất cho doanh thu thuần, số lượng, giá vốn, lợi nhuận gộp và tăng trưởng.
- API bổ sung `growthPct` và `growthStatus`: `COMPARABLE`, `NEW`, `NO_BASE`, `NOT_REQUESTED`.
- Flutter chỉ định dạng kết quả API; không tự tính lại công thức.
- Bảng hiển thị rõ `Tăng trưởng so với <kỳ trước>` trên desktop và mobile.
- Sản phẩm mới hiển thị `Mới`; kỳ gốc bằng 0 hiển thị `Chưa có kỳ gốc`.

## Công thức

- Doanh thu thuần sản phẩm = tiền hàng sau phân bổ chiết khấu − tiền hàng hoàn hợp lệ.
- Số lượng thuần = số lượng bán − số lượng hoàn hợp lệ.
- Lợi nhuận gộp = doanh thu thuần − giá vốn thuần.
- Tăng trưởng (%) = `(doanh thu kỳ này − doanh thu kỳ trước) / doanh thu kỳ trước × 100`.
- Không chia cho 0; sản phẩm không có dữ liệu kỳ trước được gắn trạng thái thay vì tạo phần trăm giả.

## Đối soát DB/API chỉ đọc

Kỳ hiện tại `01–28/07/2026`, kỳ so sánh `01–28/06/2026`:

| Cửa hàng | Dòng API | Dòng DB độc lập | Lệch thứ hạng | Lệch doanh thu/số lượng/giá vốn/lợi nhuận | Lệch tăng trưởng |
|---:|---:|---:|---:|---:|---:|
| 34 | 10 | 10 | 0 | 0 | 0 |
| 35 | 10 | 10 | 0 | 0 | 0 |

Lệnh tái lập chỉ đọc:

`npm run audit:top-products -- --shop-ids=34,35 --from=2026-07-01 --to=2026-07-28 --previous-from=2026-06-01 --previous-to=2026-06-28`

## Trạng thái

- Logic backend và dữ liệu DB: **Đã xác minh local**.
- Responsive: widget test 390px và 1000px đạt; không có overflow.
- Cổng hồi quy mới nhất: backend lint/build và `181/181` test P0 đạt; Flutter analyze sạch và `133/133` unit/widget test đạt.
- Production: **Chưa xác minh**, vì thay đổi chưa được deploy theo yêu cầu người dùng.
