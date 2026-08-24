# Ma trận thành phần và triển khai giao diện theo 59 màn hình — 01/08/2026

## 1. Kết luận

Kiểm kê tĩnh toàn bộ `*_screen.dart` cho thấy giao diện SmartStock không thiếu component, nhưng component chưa được
áp dụng thành hệ thống. Có 59 màn hình Dart và 56 route duy nhất, trong đó:

| Tín hiệu từ code | Số màn | Tỷ lệ | Ý nghĩa |
|---|---:|---:|---|
| Dùng `AppPageHeader` | 9 | 15,3% | 50 màn còn tự dựng AppBar/header, làm lệch vị trí title/help/action |
| Dùng `featureGuideButton` | 29 | 49,2% | 30 màn không có hướng dẫn; một số là form nhỏ, nhưng nhiều màn rủi ro cao vẫn thiếu |
| Dùng `AppDataTable` | 1 | 1,7% | Bảng dùng chung gần như chưa được áp dụng |
| Dùng `DataTable` trực tiếp | 1 | 1,7% | XNT còn dùng bảng riêng, khó thống nhất responsive |
| Có biểu đồ | 7 | 11,9% | Biểu đồ tập trung đúng ở dashboard/finance nhưng chưa có bảng drill-down |
| Có tín hiệu phân trang đầy đủ | 1 | 1,7% | Chỉ `purchase_no_invoice_screen` có điều khiển trang rõ |
| Có tín hiệu loading | 48 | 81,4% | Khá tốt nhưng chưa chứng minh thông báo và retry đúng |
| Có tín hiệu empty | 49 | 83,1% | Cần chuẩn hóa cùng component/copy |
| Có tín hiệu error/retry | 47 | 79,7% | Còn màn chỉ có text hoặc không có recovery |

Các tỷ lệ trên là phân tích source, không thay thế screenshot production. Màn protected hiện vẫn thiếu ảnh trực quan
hiện hành vì công cụ chụp Flutter canvas timeout.

## 2. Phát hiện hệ thống

### UI-01 — Header và vị trí hành động bị phân mảnh

Chỉ dashboard, sales, product list, customer list, supplier list, inventory, finance, customer debt và settings dùng
`AppPageHeader`. Các màn còn lại tự dựng AppBar/Column. Vì vậy help icon, subtitle, primary action, khoảng đệm và
responsive breakpoint không đồng nhất.

**Mục tiêu:** `AppScreenScaffold` sở hữu title/subtitle/help/scope; desktop primary action nổi góc phải dưới, mobile
đưa primary action lên app bar. Form/detail dùng biến thể compact, không ép mọi màn thành dashboard.

### UI-02 — Hướng dẫn có dữ liệu nhưng phủ chưa đúng rủi ro

`feature_guide_data.dart` có 29 guide và đúng 29 màn đang gọi. Các màn còn thiếu nhưng cần ưu tiên guide gồm:

- product form, purchase-order form, stock-take form;
- payment config và shop profile;
- staff/roles, activity log và AI knowledge;
- tax config và tax estimate;
- transaction detail và return detail.

Không cần ép guide vào màn đăng nhập hoặc form đơn giản. Guide là icon help ở header, không là nút chữ chiếm một hàng.

### UI-03 — Danh sách có state nhưng người dùng không duyệt hết dữ liệu

`sales_list_screen` có `_page` nhưng không có nút đổi trang. Product, customer, supplier, invoice, transaction và
nhiều picker gọi cố định `page: 1`; form nhập hàng/kiểm kê vì vậy chỉ có thể chọn tập đầu tiên. Đây là lỗi nghiệp vụ,
không chỉ là vấn đề giao diện.

### UI-04 — Bảng desktop đang được ép sang mobile

`AppDataTable` ép bảng rộng 650 px rồi cuộn ngang trên mobile. Nó chưa có sort, pagination, selection, total theo
filter, sticky header hoặc column chooser. Mục tiêu đúng là:

- desktop: `AppPagedTable`;
- mobile: `AppRecordCardList`;
- cùng dùng một query/filter/sort contract và tổng từ server.

