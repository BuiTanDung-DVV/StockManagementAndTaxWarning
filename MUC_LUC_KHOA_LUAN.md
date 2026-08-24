# MỤC LỤC KHÓA LUẬN TỐT NGHIỆP

**Tên đề tài đề xuất:** Xây dựng hệ thống quản lý bán hàng, tồn kho và cảnh báo nghĩa vụ thuế cho hộ kinh doanh và cửa hàng bán lẻ

> Ghi chú: Số trang được cập nhật tự động sau khi hoàn thiện nội dung và định dạng trong Word. Các mục như “Nhận xét của giảng viên” hoặc “Phiếu giao nhiệm vụ” có thể điều chỉnh theo mẫu của trường.

## PHẦN ĐẦU

- Trang bìa
- Trang bìa phụ
- Phiếu giao nhiệm vụ khóa luận
- Lời cam đoan
- Lời cảm ơn
- Nhận xét của giảng viên hướng dẫn
- Nhận xét của giảng viên phản biện
- Tóm tắt khóa luận bằng tiếng Việt
- Abstract
- Mục lục
- Danh mục từ viết tắt và thuật ngữ
- Danh mục bảng
- Danh mục hình, biểu đồ và sơ đồ

## MỞ ĐẦU

### 1. Lý do chọn đề tài

### 2. Bài toán cần giải quyết

### 3. Mục tiêu của đề tài

#### 3.1. Mục tiêu tổng quát

#### 3.2. Mục tiêu cụ thể

### 4. Đối tượng và phạm vi nghiên cứu

#### 4.1. Đối tượng nghiên cứu

#### 4.2. Phạm vi nghiệp vụ

#### 4.3. Phạm vi kỹ thuật

#### 4.4. Giới hạn của đề tài

### 5. Phương pháp nghiên cứu và thực hiện

### 6. Ý nghĩa khoa học và thực tiễn

### 7. Kết quả dự kiến

### 8. Bố cục khóa luận

## CHƯƠNG 1. TỔNG QUAN VỀ BÀI TOÁN QUẢN LÝ BÁN HÀNG, TỒN KHO VÀ CẢNH BÁO THUẾ

### 1.1. Tổng quan hoạt động của hộ kinh doanh và cửa hàng bán lẻ

### 1.2. Thực trạng quản lý bán hàng

### 1.3. Thực trạng quản lý hàng hóa và tồn kho

### 1.4. Thực trạng quản lý tài chính và công nợ

### 1.5. Nhu cầu theo dõi và cảnh báo nghĩa vụ thuế

### 1.6. Hạn chế của phương pháp quản lý thủ công và các công cụ rời rạc

### 1.7. Khảo sát một số hệ thống liên quan

#### 1.7.1. Tiêu chí khảo sát

#### 1.7.2. So sánh các giải pháp hiện có

#### 1.7.3. Khoảng trống và hướng tiếp cận của đề tài

### 1.8. Giải pháp SmartStock được đề xuất

#### 1.8.1. Tầm nhìn sản phẩm

#### 1.8.2. Nhóm người dùng mục tiêu

#### 1.8.3. Các chức năng chính

#### 1.8.4. Giá trị mang lại

### 1.9. Phạm vi và giới hạn của hệ thống

### 1.10. Kết chương

## CHƯƠNG 2. CƠ SỞ LÝ THUYẾT VÀ CÔNG NGHỆ SỬ DỤNG

### 2.1. Cơ sở nghiệp vụ bán hàng

#### 2.1.1. Quy trình bán hàng tại điểm bán

#### 2.1.2. Đơn bán hàng, thanh toán, bán chịu và hoàn hàng

#### 2.1.3. Doanh thu, giá vốn và lợi nhuận

### 2.2. Cơ sở nghiệp vụ quản lý kho

#### 2.2.1. Nhập, xuất và tồn kho

#### 2.2.2. Lô hàng và hạn sử dụng

#### 2.2.3. Kiểm kê và điều chỉnh tồn kho

#### 2.2.4. Phương pháp xác định giá vốn FIFO

#### 2.2.5. Cảnh báo tồn kho thấp và hàng sắp hết hạn

### 2.3. Cơ sở nghiệp vụ tài chính và công nợ

#### 2.3.1. Thu, chi và dòng tiền

#### 2.3.2. Công nợ phải thu của khách hàng

#### 2.3.3. Công nợ phải trả nhà cung cấp

