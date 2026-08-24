# Design QA

## Phạm vi đã xác minh trước đây

- Bản kiểm tra: Flutter Web release tại môi trường local.
- Viewport desktop: 1440 × 900.
- Viewport mobile: 390 × 844.
- Tham chiếu: mẫu desktop và mobile đã chọn trong giai đoạn định hướng thiết kế.
- Màn hình đã rà soát: đăng nhập, tổng quan, bán hàng, POS, sản phẩm, tồn kho,
  tài chính, công nợ, khách hàng, nhà cung cấp và cài đặt.

## Tiêu chí

- Hệ thống phân cấp thị giác rõ, ưu tiên dữ liệu và hành động nghiệp vụ.
- Thành phần co giãn theo chiều rộng, không tràn hoặc che thanh điều hướng.
- Giảm icon trang trí; dùng asset thương hiệu và hình minh họa có sẵn.
- Có loading, empty và error state phù hợp với ngữ cảnh màn hình.
- Lối vào Hỏi AI luôn hiện trên shell chính; POS/QR giữ giao diện giao dịch tập trung.
- Không ghi nhận đạt chuẩn accessibility vì chưa thực hiện kiểm thử chuyên biệt.

## Kết quả lần kiểm tra trước

- P0: Không phát hiện.
- P1: Không phát hiện sau khi sửa lỗi nội dung dashboard/tồn kho bị ẩn và trạng thái
  lỗi mobile che thanh điều hướng.
- P2: Không phát hiện lỗi bố cục còn mở trong các viewport đã kiểm tra.
- Trình duyệt: không có log mức `error` hoặc `warn` trong lần kiểm tra cuối.
- Giới hạn: một số API trên môi trường local trả lỗi kết nối; error state đã được xác
  minh, còn dữ liệu nghiệp vụ thực tế sẽ được kiểm tra lại trên production sau deploy.

## Lần nâng cấp 09/08/2026

- Visual target: `C:/Users/tandu/.codex/generated_images/019f9802-23a5-72b2-96b7-2aebb4688fac/exec-6a9cbe1a-e730-4636-9c01-e311e63da12b.png`.
- Viewport đã kiểm tra: desktop 1440 × 1024 và mobile 390 × 844.
- Theme, typography và shared controls không có lỗi phân tích tĩnh.
- Đăng nhập hiển thị đúng trên desktop/mobile và không có console error.
- Widget test xác nhận kỳ trước là cột trái màu teal, kỳ hiện tại/kỳ sau là cột phải màu xanh.
- Bộ lọc biểu đồ vẫn thao tác được; biểu đồ dài vẫn cuộn ngang được.

### Phần đối chiếu đang bị chặn

- Mẫu được duyệt là dashboard sau đăng nhập.
- Trình duyệt local chưa có phiên tài khoản test nên chưa thể chụp dashboard ở cùng trạng thái
  để so sánh trực tiếp với mẫu.
- Không sao chép thông tin đăng nhập hoặc phiên production vào môi trường local.

### Cổng kiểm tra còn lại

1. Đăng nhập local bằng tài khoản test được chỉ định.
2. Chụp dashboard desktop/mobile với dữ liệu thật.
3. So sánh với mẫu đã duyệt và sửa các sai lệch P1/P2 còn lại nếu có.

final result: blocked