### UI-05 — Hai màn finance là code không thể truy cập

`budget_plan_screen.dart` và `invoice_scan_screen.dart` không được tham chiếu bởi router hoặc màn khác. Cần chọn một
trong hai hướng: khai báo route/menu/quyền/test hoặc xóa sau khi xác nhận không còn phạm vi. Không để màn “có code”
nhưng người dùng không thể mở.

## 3. Ma trận 59 màn hình

Ký hiệu:

- `P0`: sai dữ liệu, không hoàn tất nghiệp vụ hoặc rủi ro thuế/quyền.
- `P1`: thiếu nhất quán, khó sử dụng, thiếu drill-down/pagination.
- `P2`: hoàn thiện trải nghiệm.
- “Code-only” nghĩa là kết luận từ source, chưa phải đánh giá hình ảnh production hiện tại.

### 3.1 Auth — 6 màn

| Màn | Route | Sức khỏe code-only | Ưu tiên | Mẫu mục tiêu |
|---|---|---|---|---|
| Login | `/login` | Có loading/error; cần inline validation và xóa lỗi khi nhập lại | P1 | Auth shell desktop 2 cột, mobile 1 cột, submit rỗng không gọi API |
| Register | `/register` | Form dài, desktop còn dùng vùng hẹp kiểu mobile | P1 | Auth shell chung, chia section, progress hợp lý, lỗi từng field |
| OTP verification | `/verify-otp` | Có resend/loading nhưng cần focus/paste/countdown/accessibility test | P1 | 6 ô hoặc một input semantic, paste toàn mã, retry có giới hạn |
| Forgot password | `/forgot-password` | Có state nhưng contract email/phone từng lệch backend | P0 | Copy đúng contract, inline validation, success state rõ |
| Onboarding | `/onboarding` | File 1.019 dòng, nhiều bước và nhiều trách nhiệm | P1 | Wizard tách step, lưu nháp, back/next ổn định, summary xác nhận |
| Waiting approval | `/waiting-approval` | Ít state, thiếu refresh/support rõ | P2 | Trạng thái, thời điểm kiểm tra, refresh và lối đăng xuất/hỗ trợ |

### 3.2 Dashboard — 1 màn

| Màn | Route | Sức khỏe code-only | Ưu tiên | Mẫu mục tiêu |
|---|---|---|---|---|
| Dashboard | `/` | Header/guide/chart có chuẩn; metric contract và drill-down chưa đủ | P1 | 3 KPI chính, biểu đồ 2/3, alert table 1/3, top 10 thanh ngang |

### 3.3 Sales — 6 màn

| Màn | Route | Sức khỏe code-only | Ưu tiên | Mẫu mục tiêu |
|---|---|---|---|---|
| Sales list | `/sales` | Có header/guide/filter/chart/FAB; `_page` không có pagination | P0 | Report card có filter riêng, server pagination, summary + list |
| POS | `/pos` | Luồng chính rộng; sản phẩm và khách hàng vẫn gọi trang 1 | P0 | Search server, category virtualized, cart sticky, mobile checkout an toàn |
| Order detail | `/sales/:id` | Có guide và state; hoàn/thu nợ là thao tác rủi ro cao | P0 | Header trạng thái, timeline, lines, payment, return; confirm theo quyền |
| Return detail | `/sales/returns/:id` | Ít loading/error signal; dữ liệu hoàn chưa gắn dòng bán gốc | P0 | Tải theo ID, original line, returned qty/cost, audit timeline |
| Customer debt | `/customer-debts` | Màn duy nhất dùng `AppDataTable`; 453 khoản mở không phân trang | P1 | Paged table/record card, aging/filter, tổng toàn bộ, thu nợ CTA |
| QR payment | Nội bộ từ POS | Có guide/loading/error; cần state chờ/xác nhận/hết hạn rõ | P1 | QR theo shop, amount/reference cố định, countdown và fallback |

### 3.4 Products — 4 màn

