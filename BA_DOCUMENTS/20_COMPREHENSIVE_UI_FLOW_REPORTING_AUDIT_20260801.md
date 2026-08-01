# Audit tổng thể UI, luồng và hệ thống báo cáo — 01/08/2026

## 1. Kết luận điều hành

SmartStock đã có phạm vi chức năng rộng, app shell tương đối nhất quán và phần lớn màn hình đã
dùng API thay vì dữ liệu mẫu tại giao diện. Tuy nhiên hệ thống chưa nên được coi là hoàn thiện cho
cửa hàng có vài trăm sản phẩm vì bốn nhóm vấn đề ảnh hưởng trực tiếp đến tính đúng và khả năng vận hành:

1. Nhiều danh sách chỉ tải trang đầu tiên (mặc định 20 dòng) nhưng không có điều khiển chuyển
   trang hoặc tải tiếp. Người dùng có thể không nhìn thấy phần lớn sản phẩm, khách hàng, nhà cung
   cấp, hóa đơn và giao dịch.
2. Giá vốn hàng hoàn trong báo cáo bán hàng có khả năng trừ toàn bộ giá vốn của đơn cho một lần
   hoàn một phần. Lợi nhuận gộp vì vậy có thể bị thổi phồng.
3. Báo cáo sản phẩm bán chạy đang xếp theo doanh thu và số lượng bán gộp, chưa trừ hàng hoàn.
   Nhãn “bán chạy” hiện không đồng nghĩa với doanh thu thuần hoặc số lượng thuần.
4. Đối soát 24 quy tắc phát hiện 60 hóa đơn đầu vào không có dòng hàng và 558 hóa đơn bán không
   tự cân bằng giảm giá vì schema invoice thiếu `discount_amount`.

Ưu tiên đúng là sửa tính toàn vẹn dữ liệu và khả năng truy cập toàn bộ bản ghi trước, sau đó mới
tăng độ nổi bật của card, biểu đồ và hiệu ứng.

## 2. Phạm vi và bằng chứng

| Nguồn | Kết quả | Trạng thái |
|---|---|---|
| Production `smartstock-tax.vercel.app` | Chụp 10 trạng thái public ở desktop/mobile: đăng nhập, đăng ký, quên mật khẩu, validation và auth redirect | Đã xác minh |
| Production sau đăng nhập | 47 route protected mở đúng, không redirect login; 48/48 API đọc đạt; ảnh canvas protected vẫn bị timeout | Đã xác minh route/API, bị chặn ảnh |
| Frontend Flutter | Kiểm kê 57 file màn hình và hơn 50 route | Đã xác minh từ code |
| Backend Express/TypeORM | Đối chiếu route, service và công thức tổng hợp | Đã xác minh từ code |
| Bộ test backend P0 | Build/lint và 47/47 test đạt | Đã xác minh |
| Flutter analyze/test/build | Analyze sạch, 57/57 test đạt, Web release build thành công | Đã xác minh local |
| Kiểm toán dữ liệu DB | 24 quy tắc chạy chỉ đọc trên hai shop; 21 đạt, 2 lỗi invoice và 1 cảnh báo freshness mỗi shop | Đã xác minh, còn lỗi P0 |
| Accessibility | Chưa chạy keyboard, screen reader, contrast và zoom chuyên biệt | Chưa xác minh |

Ảnh được chấp nhận trong vòng đánh giá hiện tại:

- [01 — Đăng nhập desktop](screenshots/20260801-production-audit-run2/01-login-desktop.png)
- [02 — Đăng nhập mobile](screenshots/20260801-production-audit-run2/02-login-mobile.png)
- [03 — Đăng ký mobile](screenshots/20260801-production-audit-run2/03-register-mobile.png)
- [04 — Đăng ký desktop](screenshots/20260801-production-audit-run2/04-register-desktop.png)
- [05 — Quên mật khẩu mobile](screenshots/20260801-production-audit-run2/05-forgot-password-mobile.png)
- [06 — Quên mật khẩu desktop](screenshots/20260801-production-audit-run2/06-forgot-password-desktop.png)
- [07 — Validation đăng nhập mobile](screenshots/20260801-production-audit-run2/07-login-validation-mobile.png)
- [08 — Validation đăng ký mobile](screenshots/20260801-production-audit-run2/08-register-validation-mobile.png)
- [09 — Validation quên mật khẩu mobile](screenshots/20260801-production-audit-run2/09-forgot-password-validation-mobile.png)
- [10 — Auth redirect desktop](screenshots/20260801-production-audit-run2/10-inventory-auth-redirect-desktop.png)

