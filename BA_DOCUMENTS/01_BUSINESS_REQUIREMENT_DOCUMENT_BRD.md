# Business Requirement Document (BRD)

> **Trạng thái cập nhật 25/07/2026:** các trạng thái baseline trong bảng phía
> dưới mô tả production đã đánh giá trước bản vá. Bảng delta sau đây là bằng
> chứng code/test local trên working tree sau `bba0c5f5`, chưa thay thế nghiệm
> thu production.

## Delta yêu cầu sau bản vá local

| ID | Kết quả code/test | Trạng thái phát hành |
|---|---|---|
| BR-RBAC-01 | Middleware kiểm tra membership active, role cùng shop và permission theo module/cấp độ; test permission đạt | Đã xác minh code/test; chưa production |
| BR-RBAC-02 | `all` chỉ cho phép thao tác xem, giao tập shop được xác thực và tập shop có quyền; input shop không hợp lệ fail-closed | Đã xác minh code/test; chưa production |
| BR-SALE-05 | Status hoàn tất gồm `COMPLETED` và `DELIVERED`; query list được kiểm tra property path; kỳ tháng dùng helper chung | Backend test đạt; helper Flutter đã review nhưng test chưa chạy lại; chưa đối soát production |
| BR-DEBT-01 | UI lấy receivable thật từ `/customer-receivables`; không còn tạo danh sách nợ mẫu trên màn hình | Đã xác minh code; chưa production |
| BR-REP-01 | CSV công nợ dùng dữ liệu API, BOM UTF-8, escape CSV/formula, số còn nợ không âm và tổng kiểm soát | Đã xác minh code; test Flutter đã bổ sung nhưng chưa chạy lại; chưa đối chiếu production |
| BR-TAX-02 | API chuẩn hóa số thuế đầu vào và số phải nộp không âm; số nộp thừa được tách riêng | Đã xác minh code/test; chưa production |
| BR-TAX-03 | Thiếu/sai MST và placeholder cũ `0123456789` đều chặn xuất XML | Đã xác minh code/test; chưa production |
| BR-UX-01 | Các vùng dashboard/finance liên quan dùng error/retry rõ hơn thay vì số fallback | Đã xác minh code; chưa production |
| BR-SALE-06 | CTA POS mobile có khoảng an toàn; AI không phủ POS mobile | Đã xác minh code; test layout đã bổ sung nhưng chưa chạy lại; chưa kiểm tra production |

Các yêu cầu vẫn mở: transaction toàn vẹn sale/return, đối soát số liệu production,
XSD/import HTKK, accessibility, migration `system_configs` và kiểm thử thiết bị
mobile thực.

## 1. Thông tin tài liệu

| Thuộc tính | Giá trị |
|---|---|
| Sản phẩm | SmartStock |
| Phiên bản tài liệu | 2.0 |
| Baseline | Production ngày 25/07/2026 |
| Đối tượng | Hộ/cửa hàng bán lẻ, chủ cửa hàng, nhân viên bán hàng/kho/kế toán |
| Phạm vi | Bán hàng, tồn kho, tài chính, công nợ, cảnh báo thuế, quản trị cửa hàng |

## 2. Bối cảnh và vấn đề nghiệp vụ

Cửa hàng nhỏ thường ghi nhận đơn hàng, tồn kho, công nợ và thu/chi trên nhiều công
cụ tách rời. Hệ quả là:

- không biết số liệu nào là nguồn đúng;
- giá vốn và lợi nhuận khó đối soát;
- nợ mua thiếu dễ bị bỏ quên;
- dữ liệu kê khai thuế có thể thiếu hoặc dùng quy tắc đã hết hiệu lực;
- quyền nhân viên khó kiểm soát khi có nhiều cửa hàng;
- báo cáo Excel/XML dễ không truy ngược được đến chứng từ.

SmartStock hướng đến một hệ thống đơn giản, dễ giải thích trong đồ án và đủ kiểm soát
để hỗ trợ vận hành. Ứng dụng chỉ hỗ trợ tính toán/cảnh báo; không thay thế tư vấn
pháp lý, kế toán hoặc cơ quan thuế.

## 3. Tầm nhìn sản phẩm

> Một nguồn dữ liệu thống nhất cho bán hàng, tồn kho, dòng tiền và nghĩa vụ thuế dự
> kiến, có phân quyền theo cửa hàng và truy vết được từ báo cáo đến giao dịch.

## 4. Mục tiêu nghiệp vụ

| ID | Mục tiêu | Chỉ số mục tiêu đề xuất |
|---|---|---|
| OBJ-01 | Rút ngắn thao tác bán hàng | 90% đơn thường hoàn tất trong ≤ 60 giây |
| OBJ-02 | Giảm chênh lệch tồn | ≥ 99% SKU cân theo công thức XNT sau kiểm kê |
| OBJ-03 | Minh bạch dòng tiền | 100% giao dịch tiền liên kết chứng từ hoặc lý do |
| OBJ-04 | Kiểm soát công nợ | 100% đơn mua thiếu tạo khoản phải thu và lịch sử thu |
| OBJ-05 | Hỗ trợ thuế có nguồn | 100% rule có nguồn, ngày hiệu lực, phiên bản và người duyệt |
| OBJ-06 | Bảo vệ dữ liệu nhiều shop | 100% API shop-scoped có test permission âm |
| OBJ-07 | Báo cáo truy vết được | Tổng báo cáo khớp dữ liệu chi tiết trong bộ kiểm soát |

