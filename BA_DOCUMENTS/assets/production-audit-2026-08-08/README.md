# Audit giao diện production công khai — 08/08/2026

## Phạm vi

- Production: `https://smartstock-tax.vercel.app/`
- Viewport kiểm tra: desktop 1440×900 và mobile 390×844.
- Màn hình: đăng nhập, đăng ký và khôi phục mật khẩu.
- Không kiểm tra các màn sau đăng nhập vì trình duyệt không có phiên hợp lệ.
- Không thực hiện đăng nhập Google thật vì thao tác đó cần quyền truy cập tài khoản Google của người dùng.

## Kết luận

Ứng dụng chưa đủ bằng chứng để coi là hoàn thiện toàn bộ. Các màn xác thực công khai hoạt động ổn,
responsive mobile không vỡ bố cục và không có lỗi console quan sát được. Tuy nhiên, desktop đang dùng
không gian chưa hiệu quả và ba màn xác thực chưa cùng một ngôn ngữ bố cục. Khả năng truy cập bằng
bàn phím/trình đọc màn hình là rủi ro cao cần kiểm thử và sửa riêng.

## Các bước đã kiểm tra

| Bước | Màn hình | Tình trạng | Bằng chứng |
|---|---|---|---|
| 1 | Đăng nhập desktop | Tốt nhưng còn loãng | [01-login-desktop-1440.png](01-login-desktop-1440.png) |
| 2 | Đăng ký desktop | Cần cải thiện bố cục | [02-register-desktop-1440.png](02-register-desktop-1440.png) |
| 3 | Đăng nhập mobile | Tốt | [04-login-mobile-390.png](04-login-mobile-390.png) |
| 4 | Đăng ký mobile | Tốt, cần làm rõ lựa chọn vai trò | [05-register-mobile-390.png](05-register-mobile-390.png) |
| 5 | Khôi phục mật khẩu desktop | Cần cải thiện bố cục | [07-forgot-password-desktop.png](07-forgot-password-desktop.png) |
| 6 | Khôi phục mật khẩu mobile | Đúng bố cục nhưng khoảng trống lớn | [08-forgot-password-mobile.png](08-forgot-password-mobile.png) |

## Phát hiện ưu tiên

1. **P0 — Chưa thể audit phần nghiệp vụ:** không có phiên đăng nhập hợp lệ nên dashboard, bán hàng,
   kho, tài chính, cài đặt và các luồng tạo/sửa chưa được xác minh trong vòng này.
2. **P1 — Accessibility:** DOM chỉ nhận diện ổn định nút Google; các trường Flutter xuất hiện như
   `INPUT` không có nhãn. Chuỗi Tab không cung cấp tên/role rõ ràng. Chưa được coi là đạt accessibility.
3. **P1 — Thiếu nhất quán:** đăng nhập dùng bố cục hai cột có panel thương hiệu; đăng ký và khôi phục
   mật khẩu lại dùng form nhỏ giữa canvas. Cảm giác như ba phiên bản thiết kế khác nhau.
4. **P1 — Mật độ desktop quá thấp:** form đăng ký/khôi phục chỉ chiếm một vùng nhỏ, chữ và điều khiển
   quá nhỏ so với 1440×900; phần lớn màn hình không truyền tải thông tin hay hỗ trợ thao tác.
5. **P2 — Vai trò đăng ký chưa được giải thích:** “Chủ cửa hàng” và “Nhân viên” thiếu mô tả hậu quả,
   quyền và bước tiếp theo; người dùng có thể chọn sai trước cả đăng ký Google/email.
6. **P2 — Thiếu nội dung tạo niềm tin:** chưa thấy điều khoản, chính sách quyền riêng tư hoặc giải thích
   dữ liệu Google được sử dụng thế nào.
7. **P2 — Khôi phục mật khẩu mobile:** khoảng trống phía trên lớn làm CTA bị đẩy xuống không cần thiết.
8. **P3 — Copy và nhận diện:** tên “SmartStock POS & Tax” chỉ xuất hiện ở đăng nhập; hai màn còn lại
   không duy trì logo/brand context. Cách viết hoa tiêu đề cũng chưa thống nhất.

## Google Sign-In

- Nút Google có trên đăng nhập và đăng ký production.
- Backend đã được cấu hình Google Client ID: payload token giả hợp lệ về độ dài nhận `401
  GOOGLE_TOKEN_INVALID`, không còn `503 GOOGLE_NOT_CONFIGURED`.
- Chưa xác minh popup chọn tài khoản và callback end-to-end vì chưa được phép truy cập tài khoản Google.

## Giới hạn bằng chứng

- Screenshot không chứng minh đầy đủ WCAG, contrast ratio, screen reader hoặc focus indicator.
- Chưa có ảnh và bằng chứng vòng này cho các route protected.
- Không nhập OTP, tạo tài khoản hay thay đổi dữ liệu production.
