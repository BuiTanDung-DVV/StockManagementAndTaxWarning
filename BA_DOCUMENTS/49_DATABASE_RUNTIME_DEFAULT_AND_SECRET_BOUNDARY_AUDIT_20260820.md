# Kiểm toán nguồn dữ liệu runtime và ranh giới bí mật — 20/08/2026

## Kết luận

- **REAL:** số liệu nghiệp vụ của các cửa hàng 34 và 35 được đọc từ PostgreSQL qua API backend.
- **HARDCODED hợp lệ:** nhãn giao diện, màu, route, cấp quyền và mã loại nghiệp vụ; đây không phải dữ liệu cửa hàng.
- **Đã sửa local:** lỗi tải phương pháp giá vốn/thông báo không còn bị trình bày như `AVG`, số 0 hoặc danh sách rỗng lấy từ DB.
- **Đã sửa local:** bán hàng, tồn kho, tài chính, sản phẩm, nhãn và tìm kiếm cửa hàng không còn biến phản hồi API sai cấu trúc/lỗi DB thành danh sách rỗng.
- **Đã sửa local:** KPI bán hàng, dòng tiền và lãi/lỗ từ chối response thiếu trường bắt buộc, không ép trường bị thiếu thành số 0.
- **Đã sửa local:** KPI tổng sản phẩm kho và phân tích ABC bắt buộc metadata tổng, kỳ, timezone và số liệu đối soát từ backend.
- **Đã sửa local:** lỗi tải membership không còn bị trình bày thành “Chưa có cửa hàng”; shop ID lạ không tự chuyển sang cửa hàng đầu tiên.
- **Đã sửa local:** AI không còn danh sách văn bản pháp luật hard-code; chỉ dùng kho tài liệu DB của cửa hàng.
- **Đã sửa local:** bán hàng thiếu lô tồn phải rollback, không lấy `products.cost_price` để che thiếu lô.
- **Đã sửa local:** chốt ngày, giao dịch chênh lệch, sổ cái và số dư tài khoản tiền mặt được ghi trong một transaction.
- **Secret boundary đạt ở code:** Flutter không chứa `DATABASE_URL`, Cloudinary secret, Gemini key, JWT/refresh/OTP secret hoặc chuỗi kết nối PostgreSQL. Upload ảnh và AI đều đi qua backend.
- **Đúng một phần:** production đang là bản cũ `deploy=78f85dd5`; chưa đăng nhập smoke test vì chưa có xác nhận nhập tài khoản kiểm thử vào trình duyệt.

## Bằng chứng DB chỉ đọc

Chạy `node dist/scripts/audit-store-data.js`, không ghi dữ liệu:

| Shop | Sản phẩm | Đơn bán | Khách | Kỳ đơn | Dấu hiệu mock/generator |
|---:|---:|---:|---:|---|---:|
| 34 | 250 | 7.595 | 24 | 29/07/2023–28/07/2026 | 0 |
| 35 | 250 | 7.783 | 24 | 29/07/2023–28/07/2026 | 0 |
| 36 | 1 | 0 | 0 | Chưa có | 0 |

Shop 34/35 có dữ liệu cho sản phẩm, danh mục, tồn/lô, kiểm kê, nhập hàng, bán/trả hàng,
công nợ, quỹ, sổ tài chính, chốt ngày, dự báo, ngân sách, hóa đơn, thuế, nhật ký,
kho tri thức AI và thông báo. `debt_evidences` và `invoice_scans` hiện bằng 0; UI phải hiển thị
empty state thật, không chèn ảnh mẫu.

Shop 36 là cửa hàng DB thật nhưng dữ liệu chưa đủ cho kiểm thử nghiệp vụ. Không được dùng
số 0 của shop này để kết luận hệ thống tính đúng; cần seed riêng nếu muốn dùng làm cửa hàng demo.

## Các thay đổi local

| Khu vực | Trước | Sau |
|---|---|---|
| Phương pháp giá vốn | Chưa tải/lỗi API có thể hiện `AVG` | `method=null`, có loading/error; chỉ nhận `AVG/FIFO` từ API |
| Lô và định giá tồn | Lỗi API trả `[]` hoặc `{}` | Lỗi được ném lên caller; không giả thành dữ liệu rỗng |
| Thông báo | Lỗi API giữ số 0/danh sách rỗng | Có loading/error/retry; empty chỉ khi API trả danh sách rỗng |
| Sales/kho/tài chính/sản phẩm/nhãn | Phản hồi sai cấu trúc có thể bị chuẩn hóa thành `[]` | Ném lỗi hợp đồng dữ liệu; chỉ hiện empty khi backend thực sự trả danh sách rỗng |
| KPI bán hàng/dòng tiền/lãi lỗ | Trường bị thiếu có thể được UI ép thành 0 | Provider kiểm tra metric, kỳ và chuỗi biểu đồ bắt buộc; response thiếu bị báo lỗi |
| KPI tồn kho/ABC | Thiếu `productTotal` hoặc trường đối soát có thể thành 0 | Provider kiểm tra tổng DB, danh sách, kỳ và metric ABC trước khi render |
| Tìm kiếm cửa hàng | Lỗi DB bị hiểu là không có kết quả | UI báo không tải được dữ liệu; kết quả rỗng chỉ dành cho truy vấn hợp lệ không có shop |
| Membership/cửa hàng | Lỗi DB có thể thành `shops=[]`; shop ID lạ rơi về shop đầu | Lỗi DB được giữ là lỗi; không cấp session trước khi tải shop; ID lạ không đổi scope |
| Nguồn pháp lý AI | Có bốn văn bản hard-code làm fallback | Chỉ dùng `ai_knowledge_documents`; thiếu/lỗi DB phải báo chưa đủ căn cứ |
| Giá vốn khi thiếu lô | Tự bù bằng giá vốn master sản phẩm | Từ chối giao dịch và rollback để bảo toàn tồn–lô–COGS |
| Chênh lệch chốt ngày | Có thể lưu phiếu trước, bỏ qua điều chỉnh khi thiếu tài khoản CASH | Một transaction; khóa tài khoản CASH; mọi bước cùng thành công hoặc cùng rollback |
| Secret frontend | Có nguy cơ cấu hình sai theo thời gian | Test quét toàn bộ Dart và chặn tên secret/chuỗi PostgreSQL |

## Lưu ý về Google OAuth

`GOOGLE_WEB_CLIENT_ID` là định danh công khai bắt buộc cho OAuth trên trình duyệt, không phải
client secret. Backend vẫn phải kiểm chứng ID token với danh sách client ID được phép. Mọi
client secret, khóa AI, khóa ảnh và thông tin DB phải chỉ tồn tại trong biến môi trường backend.

## Kiểm thử

- Backend build và P0: **194/194 đạt**.
- Flutter: **134/134 đạt**; analyze toàn dự án **không có lỗi**.
- Kiểm thử ranh giới dữ liệu/secret: **14/14 đạt**.
- Production login: không có console error/warning; nhận diện vẫn ghi `SmartStock POS & Tax`,
  chứng minh production chưa chứa toàn bộ thay đổi local mới.

## Phần chưa xác minh

Muốn phân loại REAL/BROKEN cho từng KPI hiển thị sau đăng nhập, cần quyền nhập tài khoản kiểm
thử vào `smartstock-tax.vercel.app`. Việc này chỉ đọc và điều hướng; không bấm các hành động ghi,
không tạo đơn, không sửa cấu hình và không tải tệp.