Không sử dụng ảnh chụp lỗi responsive hoặc ảnh chưa tải ổn định làm bằng chứng.

Khung KPI, benchmark hệ thống lớn, blueprint bảng/report và grain dữ liệu mục tiêu nằm tại
[KPI, report, table và data benchmark](23_KPI_REPORT_TABLE_AND_DATA_BENCHMARK_20260801.md).
Ma trận triển khai từ source cho toàn bộ 59 file màn hình nằm tại
[Ma trận thành phần và triển khai giao diện](24_SCREEN_COMPONENT_IMPLEMENTATION_MATRIX_20260801.md).

## 3. Đánh giá theo hành trình

| Bước | Hành trình | Sức khỏe | Nhận xét chính |
|---:|---|---|---|
| 1 | Đăng nhập | Đúng một phần | Bố cục hai cột rõ; submit rỗng vẫn gọi API rồi hiện lỗi chung, chưa có validation từng trường |
| 2 | Khôi phục phiên | Đúng một phần | Bản production vẫn cần kiểm thử refresh token đồng thời; bản local đang thay đổi cơ chế auth |
| 3 | Chọn cửa hàng / tất cả cửa hàng | Đúng một phần | API tổng hợp hỗ trợ nhiều shop ở một số endpoint, nhưng không phải mọi báo cáo đều hỗ trợ cùng phạm vi |
| 4 | Dashboard | Đúng một phần | Có kỳ so sánh, top 10, ưu tiên nghiệp vụ; quyền `finance` đang chi phối phần lớn KPI doanh thu |
| 5 | Lịch sử bán hàng | Đúng một phần | Bộ lọc đã đặt đúng trong khối danh sách; không có phân trang thực tế dù state `_page` đã tồn tại |
| 6 | POS | Đúng một phần | Có tìm kiếm server; danh mục mặc định chỉ nạp trang đầu nên duyệt hàng hóa chưa đầy đủ |
| 7 | Sản phẩm | Không chính xác với dữ liệu lớn | UI cố định `page: 1`, backend mặc định 20; vài trăm sản phẩm không thể duyệt hết |
| 8 | Khách hàng | Không chính xác với dữ liệu lớn | Cố định trang 1; thiếu phân trang/tải tiếp |
| 9 | Nhà cung cấp | Không chính xác với dữ liệu lớn | Cố định trang 1; thiếu phân trang/tải tiếp |
| 10 | Kho / kiểm kê / nhập hàng | Đúng một phần | Cảnh báo lấy API thật; form chọn sản phẩm/nhà cung cấp có nguy cơ chỉ thấy 20 dòng đầu |
| 11 | Xuất–nhập–tồn | Khá | Có bảng tổng hợp và khoảng ngày; cần thêm giá trị tồn và đối chiếu sổ kho |
| 12 | Tài chính | Đúng một phần | KPI và biểu đồ lấy API; cần khóa định nghĩa “số dư quỹ” và “dòng tiền thuần” |
| 13 | Công nợ | Khá | Có bảng, aging và xuất CSV; cần lịch sử thu nợ, chứng từ và tổng kiểm soát theo bộ lọc |
| 14 | Thuế | Đúng một phần | Có cấu hình và XML; chưa thể coi XML đạt chuẩn nếu chưa import thành công vào HTKK |
| 15 | Cài đặt / RBAC | Đúng một phần | Phạm vi rộng; hai route nhân viên trùng mục đích và ma trận quyền khó quét trên mobile |
| 16 | Trợ lý AI | Đúng một phần | Đã giảm che khuất; dữ liệu trả lời cần luôn kèm nguồn, kỳ và cửa hàng đang áp dụng |

### Nhận xét trực quan luồng public

- Đăng nhập desktop có phân cấp tốt hơn các màn public còn lại; bản mobile co giãn đúng và CTA đủ rõ.
- Đăng ký và quên mật khẩu desktop dùng form hẹp kiểu mobile ở giữa vùng trống rất lớn, làm giao diện
  thiếu ngữ cảnh, kém cân bằng và không tận dụng màn hình rộng.
- Production còn nút Facebook nhưng bản local đã bỏ; đây là chênh lệch phiên bản cần kiểm lại sau deploy.
- Production ghi “Email hoặc số điện thoại” ở quên mật khẩu trong khi backend auth local chỉ chấp nhận
  Gmail. Nội dung UI và contract auth phải dùng một định nghĩa.
