# Đánh giá production UI/UX vòng 2

## 1. Phạm vi và phương pháp

| Thuộc tính | Giá trị |
|---|---|
| Production | [smartstock-tax.vercel.app](https://smartstock-tax.vercel.app) |
| Ngày đánh giá | 26/07/2026 |
| Desktop | 1440×900 |
| Mobile | 390×844 |
| Phương pháp | Giao diện production → route Flutter → provider/API liên quan |
| Accessibility | Chưa kiểm thử chuyên biệt; không kết luận đạt chuẩn |

Đã kiểm tra 18 màn desktop và 7 màn mobile, bao phủ dashboard, bán hàng, POS,
sản phẩm, khách hàng, nhà cung cấp, kho, nhập hàng, tài chính, lãi/lỗ, giao dịch,
hóa đơn, thuế, thiết lập, nhân sự, vai trò, hồ sơ cửa hàng và kho tri thức AI.
Không tạo, sửa hoặc xóa giao dịch production trong vòng đánh giá này.

Toàn bộ ảnh As-Is được lưu tại
[`assets/production-ui-audit-2026-07-26-round2`](assets/production-ui-audit-2026-07-26-round2/).

## 2. Kết luận điều hành

Trạng thái tổng thể: **Đúng một phần**.

Ứng dụng đã có nền tảng điều hướng, typography và màu sắc nhất quán. Điểm làm giao
diện thiếu cảm giác của một hệ thống vận hành thực tế là thẻ gradient quá nổi,
nhiều nút nổi che dữ liệu, cách viết tiêu đề không thống nhất, trạng thái trống
dùng hoạt ảnh trang trí lớn và dữ liệu kiểm thử lộ mã kỹ thuật.

Không phát hiện lỗi hoặc cảnh báo JavaScript trong các route đã mở. Tuy nhiên,
không thể dùng kết quả này để kết luận luồng ghi dữ liệu, phân quyền từng vai trò
hoặc accessibility đã đạt.

## 3. Phát hiện theo mức độ

| ID | Mức | Khu vực | Phát hiện | Ảnh hưởng | Trạng thái xử lý |
|---|---|---|---|---|---|
| UI2-01 | P0 | Dữ liệu production | Tên `Simulated...`, `Temp Product...` và nhãn `sim_tag_*` hiển thị như dữ liệu thật | Giảm độ tin cậy, dễ dùng nhầm khi nghiệm thu | Ẩn mã nhãn nội bộ, gắn nhãn “Dữ liệu thử nghiệm”; vẫn cần dọn dữ liệu ở môi trường production |
| UI2-02 | P1 | Tài chính mobile | Thẻ gradient chiếm gần toàn bộ viewport đầu tiên | Che thông tin vận hành và tạo cảm giác giao diện trình diễn | Đã đổi thành thẻ nền trung tính, viền nhẹ |
| UI2-03 | P1 | Bán hàng/sản phẩm | Nút nổi dạng dài che dòng dữ liệu và thanh điều hướng | Khó đọc số tiền, dễ bấm nhầm | Đã đổi thành FAB gọn và tăng vùng đệm cuối danh sách |
| UI2-04 | P1 | POS mobile | Tổng tiền có thể tách ký hiệu tiền tệ sang dòng mới; thanh checkout tương phản quá gắt | Khó quét nhanh trong giờ bán hàng | Đã khóa một dòng, co theo chiều rộng và chuẩn hóa nút |
| UI2-05 | P1 | Hóa đơn | Trạng thái trống có hai CTA “Thêm hóa đơn” | Mơ hồ về hành động chính | Đã giữ một CTA trong trạng thái trống |
| UI2-06 | P2 | Điều hướng | Các màn cấp một vẫn có nút quay lại dù đã nằm trong shell chính | Sai mô hình điều hướng desktop/mobile | Đã bỏ ở sản phẩm, khách hàng, nhà cung cấp, kho và tài chính |
| UI2-07 | P2 | Toàn hệ thống | Trạng thái trống dùng hoạt ảnh lớn, chiếm nhiều khoảng trắng | Thiếu cảm giác hệ thống nghiệp vụ | Đã thay bằng trạng thái trung tính, nhỏ gọn |
| UI2-08 | P2 | Nội dung | Nhiều tiêu đề viết hoa từng từ, trộn tiếng Anh và key kỹ thuật | Thiếu nhất quán, khó đọc | Đã sửa các màn chính; RBAC và dữ liệu nhân sự đưa vào backlog |
| UI2-09 | P1 | Biểu đồ | Nhãn trục tài chính chồng nhau trên mobile | Khó đọc xu hướng | Chưa sửa; cần điều chỉnh mật độ nhãn theo viewport |
| UI2-10 | P1 | Dashboard/tài chính | Số dư quỹ và chỉ số tổng hợp rất lớn so với doanh thu kỳ hiện tại | Có thể đúng do dữ liệu tích lũy, nhưng chưa đủ bằng chứng | Cần đối soát API, kỳ báo cáo và dữ liệu nguồn |

## 4. Bằng chứng chính

- [Dashboard desktop](assets/production-ui-audit-2026-07-26-round2/01-dashboard-desktop.png)
- [Tài chính desktop](assets/production-ui-audit-2026-07-26-round2/09-finance-desktop.png)
- [Sản phẩm mobile](assets/production-ui-audit-2026-07-26-round2/22-products-mobile.png)
- [Tài chính mobile](assets/production-ui-audit-2026-07-26-round2/24-finance-mobile.png)
- [Thiết lập mobile](assets/production-ui-audit-2026-07-26-round2/25-settings-mobile.png)

## 5. Hướng thiết kế được áp dụng

1. Ưu tiên mật độ thông tin, phân cấp và khả năng quét nhanh thay cho gradient,
   bóng đổ và hoạt ảnh trang trí.
2. Mỗi trạng thái chỉ có một hành động chính; FAB không được che dữ liệu.
3. Màn cấp một dùng shell điều hướng, chỉ màn chi tiết/form mới có nút quay lại.
4. Dữ liệu kiểm thử phải được nhận diện rõ, không hiển thị mã kỹ thuật nội bộ.
5. Giữ nguyên design token, Material 3, Riverpod, GoRouter và API hiện có.

## 6. Backlog tiếp theo

| Ưu tiên | Hạng mục | Tiêu chí nghiệm thu |
|---|---|---|
| P0 | Tách hoặc dọn dữ liệu mô phỏng khỏi production | Không còn bản ghi `Simulated`, `Temp Product` hoặc `sim_tag_*` trong dữ liệu nghiệp vụ production |
| P1 | Responsive chart | Nhãn trục không chồng ở 390×844, 768×1024 và 1440×900 |
| P1 | Chuẩn hóa RBAC | Tên vai trò/quyền hiển thị tiếng Việt nghiệp vụ; không lộ key như `all: true` |
| P1 | Đối soát dashboard–tài chính | Cùng định nghĩa/kỳ dữ liệu cho từng chỉ số; có tooltip giải thích số dư lũy kế |
| P2 | Chuẩn hóa empty/error/loading | Có nội dung theo ngữ cảnh và một CTA chính trên mọi route |
| P2 | Accessibility chuyên biệt | Keyboard, screen reader, contrast và zoom 200% có biên bản kiểm thử |

## 7. Xác minh kỹ thuật trước deploy

| Kiểm tra | Kết quả |
|---|---|
| `flutter analyze` | Đạt, không có issue |
| `flutter test` | Đạt 23/23 |
| Flutter web release build | Đạt; còn cảnh báo phụ thuộc `flutter_tts` với Wasm và thiếu font Cupertino |
| Backend lint/build | Đạt |
| Backend P0 tests | Đạt 28/28 |
| npm audit mức high | 0 lỗ hổng |

Ảnh sau sửa phải được bổ sung sau khi Vercel deploy đúng commit mới; ảnh trong tài
liệu này hiện là bằng chứng As-Is để so sánh.
