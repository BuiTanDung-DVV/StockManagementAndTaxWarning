# Design QA

## Phạm vi

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

## Kết quả

- P0: Không phát hiện.
- P1: Không phát hiện sau khi sửa lỗi nội dung dashboard/tồn kho bị ẩn và trạng thái
  lỗi mobile che thanh điều hướng.
- P2: Không phát hiện lỗi bố cục còn mở trong các viewport đã kiểm tra.
- Trình duyệt: không có log mức `error` hoặc `warn` trong lần kiểm tra cuối.
- Giới hạn: một số API trên môi trường local trả lỗi kết nối; error state đã được xác
  minh, còn dữ liệu nghiệp vụ thực tế sẽ được kiểm tra lại trên production sau deploy.

final result: passed