- Lỗi đăng nhập tồn tại khi điều hướng sang route bảo vệ rồi quay về `/login`; provider chưa xóa error khi
  người dùng nhập lại hoặc khi router chuyển màn.
- Flutter canvas trong ảnh chỉ công bố nút “Enable accessibility”; chưa đủ bằng chứng để kết luận keyboard,
  focus, screen reader, contrast hoặc zoom đạt chuẩn.

## 4. Phát hiện tính đúng dữ liệu và code

### P0-01 — Giá vốn hoàn một phần có thể bị trừ sai

Trong `SalesService.summary`, tổng giá vốn hoàn đang cộng `total_cogs` của toàn bộ đơn cho mỗi bản
ghi hoàn hàng. Với hoàn một phần hoặc nhiều lần hoàn, giá vốn hoàn có thể lớn hơn giá vốn thực tế.

**Ảnh hưởng:** lợi nhuận gộp, dashboard, báo cáo bán hàng và quyết định giá có thể sai.

**Hướng sửa:** tính giá vốn hoàn từ `sales_return_items` và giá vốn đơn vị/lô thực tế của từng dòng;
đặt ràng buộc tổng số lượng hoàn không vượt số lượng đã bán.

**Nghiệm thu:** đơn 10 sản phẩm, hoàn 2 sản phẩm chỉ hoàn đúng giá vốn của 2 sản phẩm; hoàn nhiều lần
không làm tổng giá vốn hoàn vượt giá vốn đơn.

### P0-02 — Danh sách không hiển thị hết dữ liệu

Các màn sản phẩm, khách hàng, nhà cung cấp, hóa đơn và nhiều màn giao dịch gọi provider với
`page: 1`. Backend giới hạn mặc định 20 dòng. Sales có state `_page` nhưng chưa có điều khiển đổi
trang. Form kiểm kê và nhập hàng cũng phụ thuộc danh sách trang đầu.

**Ảnh hưởng:** dữ liệu vẫn có trong DB nhưng người dùng tưởng bị mất; không thể kiểm kê hoặc chọn
đủ hàng hóa.

**Hướng sửa:** chuẩn hóa một `PagedResult<T>` và một `AppPagedTable/AppInfiniteList`; tìm kiếm phải
thực hiện ở server; hiển thị tổng bản ghi và trang hiện tại.

**Nghiệm thu:** cửa hàng có 300 sản phẩm có thể duyệt, tìm và chọn đủ 300; thay đổi bộ lọc đưa về
trang 1; không lặp hoặc bỏ dòng khi tải tiếp.

### P0-03 — Metadata auth đã sửa local; production chưa có migration tương ứng

Các cột nullable của `User` đã khai báo rõ kiểu PostgreSQL và regression test metadata đã đạt.
Kiểm tra schema chỉ đọc cho thấy production vẫn chưa có `refresh_sessions`, `google_subject`,
`email_verified` và trường purpose của OTP.

**Ảnh hưởng:** nếu deploy backend auth mới trước migration/cấu hình secret, backend có thể không khởi động
hoặc lỗi truy vấn cột chưa tồn tại.

**Hướng xử lý phát hành:** sao lưu DB, cấu hình ba secret khác nhau, chạy migration có kiểm soát rồi
smoke test cold-start, login, OTP, refresh và logout trước khi chuyển production.

### P0-13 — KPI tổng sản phẩm ở Kho chỉ đếm trang đầu

Endpoint `/inventory/stock` trả `PagedResult` với giới hạn mặc định 20. `stockProvider` bỏ các trường
`total/page/totalPages` và chỉ trả `items`; `_InventoryMetricStrip` lại dùng `items.length`. Vì vậy cửa hàng
có 250 sản phẩm vẫn hiển thị “Tổng sản phẩm: 20”.

**Ảnh hưởng:** dashboard kho hiển thị sai quy mô tồn, người dùng có thể tin rằng dữ liệu đã mất.

**Hướng sửa:** tạo endpoint summary riêng hoặc giữ `PagedResult` trong provider và dùng `total`; đồng thời
không dùng danh sách trang đầu để tính KPI.

**Nghiệm thu:** DB có 250 sản phẩm thì KPI là 250 ở mọi trang; đổi kho/cửa hàng cập nhật đúng; tổng không
thay đổi khi chuyển trang danh sách.

