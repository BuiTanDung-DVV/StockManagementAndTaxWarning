# Xác minh danh sách bán hàng đa cửa hàng

**Ngày kiểm tra:** 20/08/2026
**Phạm vi:** `GET /sales-orders` và màn Lịch sử đơn hàng
**Trạng thái:** Đã sửa local, chưa deploy production

## 1. Sai lệch đã phát hiện

- API KPI bán hàng đã nhận danh sách cửa hàng được phân quyền.
- API danh sách đơn chỉ nhận một `shopId`; middleware cũng từ chối giá trị `all`.
- Vì vậy giao diện tổng hợp có thể tải KPI nhưng bảng đơn báo lỗi 403.
- Nút ghi nhận giao dịch vẫn xuất hiện dù chế độ tất cả cửa hàng chỉ có quyền xem.

## 2. Thay đổi

- Middleware chỉ cho phép phạm vi nhiều cửa hàng đối với thao tác xem danh sách.
- Service lọc trực tiếp tại PostgreSQL bằng các `shopId` đã được middleware xác thực.
- Tìm kiếm, trạng thái và phân trang tiếp tục xử lý ở DB, không lọc danh sách giả tại Flutter.
- Tên cửa hàng của từng đơn được ghép từ dữ liệu `/my-shops` đã tải từ backend.
- Giao diện ẩn thao tác tạo giao dịch trong chế độ tổng hợp.
- Khi mở chi tiết từ danh sách tổng hợp, ứng dụng chọn đúng cửa hàng của đơn trước khi gọi API chi tiết.

## 3. Bằng chứng

Đối soát chỉ đọc trên DB:

| Phạm vi | Số đơn |
|---|---:|
| Cửa hàng 34 | 7.595 |
| Cửa hàng 35 | 7.783 |
| Cả hai cửa hàng | 15.378 |

Kết quả tổng hợp bằng đúng tổng hai cửa hàng và `0` dòng nằm ngoài phạm vi 34/35.

Kiểm thử:

- Backend TypeScript build thành công.
- Kiểm thử phạm vi bán hàng đa cửa hàng: `2/2` đạt.
- Phân tích hai tệp Flutter liên quan: không có lỗi.
- Kiểm thử bố cục và hành vi danh sách bán hàng: `4/4` đạt.

## 4. Ranh giới dữ liệu và bí mật

- Đơn hàng, khách hàng, trạng thái, tiền và tên cửa hàng đều đến từ backend/DB.
- Frontend chỉ chứa nhãn giao diện và trạng thái trình bày; không chứa số liệu nghiệp vụ mẫu.
- Bí mật kết nối DB, Cloudinary và OAuth secret chỉ được đọc tại backend từ biến môi trường.
- Google OAuth Client ID là định danh công khai theo giao thức; không được xem là secret và không thể giấu hoàn toàn trong ứng dụng web.

## 5. Chưa xác minh

- Chưa smoke test production vì thay đổi chưa được deploy.
- Chưa chụp ảnh desktop/mobile sau sửa.
- Chưa thực hiện thao tác mở chi tiết production vì cần phiên đăng nhập kiểm thử được người dùng cho phép.
