# Danh mục kiểm thử nghiệm thu

> **Cập nhật gate phát hành local, 02/08/2026:** backend build + lint + P0 suite đạt `57/57`,
> audit dependency production không có lỗ hổng; Flutter analyze sạch, toàn bộ `61/61` test và Web release build đạt.
> Production chưa deploy gói sửa này. Migration auth đã được phê duyệt, chạy thành công và
> xác minh ngày 02/08/2026: `refresh_sessions`, `users.auth_version`, `otps.purpose` sẵn sàng;
> 14 OTP thử nghiệm đã được hủy và số OTP đang chờ còn `0`.

> **Bằng chứng hiện có 25/07/2026:** backend P0 suite đạt `28/28` trên local cho
> permission, debt, sales metric, invoice metadata và tax policy. Các test
> Flutter cho reporting period, CSV công nợ và mobile AI/POS đã được bổ sung;
> việc chạy lại toàn bộ Flutter suite bị chặn trước compile do native hook
> `win32` không tìm thấy C++ compiler. Không test local nào thay thế smoke test
> production.

## Test delta bắt buộc trước khi đóng bản vá

| ID | Phạm vi | Điều kiện đạt | Trạng thái hiện tại |
|---|---|---|---|
| TC-RBAC-06 | Role shop A gắn cho member shop B | API từ chối; không cấp quyền chéo shop | Unit test đạt; route/production chưa xác minh |
| TC-RBAC-07 | `x-shop-id` rỗng, số âm, thập phân, chuỗi nhập nhằng | 400, không fallback sang scope rộng | Unit test parser đạt; production chưa xác minh |
| TC-SALE-07 | Dữ liệu có cả `COMPLETED` và `DELIVERED` | Filter completed và summary bao gồm đúng cả hai | Unit/source test đạt; production chưa đối soát |
| TC-ERR-01 | Dashboard API timeout/403/500 | Hiện error/retry, không hiển thị số 0 như dữ liệu thật | Code review; production chưa xác minh |
| TC-DATA-04 | Metadata/route invoice | Một table owner, một route set, CRUD không regression | Metadata test đạt; CRUD production chưa xác minh |
| TC-DATA-06 | Chất lượng dữ liệu hóa đơn | API đếm đúng header thiếu item, lệch header–items và dòng sai công thức theo cửa hàng/kỳ; UI cảnh báo và ghi rõ khoảng kiểm tra | Test chuẩn hóa đạt; audit DB shop 34/35 xác nhận 60 + 558 sai lệch; chưa backfill |
| TC-DATA-07 | Độ mới dữ liệu KPI | API trả ngày phát sinh mới nhất từ DB theo shop/kho; kỳ thiếu dữ liệu hiện cảnh báo, kỳ đủ dữ liệu không chiếm chỗ; 390px không overflow | Unit/widget test local và audit DB shop 34/35 đạt; production chưa deploy |
| TC-DATA-08 | Kỳ danh sách hóa đơn | Mặc định list dùng cùng from/to với KPI VAT; chuyển Toàn bộ bỏ cả hai ngày; loại lọc trước phân trang; cặp ngày thiếu/sai trả 400 | Unit test và audit kỳ 07/08 shop 34/35 đạt; production chưa deploy |
| TC-TAX-06 | Declared < paid, số âm/NaN cũ | Owed = 0; overpaid tách riêng; UI không hiện nghĩa vụ âm | Unit test đạt; production chưa xác minh |
| TC-TAX-07 | MST `0123456789` và biến thể đơn vị phụ thuộc | 422, không tạo XML | Unit test đạt; production chưa xác minh |
| TC-DEBT-04 | API receivable → UI → CSV | KPI lấy toàn bộ DB; danh sách lọc trước phân trang; export đủ toàn bộ tập lọc; tổng còn nợ không âm | Backend/Flutter test và DB read-only đạt; production chưa deploy |
| TC-CSV-01 | Tên có dấu phẩy/nháy và ô bắt đầu `=+-@` | CSV UTF-8 đúng và không thực thi formula | Flutter test đạt; browser production chưa xác minh |
| TC-MOB-01 | POS 390×844 với cart và AI | Checkout không bị nav/AI che | Flutter test đạt; viewport production chưa xác minh |
| TC-PERIOD-01 | Ngày đầu/cuối tháng, tháng 1 | Dashboard/sales/finance dùng cùng from/to | Flutter test đạt; API production chưa đối soát |
| TC-SALE-08 | Client gửi `unitPrice` khác giá/policy backend | Backend từ chối hoặc áp dụng giá hợp lệ; override cần quyền+lý do+audit | Unit test giá bán lẻ/sỉ/khuyến mại và giá sửa trái phép đạt local; override có kiểm soát và production chưa xác minh |
| TC-SALE-09 | Đơn 10 dòng/sản phẩm, hoàn 2 rồi hoàn tiếp 3 | COGS hoàn lần lượt đúng 2 và 3; tổng không vượt COGS đã bán | Summary COGS theo dòng đã sửa và data gate hai shop đạt; service chủ động chặn hoàn một phần, nên test nhiều lần vẫn P0 mở |
| TC-PAGE-01 | 300 sản phẩm/khách/NCC, tìm bản ghi ở trang cuối | UI duyệt/tìm/chọn được đủ; không lặp/mất; filter reset trang | Chưa có test, P0 mở |
| TC-ROUTE-01 | Quét mọi literal `context.go/push` và reload detail URL | Không có path dùng nhưng chưa khai báo; detail tải lại bằng `:id` | Static route registry đạt; reload detail còn cần integration test |
| TC-AUTH-05 | Build metadata và khởi tạo datasource sau auth hardening | Không có cột TypeORM kiểu `Object`; datasource init thành công | Metadata test đạt; migration production và kiểm tra schema độc lập đạt ngày 02/08/2026 |
| TC-INV-07 | Hai request đồng thời tạo/cập nhật cùng tồn SKU/kho | Chỉ một dòng `(shop,warehouse,product)`; quantity cân | Chưa có unique constraint/test |
| TC-RBAC-08 | Menu/router/API cho tax estimate, tax config, logs, AI knowledge | Cùng module/action cho owner/view/edit/none | Hiện mapping không khớp |
| TC-SALE-10 | Mở cùng một đơn từ list, detail và invoice | `customerId/name`, tổng, thanh toán và trạng thái giống nhau | Production sai tên khách; chưa có contract test |
| TC-INV-08 | 300 sản phẩm, nhiều kho, min-stock riêng | KPI tổng dùng server total; low-stock dùng `min_stock`; đổi trang không đổi tổng | Fix local có; production chưa deploy/test |
| TC-DATA-05 | Tạo/import/duyệt chứng từ có quantity 0 hoặc âm | UI/API/DB từ chối; không ghi movement, COGS hoặc tổng | Production còn bản ghi quantity 0; chưa có DB constraint |
| TC-FIN-04 | Sổ chi phí tháng không có dữ liệu nhưng có giao dịch tháng trước | KPI/chart/list/export cùng rỗng; đổi sang tháng trước thì tổng bằng tổng dòng | Logic kỳ và truy vấn recent list đã sửa local; backend P0 57/57 đạt; production chưa deploy/test |
| TC-FIN-05 | Sổ lương tháng 8 với giao dịch ngày 10/07 | Dòng tháng 7 không xuất hiện; header/tổng/list/export cùng `from/to` | Đã lọc tháng + `SALARY` server-side và dùng tổng toàn bộ tập lọc; production chưa deploy/test |
| TC-FIN-06 | Mở chốt ca nhưng chưa nhập tiền thực tế | Hiện “Chưa đối soát”, không tính chênh lệch và không cho khóa | Unit test ô trống/0/sai/âm đạt; production chưa deploy/test |
| TC-ROUTE-02 | Reload/share PO detail và transaction detail | Tải bằng `:id`; id thiếu/sai trả 404 UI; không hiện sửa/xóa khi entity không hợp lệ | Production dựng `PO-null`/`-0 đ` |
| TC-MOB-02 | XNT và ngưỡng thuế ở 390×844/zoom 200% | Đọc đủ cột hoặc card; mốc 900 triệu/1 tỷ không vỡ chữ | Production bị cắt/vỡ nhãn |
| TC-MEDIA-01 | List/detail/form cùng sản phẩm có ảnh; thay ảnh | Cùng ảnh/thumbnail contract; ảnh cũ bị xóa; fallback chỉ khi tải lỗi | Lifecycle unit test đạt; production detail chưa dùng ảnh |
| TC-REP-02 | Một filter áp dụng KPI, chart, bảng và export | Cùng `shop/from/to/status/timezone/asOf`; tổng đối soát bằng dòng | Chưa có metric contract toàn hệ thống |
| TC-TAX-08 | Nghĩa vụ nhiều năm/quý và hành động nộp | Sắp mới→cũ; CTA nói đúng khả năng; chỉ ghi “Nộp” khi có tích hợp/receipt | Production sort sai và CTA chỉ mở disclaimer |