#### 2.3.4. Báo cáo kết quả kinh doanh

### 2.4. Cơ sở về nghĩa vụ thuế của hộ kinh doanh

#### 2.4.1. Các khái niệm và sắc thuế liên quan

#### 2.4.2. Dữ liệu đầu vào phục vụ ước tính thuế

#### 2.4.3. Nguyên tắc phiên bản hóa quy tắc theo ngày hiệu lực

#### 2.4.4. Nguyên tắc cảnh báo và kiểm soát kết quả ước tính

#### 2.4.5. Xuất dữ liệu kê khai và giới hạn pháp lý của hệ thống

### 2.5. Kiến trúc ứng dụng client–server và RESTful API

### 2.6. Công nghệ phát triển phía người dùng

#### 2.6.1. Flutter và ngôn ngữ Dart

#### 2.6.2. Riverpod trong quản lý trạng thái

#### 2.6.3. GoRouter trong quản lý điều hướng

#### 2.6.4. Dio trong giao tiếp API

#### 2.6.5. Thiết kế giao diện responsive đa thiết bị

### 2.7. Công nghệ phát triển phía máy chủ

#### 2.7.1. Node.js và TypeScript

#### 2.7.2. Express.js

#### 2.7.3. TypeORM

#### 2.7.4. PostgreSQL và Supabase

### 2.8. Các kỹ thuật bảo mật được áp dụng

#### 2.8.1. Xác thực OTP và Google

#### 2.8.2. Access token và refresh token

#### 2.8.3. Mã hóa mật khẩu

#### 2.8.4. Phân quyền dựa trên vai trò và phạm vi cửa hàng

#### 2.8.5. Kiểm tra dữ liệu đầu vào và xử lý lỗi

#### 2.8.6. Nhật ký kiểm toán và bảo vệ dữ liệu nhạy cảm

### 2.9. Công cụ phát triển, kiểm thử và triển khai

### 2.10. Kết chương

## CHƯƠNG 3. PHÂN TÍCH YÊU CẦU HỆ THỐNG

### 3.1. Mô tả tổng thể hệ thống

### 3.2. Các bên liên quan

### 3.3. Tác nhân của hệ thống

#### 3.3.1. Chủ cửa hàng

#### 3.3.2. Quản lý cửa hàng

#### 3.3.3. Nhân viên bán hàng

#### 3.3.4. Nhân viên kho

#### 3.3.5. Nhân viên kế toán hoặc phụ trách tài chính

#### 3.3.6. Quản trị hệ thống

### 3.4. Yêu cầu chức năng

#### 3.4.1. Quản lý tài khoản và xác thực

#### 3.4.2. Quản lý cửa hàng, thành viên và phân quyền

#### 3.4.3. Quản lý sản phẩm, danh mục, nhãn và đơn vị tính

#### 3.4.4. Quản lý khách hàng

#### 3.4.5. Quản lý nhà cung cấp

#### 3.4.6. Bán hàng tại quầy và quản lý đơn hàng

#### 3.4.7. Thanh toán, bán chịu, hoàn và hủy đơn

#### 3.4.8. Quản lý nhập hàng và đơn đặt hàng

#### 3.4.9. Quản lý lô, tồn kho và biến động kho

#### 3.4.10. Kiểm kê và điều chỉnh tồn kho

#### 3.4.11. Quản lý thu, chi và sổ quỹ

#### 3.4.12. Quản lý công nợ phải thu và phải trả

#### 3.4.13. Thống kê, báo cáo và dự báo dòng tiền

#### 3.4.14. Ước tính, cảnh báo và xuất dữ liệu thuế

#### 3.4.15. Thông báo và nhật ký hoạt động

#### 3.4.16. Trợ lý AI và kho tri thức có kiểm soát

### 3.5. Yêu cầu phi chức năng

#### 3.5.1. Hiệu năng

#### 3.5.2. Bảo mật và riêng tư dữ liệu

#### 3.5.3. Tính toàn vẹn và nhất quán dữ liệu

#### 3.5.4. Khả dụng và khả năng phục hồi lỗi

#### 3.5.5. Khả năng mở rộng và bảo trì

#### 3.5.6. Khả năng sử dụng và hỗ trợ đa thiết bị

#### 3.5.7. Hỗ trợ tiếng Việt và khả năng tiếp cận

### 3.6. Quy tắc nghiệp vụ

#### 3.6.1. Quy tắc phạm vi dữ liệu theo cửa hàng

