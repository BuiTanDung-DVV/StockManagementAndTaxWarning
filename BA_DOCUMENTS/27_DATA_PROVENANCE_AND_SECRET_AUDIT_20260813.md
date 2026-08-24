# Kiểm kê nguồn dữ liệu và bí mật — 13/08/2026

## 1. Nguyên tắc áp dụng

- Dữ liệu nghiệp vụ hiển thị trên giao diện phải đi theo luồng `DB → backend API → Flutter`.
- Frontend không tự sinh số liệu nghiệp vụ, không dùng danh sách mẫu khi API lỗi và không tự quyết định công thức phía server.
- Khóa bí mật chỉ được đọc từ biến môi trường backend; không ghi vào source, log hoặc response.
- Nhãn giao diện, thông báo hướng dẫn, icon và route là metadata của ứng dụng, không phải dữ liệu nghiệp vụ.
- Dữ liệu do người dùng nhập trong biểu mẫu chỉ được coi là đã ghi nhận sau khi backend xác thực và lưu DB thành công.

## 2. Kết quả kiểm kê

| ID | Khu vực | Trạng thái | Nguồn thực tế / bằng chứng | Hành động |
|---|---|---|---|---|
| DP-01 | Bán hàng, kho, tài chính, khách hàng, nhà cung cấp | REAL | Các provider Flutter gọi API; backend truy vấn entity PostgreSQL theo shop | Tiếp tục đối soát công thức và tính đầy đủ dữ liệu |
| DP-02 | Dữ liệu demo ba năm | REAL-SEED | Dữ liệu tồn tại trong PostgreSQL và được tải qua API, không hard-code ở Flutter; tuy nhiên đây vẫn là dữ liệu mô phỏng | Phải gắn nhãn môi trường test và bổ sung dữ liệu đến ngày hiện tại |
| DP-03 | Cấu hình/ngưỡng thuế | KHÔNG CHÍNH XÁC PRODUCTION; ĐÃ SỬA LOCAL | DB production còn `100.000.000/90.000.000`, trong khi source dùng `1.000.000.000/900.000.000` | Đã chuyển frontend/backend sang DB là nguồn duy nhất; chờ duyệt migration `20260813_seed_verified_tax_policy.sql` |
| DP-04 | Tỷ lệ thuế theo ngành | BROKEN PRODUCTION; ĐÃ SỬA LOCAL | Bảng `tax_rules` production đang trống; backend cũ dùng tỷ lệ fallback trong code | Migration bổ sung bốn nhóm ngành và ngày hiệu lực; backend fail-closed nếu DB thiếu |
| DP-05 | AI ở chế độ tất cả cửa hàng | KHÔNG CHÍNH XÁC; ĐÃ SỬA LOCAL | Controller cũ fallback về shop `1`/shop đầu tiên | Chỉ cho phép AI khi có một `shopId` cụ thể; có regression test |
| DP-06 | Kho tri thức AI | REAL | `/ai/knowledge` đọc/ghi bảng `ai_knowledge_documents`; provider giữ trạng thái DB cuối cùng và không thay bằng tài liệu mẫu | Cần bổ sung trạng thái lỗi rõ trên UI |
| DP-07 | Tra cứu địa chỉ onboarding | ĐÚNG MỘT PHẦN; ĐÃ SỬA LOCAL | Flutter trước đây gọi trực tiếp Google/Nominatim và có tùy chọn build `MAPS_API_KEY` | Đã chuyển tra cứu qua endpoint backend có xác thực; frontend không còn Maps key |
| DP-08 | Ảnh Cloudinary | REAL, ĐÃ ĐÓNG KEY Ở BACKEND | Frontend gửi bytes ảnh tới API có xác thực; backend tải lên Cloudinary và DB chỉ lưu URL/object key đã xác nhận | Frontend không nhận API key, signature hay API secret; luồng áp dụng cho ảnh sản phẩm, QR cửa hàng và chứng từ công nợ |
| DP-09 | Google Sign-In | CẤU HÌNH PUBLIC | OAuth Client ID bắt buộc xuất hiện ở client theo giao thức; client secret không được dùng trong Flutter | Đã bỏ Client ID hard-code; build dừng nếu thiếu biến cấu hình public |
| DP-10 | Hóa đơn | ĐÚNG MỘT PHẦN; ĐÃ SỬA LOCAL | Editor mới gửi dòng hàng; backend tự tính subtotal, VAT và tổng tiền, ghi header/items trong transaction | Mỗi cửa hàng 34/35 còn 30 hóa đơn mua thiếu dòng; hóa đơn bán lệch mô hình chiết khấu lần lượt là 268/290; cần kế hoạch backfill riêng |
| DP-11 | Dữ liệu mẫu/faker trong runtime Flutter | KHÔNG PHÁT HIỆN | Quét `lib/` và `backend/src/` không phát hiện faker, random hoặc danh sách nghiệp vụ mẫu; `DUMMY_PASSWORD_HASH` là hằng bảo vệ timing trong đăng nhập, không phải dữ liệu hiển thị | Tiếp tục kiểm tra network/DOM sau deployment |
| DP-12 | API URL | CẤU HÌNH ỨNG DỤNG | Flutter nhận `API_URL` từ build; có fallback URL production hiện hữu | Nên bỏ fallback khi chuẩn hóa quy trình CI để build sai môi trường phải thất bại rõ ràng |
| DP-13 | Giá và thuế đơn bán | ĐÃ SỬA LOCAL | Backend kiểm tra giá gửi lên với giá lẻ/sỉ/khuyến mãi của sản phẩm trong DB; thuế suất lấy từ `products.tax_rate`, phân bổ chiết khấu rồi tự tính lại thuế từng dòng và tổng đơn | Frontend chỉ hiển thị số tạm tính; giao dịch tiền mặt dùng tổng tiền backend xác nhận, không tin `taxAmount` hoặc tổng tiền do client gửi |
| DP-14 | Giỏ giao dịch nháp | ĐÃ SỬA LOCAL | Trước đây tên, giá, thuế, khách hàng và ghi chú được sao chép vào `SharedPreferences` | Đã bỏ lưu cục bộ; giỏ chỉ tồn tại trong bộ nhớ phiên và dữ liệu chính thức chỉ hình thành sau khi backend kiểm tra rồi ghi DB |
| DP-15 | Bút toán thu tiền bán hàng | CODE MỚI ĐÚNG; DỮ LIỆU LỊCH SỬ SAI MỘT PHẦN | Service hiện ghi tiền mặt vào 111, chuyển khoản/QR/thẻ vào 112 và thu công nợ đối ứng 131; đối soát phát hiện 870 đơn ở cửa hàng 34 và 834 đơn ở cửa hàng 35 thiếu/lệch phần thu công nợ ở 112 | Chuẩn bị backfill riêng có snapshot; không tự sửa production trong đợt audit |
| DP-16 | Biểu mẫu và liên kết tham chiếu thuế | ĐÃ SỬA LOCAL; CHỜ NHẬP DB | Hai danh sách trước đây nằm trực tiếp trong widget; frontend mới gọi `/tax-reference-data`, backend đọc `TAX_DECLARATION_FORMS` và `TAX_SUPPORT_LINKS` từ `system_configs` rồi kiểm tra cấu trúc/tên miền | Duyệt và chạy `20260820_seed_tax_reference_data.sql`, sau đó deploy và smoke test |

