<div align="center">
  <img src="web/icons/Icon-192.png" alt="Biểu trưng SmartStock" width="96" height="96">

  <h1>SmartStock</h1>

  Quản lý bán hàng, tồn kho và theo dõi nghĩa vụ thuế cho cửa hàng.
</div>

SmartStock là đồ án tốt nghiệp xây dựng ứng dụng quản lý cho cửa hàng và hộ kinh doanh. Chủ cửa hàng quản lý thành viên và phân quyền theo từng cửa hàng. Nhân viên sử dụng các chức năng được cấp quyền, chẳng hạn lập đơn bán, nhập hàng hoặc kiểm kê.

[Mở SmartStock Web](https://smartstock-tax.vercel.app/)

## Chức năng chính

| Nhóm nghiệp vụ | Chức năng |
| --- | --- |
| Bán hàng | Tìm theo tên, SKU hoặc mã vạch, lập đơn bán, ghi nhận tiền mặt, chuyển khoản hoặc công nợ, trả từng mặt hàng theo số lượng, in phiếu và thiết lập giao hàng. |
| Kho hàng | Quản lý danh mục, phiếu nhập, lô và hạn dùng, kiểm kê, định mức tồn tối thiểu và báo cáo xuất – nhập – tồn. |
| Tài chính | Theo dõi thu chi, công nợ và tuổi nợ, đối soát tiền mặt khi kết ca, dự báo dòng tiền theo hạn thanh toán và kế hoạch thu chi. |
| Hóa đơn | Lưu chứng từ nội bộ. Trích xuất thông tin từ ảnh hóa đơn để người dùng kiểm tra trước khi lưu hoặc lập phiếu nhập. |
| Thuế và trợ giúp | Theo dõi nghĩa vụ thuế, ước tính theo cấu hình, tạo tệp XML để đối chiếu trên HTKK và hỏi đáp bằng Gemini dựa trên tài liệu tham khảo đã cấu hình. |
| Quản trị | Quản lý thành viên, nhật ký hoạt động, tài khoản nhận tiền, mẫu phiếu và đơn vị vận chuyển. |

POS tạo VietQR theo số tiền và mã đơn. Việc ghi nhận tiền chuyển khoản diễn ra khi người dùng xác nhận đã nhận tiền. Phí giao hàng được cộng vào tổng tiền khách phải trả khi chọn **Khách trả**. Tiền mặt, ghi nợ và xác nhận chuyển khoản có âm báo riêng.

Một số danh sách và báo cáo, như danh mục sản phẩm và báo cáo xuất – nhập – tồn, hỗ trợ xuất Excel. Dữ liệu OCR, câu trả lời AI và số thuế ước tính cần được đối chiếu trước khi sử dụng để ghi sổ hoặc kê khai.

## Kiến trúc và công nghệ

Ứng dụng Flutter dùng chung mã giao diện cho web và Android. Riverpod quản lý trạng thái, GoRouter điều hướng và Dio gửi yêu cầu đến REST API. Backend dùng Express, TypeScript và TypeORM để xử lý nghiệp vụ và lưu dữ liệu trong PostgreSQL. Google Sign-In hỗ trợ đăng nhập, Cloudinary lưu ảnh và Gemini API hỗ trợ nhận dạng hóa đơn, hỏi đáp.

~~~text
lib/                Giao diện Flutter, trạng thái và kết nối API
backend/src/        REST API, xử lý nghiệp vụ, xác thực và phân quyền
backend/database/   Lược đồ, migration và dữ liệu tham chiếu
assets/             Ảnh, biểu tượng, phông chữ, mẫu nhập và âm báo
android/            Cấu hình ứng dụng Android
web/                Điểm khởi chạy và tài nguyên riêng của bản web
scripts/            Kiểm tra gói build web dùng khi triển khai
~~~

## Chạy cục bộ

Cần Flutter SDK đi kèm Dart tương thích với ràng buộc `^3.11.0` trong [pubspec.yaml](pubspec.yaml), Node.js 22.13 trở lên trong nhánh 22 hoặc Node.js 24 và cơ sở dữ liệu PostgreSQL đã có lược đồ SmartStock. TypeORM không tự tạo lược đồ khi khởi động. Các migration phụ thuộc vào trạng thái cơ sở dữ liệu.

**Backend** — từ thư mục gốc, chạy trong PowerShell.

~~~powershell
Set-Location backend
Copy-Item .env.example .env
npm.cmd ci
~~~

Khai báo `DATABASE_URL` và cấu hình xác thực trong `backend/.env` theo [mẫu biến môi trường](backend/.env.example). Khai báo thêm thông tin cho Google Sign-In, email, Cloudinary và Gemini nếu sử dụng các tính năng tương ứng.

~~~powershell
npm.cmd run dev
~~~

API mặc định chạy tại `http://localhost:8080/api/`.

**Flutter Web** — mở cửa sổ lệnh mới tại thư mục gốc.

~~~powershell
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://localhost:8080/api/
~~~

Với Google Sign-In trên web, cấu hình thêm `GOOGLE_WEB_CLIENT_ID` khi build và khai báo origin được phép của ứng dụng trong cấu hình OAuth.

## Kiểm tra

~~~powershell
flutter analyze
npm.cmd --prefix backend run build
~~~

Các bộ kiểm thử và dữ liệu kiểm thử được quản lý cục bộ. Những lệnh kiểm thử phụ thuộc vào tệp trong `test/` hoặc `backend/test/` cần bộ kiểm thử tương ứng trên máy.

## Triển khai web trên Vercel

1. Chuẩn bị PostgreSQL với lược đồ SmartStock và các migration cần cho phiên bản triển khai.
2. Tạo dự án Vercel cho API, chọn `backend` làm **Root Directory** và cấu hình biến môi trường production theo `backend/.env.example`. Triển khai API theo [backend/vercel.json](backend/vercel.json) rồi lấy tên miền API.
3. Tạo dự án Vercel cho Flutter Web từ thư mục gốc của kho mã. Nếu dùng tên miền API riêng, cập nhật đích chuyển tiếp `/api/` trong [vercel.json](vercel.json). Tệp [build_vercel.sh](build_vercel.sh) biên dịch ứng dụng và kiểm tra gói web trong `build/web`.
4. Nếu bật Google Sign-In, đặt `GOOGLE_WEB_CLIENT_ID` cho bản web, cấu hình `GOOGLE_CLIENT_IDS` ở API và thêm origin web vào danh sách được phép trong OAuth.
5. Sau khi triển khai, mở tên miền web và kiểm tra đăng nhập, chọn cửa hàng và tải danh sách sản phẩm.

Xem cách thiết lập [hai dự án từ cùng một kho mã](https://vercel.com/docs/monorepos) và [biến môi trường trên Vercel](https://vercel.com/docs/environment-variables).

## Phạm vi commit lên GitHub

- Commit mã ứng dụng, tài nguyên được tham chiếu lúc chạy, tệp khóa phụ thuộc, cấu hình build, lược đồ và migration cần thiết. Giữ `backend/.env.example` dưới dạng mẫu với giá trị minh họa.
- Giữ cục bộ dữ liệu tài khoản và cửa hàng, tệp xuất báo cáo, script tạo dữ liệu kiểm thử, ảnh chụp, tài liệu khóa luận, tệp sao lưu, khóa ký ứng dụng, bản build và cache.
- Stage từng tệp bằng `git add -- đường/dẫn/tệp`. Nếu tệp chứa nhiều nhóm thay đổi, dùng `git add -p -- đường/dẫn/tệp`.

~~~powershell
git status --short
git diff --cached --name-status
git diff --cached --check
git diff --cached
~~~

`.gitignore` áp dụng cho tệp chưa được theo dõi. Dùng `git ls-files -ci --exclude-standard` để rà các tệp đã được Git theo dõi nhưng hiện khớp quy tắc ignore. Xóa khỏi chỉ mục cần một commit riêng và không xóa bản sao đã có trong lịch sử Git.