| Màn | Route | Sức khỏe code-only | Ưu tiên | Mẫu mục tiêu |
|---|---|---|---|---|
| Product list | `/products` | Header/guide/FAB tốt; cố định `page: 1` | P0 | Search/filter trong dataset, paged list, mobile record card |
| Product form | `/products/form` | 735 dòng; thiếu guide ở workflow giá/đơn vị/ảnh | P1 | Sections: nhận diện, đơn vị, giá, thuế, tồn, ảnh; sticky save |
| Product detail | `/products/:id` | Có guide/FAB; movement history gọi trang 1 | P1 | Snapshot KPI, tồn theo kho/lô, price/movement tabs có pagination |
| Tag management | `/products/tags` | CRUD modal và FAB; màu preset là cấu hình UI hợp lệ | P2 | List gọn, preview màu/text, usage count trước khi xóa |

### 3.5 Customers — 3 màn

| Màn | Route | Sức khỏe code-only | Ưu tiên | Mẫu mục tiêu |
|---|---|---|---|---|
| Customer list | `/customers` | Header/guide/FAB; cố định trang 1 | P0 | Paged table/card, search server, debt/type/status filters |
| Customer form | `/customers/form` | Có error nhưng không có loading; dữ liệu định danh nhạy cảm | P1 | Section cơ bản/tín dụng/định danh, privacy copy, upload state |
| Customer detail | `/customers/:id` | Có guide/FAB; receivable history gọi trang 1 | P1 | Summary, credit utilization, order/debt/payment tabs paged |

### 3.6 Suppliers — 3 màn

| Màn | Route | Sức khỏe code-only | Ưu tiên | Mẫu mục tiêu |
|---|---|---|---|---|
| Supplier list | `/suppliers` | Header/guide/FAB; cố định trang 1 | P0 | Paged table/card, balance/status/category filters |
| Supplier form | `/suppliers/form` | Form đơn giản; thiếu chuẩn validation/loading | P1 | Section contact/payment/bank, inline validation, save state |
| Supplier detail | `/suppliers/:id` | Có guide/FAB; cần PO/payable drill-down | P1 | Supplier KPI, PO/payable/payment tabs, aging và CTA thanh toán |

### 3.7 Inventory — 8 màn

| Màn | Route | Sức khỏe code-only | Ưu tiên | Mẫu mục tiêu |
|---|---|---|---|---|
| Inventory overview | `/inventory` | Header/guide/FAB; KPI total/low-stock đã sửa local | P0 verify | KPI compact, alert sections, ABC/days-on-hand/valuation links |
| Purchase-order list | `/purchase-orders` | Có guide/FAB; chưa có pagination/search rõ | P1 | Paged list, status/supplier/date filters, total open value |
| Purchase-order form | `/purchase-orders/form` | Supplier/product picker cố định trang 1 | P0 | Server search picker, line editor, totals sticky, validation |
| Purchase-order detail | `/purchase-orders/detail` | Dựa `state.extra`, reload/deep-link dễ mất dữ liệu | P1 | Route `:id`, tải API, receipt/payment/timeline tabs |
| Stock-take launcher | `/stock-take` | Có guide/FAB; điều hướng bằng `MaterialPageRoute` ngoài router | P1 | Router thống nhất, primary action rõ, recent/open count |
| Stock-take form | Nội bộ | Product picker trang 1; file 1.078 dòng | P0 | Stepper compact, server search/scan, variance summary, confirm |
| Stock-take history | Nội bộ | List nhỏ, chưa pagination/filter | P1 | Paged history, status/date/user filter, variance totals |
| XNT report | `/xnt-report` | Có guide, kỳ báo cáo, phân trang 20; mobile card và desktop table dùng cùng dữ liệu DB | P1 | Bổ sung bộ lọc kho và giá trị tồn khi ledger có đơn giá đáng tin cậy |

### 3.8 Finance — 16 màn