**Trạng thái local:** đã sửa để giữ metadata phân trang và dùng `total`; unit test hồi quy và analyze đạt.

### P0-14 — Cảnh báo “Dưới định mức” dùng sai ngưỡng

Frontend cũ luôn gọi `/inventory/low-stock?threshold=10`, trong khi nhãn UI là “Dưới định mức”. Đối soát
production cho thấy shop 34 có 112 dòng `≤10` nhưng 0 dòng dưới `products.min_stock`; shop 35 tương ứng
24 và 0. Vì vậy cảnh báo đúng về phép so sánh nhưng sai ý nghĩa nghiệp vụ được trình bày.

**Trạng thái local:** provider mặc định không gửi threshold để backend dùng định mức từng sản phẩm. Nếu
cần ngưỡng cố định, phải là filter có nhãn và cấu hình rõ.

### P1-01 — Top sản phẩm chưa phải số liệu thuần

`getTopProducts` dùng tổng `sales_order_items.subtotal` và `quantity`, loại đơn hủy nhưng không trừ
`sales_return_items`. Sản phẩm bị hoàn vẫn được tính đủ doanh thu và số lượng bán.

**Hướng sửa:** trả đồng thời `grossQuantity`, `returnedQuantity`, `netQuantity`, `grossRevenue`,
`returnRevenue`, `netRevenue`; cho người dùng chọn xếp theo số lượng thuần hoặc doanh thu thuần.

### P1-02 — Trạng thái đơn đang trộn thanh toán và xử lý đơn

POS tạo đơn đủ tiền với trạng thái `DELIVERED`, chưa đủ tiền với `PENDING`. UI lại gọi `PENDING`
là “Chờ xử lý”, trong khi đó có thể chỉ là đơn bán chịu. `CONFIRMED` hầu như không xuất hiện trong
luồng tạo đơn hiện tại.

**Hướng sửa:** tách `fulfillmentStatus`, `paymentStatus` và `returnStatus`. Không dùng một cột để
diễn tả cả giao hàng và thanh toán.

### P1-03 — Giá trị tồn kho chưa cùng phương pháp giá vốn

Phân bổ tồn theo danh mục tính `quantity × products.cost_price`. Nếu cửa hàng dùng AVG/FIFO và giá
nhập thay đổi, số này có thể lệch với giá trị tồn từ lô hoặc sổ cái.

**Hướng sửa:** dùng chung valuation service với phương pháp giá vốn đang cấu hình; trả thêm
`valuationMethod` và thời điểm chốt dữ liệu.

### P1-04 — Xuất “Excel” thực tế là CSV và có thể chỉ xuất phần đang tải

Service xuất file tạo CSV tương thích Excel. Một số điểm xuất nhận trực tiếp danh sách đang hiển
thị/recent list, không có endpoint export toàn bộ tập kết quả theo bộ lọc.

**Hướng sửa:** đặt tên đúng “CSV” hoặc tạo XLSX thật; export phải chạy server-side/stream theo bộ
lọc và ghi tổng số dòng, kỳ, cửa hàng, múi giờ, đơn vị tiền.

### P1-05 — Hai CTA đã được sửa local; deep-link detail còn chưa hoàn chỉnh

- Router đã khai báo `/purchase-orders/form`.
- Chi tiết đơn đã dùng `/sales/returns/:id`; static route registry test đạt.

Phần còn lại là route chi tiết phiếu trả, đơn nhập và giao dịch vẫn phụ thuộc `state.extra`, nên
refresh/deep-link có thể mất dữ liệu. Chi tiết và ma trận nghiệm thu nằm tại
[Ma trận chụp toàn bộ production](21_PRODUCTION_SCREEN_CAPTURE_MATRIX_20260801.md).

### P1-06 — Quyền route frontend không khớp quyền API backend

Đối chiếu guard frontend và middleware backend cho thấy:

- `/tax-estimate` không được frontend xếp vào nhóm `finance`, nhưng API `/tax/estimate` yêu cầu
  `finance:view`;
- `/activity-logs` và `/settings/ai-knowledge` không có guard tương ứng ở frontend, nhưng API yêu
  cầu quyền `settings`;
- `/tax-config` được frontend gắn với quyền `settings`, trong khi hai endpoint cấu hình thuế backend
  yêu cầu quyền `finance`.

Backend vẫn chặn request nên chưa có bằng chứng lộ dữ liệu, nhưng người dùng có thể vào màn rồi gặp
403 hoặc bị frontend chặn dù API cho phép. Cần tạo một route-policy duy nhất dùng chung cho menu,
router và contract test API.