#### 3.6.2. Quy tắc phân quyền theo mô-đun và cấp độ thao tác

#### 3.6.3. Quy tắc xác định trạng thái đơn hàng

#### 3.6.4. Quy tắc cập nhật tồn kho và giá vốn

#### 3.6.5. Quy tắc ghi nhận công nợ và thanh toán

#### 3.6.6. Quy tắc tổng hợp chỉ số báo cáo

#### 3.6.7. Quy tắc ước tính và cảnh báo thuế

### 3.7. Phân tích các ca sử dụng

#### 3.7.1. Sơ đồ ca sử dụng tổng quát

#### 3.7.2. Ca sử dụng đăng ký, đăng nhập và khôi phục tài khoản

#### 3.7.3. Ca sử dụng quản lý cửa hàng và nhân viên

#### 3.7.4. Ca sử dụng quản lý sản phẩm

#### 3.7.5. Ca sử dụng bán hàng và thanh toán

#### 3.7.6. Ca sử dụng hoàn hoặc hủy đơn hàng

#### 3.7.7. Ca sử dụng nhập hàng và kiểm kê

#### 3.7.8. Ca sử dụng thu và trả công nợ

#### 3.7.9. Ca sử dụng lập báo cáo

#### 3.7.10. Ca sử dụng ước tính và xuất dữ liệu thuế

### 3.8. Mô hình hóa quy trình nghiệp vụ

#### 3.8.1. Quy trình đăng ký và bảo vệ tài khoản

#### 3.8.2. Quy trình bán hàng và thanh toán

#### 3.8.3. Quy trình nhập, xuất và kiểm kê kho

#### 3.8.4. Quy trình quản lý công nợ

#### 3.8.5. Quy trình ước tính và xuất dữ liệu thuế

### 3.9. Ma trận truy vết yêu cầu

### 3.10. Kết chương

## CHƯƠNG 4. PHÂN TÍCH VÀ THIẾT KẾ HỆ THỐNG

### 4.1. Kiến trúc tổng thể

#### 4.1.1. Mô hình kiến trúc client–server

#### 4.1.2. Kiến trúc ứng dụng Flutter theo tính năng

#### 4.1.3. Kiến trúc backend theo routes–controllers–services–entities

#### 4.1.4. Luồng giao tiếp giữa frontend, backend và cơ sở dữ liệu

### 4.2. Thiết kế các mô-đun chức năng

#### 4.2.1. Mô-đun xác thực và quản lý phiên

#### 4.2.2. Mô-đun cửa hàng và phân quyền RBAC

#### 4.2.3. Mô-đun sản phẩm và kho

#### 4.2.4. Mô-đun bán hàng và thanh toán

#### 4.2.5. Mô-đun khách hàng, nhà cung cấp và công nợ

#### 4.2.6. Mô-đun tài chính và báo cáo

#### 4.2.7. Mô-đun cảnh báo và báo cáo thuế

#### 4.2.8. Mô-đun thông báo, nhật ký và trợ lý AI

### 4.3. Thiết kế cơ sở dữ liệu

#### 4.3.1. Nguyên tắc thiết kế dữ liệu

#### 4.3.2. Sơ đồ thực thể–liên kết tổng quát

#### 4.3.3. Nhóm bảng tài khoản, cửa hàng và phân quyền

#### 4.3.4. Nhóm bảng sản phẩm, danh mục, đơn vị và lịch sử giá

#### 4.3.5. Nhóm bảng kho, lô, đơn nhập và kiểm kê

#### 4.3.6. Nhóm bảng bán hàng, chi tiết đơn và thanh toán

#### 4.3.7. Nhóm bảng khách hàng, nhà cung cấp và công nợ

#### 4.3.8. Nhóm bảng tài chính, hóa đơn và thuế

#### 4.3.9. Nhóm bảng thông báo, cấu hình và nhật ký kiểm toán

#### 4.3.10. Khóa, quan hệ, ràng buộc và chỉ mục

#### 4.3.11. Migration và quản lý phiên bản cơ sở dữ liệu

### 4.4. Thiết kế API

#### 4.4.1. Quy ước endpoint và phương thức HTTP

#### 4.4.2. Cấu trúc request và response

#### 4.4.3. Xác thực, phân quyền và phạm vi cửa hàng

#### 4.4.4. Kiểm tra dữ liệu đầu vào

#### 4.4.5. Xử lý lỗi và mã trạng thái HTTP