## 3. Phân loại khóa và cấu hình

| Giá trị | Nơi được phép tồn tại | Có được gửi tới frontend? |
|---|---|---|
| `DATABASE_URL` | Backend environment | Không |
| `ACCESS_TOKEN_SECRET`, `REFRESH_TOKEN_SECRET`, `OTP_SECRET` | Backend environment | Không |
| `GEMINI_API_KEY` | Backend environment | Không |
| `CLOUDINARY_API_SECRET` | Backend environment | Không |
| Cloudinary upload signature | Backend nội bộ | Không |
| `CLOUDINARY_API_KEY` | Backend environment | Không |
| Google OAuth Client ID | Build environment | Có; đây là định danh public, không phải client secret |
| Google OAuth Client Secret | Backend/Google console nếu một flow yêu cầu | Không |

## 4. Quy tắc fail-closed đã áp dụng local

- Thiếu cấu hình thuế hoặc tỷ lệ ngành trong DB: API trả lỗi cấu hình, UI không tự dùng số mặc định.
- Chọn tất cả cửa hàng: AI yêu cầu chọn một cửa hàng cụ thể.
- Thiếu Google Client ID khi build: dừng build thay vì dùng ID hard-code.
- API địa chỉ lỗi: hiển thị không có gợi ý; không gọi dịch vụ bằng key từ frontend.
- Hóa đơn thiếu dòng hoặc số lượng/đơn giá/VAT sai: backend từ chối, không tin tổng tiền client gửi.
- Đơn bán: backend không nhận thuế suất/số thuế do frontend tự tính; giá phải khớp cấu hình sản phẩm trong DB và tổng tiền được tính lại phía server.
- Giỏ nháp không được coi là dữ liệu chính thức và không còn lưu bản sao giá/sản phẩm trong trình duyệt. Muốn hỗ trợ tiếp tục giỏ trên thiết bị khác phải bổ sung API/bảng nháp có migration riêng.
- Tải ảnh: frontend chỉ gửi bytes tới API đã xác thực theo cửa hàng; mọi cấu hình Cloudinary và thao tác với nhà cung cấp lưu trữ nằm trong backend.
- Dữ liệu tham chiếu thuế: thiếu hoặc sai JSON trong DB thì màn hình báo lỗi; frontend không dùng danh sách dự phòng.
- URL hỗ trợ thuế: backend chỉ chấp nhận HTTPS và allowlist tên miền Cục Thuế, không tin URL tùy ý trong DB.