Đây là mục tiêu tương lai, không phải số liệu đã đạt trên baseline.

## 5. Các bên liên quan

| Vai trò | Nhu cầu chính | Quyền quyết định |
|---|---|---|
| Chủ cửa hàng | Tổng quan, lợi nhuận, thuế, nhân viên, cấu hình | Nghiệp vụ và phát hành |
| Nhân viên bán hàng | POS, khách hàng, đơn, thu nợ theo quyền | Vận hành bán hàng |
| Nhân viên kho | Nhập, kiểm kê, XNT, cảnh báo tồn | Vận hành kho |
| Kế toán/người phụ trách tài chính | Sổ quỹ, công nợ, báo cáo, xuất dữ liệu | Xác nhận số liệu |
| BA/PO | Requirement, acceptance, ưu tiên backlog | Phạm vi phiên bản |
| Nhóm phát triển | Giải pháp kỹ thuật và test | Thiết kế kỹ thuật |
| Chuyên gia thuế/kế toán | Công thức, nguồn pháp lý, mẫu kê khai | Duyệt nội dung thuế |

## 6. Phạm vi

### 6.1 Trong phạm vi hiện tại

- Đăng ký email/OTP, đăng nhập, quên/đặt lại mật khẩu, refresh token.
- Cửa hàng, thành viên, vai trò và permission.
- Sản phẩm, danh mục, tag, đơn vị quy đổi, lô và lịch sử giá.
- POS, đơn bán, payment, hoàn hàng.
- Kho, movement, PO, kiểm kê, XNT và cảnh báo.
- Khách hàng, nhà cung cấp, khoản phải thu/phải trả.
- Sổ quỹ, giao dịch, P&L, dự báo, hóa đơn và nghĩa vụ thuế.
- Ước tính thuế, cấu hình rule và xuất XML hướng HTKK.
- Thông báo, audit log, cấu hình, hồ sơ shop và kho tri thức AI.
- Flutter Web responsive; backend API deploy trên Vercel.

### 6.2 Ngoài phạm vi baseline

- Kết nối ngân hàng/QR production đã được chứng nhận.
- Ký số, nộp tờ khai hoặc thanh toán thuế trực tiếp.
- Kế toán kép hoàn chỉnh theo chuẩn pháp lý.
- Chứng nhận tương thích HTKK.
- Cam kết accessibility/WCAG.
- AI đưa ra tư vấn pháp lý độc lập.
- Tự động sửa schema, API contract hoặc công thức trong giai đoạn BA.

## 7. Yêu cầu nghiệp vụ

### 7.1 Tài khoản và cửa hàng

| ID | Yêu cầu | Mức ưu tiên | Trạng thái baseline |
|---|---|---|---|
| BR-AUTH-01 | Người dùng đăng ký bằng email đã xác minh OTP | Must | Đúng một phần |
| BR-AUTH-02 | Phiên đăng nhập được làm mới và thu hồi an toàn | Must | Đúng một phần |
| BR-AUTH-03 | Mỗi request chỉ truy cập shop có membership hoạt động | Must | Đúng một phần |
| BR-RBAC-01 | Quyền được kiểm tra tại backend theo module/cấp độ | Must | Không chính xác |
| BR-RBAC-02 | Tổng hợp nhiều shop không làm tăng quyền | Must | Không chính xác |
| BR-RBAC-03 | Thay đổi vai trò/nhân viên có audit | Must | Đúng một phần |

### 7.2 Bán hàng

| ID | Yêu cầu | Mức ưu tiên | Trạng thái baseline |
|---|---|---|---|
| BR-SALE-01 | POS tìm hàng, thêm giỏ, chọn khách và thanh toán | Must | Đúng một phần |
| BR-SALE-02 | Đơn/payment/tồn/COGS ghi atomically | Must | Bị chặn |
| BR-SALE-03 | Đơn nợ tạo khoản phải thu | Must | Đúng một phần |
| BR-SALE-04 | Hoàn/hủy đảo tác động đúng một lần | Must | Bị chặn |
| BR-SALE-05 | Summary khớp danh sách theo cùng filter | Must | Không chính xác |
| BR-SALE-06 | POS hoàn tất được trên mobile | Must | Không chính xác |

### 7.3 Kho và giá vốn

| ID | Yêu cầu | Mức ưu tiên | Trạng thái baseline |
|---|---|---|---|
| BR-INV-01 | Cảnh báo dưới định mức khớp tồn hiện tại | Must | Đã xác minh |
| BR-INV-02 | Nhập hàng cập nhật tồn/lô/giá vốn | Must | Bị chặn |
| BR-INV-03 | Kiểm kê và điều chỉnh có lý do/người duyệt | Must | Đúng một phần |
| BR-INV-04 | Báo cáo XNT cân theo công thức | Must | Bị chặn |
| BR-INV-05 | Giá vốn nhất quán giữa đơn, kho và P&L | Must | Đúng một phần |

