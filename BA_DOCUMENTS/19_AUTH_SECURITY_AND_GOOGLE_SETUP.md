# Bảo mật đăng nhập, đăng ký và cấu hình Google

## Phạm vi đã triển khai

- Đăng ký bằng Gmail + mật khẩu + OTP 6 số.
- Đăng nhập bằng Gmail/tên đăng nhập + mật khẩu.
- Đăng ký và đăng nhập bằng tài khoản Google đã xác minh Gmail.
- Access token sống ngắn 15 phút; refresh token được xoay vòng và có phát hiện tái sử dụng.
- Web lưu refresh token trong cookie `HttpOnly`; Android/iOS lưu token bằng kho bảo mật hệ điều hành.
- Khóa tài khoản 15 phút sau 5 lần nhập sai liên tiếp; giới hạn tần suất đăng nhập và gửi OTP.
- OTP sống 5 phút, tối đa 5 lần thử, chỉ lưu HMAC trong cơ sở dữ liệu.
- Đổi/đặt lại mật khẩu thu hồi toàn bộ phiên đang hoạt động.

## Migration cơ sở dữ liệu

File: `backend/database/20260801_harden_authentication.sql`

Rủi ro cần xác nhận trước khi chạy:

1. Migration xóa toàn bộ OTP chưa dùng vì OTP cũ đang lưu dạng rõ và không tương thích HMAC mới.
2. Người đang ở màn hình nhập OTP phải yêu cầu mã mới.
3. Khi thay secret JWT, mọi phiên cũ sẽ hết hiệu lực và người dùng phải đăng nhập lại.
4. Tài khoản cũ được đánh dấu email chưa xác minh; chúng không tự liên kết Google cho đến khi có luồng xác minh riêng. Tài khoản đăng ký mới bằng OTP không bị ảnh hưởng.
5. Cần sao lưu PostgreSQL và chạy thử trên staging trước production.

Không bật `DB_SYNC=true` để thay migration trên production.

## Biến môi trường backend

Thiết lập trên máy chủ/Vercel, không commit giá trị thật:

```text
NODE_ENV=production
ACCESS_TOKEN_SECRET=<chuỗi ngẫu nhiên riêng, tối thiểu 32 byte>
REFRESH_TOKEN_SECRET=<chuỗi ngẫu nhiên riêng, tối thiểu 32 byte>
OTP_SECRET=<chuỗi ngẫu nhiên riêng, tối thiểu 32 byte>
GOOGLE_CLIENT_IDS=<web-client-id>,<server-client-id>,<ios-client-id>
ALLOWED_ORIGINS=https://<ten-mien-frontend>
SMTP_USER=<gmail gửi OTP>
SMTP_PASS=<Google App Password>
OTP_DEBUG_RESPONSE=false
```

Ba secret phải khác nhau. Backend sẽ từ chối khởi động production nếu secret thiếu, ngắn hoặc trùng nhau.

## Cấu hình Google Cloud

1. Tạo OAuth consent screen và ba loại OAuth client phù hợp: Web, Android và iOS.
2. Web: khai báo đúng `Authorized JavaScript origins`, gồm domain production và origin local dùng để phát triển.
3. Android: trước tiên đổi `com.example.flutter_app` thành application ID chính thức; sau đó đăng ký đúng application ID và SHA-1/SHA-256 của khóa debug/release.
4. iOS: đăng ký đúng bundle ID và thêm URL scheme đảo ngược từ iOS client ID vào `ios/Runner/Info.plist`.
5. Thêm các client ID được backend chấp nhận vào `GOOGLE_CLIENT_IDS`.

Google yêu cầu backend xác minh ID token, gồm chữ ký, `audience`, thời hạn và email đã xác minh. Không gửi access token Google thay cho ID token.

## Tham số build Flutter

Web:

```powershell
flutter run -d chrome --dart-define=API_URL=https://<backend>/api/ --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>
```

Android:

```powershell
flutter run -d android --dart-define=API_URL=https://<backend>/api/ --dart-define=GOOGLE_SERVER_CLIENT_ID=<server-client-id>
```

iOS:

```powershell
flutter run -d ios --dart-define=API_URL=https://<backend>/api/ --dart-define=GOOGLE_SERVER_CLIENT_ID=<server-client-id> --dart-define=GOOGLE_IOS_CLIENT_ID=<ios-client-id>
```

Client ID OAuth không phải secret, nhưng phải khớp cấu hình Google Cloud và backend.

## Thứ tự triển khai an toàn

1. Sao lưu database.
2. Tạo OAuth client và cấu hình biến môi trường backend.
3. Chạy migration trên staging; kiểm tra đăng ký Gmail, OTP, đăng nhập, refresh, logout và Google.
4. Triển khai backend mới.
5. Build/triển khai Flutter với đúng client ID.
6. Sau khi xác minh staging, lặp lại migration và triển khai production trong cùng cửa sổ bảo trì.

Tài liệu tham khảo chính thức:

- https://developers.google.com/identity/sign-in/web/backend-auth
- https://pub.dev/packages/google_sign_in
- https://pub.dev/packages/flutter_secure_storage