## 1. Tiền điều kiện chung

- Môi trường staging tách production.
- Seed data có hai shop, một owner, một employee theo từng cấp quyền.
- Múi giờ kiểm thử: `Asia/Saigon`.
- Có sản phẩm thường, dưới định mức, hết hàng, quản lý theo lô và không theo lô.
- Có đơn tiền mặt, chuyển khoản, mua thiếu, hoàn một phần và hủy.
- Có bộ expected result do BA/kế toán xác nhận.

## 2. Authentication

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-AUTH-01 | Đăng nhập đúng/sai, tài khoản inactive | Đúng trả token + shops; sai/inactive trả 401, không lộ stack/secret |
| TC-AUTH-02 | OTP đúng, sai, hết hạn, dùng lại, gửi nhiều lần | Chỉ OTP đúng/còn hạn/dùng một lần tạo tài khoản; có rate limit |
| TC-AUTH-03 | Access hết hạn, refresh hợp lệ/hết hạn/bị revoke | Rotation đúng; token cũ không tái dùng; UI xử lý logout rõ |
| TC-AUTH-04 | Đổi mật khẩu khi có nhiều phiên | Phiên theo chính sách bị thu hồi; audit log được ghi |

## 3. RBAC và shop scope

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-RBAC-01 | User A gửi shopId của shop không thuộc về | 403 ở mọi endpoint shop-scoped |
| TC-RBAC-02 | Employee có `view`, `edit`, `none` theo module | View chỉ đọc; edit ghi đúng phạm vi; none nhận 403 |
| TC-RBAC-03 | Employee gửi `x-shop-id: all` | Không nâng quyền; chỉ tổng hợp shop được phép và đúng permission |
| TC-RBAC-04 | Owner đổi role của chính mình/chủ cuối cùng | Bị chặn theo rule tránh shop mất owner |
| TC-RBAC-05 | Customer/supplier/tag/tax-config | Kiểm tra đủ owner/view/edit/none ở API, không chỉ ẩn menu |