### 7.4 Tài chính và công nợ

| ID | Yêu cầu | Mức ưu tiên | Trạng thái baseline |
|---|---|---|---|
| BR-FIN-01 | Số dư quỹ khớp tổng thu/chi và dashboard | Must | Không chính xác |
| BR-FIN-02 | Lợi nhuận dùng định nghĩa được công bố | Must | Đúng một phần |
| BR-DEBT-01 | Sổ nợ dùng receivable thật, không dùng dữ liệu mẫu | Must | Không chính xác |
| BR-DEBT-02 | Thu nợ cập nhật khoản phải thu và sổ quỹ | Must | Bị chặn |
| BR-REP-01 | Excel phản ánh đúng dữ liệu nguồn và tổng kiểm soát | Must | Bị chặn |

### 7.5 Thuế

| ID | Yêu cầu | Mức ưu tiên | Trạng thái baseline |
|---|---|---|---|
| BR-TAX-01 | Rule thuế có nguồn và ngày hiệu lực | Must | Không chính xác |
| BR-TAX-02 | Không hiển thị nghĩa vụ thuế âm | Must | Không chính xác |
| BR-TAX-03 | Không xuất nếu thiếu dữ liệu định danh bắt buộc | Must | Không chính xác |
| BR-TAX-04 | XML được validate/import đúng phiên bản HTKK | Must | Bị chặn |
| BR-TAX-05 | Hành vi code và nhận định pháp lý được tách rõ | Must | Đúng một phần |

### 7.6 UX và vận hành

| ID | Yêu cầu | Mức ưu tiên | Trạng thái baseline |
|---|---|---|---|
| BR-UX-01 | Màn chính có loading/empty/error/retry | Must | Đúng một phần |
| BR-UX-02 | Desktop/mobile không che CTA hoặc cắt nội dung | Must | Không chính xác |
| BR-OPS-01 | Build/lint/test chạy lặp lại trong CI | Must | Đúng một phần |
| BR-OPS-02 | Schema chỉ thay đổi qua migration được duyệt | Must | Không chính xác |
| BR-AI-01 | AI chỉ dùng nguồn đã duyệt và còn hiệu lực | Must | Không chính xác |

## 8. Quy tắc nghiệp vụ cấp cao

1. Mọi bảng nghiệp vụ phải có `shop_id` hoặc quan hệ scope tương đương.
2. Frontend không phải là hàng rào bảo mật; backend phải kiểm tra quyền.
3. Mọi tổng phải xác định kỳ, timezone, trạng thái giao dịch và thời điểm `asOf`.
4. Không tính doanh thu từ đơn hủy; hoàn hàng phải giảm theo rule công bố.
5. Không ghi nghĩa vụ thuế âm.
6. Không xuất tệp kê khai với mã định danh giả hoặc dữ liệu bắt buộc thiếu.
7. Dữ liệu demo phải được tách môi trường hoặc gắn nhãn rõ.
8. Thao tác sale/return/payment/stock/role/tax export phải có audit.
9. `all shops` là scope hợp tập, không phải một vai trò.
10. Quy định thuế phải được version hóa theo ngày hiệu lực.

## 9. Ràng buộc

- Cần duy trì Flutter/Riverpod/GoRouter và Express/TypeORM hiện có trong các bản vá gần.
- Không đổi schema/API diện rộng nếu chưa có migration và kế hoạch tương thích.
- Production hiện dùng Vercel serverless; DDL trong cold start là rủi ro phải loại bỏ.
- Dữ liệu production không được dùng cho test phá hủy.
- Nội dung pháp lý phải được xác nhận bởi người có chuyên môn.

## 10. Rủi ro nghiệp vụ

| Rủi ro | Xác suất | Tác động | Ứng phó |
|---|---|---|---|
| Sai quyền làm lộ dữ liệu shop | Cao | Rất cao | P0 RBAC + negative tests |
| Sai thuế do rule cũ | Cao | Rất cao | P0 rule versioning + legal review |
| Dashboard gây quyết định sai | Cao | Cao | Metric contract + reconciliation |
| Dữ liệu mẫu bị hiểu là dữ liệu thật | Cao | Rất cao | Xóa/ẩn hoặc gắn nhãn demo |
| Migration/cold start gây gián đoạn | Trung bình | Cao | Migration pipeline, không DDL runtime |
| Export không dùng được | Trung bình | Cao | Schema fixture + import acceptance |

## 11. Tiêu chí thành công của bản ổn định

- Không còn finding P0 mở.
- Dashboard, sales, finance, công nợ và tồn kho khớp bộ dữ liệu kiểm soát.
- Employee không thể vượt quyền bằng shop ID hoặc `all`.
- Rule thuế có nguồn/hiệu lực; không còn nội dung 100 triệu như quy định hiện hành.
- POS mobile hoàn tất được luồng chính.
- Build/lint/test chạy trong CI và ma trận truy vết được cập nhật.