## 5. Bằng chứng kiểm thử local

- Backend build và lint đạt; `113/113` kiểm thử P0 đạt trước khi bổ sung test AI, sau đó test AI được thêm vào bộ P0.
- Flutter analyze các file liên quan đạt, không có cảnh báo.
- Kiểm thử widget editor hóa đơn và kiểm thử điều hướng/khung ứng dụng đạt.
- Backend có 12/12 kiểm thử mục tiêu về giá bán, phân bổ chiết khấu, thuế và hạch toán đạt; Flutter analyze phần ghi nhận bán hàng sạch và kiểm thử tồn kho/thuế tạm tính đạt.
- Luồng ảnh backend build/lint đạt, 16/16 kiểm thử lưu trữ và phân quyền đạt; Flutter analyze đạt và 2/2 kiểm thử provider upload qua backend đạt.
- Truy vấn production chỉ đọc xác nhận `tax_rules` đang trống và hai cấu hình ngưỡng DB đang cũ.
- Chưa chạy migration và chưa deploy thay đổi ngày 13/08/2026.
- Migration tạo snapshot các dòng bị ảnh hưởng trong `configuration_migration_backups` trước khi
  cập nhật, rồi đối soát ngưỡng, nguồn và đủ bốn nhóm tỷ lệ trong cùng transaction.

## 6. Nguồn pháp lý dùng để chuẩn bị migration

- [Nghị định 141/2026/NĐ-CP trên Cổng thông tin Chính phủ](https://vanban.chinhphu.vn/?classid=1&docid=217960&pageid=27160&typegroupid=4).
- Tỷ lệ thuế theo ngành phải được lưu kèm ngày hiệu lực trong `tax_rules`; không coi hằng số trong source là nguồn pháp lý.