## 4. Bán hàng, thanh toán, hoàn/hủy

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-SALE-01 | Bán 2 mặt hàng tiền mặt | Một đơn, đúng item/tổng/thuế; tồn giảm; sổ quỹ tăng; audit có correlation ID |
| TC-SALE-02 | Thanh toán hỗn hợp tiền mặt + chuyển khoản + nợ | Tổng payment = tổng đơn; từng nguồn vào đúng account; receivable bằng phần thiếu |
| TC-SALE-03 | Hoàn một phần rồi retry callback | Tồn/tiền/công nợ đảo đúng một lần; retry không nhân đôi |
| TC-SALE-04 | Hủy đơn trước/sau thanh toán | Rule trạng thái rõ; không để movement/payment mồ côi |
| TC-SALE-05 | So sánh summary và list theo 4 trạng thái/cùng `from–to` | API list yêu cầu đủ hai đầu kỳ; số đơn không hủy bằng `PENDING + CONFIRMED + COMPLETED/DELIVERED`; cộng `CANCELLED` bằng tổng bảng; doanh thu, giá vốn, lợi nhuận và biểu đồ ngày khớp sổ cái |
| TC-SALE-06 | Ghi nhận giao dịch bán ở 390×844 | Tìm hàng, thêm giỏ, chọn khách, thanh toán và thấy kết quả không bị che |
| TC-SALE-11 | Chọn “Tất cả cửa hàng”, tải/lọc/phân trang danh sách và mở một đơn | Tổng dòng bằng tổng các shop được cấp quyền; không có dòng ngoài phạm vi; hiện đúng tên cửa hàng từ DB; không cho tạo mới trong chế độ tổng hợp; trước khi mở chi tiết phải chuyển về shop của đơn |
| TC-SALE-12 | Top 10 sản phẩm kỳ hiện tại so với kỳ trước | Thứ hạng, doanh thu thuần sau hoàn, số lượng, giá vốn, biên lãi và tăng trưởng khớp truy vấn DB độc lập; API phân biệt `COMPARABLE/NEW/NO_BASE`; UI ghi rõ kỳ so sánh và không tự tính lại phần trăm |
| TC-SALE-13 | Import dữ liệu lịch sử không theo thứ tự rồi mở Dashboard/Danh sách bán hàng | API sắp `orderDate DESC, id DESC`; UI hiện ngày giao dịch; 20 dòng đầu khớp SQL độc lập; thẻ tóm tắt không cung cấp hành động xuất dữ liệu thiếu |