| Màn | Route | Sức khỏe code-only | Ưu tiên | Mẫu mục tiêu |
|---|---|---|---|---|
| Finance overview | `/finance` | Header/guide/chart/FAB; nhiều KPI, định nghĩa còn phân mảnh | P1 | 3 KPI chính, P&L bridge, cash trend, action/alert table |
| Daily closing | `/daily-closing` | Có guide/loading/error; form dài | P1 | Business-day context, expected/actual/difference, approval trail |
| Profit & loss | `/profit-loss` | Có chart/guide; phụ thuộc COGS hoàn chưa đúng | P0 | Waterfall + account table, gross/discount/return/net/COGS |
| Cashflow forecast | `/cashflow-forecast` | Có chart/guide/FAB; actual/forecast provenance chưa rõ | P1 | Actual vs forecast line, confidence/source, scenario table |
| Debt aging | `/debt-aging` | Có chart/guide; thiếu table pagination/drill-down | P1 | Aging stacked bar + paged debtor table |
| Invoice list | `/invoices` | Có guide/filter; cố định page 1, dữ liệu invoice có lỗi P0 | P0 | Paged invoice table/card, reconciliation status, drill-down |
| Purchase without invoice | `/purchases-no-invoice` | Màn duy nhất có pagination; có guide/FAB | Khá | Giữ pattern, bổ sung total theo filter và approval timeline |
| Tax calculator | `/tax-calculator` | Có guide nhưng thiếu loading/error signal rõ | P0 | Rule version/source/effective date, input validation, disclaimer |
| Expense ledger | `/expense-ledger` | Chart/guide/FAB; cần Việt hóa enum và pagination | P1 | Category bar/table, server page, receipt drill-down |
| Tax obligations | `/tax-obligations` | Guide/FAB/filter; cần source trace và legal state | P0 | Period/status KPI, obligation table, invoice/rule trace |
| Salary ledger | `/salary-ledger` | Guide/FAB; transactions page 1 | P1 | Paged payroll ledger, employee/period filter, approval/evidence |
| Tax declaration | `/tax-declaration` | Có guide/loading/error; XML chưa có biên bản HTKK | P0 | Data-quality gate, trace table, export version + validation result |
| Transaction history | `/transactions` | Có guide nhưng gọi page 1 | P0 | Paged table/card, account/type/date filter, totals from server |
| Transaction detail | `/transactions/detail` | Dựa `state.extra`, không tải theo ID | P1 | Route `:id`, reference/evidence/audit timeline |
| Budget plan | Không có route | Code không thể truy cập | P1 decision | Khai báo route/menu/quyền/test hoặc xóa sau phê duyệt |
| Invoice scan | Không có route | Code không thể truy cập; chỉ 52 dòng | P1 decision | Hoàn thiện scan queue/workflow hoặc loại khỏi phạm vi |

### 3.9 Settings — 11 màn

| Màn | Route | Sức khỏe code-only | Ưu tiên | Mẫu mục tiêu |
|---|---|---|---|---|
| Settings hub | `/settings` | Header/guide chuẩn; file 1.055 dòng và nhiều nhóm | P1 | Search setting, nhóm theo quyền, status/config completeness |
| AI knowledge | `/settings/ai-knowledge` | CRUD modal; thiếu guide/citation lifecycle | P0 | Source, effective date, reviewer, status, revoke và version |
| Activity logs | `/activity-logs` | Có filter nhưng không pagination/guide | P1 | Immutable paged table/card, actor/action/entity/date filters |
| Tax config | `/tax-config` | FAB save; thiếu guide và version/source rõ | P0 | Rule source/effective date, approval, impact preview |
| Tax support | `/tax-support` | Có nội dung hướng dẫn riêng; cần nguồn pháp lý có hiệu lực | P0 | Topic index, citation, effective/expired state, feedback |
| Payment config | `/payment-config` | QR theo shop; thiếu guide và state “all shops” rõ | P0 | Single-shop guard, upload/replace/delete lifecycle, preview |
| Notifications | `/notifications` | 161 dòng, thiếu pagination/error recovery | P1 | Group today/earlier, unread filter, pagination, deep-link |
| Staff management | `/staff`, `/employees` | Hai route cùng màn; file chứa cả staff và role UI | P0 | Một route canonical, member table/card, invite/approve/audit |
| Role config | `/roles` | Cùng file 1.282 dòng với staff; quyền khó quét mobile | P0 | Permission matrix desktop, grouped accordion mobile, diff preview |
| Profile | `/profile` | Form cơ bản, thiếu guide không nghiêm trọng | P2 | Compact form, avatar state, inline validation |
| Change password | `/change-password` | Có loading/error; cần auth hardening production | P0 release | Current/new/confirm, strength, revoke sessions, success state |
| Shop profile | `/shop-profile` | Không dùng header/guide; nhiều thông tin pháp lý và ảnh | P1 | Sections identity/contact/bank/brand/tax, completeness checklist |

