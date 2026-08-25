# Kiểm tra vệ sinh repository và dữ liệu nhạy cảm

Ngày kiểm tra: 26/08/2026
Phạm vi: file trong workspace, Git index, các nhánh `main`/`backup`, remote refs và URL commit từng làm lộ PostgreSQL.

## Tóm tắt điều hành

- Mã nguồn chuẩn bị commit không còn phát hiện chuỗi PostgreSQL URI, private key hoặc token phổ biến bị hard-code.
- File `.env` và Google OAuth client secret chỉ tồn tại cục bộ, đã được `.gitignore` bảo vệ và không bị Git theo dõi.
- Đã loại khỏi repository các file đọc OTP thủ công, script kiểm thử API cũ chứa thông tin đăng nhập trực tiếp và log trình duyệt.
- `TaiKhoanKiemThu.md` cùng cấu hình trợ lý cục bộ được giữ trên máy nhưng đã bỏ theo dõi và thêm vào `.gitignore`.
- Còn một blocker bên ngoài repository hiện tại: URL commit cũ chứa PostgreSQL URI vẫn truy cập được trực tiếp trên GitHub dù commit đó không còn thuộc các nhánh hiện hành.

## SEC-REPO-001 — Cached commit cũ vẫn truy cập được

- Mức độ: **Critical**
- Vị trí: commit `5dea55e554480fec076e84aef484ca545526eed7`, file `backend/get_latest_otp.js`, dòng lịch sử từng chứa PostgreSQL URI.
- Bằng chứng: HTTP HEAD tới URL commit cũ trả `200`; kiểm tra ancestor xác nhận commit không thuộc `main`, `backup`, `origin/main` hoặc `origin/backup`.
- Ảnh hưởng: người biết SHA cũ vẫn có thể xem credential đã công khai. Nếu credential chưa được rotate, database có thể bị đọc, sửa hoặc xóa.
- Cách xử lý bắt buộc:
  1. Xác nhận credential PostgreSQL cũ đã bị thu hồi/rotate.
  2. Gửi yêu cầu GitHub Support xóa cached views và references cho commit nhạy cảm.
  3. Kiểm tra fork hoặc clone cũ để tránh đưa lịch sử nhiễm secret trở lại.
- Giảm thiểu: bật secret scanning/push protection và tiếp tục chỉ lấy `DATABASE_URL` từ biến môi trường.
- Lưu ý: việc rewrite/force-push nhánh đã hoàn thành phần refs nhưng không tự xóa cached commit view trên GitHub.

## SEC-REPO-002 — File tài khoản kiểm thử từng được theo dõi

- Mức độ: **High**
- Vị trí: `TaiKhoanKiemThu.md`.
- Bằng chứng: file chứa nhãn mật khẩu và từng nằm trong Git index.
- Ảnh hưởng: tài khoản thử nghiệm có thể bị sử dụng trái phép nếu còn hiệu lực trên production.
- Đã xử lý: bỏ theo dõi bằng Git, giữ file cục bộ và thêm `/TaiKhoanKiemThu.md` vào `.gitignore`.
- Việc cần xác minh: đổi mật khẩu hoặc vô hiệu hóa mọi tài khoản từng được công khai trong lịch sử.

## SEC-REPO-003 — Tiện ích OTP và script test có thông tin đăng nhập

- Mức độ: **High**
- Vị trí:
  - `backend/get_latest_otp.js`
  - `backend/get_otps.js`
  - `backend/scratch_otp.js`
  - `backend/run_api_tests.js`
- Bằng chứng: ba script OTP truy vấn trực tiếp mã xác thực; script API cũ có các literal đăng nhập và không được runtime/package script sử dụng.
- Ảnh hưởng: tăng nguy cơ lộ OTP, tài khoản thử nghiệm và tạo đường tắt ngoài luồng xác thực chuẩn.
- Đã xử lý: xóa khỏi working tree/Git và chặn ba script OTP bằng `.gitignore`.

## SEC-REPO-004 — File công cụ và log cục bộ bị commit

- Mức độ: **Low**
- Vị trí: `.cursorrules`, `CLAUDE.md`, `agents/orchestrator/context.md`, `chrome_error.txt`, `chrome_output.txt`.
- Ảnh hưởng: làm repository nhiễu và có thể vô tình lưu ngữ cảnh máy hoặc thông tin debug.
- Đã xử lý: file trợ lý được giữ cục bộ nhưng bỏ theo dõi; log đã xóa; các pattern tương ứng đã thêm vào `.gitignore`.

## Kiểm tra xác nhận

- `git grep` trên index sau dọn dẹp: không phát hiện PostgreSQL URI, private key, Cloudinary secret, Google client secret hoặc token theo các định dạng phổ biến.
- `git ls-files -ci --exclude-standard`: không còn file bị theo dõi trái với `.gitignore`.
- `npm audit --omit=dev --audit-level=high`: `0 vulnerabilities`.
- `.env.example`: các trường secret để trống; giá trị còn lại chỉ là cấu hình mẫu không nhạy cảm.

## Trạng thái

**Chưa được coi là hoàn tất trên GitHub** cho tới khi:

1. Commit và push bộ xóa file hiện tại.
2. GitHub Support xác nhận cached commit nhạy cảm đã được purge.
3. Xác nhận credential và tài khoản từng lộ đã được rotate/vô hiệu hóa.