## 5. Kho và giá vốn

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-INV-01 | Sản phẩm dưới min stock ở một hoặc nhiều kho | API trả một dòng/cửa hàng+sản phẩm, cộng tổng tồn các kho rồi so với `min_stock`; Dashboard và Kho cùng số lượng/danh sách; UI ghi rõ tổng tồn và số kho |
| TC-INV-02 | Nhận PO có phí mua hàng | Tồn/lô tăng; landed cost phân bổ đúng; journal/movement liên kết PO |
| TC-INV-03 | Kiểm kê thừa/thiếu | Chênh lệch cần duyệt; movement có actor/reason; tồn cuối đúng |
| TC-INV-04 | Báo cáo XNT | `tồn đầu + nhập - xuất ± điều chỉnh = tồn cuối` cho từng SKU/lô |
| TC-INV-05 | Bán/hoàn theo FIFO hoặc bình quân | COGS đúng cấu hình và đảo đúng khi hoàn |
| TC-INV-06 | Hai request bán đồng thời gần hết tồn | Không âm tồn hoặc oversell ngoài rule |
| TC-INV-13 | Đối chiếu tồn–lô–COGS và chạy hai giao dịch cùng tiêu thụ một lô | Từng SKU có tổng tồn bằng tổng lô; header COGS bằng tổng dòng; không có giá vốn 0; giao dịch không trừ được lô phải rollback; kiểm kê chênh lệch cập nhật cả tồn, lô và bút toán theo policy đã duyệt |

## 6. Tài chính và công nợ

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-FIN-01 | Đối chiếu cash account, transactions và dashboard | Số dư đầu + thu - chi = cuối; cùng `asOf` cho kết quả giống nhau |
| TC-FIN-02 | P&L có sale, COGS, expense, return | Lợi nhuận khớp expected result; không trộn tiền mặt với doanh thu dồn tích |
| TC-FIN-03 | Đổi khoảng thời gian/timezone | Giao dịch biên ngày chỉ thuộc đúng một kỳ |
| TC-DEBT-01 | Tạo đơn mua thiếu | Receivable thật xuất hiện; không có bản ghi mẫu |
| TC-DEBT-02 | Thu nợ một phần/toàn bộ | Còn nợ, payment history và sổ quỹ cập nhật trong một transaction |
| TC-DEBT-03 | Xuất Excel nợ | Số dòng, tổng nợ/đã trả/còn nợ khớp API và có kỳ xuất |
| TC-DEBT-05 | Đối soát tuổi nợ theo ngày | Tổng phải thu bằng tổng bốn nhóm; số khoản/khách và từng bucket khớp SQL độc lập theo cùng `asOf` |