### P1-07 — Sổ công nợ tải toàn bộ dữ liệu nhưng bảng không có phân trang

`/customer-receivables` trả toàn bộ khoản đang mở; shop 34 hiện có 453 khoản mở (hơn 1.300 bản ghi
receivable lịch sử trong DB).
Frontend dựng toàn bộ dòng trong `AppDataTable`, không sort, không phân trang, không virtualize và export
trực tiếp danh sách đã tải.

**Ảnh hưởng:** tải chậm, cuộn dài, tốn bộ nhớ trình duyệt và khó kiểm soát tổng theo bộ lọc.

**Hướng sửa:** phân trang server, lọc theo khách hàng/hạn nợ/trạng thái, sticky header; mobile dùng card
tóm tắt; export server-side theo đúng tập lọc.

## 5. Đánh giá giao diện và hệ thống thiết kế

### Điểm nên giữ

- `AppPageHeader`, `AppResponsiveContent`, `AppFillGrid`, `AppKpiCard` và các trạng thái
  loading/empty/error là nền tảng đúng.
- Bộ lọc bán hàng đã được đặt trong khối “Danh sách đơn hàng” và có mô tả phạm vi, tránh hiểu nhầm
  lọc cả biểu đồ.
- Hành động chính đã tách khỏi header: mobile đặt góc trên, desktop dùng floating action.
- Top sản phẩm đã chuyển sang thanh ngang, có số lượng và doanh thu, phù hợp tên sản phẩm dài.
- Các biểu đồ tiền tệ đã có format Việt Nam và tooltip có đơn vị ở component dùng chung.

### Điểm cần cải thiện

- Typography đang trộn Outfit, Inter, Manrope và JetBrains Mono tại cấp màn/component. Chỉ nên dùng
  một font UI và một font số liệu tabular; không để từng màn tự chọn font.
- Mã nguồn còn 410 lần dùng icon thư viện trực tiếp so với 121 lần dùng asset icon.
  Navigation chính đã dùng asset nhưng ngôn ngữ hình ảnh trong form, empty state và dashboard chưa
  đồng nhất với yêu cầu thương hiệu.
- Nhiều màn desktop vẫn dùng card/list thay cho bảng có header cố định, sắp xếp, chọn cột và phân
  trang. Điều này phù hợp mobile nhưng không hiệu quả cho nghiệp vụ nhập liệu khối lượng lớn.
- Một số chart card có chiều cao cố định; ở mobile cần ưu tiên vùng biểu đồ, giảm padding và không
  thu nhỏ toàn bộ canvas.
- Nhãn đơn vị phải nằm ở tiêu đề trục hoặc header cột. Tooltip phải dùng cùng đơn vị và cách làm
  tròn với trục; không hiển thị số nguyên thô khi trục dùng “triệu đồng”.

### Kiểm kê component dùng chung

| Thành phần | Hiện trạng đã xác minh | Khoảng trống cần xử lý |
|---|---|---|
| `AppPageHeader` | Chỉ xuất hiện ở 9 điểm gọi | Phần lớn màn vẫn tự dựng `AppBar`/header nên khoảng cách, hành động và typography không đồng nhất |
| Hướng dẫn nghiệp vụ | Có 35 điểm gọi `featureGuideButton` | Cần ma trận màn nào bắt buộc có hướng dẫn; không thêm icon hướng dẫn theo cảm tính |
| `AppPrimaryFloatingAction` | Có 7 điểm gọi; component luôn là nút extended | Chưa tự chuyển thành action gọn trên header mobile và FAB dưới-phải desktop theo yêu cầu |
| `AppDataTable` | Có header, zebra row và cuộn ngang mobile | Chưa có sort, phân trang, chọn dòng, sticky header, chọn cột hoặc tổng theo tập lọc; mobile bị ép bảng rộng 650 px |
| List/bảng nghiệp vụ | 43 điểm dùng `ListView`, chỉ 3 điểm có cấu trúc table | Card/list phù hợp mobile nhưng thiếu mật độ và thao tác hàng loạt cho desktop |
| Biểu đồ | 7 bar, 4 line và 4 pie | Chưa đủ báo cáo waterfall, đối soát, aging/ABC và pivot; cần ưu tiên biểu đồ theo quyết định nghiệp vụ |
| Typography | Outfit, Inter, Manrope và JetBrains Mono cùng tồn tại | Chuẩn hóa một font UI; chỉ dùng số tabular trong KPI/cột tiền, tránh dashboard có giọng chữ riêng |
| Icon/asset | 410 lần icon thư viện, 121 lần asset/icon thương hiệu | Lập mapping ngữ nghĩa theo module; logo/linh vật chỉ dùng cho thương hiệu và trợ lý AI |