#### 4.4.6. Thiết kế API theo nhóm chức năng

### 4.5. Thiết kế giao diện người dùng

#### 4.5.1. Nguyên tắc thiết kế

#### 4.5.2. Sơ đồ điều hướng

#### 4.5.3. Thiết kế dashboard

#### 4.5.4. Thiết kế giao diện bán hàng POS

#### 4.5.5. Thiết kế giao diện sản phẩm và kho

#### 4.5.6. Thiết kế giao diện tài chính và công nợ

#### 4.5.7. Thiết kế giao diện thuế và báo cáo

#### 4.5.8. Thiết kế trạng thái tải, rỗng và lỗi

#### 4.5.9. Thiết kế responsive cho desktop và thiết bị di động

### 4.6. Thiết kế bảo mật

#### 4.6.1. Luồng xác thực và làm mới phiên

#### 4.6.2. Mô hình vai trò và quyền

#### 4.6.3. Cô lập dữ liệu giữa các cửa hàng

#### 4.6.4. Bảo vệ thông tin nhạy cảm

#### 4.6.5. Ghi nhật ký các thao tác quan trọng

### 4.7. Thiết kế triển khai

### 4.8. Kết chương

## CHƯƠNG 5. XÂY DỰNG VÀ TRIỂN KHAI HỆ THỐNG

### 5.1. Môi trường và công cụ phát triển

### 5.2. Tổ chức mã nguồn

#### 5.2.1. Cấu trúc dự án Flutter

#### 5.2.2. Cấu trúc dự án backend

#### 5.2.3. Cấu trúc migration và tài liệu nghiệp vụ

### 5.3. Xây dựng ứng dụng Flutter

#### 5.3.1. Khởi tạo ứng dụng và cấu hình môi trường

#### 5.3.2. Xây dựng hệ thống định tuyến

#### 5.3.3. Quản lý trạng thái và gọi API

#### 5.3.4. Xây dựng giao diện dùng chung

#### 5.3.5. Xử lý loading, empty, error và retry

### 5.4. Xây dựng backend REST API

#### 5.4.1. Khởi tạo máy chủ và cấu hình môi trường

#### 5.4.2. Tổ chức route, controller và service

#### 5.4.3. Tích hợp TypeORM và PostgreSQL

#### 5.4.4. Middleware xác thực, phân quyền và xử lý lỗi

#### 5.4.5. Validation và chuẩn hóa dữ liệu

#### 5.4.6. Transaction và đảm bảo tính toàn vẹn dữ liệu

### 5.5. Hiện thực các chức năng chính

#### 5.5.1. Đăng ký, OTP, đăng nhập và quản lý phiên

#### 5.5.2. Quản lý cửa hàng, thành viên và quyền truy cập

#### 5.5.3. Quản lý hàng hóa, danh mục, giá và hình ảnh

#### 5.5.4. Quản lý nhập hàng, lô và tồn kho

#### 5.5.5. Ghi nhận bán hàng, thanh toán và hóa đơn

#### 5.5.6. Xử lý hoàn hàng và hủy đơn

#### 5.5.7. Quản lý khách hàng, nhà cung cấp và công nợ

#### 5.5.8. Quản lý sổ quỹ, chi phí, lương và dòng tiền

#### 5.5.9. Xây dựng dashboard và hệ thống báo cáo

#### 5.5.10. Ước tính, cảnh báo và xuất dữ liệu thuế

#### 5.5.11. Xây dựng thông báo, audit log và trợ lý AI

### 5.6. Triển khai hệ thống

#### 5.6.1. Cấu hình cơ sở dữ liệu

#### 5.6.2. Triển khai backend

#### 5.6.3. Xây dựng và triển khai Flutter Web

#### 5.6.4. Quản lý biến môi trường và bí mật

#### 5.6.5. Kiểm tra sau triển khai

### 5.7. Minh họa kết quả xây dựng

#### 5.7.1. Màn hình xác thực

#### 5.7.2. Màn hình tổng quan

#### 5.7.3. Màn hình bán hàng

#### 5.7.4. Màn hình sản phẩm và kho

#### 5.7.5. Màn hình khách hàng, nhà cung cấp và công nợ

#### 5.7.6. Màn hình tài chính và báo cáo

#### 5.7.7. Màn hình ước tính và cảnh báo thuế

#### 5.7.8. Màn hình quản trị cửa hàng và nhân viên

### 5.8. Kết chương

