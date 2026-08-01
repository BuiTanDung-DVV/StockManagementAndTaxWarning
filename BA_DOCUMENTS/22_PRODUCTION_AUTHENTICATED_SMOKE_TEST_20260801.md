# Smoke test production sau đăng nhập — 01/08/2026

## 1. Phạm vi và nguyên tắc

- Frontend: `https://smartstock-tax.vercel.app`.
- Backend: `https://stock-management-and-tax-warning.vercel.app/api`.
- Tài khoản test đã được khai báo trong script kiểm thử của dự án; không ghi thông tin đăng nhập vào tài liệu.
- Cửa hàng kiểm tra chính: `shopId=34`; đối soát đa cửa hàng với `shopId=35` và `x-shop-id=all`.
- Chỉ dùng `GET` sau bước đăng nhập; không tạo, sửa, xóa hoặc xuất dữ liệu.
- Khoảng số liệu đối soát: `01/07/2026–29/07/2026`.

## 2. Kết quả API

Sau khi sửa tham số kỳ thuế từ `7` thành định dạng hợp lệ `07`, **48/48 endpoint đọc trả HTTP 200 và
`success=true`**. Lần gọi `period=7` trả 422 đúng validation nên không được tính là lỗi production.

| Nhóm | Bằng chứng chính từ production |
|---|---|
| Cửa hàng | Tài khoản test có 2 membership active: shop 34 và 35 |
| Sản phẩm | 250 sản phẩm, 6 danh mục, 9 tag ở shop 34 |
| Bán hàng | 7.595 đơn lịch sử; 216 đơn trong kỳ; top 10 và 3 phương thức thanh toán tải được |
| Khách hàng/công nợ | 24 khách; 416 khoản quá hạn; 453 khoản phải thu đang mở; tổng nợ aging 904.500.000 đồng |
| Kho | 250 dòng tồn, 27.952 biến động, XNT 250 sản phẩm, 48 lô sắp hết hạn, 37 sản phẩm chậm luân chuyển |
| Nhập hàng | 37 đơn nhập và 12 phiếu kiểm kê |
| Tài chính | 219 giao dịch trong kỳ, 1.096 chốt ngày, 90 dòng dự báo, 37 kế hoạch ngân sách |
| Hóa đơn/thuế | 2.380 hóa đơn, 13 nghĩa vụ thuế, 7 khoản mua không hóa đơn; estimate kỳ `07/2026` tải được |
| Quản trị | 10 thông báo, 59 activity log, 3 tài liệu AI, 5 role và 12 member |

Các endpoint bao phủ: danh mục, bán hàng, công nợ, kho/XNT, nhập hàng/kiểm kê, dòng tiền, P&L,
đối soát hóa đơn, dự báo, ngân sách, thuế, cấu hình, QR, thông báo, audit log, AI knowledge, role và member.

## 3. Đối soát chế độ Tất cả cửa hàng

| Metric kỳ 01–29/07/2026 | Shop 34 | Shop 35 | Tất cả | Chênh lệch so với tổng hai shop |
|---|---:|---:|---:|---:|
| Doanh thu thuần | 649.165.000 | 785.480.000 | 1.434.645.000 | 0 |
| Giá vốn | 498.135.000 | 647.082.000 | 1.145.217.000 | 0 |
| Lợi nhuận gộp | 151.030.000 | 138.398.000 | 289.428.000 | 0 |
| Số đơn | 216 | 212 | 428 | 0 |
| Tổng thu | 577.461.000 | 725.676.000 | 1.303.137.000 | 0 |
| Tổng chi | 580.780.000 | 749.498.000 | 1.330.278.000 | 0 |
| Số dư quỹ | 1.919.881.000 | 816.768.000 | 2.736.649.000 | 0 |

**Kết luận:** các API tổng hợp bán hàng và tiền đang cộng đúng giữa hai cửa hàng trong dataset kiểm tra.
Kết quả này không chứng minh mọi endpoint hỗ trợ `all`; các route không khai báo `allowAllShops` vẫn phải
giữ phạm vi một cửa hàng.

## 4. Smoke test route frontend

- Đã mở 47 route sau đăng nhập, gồm dashboard, bán hàng, POS, chi tiết đơn/sản phẩm/khách/NCC, kho,
  XNT, tài chính, hóa đơn, thuế, settings, AI knowledge, log, nhân viên, role và hồ sơ.
- 47/47 route giữ đúng hash mong đợi, không bị đẩy về `/login`.
- Console của tab không ghi warning/error trong vòng điều hướng.

Đây là bằng chứng route/guard và app shell khởi tạo được, **không thay thế kiểm tra trực quan từng màn**.
Lệnh chụp canvas Flutter của in-app browser vẫn hết thời gian, vì vậy ảnh protected production còn thiếu.

## 5. Sai lệch mới được xác minh

### INV-01 — KPI Tổng sản phẩm dùng độ dài trang đầu

- API `/inventory/stock` trả `total=250`, `items=20` ở trang mặc định.
- UI cũ bỏ metadata rồi dùng `items.length`, nên hiện 20.
- Đã sửa local: thêm `stockPageProvider`, KPI dùng `total`; test hồi quy đạt.

### INV-02 — “Dưới định mức” thực tế dùng ngưỡng cố định 10

| Phạm vi | Theo `products.min_stock` | Theo ngưỡng cố định 10 |
|---|---:|---:|
| Shop 34 | 0 | 112 |
| Shop 35 | 0 | 24 |
| Tất cả | 0 | 136 |

UI ghi “Dưới định mức” nhưng provider cũ luôn gửi `threshold=10`. Đã sửa local để mặc định không gửi
threshold, từ đó backend so với `product.min_stock`. Nếu cần chế độ ngưỡng 10, UI phải ghi rõ và cho cấu hình.

### DEBT-01 — Công nợ tải quá nhiều dòng một lần

Production shop 34 hiện có 453 khoản phải thu đang mở; endpoint trả toàn bộ và frontend dựng toàn bộ bảng.
Cần phân trang/filter server-side, sticky header và export theo tập lọc.

### PERF-01 — Đơn nhập là endpoint chậm nhất trong một lần đo

`/purchase-orders?page=1&limit=5` mất khoảng 1.170 ms, trong khi phần lớn endpoint khác ở khoảng
106–344 ms. Đây mới là một mẫu, chưa đủ kết luận SLA; cần đo p50/p95 bằng nhiều vòng và Vercel logs.

## 6. Giới hạn và việc tiếp theo

1. Chưa kiểm thử luồng ghi: tạo đơn, hoàn/hủy, thu nợ, kiểm kê, nhập hàng, upload ảnh và RBAC âm.
2. Chưa chụp trực quan 47 màn protected vì công cụ chụp Flutter canvas hết thời gian.
3. Chưa chạy migration auth production; không deploy commit auth mới trước khi có xác nhận.
4. Cần staging/test shop riêng để chạy luồng ghi và failure-injection mà không ảnh hưởng dữ liệu production.