## 7. Thuế và báo cáo

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-TAX-01 | Kỳ trước/sau ngày hiệu lực rule | Chọn đúng phiên bản rule; UI hiển thị nguồn và ngày hiệu lực |
| TC-TAX-02 | Doanh thu/lợi nhuận âm, 0, dương | Không tạo nghĩa vụ âm; trạng thái thiếu dữ liệu rõ |
| TC-TAX-03 | Xuất XML với bộ fixture | Pass XSD/validator và import HTKK đúng phiên bản |
| TC-TAX-04 | Thiếu/sai MST hoặc hồ sơ | Chặn xuất; chỉ rõ trường cần sửa; không dùng fallback |
| TC-TAX-05 | Export cùng dữ liệu hai lần | Nội dung deterministic hoặc metadata biến đổi được mô tả; có checksum/audit |
| TC-TAX-09 | Cùng shop/kỳ giữa báo cáo thuế và tổng hợp bán hàng | Doanh thu tháng/năm sau hoàn khớp tuyệt đối; không tải toàn bộ đơn vào bộ nhớ; thiếu policy DB phải fail rõ, không dùng ngưỡng hard-code |
| TC-REP-01 | Excel/XML với dataset lớn và ký tự Việt | Không mất dòng, không lỗi encoding, tổng kiểm soát khớp |

## 8. Dữ liệu, migration và API

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-DATA-01 | Khởi tạo metadata TypeORM | Không trùng tên bảng/entity owner; không trùng route shadow |
| TC-DATA-02 | Chạy migration mới/rollback trên bản sao staging | Có checksum, idempotency theo thiết kế, không mất dữ liệu |
| TC-DATA-03 | Cold start Vercel | Chỉ kết nối DB; không chạy DDL; request đầu trong SLA |
| TC-API-01 | Validation sai và not-found | Dùng 400/404 phù hợp, response contract thống nhất |
| TC-API-02 | Lỗi server | Không lộ stack, SQL, token, secret hoặc PII nhạy cảm |
| TC-DATA-04 | Tắt/làm lỗi API giá vốn, thông báo, AI và ảnh | UI hiện loading/error/retry; không biến lỗi thành AVG, số 0, dữ liệu rỗng hoặc dữ liệu mẫu; Flutter không chứa secret backend |
| TC-DATA-05 | Membership DB lỗi hoặc yêu cầu chuyển tới shop ID không thuộc tài khoản | Không cấp phiên mới khi context shop lỗi; UI hiện lỗi DB; giữ nguyên shop hiện tại, không rơi về shop đầu |
| TC-DATA-06 | Tồn master đủ nhưng tổng lô thiếu khi ghi nhận bán | Backend từ chối và rollback toàn bộ đơn/tồn/sổ cái; không bù giá từ master sản phẩm |
| TC-DATA-07 | API sales/kho/tài chính/sản phẩm/nhãn/tìm shop lỗi hoặc trả sai cấu trúc | UI hiện lỗi tải dữ liệu; không hiển thị như danh sách DB rỗng; retry gọi lại API |
| TC-DATA-08 | Tổng dòng hóa đơn bán cao hơn header đúng bằng chiết khấu đơn gốc | Phân loại “chiết khấu chưa phân bổ vào dòng”; không gộp vào sai lệch tiền hàng chưa giải thích; vẫn giữ trạng thái cần xử lý dữ liệu |
| TC-DATA-09 | Response summary thiếu doanh thu/lợi nhuận/dòng tiền/kỳ hoặc biểu đồ | Provider trả lỗi dữ liệu không đầy đủ; UI không dựng KPI 0 từ trường bị thiếu |
| TC-DATA-10 | Response tồn kho thiếu `productTotal` hoặc ABC thiếu trường đối soát/kỳ | Màn Kho hiện lỗi dữ liệu; không dùng số dòng trang đầu hoặc số 0 thay cho tổng DB |
| TC-DATA-11 | Response khách hàng/nhà cung cấp/công nợ thiếu metadata, tổng tiền, nhóm tuổi nợ hoặc danh sách | UI hiện lỗi tải từ DB và cho thử lại; không hiển thị “chưa có dữ liệu” hoặc KPI 0 giả |
| TC-DATA-12 | Response giao dịch/nhóm chi/hóa đơn/chốt ngày thiếu metadata, tổng hoặc danh sách | Provider trả lỗi; không dựng bảng/biểu đồ rỗng giả; lịch sử chốt ngày trả đủ `totalPages` |
| TC-DATA-13 | Chuỗi ngày bán hàng thiếu doanh thu, giá vốn, lợi nhuận, biên lãi hoặc số đơn | Provider trả lỗi; không dựng biểu đồ từ số 0. Khi đủ dữ liệu, tổng chuỗi ngày khớp tổng kỳ; mỗi ngày doanh thu ở cột trái, lợi nhuận gộp ở cột phải và hỗ trợ giá trị âm |
| TC-TAX-10 | Shop thiếu hoặc có `businessSector` ngoài danh mục backend | Chặn tải cấu hình thuế và hiện lỗi; không tự chọn ngành thương mại hoặc tiếp tục tính thuế |
| TC-FIN-11 | Chốt ngày có chênh lệch, thiếu tài khoản CASH hoặc lỗi ghi sổ | Phiếu chốt, giao dịch, journal và số dư cùng rollback; không lưu trạng thái một phần |