### Quyết định component mục tiêu

1. Tạo `AppScreenScaffold` điều phối header, guide, primary action, AI safe-area và breakpoint.
2. Tạo `AppPagedTable` cho desktop và `AppRecordCardList` cho mobile, cùng nhận một nguồn
   `PagedResult<T>` để không tách logic dữ liệu.
3. Tách `AppChartCard` thành header, kỳ, legend, đơn vị, plot và footer drill-down; chiều cao plot
   tối thiểu được khóa theo loại biểu đồ.
4. Mọi màn dữ liệu phải dùng cùng `AppFilterBar` nằm trong card danh sách/báo cáo mà nó tác động.
5. Primary action: mobile dùng action icon/compact ở góc phải thanh màn; desktop dùng FAB dưới-phải.

## 6. Đối chiếu hệ thống thực tế

| Hệ thống | Cách tổ chức đáng học | Áp dụng cho SmartStock |
|---|---|---|
| Shopify Analytics | Dashboard tùy biến card, đổi kỳ, so sánh kỳ, drill-down từ card sang báo cáo | Cho phép chủ shop thêm/bớt/sắp xếp KPI; card mở báo cáo chi tiết |
| Shopify Inventory | Sell-through, days of inventory remaining, ABC và inventory value | Bổ sung KPI bán xuyên, ngày tồn còn lại, ABC theo doanh thu |
| Square | Sales summary tách gross/net, discount, return, tax, payment; có định nghĩa metric | Thêm từ điển metric ngay trong UI và bảng đối soát doanh thu–thanh toán |
| Lightspeed | Year-over-year sales/profit, dusty inventory, low stock, turns, GMROI, margin alert | Ưu tiên tồn chậm, vòng quay, GMROI và cảnh báo biên lợi nhuận |
| Odoo | Graph + pivot, chọn measure, group by và drill-down | Báo cáo nâng cao dùng pivot thay vì tạo quá nhiều dashboard cố định |
| Dynamics 365 Commerce | Gross sales, tender type, tax, discount và price override theo cửa hàng | Dashboard đa cửa hàng cần so sánh location và các ngoại lệ giá/chiết khấu |
| QuickBooks | P&L, cash flow, AR aging summary/detail và đối chiếu inventory valuation | Tách báo cáo điều hành khỏi báo cáo đối soát; mọi tổng phải drill-down đến chứng từ |

Nguồn chính thức:

- [Shopify Analytics overview](https://help.shopify.com/en/manual/reports-and-analytics/shopify-reports/overview-dashboard)
- [Shopify inventory reports](https://help.shopify.com/en/manual/reports-and-analytics/shopify-reports/report-types/default-reports/inventory-reports)
- [Shopify product analytics](https://help.shopify.com/en/manual/products/analytics)
- [Square sales summary](https://squareup.com/help/us/en/article/5381-in-app-summaries-and-reports)
- [Lightspeed Analytics reports](https://retail-support.lightspeedhq.com/hc/en-us/articles/4410657877659-About-Lightspeed-Analytics-reporting)
- [Odoo reporting](https://www.odoo.com/documentation/17.0/applications/essentials/reporting.html)
- [Odoo inventory forecast](https://www.odoo.com/documentation/19.0/applications/inventory_and_mrp/inventory/warehouses_storage/reporting/forecast.html)
- [Dynamics 365 store performance](https://learn.microsoft.com/en-us/dynamics365/commerce/store-performance-information)
- [QuickBooks AR aging](https://quickbooks.intuit.com/learn-support/en-us/help-article/accounts-receivable-reports/run-accounts-receivable-aging-report/L4N7PC2hg_US_en_US)
- [QuickBooks inventory valuation reconciliation](https://quickbooks.intuit.com/learn-support/en-us/help-article/list-management/balance-sheet-inventory-stock-valuation-reports/L02dbIDsy_US_en_US)

## 7. Bộ biểu đồ mục tiêu

### Dashboard chủ cửa hàng

1. Doanh thu thuần và lợi nhuận gộp theo thời gian, so với kỳ trước.
2. Dòng tiền vào/ra và số dư tiền mặt thực tế.
3. Top 10 sản phẩm theo doanh thu thuần và số lượng thuần.
4. Công nợ phải thu theo aging và số quá hạn.
5. Giá trị tồn, tồn dưới định mức và hàng tồn chậm.
6. Ngoại lệ cần xử lý: biên lợi nhuận thấp, tồn âm, hóa đơn thiếu, thuế đến hạn.

### Bán hàng

- Doanh thu thuần 7/30 ngày; số đơn; giá trị đơn trung bình.
- Doanh thu theo giờ/ngày trong tuần để bố trí nhân sự.
- Cơ cấu phương thức thanh toán và chênh lệch thanh toán–doanh thu.
- Tỷ lệ hoàn/hủy/chiết khấu và lý do hoàn.
- Sản phẩm thường mua cùng nhau khi dữ liệu đủ lớn.

### Kho

- Sell-through, số ngày tồn còn lại, vòng quay tồn và GMROI.
- ABC theo doanh thu/biên lợi nhuận.
- Aging tồn kho và “dusty inventory”.
- Hết hàng nhưng gần đây có doanh số; đề xuất nhập lại.
- Tồn thực tế so với định mức, đang đặt mua và dự kiến về.

### Tài chính

- P&L waterfall: doanh thu → giảm trừ → giá vốn → lãi gộp → chi phí → lãi ròng.
- Dòng tiền theo ngày/tháng và dự báo 30/60/90 ngày.
- Chi phí theo nhóm có số tiền, tỷ trọng và biến động so kỳ trước.
- Aging phải thu/phải trả; top khoản quá hạn.
- Đối soát tiền mặt, chuyển khoản, QR và số chênh lệch cuối ngày.

## 8. Bộ bảng mục tiêu

| Bảng | Cột bắt buộc |
|---|---|
| Đơn bán | Mã, ngày, khách, cửa hàng, giao hàng, thanh toán, tổng, đã trả, còn nợ, hoàn, người tạo |
| Sản phẩm | Ảnh, SKU, tên, nhóm, đơn vị, giá vốn, giá bán, biên LN, tồn, giữ chỗ, khả dụng, định mức, bán 30 ngày |
| Sổ kho | Thời gian, chứng từ, SKU, kho, loại, tăng/giảm, trước, sau, giá vốn, thành tiền, người thao tác, lý do |
| Đơn nhập | Mã, NCC, trạng thái, ngày đặt, dự kiến, đã nhận, tổng, đã trả, còn phải trả, người phụ trách |
| Giao dịch tiền | Ngày, chứng từ, nhóm, phương thức, tài khoản, thu, chi, số dư, cửa hàng, người ghi, liên kết nguồn |
| Công nợ | Khách/NCC, chứng từ, ngày, hạn, gốc, đã trả, còn lại, bucket tuổi nợ, lần nhắc gần nhất |
| Thuế | Kỳ, loại nghĩa vụ, căn cứ, doanh thu tính thuế, thuế suất cấu hình, phải nộp, đã nộp, hạn, trạng thái |

Quy tắc hiển thị:

- Desktop: header cố định, cao dòng 44–52 px, sắp xếp cột, ẩn/hiện cột, chọn 25/50/100 dòng.
- Mobile: card tóm tắt 3–5 trường chính; mở chi tiết để xem phần còn lại, không ép bảng rộng.
- Bộ lọc đặt trong chính card bảng và ghi rõ phạm vi áp dụng.
- Tổng số dòng, tổng giá trị theo tập đã lọc và trạng thái tải phải luôn nhìn thấy.
- Export toàn bộ tập lọc, không chỉ trang hiện tại.

### 8.1 Thiết kế dữ liệu phục vụ báo cáo

Không nên để từng màn tự cộng lại dữ liệu nghiệp vụ theo công thức riêng. Giữ entity giao dịch hiện có làm
nguồn sự thật và bổ sung read model/materialized view sau khi contract metric được duyệt:

| Read model đề xuất | Grain (một dòng đại diện) | Chỉ số chính |
|---|---|---|
| `reporting_daily_sales` | cửa hàng × ngày × kênh × trạng thái thanh toán | gross, discount, return, net revenue, COGS, gross profit, orders, units, AOV |
| `reporting_inventory_snapshot` | cửa hàng × kho × sản phẩm × ngày | tồn đầu, nhập, xuất, điều chỉnh, trả, giữ chỗ, khả dụng, tồn cuối, đơn giá, giá trị |
| `reporting_ar_aging_snapshot` | cửa hàng × khách hàng × ngày chốt | current, 1–30, 31–60, 61–90, trên 90 ngày, tổng phải thu |
| `reporting_ap_aging_snapshot` | cửa hàng × nhà cung cấp × ngày chốt | các bucket tuổi nợ, tổng phải trả, quá hạn |
| `reporting_cashflow_daily` | cửa hàng × ngày × phương thức | thu thực tế, chi thực tế, thu/chi dự báo, số dư đầu/cuối |

Quy tắc bắt buộc:

1. Mọi response báo cáo có `shopScope`, `from`, `to`, `timezone`, `asOf`, `currency`, `filters` và phiên bản công thức.
2. Một metric chỉ có một định nghĩa dùng chung cho dashboard, màn chi tiết và export.
3. Dữ liệu tổng hợp phải drill-down được đến chứng từ nguồn và có tổng kiểm soát đối chiếu.
4. Snapshot không ghi đè lịch sử; thay đổi hồi tố phải có job tái dựng và audit.
5. Không chạy DDL/tạo view trong cold-start serverless; dùng migration được phê duyệt và đo thời gian refresh.

## 9. Lộ trình triển khai

### P0 — Toàn vẹn và không mất dữ liệu trên giao diện

1. Sửa giá vốn hoàn một phần và thêm test nhiều lần hoàn.
2. Thêm phân trang/tải tiếp cho toàn bộ danh sách và form chọn dữ liệu.
3. Chạy migration auth có kiểm soát trên production và smoke test cold-start/auth.
4. Đổi top sản phẩm sang số liệu thuần sau hoàn.
5. Chặn deploy nếu backend chỉ build nhưng không khởi tạo được datasource.

### V1.1 — Chuẩn hóa trải nghiệm vận hành

1. Tạo `AppPagedTable`, `AppMobileRecordCard` và thanh filter dùng chung.
2. Chuẩn hóa typography còn một font UI và một kiểu số tabular.
3. Chuẩn hóa đơn vị, tooltip, legend và empty/error của biểu đồ.
4. Tách trạng thái đơn: giao hàng, thanh toán, hoàn trả.
5. Giảm card KPI xuống một hàng cân đối; ưu tiên diện tích cho bảng và biểu đồ.

### V1.2 — Hoàn thiện báo cáo

1. Thêm sell-through, days cover, turnover, GMROI và ABC.
2. Thêm P&L waterfall, đối soát thanh toán và báo cáo hoàn/hủy.
3. Export XLSX/CSV server-side theo bộ lọc, có metadata kiểm soát.
4. Cho phép lưu bộ lọc, lựa chọn cột và báo cáo yêu thích.
5. Bổ sung pivot/group-by cho báo cáo phân tích.

### V2.0 — Phân tích đa cửa hàng

1. So sánh cửa hàng theo doanh thu thuần, lãi gộp, tồn, vòng quay và công nợ.
2. Dự báo nhập hàng dựa trên tốc độ bán, lead time và hàng đang đặt.
3. Insight tự động phải kèm công thức, kỳ, cửa hàng và nguồn dữ liệu.
4. Cảnh báo bất thường có ngưỡng cấu hình và giải thích, không tự khẳng định kết luận thuế.

## 10. Tiêu chí hoàn thành vòng audit tiếp theo

- Có tài khoản test production an toàn và phiên đăng nhập hoạt động.
- Chụp lại tất cả route chính ở desktop `1440×900` và mobile `390×844`.
- Mỗi ảnh được kiểm tra không loading, không crop và đúng cửa hàng/kỳ dữ liệu.
- Kiểm thử ít nhất một luồng đọc hoàn chỉnh cho mỗi nhóm và một luồng ghi an toàn trong test shop.
- Đối chiếu 10 bản ghi mẫu từ UI → API → DB cho bán hàng, tồn, tiền và công nợ.
- Kiểm thử bàn phím, focus, zoom 200% và screen reader riêng; chưa đạt thì không ghi nhận accessibility.

Phạm vi route và trạng thái bắt buộc: xem
[21 — Ma trận chụp và kiểm thử toàn bộ giao diện production](21_PRODUCTION_SCREEN_CAPTURE_MATRIX_20260801.md).

Kết quả smoke test route/API sau đăng nhập:
[22 — Smoke test production sau đăng nhập](22_PRODUCTION_AUTHENTICATED_SMOKE_TEST_20260801.md).