Lưu ý: staff management và role config là hai widget trong cùng file nên bảng trên có 12 dòng nghiệp vụ cho 11 file.

### 3.10 Tax feature riêng — 1 màn

| Màn | Route | Sức khỏe code-only | Ưu tiên | Mẫu mục tiêu |
|---|---|---|---|---|
| Tax estimate | `/tax-estimate` | Có loading/error/filter; thiếu guide và frontend guard từng lệch API | P0 | Period/shop scope, rule/version/source, breakdown và trace |

## 4. Thứ tự triển khai theo component

### Đợt 1 — Không đổi schema/API

1. Tạo `AppScreenScaffold` từ `AppPageHeader`, help icon, scope slot và mobile compact action.
2. Chuẩn hóa `AppLoadingState`, `AppEmptyState`, `AppErrorState` và copy tiếng Việt.
3. Chuẩn hóa `AppPrimaryFloatingAction`; desktop end-float, mobile app-bar compact action.
4. Áp dụng trước cho list top-level: products, customers, suppliers, sales, invoice, transaction, PO.

### Đợt 2 — Cần API pagination contract

1. `PagedResult<T>` chung: items, total, page, pageSize, totalPages, sort, filters, asOf.
2. `AppPagedTable` desktop và `AppRecordCardList` mobile.
3. Chuyển các picker ở POS, PO và stock-take sang search server có debounce.
4. Export phải chạy trên toàn bộ kết quả lọc, không chỉ page đang tải.

### Đợt 3 — Báo cáo

1. Metric contract và định nghĩa net sales/gross margin/return/COGS.
2. Chart + drill-down table theo blueprint ở tài liệu 23.
3. Store scorecard và data-quality dashboard.

### Đợt 4 — Màn rủi ro cao

1. Invoice/return/tax sau khi migration nghiệp vụ được phê duyệt.
2. Staff/roles sau khi chốt permission contract frontend–backend.
3. Auth protected screens sau migration auth và secret production.

## 5. Tiêu chí nghiệm thu giao diện

- 56 route có header/action/help đúng pattern được duyệt hoặc có lý do ngoại lệ.
- Không còn list nghiệp vụ cố định `page: 1` mà không có server search/pagination.
- Desktop 1440×900 và mobile 390×844 không overflow hoặc bị AI/FAB/nav che nội dung.
- Filter đặt trong đúng dataset; scope toàn báo cáo có nhãn riêng.
- Mọi chart có unit, period, tooltip số đầy đủ, empty/loading/error và bảng drill-down.
- Mọi bảng số tiền align phải, số lượng kèm unit, enum được Việt hóa.
- Deep-link detail tải bằng `:id`, refresh không phụ thuộc `state.extra`.
- Guide icon có ở các workflow phức tạp/rủi ro; không dùng nút chữ “Hướng dẫn” chiếm hàng.
- Keyboard, focus, screen reader, contrast và zoom phải được kiểm thử riêng trước khi ghi đạt accessibility.

## 6. Liên kết liên quan

- [Khung KPI, bảng, biểu đồ và data benchmark](23_KPI_REPORT_TABLE_AND_DATA_BENCHMARK_20260801.md)
- [Audit tổng thể UI, luồng và báo cáo](20_COMPREHENSIVE_UI_FLOW_REPORTING_AUDIT_20260801.md)
- [Ma trận chụp production](21_PRODUCTION_SCREEN_CAPTURE_MATRIX_20260801.md)
- [Backlog và roadmap](10_PRODUCT_BACKLOG_AND_RELEASE_ROADMAP.md)