## 9. UX, responsive và accessibility

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-UX-01 | API chậm/rỗng/4xx/5xx ở 8 màn chính | Loading, empty, error và retry rõ; không treo/blank |
| TC-UX-02 | 390×844, 768×1024, 1440×900 | Không overflow/cắt CTA; FAB/nav không che nội dung |
| TC-UX-03 | Keyboard-only và focus | Thứ tự focus hợp lý, thao tác chính dùng được, focus visible |
| TC-UX-04 | Screen reader và semantic labels | Icon/button/input có tên; thay đổi trạng thái được thông báo |
| TC-UX-05 | Zoom 200% và contrast | Không mất nội dung/chức năng; contrast đạt chuẩn đã chọn |

Chỉ ghi `Accessibility đạt` sau khi TC-UX-03 đến TC-UX-05 được thực hiện bằng công
cụ và thiết bị hỗ trợ phù hợp.

## 10. AI và audit

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-AI-01 | Hỏi thông tin thuế có nguồn còn/đã hết hiệu lực | Chỉ dùng nguồn được duyệt; có citation; nguồn hết hiệu lực bị loại |
| TC-AI-02 | Không có nguồn đủ tin cậy | Trả “chưa đủ dữ liệu”, không bịa hoặc khẳng định pháp lý |
| TC-AI-03 | Gỡ tài liệu | Tài liệu không còn được retrieval; có audit |
| TC-AI-04 | DB lỗi/rỗng và nhân viên thiếu/có quyền settings truy cập kho AI | Lỗi không biến thành số 0/rỗng; có retry; doanh thu dùng cùng SalesService; view/edit bị chặn đúng cấp; không lộ key ra frontend |
| TC-AUD-01 | Sale/return/stock/role/tax export | Log đủ actor/shop/action/time/correlation, redaction dữ liệu nhạy cảm |

## 11. Điều kiện đóng phiên bản

- P0 không còn test fail hoặc finding mở.
- Build, lint và automated tests chạy trong CI.
- Smoke test production không làm thay đổi dữ liệu ngoài kịch bản được duyệt.
- Verification report và traceability matrix được cập nhật bằng bằng chứng mới.
- Người phụ trách nghiệp vụ và chuyên gia thuế duyệt các công thức liên quan.

## 12. Kiểm thử công nợ phải trả nhà cung cấp

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-FIN-08 | Khoản phải trả chưa thanh toán, trả một phần, đã trả và đã hủy | Chỉ tính phần còn lại dương; loại `PAID/CANCELLED`; tổng KPI bằng tổng 4 nhóm tuổi nợ và tổng dòng mở |
| TC-FIN-09 | Hạn đúng ngày chốt, quá hạn 30, 60 và 61 ngày | Lần lượt thuộc `chưa hạn`, `1–30`, `31–60`, `>60`; chốt theo cuối ngày nghiệp vụ Việt Nam |
| TC-FIN-10 | Người dùng chuyển cửa hàng hoặc chọn “Tất cả cửa hàng” | API và mọi KPI/bảng chỉ trả dữ liệu thuộc shop đơn đang chọn; không rò dữ liệu giữa các shop; chế độ tổng hợp bị từ chối thay vì chạy với `shopId` rỗng |
| TC-UX-06 | Báo cáo phải trả ở 1440×900 và 390×844 | Desktop có bảng đầy đủ; mobile dùng card; đơn vị đồng và ngày quá hạn đọc rõ; không overflow hoặc lỗi console |
