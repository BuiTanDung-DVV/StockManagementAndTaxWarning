# Font giao diện SmartStock

Inter và Manrope được đóng gói để giao diện và kiểm thử không phụ thuộc vào
việc tải font khi mở ứng dụng. `pubspec.yaml` đã khai báo thư mục này.

- Nguồn tệp: `https://fonts.gstatic.com/s/a/<SHA256>.ttf`.
- Mã SHA256 và kích thước lấy từ metadata của `google_fonts 8.0.2` đang dùng
  trong dự án; SHA256 từng tệp đã được đối chiếu sau khi tải ngày 09/09/2026.
- Tên tệp theo quy ước Google Fonts để thư viện tự nhận tài nguyên cục bộ.
- Giấy phép: `Inter-OFL.txt` và `Manrope-OFL.txt`, từ kho chính thức
  `google/fonts` (thư mục `ofl/inter` và `ofl/manrope`).
- Hai tệp NotoSans có sẵn được giữ nguyên.

Kiểm thử ảnh nạp font và Material Icons bằng `test/support/load_ui_fonts.dart`
trước khi dựng widget, tránh font ô vuông mặc định của Flutter Test.
