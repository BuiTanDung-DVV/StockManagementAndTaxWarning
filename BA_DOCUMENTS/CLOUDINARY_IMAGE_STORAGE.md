# Lưu trữ và tối ưu ảnh bằng Cloudinary

## 1. Phạm vi

- Mỗi sản phẩm có tối đa một ảnh tại `products.image_url`.
- Mỗi cửa hàng có tối đa một QR thanh toán tại
  `shop_profiles.qr_payment_url`.
- Thay ảnh: lưu và xác minh ảnh mới trước, sau đó xóa ảnh cũ.
- Xóa sản phẩm: xóa ảnh sản phẩm liên quan.
- QR chỉ hiển thị khi chọn một cửa hàng cụ thể.
- Không thay đổi database schema hiện tại.

## 2. Kiến trúc bảo mật

1. Flutter gửi tên, loại và dung lượng ảnh cho backend.
2. Backend kiểm tra quyền và tạo chữ ký Cloudinary có thời hạn ngắn.
3. Flutter tải ảnh trực tiếp lên Cloudinary bằng `multipart/form-data`.
4. API Secret không bao giờ được gửi xuống Flutter.
5. Backend dùng Admin API xác minh `public_id`, định dạng, dung lượng và kích
   thước thật của ảnh.
6. Chỉ public ID nằm trong thư mục của cửa hàng hiện tại mới được xác nhận hoặc
   xóa.

Thư mục Cloudinary:

```text
smartstock/shops/{shopId}/products/{uuid}
smartstock/shops/{shopId}/payment-qr/{uuid}
```

## 3. Giới hạn ảnh

- Định dạng: JPG, PNG, WEBP.
- Dung lượng tối đa: 5 MB.
- Độ phân giải tối đa sau upload: 20 megapixel.
- Ảnh sản phẩm được chọn ở tối đa 1.400 px, chất lượng 82 để giảm dung lượng
  ảnh gốc.
- QR không bị nén lại ở phía Flutter để giữ khả năng quét.

## 4. Tối ưu khi hiển thị

Ảnh gốc được lưu trong database. Khi hiển thị danh sách sản phẩm, Flutter tạo
URL Cloudinary có transformation:

```text
f_auto,q_auto:good,w_240,h_240,c_fill
```

Ý nghĩa:

- `f_auto`: tự chọn AVIF, WebP hoặc định dạng phù hợp trình duyệt.
- `q_auto:good`: cân bằng chất lượng và dung lượng.
- `w_240,h_240,c_fill`: chỉ tải thumbnail phù hợp khung 70×70 trên thiết bị
  có mật độ điểm ảnh cao.

Màn chỉnh sửa sản phẩm dùng ảnh tối đa 900 px. QR dùng URL gốc, không áp dụng
transformation có thể làm giảm độ rõ.

Với thumbnail trung bình 15–40 KB và phân trang 20 sản phẩm, một trang danh sách
dự kiến tải khoảng 0,3–0,8 MB ảnh ở lần đầu; cache của Cloudinary và
`CachedNetworkImage` giảm tải lại ở các lần tiếp theo.

## 5. Tạo tài khoản Cloudinary Free

1. Đăng ký tại https://cloudinary.com/users/register_free.
2. Không cần thêm thẻ cho Free plan.
3. Mở **Console → API Keys**.
4. Sao chép Cloud name, API Key và API Secret.
5. Không gửi API Secret qua chat, không commit vào Git.

Tài liệu chính thức:

- https://cloudinary.com/documentation/node_image_and_video_upload
- https://cloudinary.com/documentation/image_upload_api_reference
- https://cloudinary.com/documentation/image_format_support
- https://cloudinary.com/documentation/billing_and_plans

## 6. Biến môi trường backend

Thêm trực tiếp trong Vercel backend:

```text
CLOUDINARY_CLOUD_NAME=<cloud name>
CLOUDINARY_API_KEY=<API key>
CLOUDINARY_API_SECRET=<API secret>
```

Sau khi thêm biến, redeploy backend. Không thêm giá trị thật vào
`backend/.env.example`.

## 7. API

Ảnh sản phẩm:

- `POST /api/products/image-upload/presign`
- `POST /api/products/image-upload/confirm`
- `POST /api/products/image-upload/delete`

QR cửa hàng:

- `GET /api/shop-payment-qr`
- `POST /api/shop-payment-qr/presign`
- `POST /api/shop-payment-qr/confirm`

## 8. Phân quyền

- Người có quyền sửa sản phẩm được tải hoặc thay ảnh sản phẩm.
- Mọi thành viên của cửa hàng được xem QR.
- Chỉ người có quyền sửa cài đặt được tải hoặc thay QR.
- Chế độ **Tất cả cửa hàng** không hiển thị nút QR và API xem QR từ chối phạm
  vi tổng hợp.

## 9. Theo dõi credit

Cloudinary Free dùng chung credit cho lưu trữ, băng thông và transformation.
Cần theo dõi ba chỉ số trong Cloudinary Console:

- Storage: dung lượng ảnh gốc và biến thể.
- Bandwidth: dung lượng ảnh thực tế được tải xuống.
- Transformations: số biến thể mới được tạo.

Không tạo kích thước thumbnail động theo mọi chiều rộng tùy ý. Ứng dụng hiện
dùng số lượng biến thể cố định để Cloudinary có thể tái sử dụng cache và tránh
tăng số transformation không cần thiết.
