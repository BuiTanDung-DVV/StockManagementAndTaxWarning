# Căn cứ doanh thu thuế và blocker cấu hình policy — 20/08/2026

## Phạm vi

Báo cáo này chỉ xác minh tính nhất quán dữ liệu nội bộ. Không kết luận ngưỡng, tỷ lệ hoặc nghĩa vụ pháp lý hiện hành.

## Sai lệch As-Is

- `TaxService` tự tải toàn bộ đơn/phiếu hoàn rồi cộng trừ trong bộ nhớ.
- Sổ bán hàng có luồng tổng hợp riêng theo dòng hàng, chiết khấu, thuế và hàng hoàn.
- Hai nguồn tính độc lập tạo rủi ro lệch số khi dữ liệu hoàn thay đổi.

## To-Be đã triển khai local

- `TaxService.getRevenueBasis()` dùng cùng nguồn tổng hợp PostgreSQL của `SalesService.summary()`.
- Doanh thu kỳ và doanh thu năm không còn được tái tính bằng danh sách entity trong bộ nhớ.
- Phiếu hoàn hợp lệ tiếp tục được trừ theo dữ liệu dòng hàng của backend.
- Không thêm fallback, ngưỡng hoặc tỷ lệ thuế vào frontend/backend.
- Khi API của kỳ mới lỗi, Flutter xóa báo cáo kỳ cũ, hiển thị lỗi cố định và nút `Thử lại`; không gắn dữ liệu kỳ trước dưới bộ lọc mới.

## Đối soát DB/API chỉ đọc

| Shop | Doanh thu thuế 07/2026 | Sổ bán hàng 07/2026 | Lệch | Doanh thu thuế năm 2026 | Sổ bán hàng năm 2026 | Lệch |
|---:|---:|---:|---:|---:|---:|---:|
| 34 | 649.165.000đ | 649.165.000đ | 0đ | 4.479.468.000đ | 4.479.468.000đ | 0đ |
| 35 | 785.480.000đ | 785.480.000đ | 0đ | 5.919.655.000đ | 5.919.655.000đ | 0đ |

Lệnh tái lập chỉ đọc: `npm run audit:tax-sales-revenue -- --shop-ids=34,35 --year=2026 --month=7`.

## Blocker production/DB

`TaxService.getTaxReportData()` hiện dừng với thông báo thiếu các khóa:

- `TAX_FISCAL_YEAR`
- `TAX_EFFECTIVE_FROM`
- `E_INVOICE_THRESHOLD`
- `TAX_POLICY_SOURCE_CODE`
- `TAX_POLICY_SOURCE_URL`

Migration đã được chuẩn bị trong dự án nhưng chưa được chạy. Không được ghi nhận báo cáo thuế “đã xác minh” cho tới khi người dùng phê duyệt migration, chạy transaction có backup/rollback và kiểm tra nguồn chính thức.

## Trạng thái

- Căn cứ doanh thu: **Đã xác minh local/DB**.
- UI lỗi/ retry: **Đã xác minh local**.
- Cổng hồi quy: backend lint/build và `181/181` test P0 đạt; Flutter analyze sạch và `133/133` unit/widget test đạt.
- Công thức nghĩa vụ và policy: **Bị chặn bởi cấu hình DB**.
- Production: **Chưa xác minh**.