## CHƯƠNG 6. KIỂM THỬ VÀ ĐÁNH GIÁ HỆ THỐNG

### 6.1. Mục tiêu kiểm thử

### 6.2. Môi trường và dữ liệu kiểm thử

### 6.3. Chiến lược kiểm thử

#### 6.3.1. Kiểm thử đơn vị

#### 6.3.2. Kiểm thử widget Flutter

#### 6.3.3. Kiểm thử tích hợp API và cơ sở dữ liệu

#### 6.3.4. Kiểm thử chức năng và nghiệm thu

#### 6.3.5. Kiểm thử bảo mật và phân quyền

#### 6.3.6. Kiểm thử responsive và trải nghiệm người dùng

#### 6.3.7. Kiểm thử hiệu năng

### 6.4. Kiểm thử theo nhóm chức năng

#### 6.4.1. Xác thực và quản lý phiên

#### 6.4.2. RBAC và phạm vi nhiều cửa hàng

#### 6.4.3. Sản phẩm và kho

#### 6.4.4. Bán hàng, thanh toán và hoàn hủy

#### 6.4.5. Tài chính và công nợ

#### 6.4.6. Thuế và xuất báo cáo

#### 6.4.7. Dữ liệu, migration và API

#### 6.4.8. Giao diện, responsive và khả năng tiếp cận

### 6.5. Các kịch bản kiểm thử tiêu biểu

#### 6.5.1. Bán hàng và cập nhật tồn kho

#### 6.5.2. Bán chịu và thu nợ

#### 6.5.3. Nhập hàng và kiểm kê kho

#### 6.5.4. Phân quyền truy cập giữa nhiều cửa hàng

#### 6.5.5. Tổng hợp báo cáo tài chính

#### 6.5.6. Ước tính và xuất dữ liệu thuế

### 6.6. Kết quả kiểm thử

#### 6.6.1. Kết quả kiểm tra tĩnh và biên dịch

#### 6.6.2. Kết quả kiểm thử tự động frontend

#### 6.6.3. Kết quả kiểm thử tự động backend

#### 6.6.4. Kết quả kiểm thử thủ công và nghiệm thu

#### 6.6.5. Tổng hợp lỗi và phương án khắc phục

### 6.7. Đánh giá kết quả

#### 6.7.1. Mức độ đáp ứng yêu cầu chức năng

#### 6.7.2. Mức độ đáp ứng yêu cầu phi chức năng

#### 6.7.3. Đối chiếu với mục tiêu ban đầu

#### 6.7.4. Ưu điểm của hệ thống

#### 6.7.5. Hạn chế còn tồn tại

### 6.8. Kết chương

## KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN

### 1. Kết quả đạt được

### 2. Đóng góp của đề tài

### 3. Hạn chế của đề tài

### 4. Hướng phát triển

#### 4.1. Hoàn thiện tính toàn vẹn giao dịch bán hàng và kho

#### 4.2. Hoàn thiện đối soát số liệu tài chính và báo cáo

#### 4.3. Kiểm chứng biểu mẫu và quy tắc thuế theo nguồn pháp lý

#### 4.4. Mở rộng kiểm thử hiệu năng, bảo mật và khả năng tiếp cận

#### 4.5. Phát triển ứng dụng trên thiết bị di động

#### 4.6. Tích hợp thanh toán, hóa đơn điện tử và các dịch vụ bên ngoài

#### 4.7. Nâng cao khả năng hỗ trợ ra quyết định của trợ lý AI

## TÀI LIỆU THAM KHẢO

## PHỤ LỤC

### Phụ lục A. Danh mục yêu cầu chức năng và phi chức năng

### Phụ lục B. Đặc tả các ca sử dụng

### Phụ lục C. Ma trận phân quyền RBAC

### Phụ lục D. Từ điển dữ liệu và lược đồ cơ sở dữ liệu

### Phụ lục E. Danh mục API

### Phụ lục F. Danh mục màn hình và luồng điều hướng

### Phụ lục G. Bộ kịch bản và kết quả kiểm thử chi tiết

### Phụ lục H. Hướng dẫn cài đặt, cấu hình và triển khai

### Phụ lục I. Hướng dẫn sử dụng hệ thống

### Phụ lục J. Nguồn, phiên bản và ngày hiệu lực của quy tắc thuế

### Phụ lục K. Một số đoạn mã nguồn tiêu biểu

### Phụ lục L. Biên bản phân công và nhật ký thực hiện đề tài
