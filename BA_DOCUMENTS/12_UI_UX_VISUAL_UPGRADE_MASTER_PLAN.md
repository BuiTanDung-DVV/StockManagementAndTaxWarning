# Kế hoạch tổng thể nâng cấp UI/UX SmartStock

> Trạng thái: Đã triển khai production vòng 1 - design system, app shell, dashboard và POS
> Ngày lập: 26/07/2026
> Commit ứng dụng production: `17dd84d4b46994c921d373d03273bb39b9787ac4`
> Frontend: [smartstock-tax.vercel.app](https://smartstock-tax.vercel.app)
> Phạm vi: Flutter Web và giao diện responsive desktop, tablet, mobile

## Tiến độ triển khai

Đã hoàn thành và triển khai production:

- Chuẩn hóa token spacing, radius và breakpoint responsive.
- App shell dùng bottom navigation, navigation rail hoặc sidebar theo chiều rộng.
- Loại AI FAB khỏi app shell và ngăn lớp nổi che nội dung.
- Chuẩn hóa `AppPageHeader` cho desktop/mobile.
- POS vô hiệu hóa sản phẩm hết hàng và chặn tăng số lượng vượt tồn khả dụng.
- Dashboard bỏ header trùng lặp, giảm gradient/shadow, thêm kỳ cho KPI và chuyển cảnh báo sang danh sách dọc.
- Settings và màn quản lý tri thức AI được điều chỉnh để giảm cảm giác trình diễn AI.

Đã xác minh:

- `flutter analyze`: đạt, không có lỗi.
- Toàn bộ 23 Flutter tests: đạt.
- `flutter build web --release`: thành công.
- Backend lint/build và 28 P0 tests: đạt.
- Frontend và backend Vercel cùng nhận commit ứng dụng, đều `READY`.
- Dashboard desktop tải đúng user/shop và các KPI.
- Sales desktop khớp dashboard ở 4 đơn, doanh thu 127.250đ và lợi nhuận -83.750đ.
- Customer debt desktop hiển thị empty state thật, không còn dữ liệu mẫu.
- Dashboard và POS trên viewport 390×844 không có lỗi console hoặc overflow
  quan sát được; POS hiển thị rõ giỏ hàng và CTA thanh toán.
- Vercel frontend không ghi nhận runtime error trong cửa sổ kiểm tra 1 giờ.

Chưa xác minh hoặc cần kiểm thử chuyên biệt:

- Thanh toán, hoàn/hủy và QR vì smoke test không được phép tạo giao dịch production.
- Bàn phím ảo và thiết bị vật lý; vòng này mới xác minh viewport 390×844.
- Accessibility, screenshot regression tự động và dark mode toàn bộ route.
- Backend còn cảnh báo deprecation `DEP0169` liên quan `url.parse()`; chưa thấy
  gián đoạn nhưng cần truy nguồn dependency trước khi nâng cấp.

## 1. Mục tiêu

Kế hoạch này định nghĩa hướng nâng cấp giao diện SmartStock để:

1. Đẹp, hiện đại và có bản sắc riêng nhưng vẫn phù hợp ứng dụng vận hành cửa hàng.
2. Giảm cảm giác giao diện do AI tạo ra: bớt gradient, bớt card thừa, bớt nút nổi,
   bỏ copy phô trương và hiệu ứng không phục vụ tác vụ.
3. Giúp chủ cửa hàng và nhân viên hoàn thành nhanh các tác vụ bán hàng, kiểm kho,
   thu nợ, xem tài chính và chuẩn bị dữ liệu thuế.
4. Làm rõ nguồn số liệu, kỳ báo cáo, trạng thái dữ liệu và hành động tiếp theo.
5. Hoạt động tốt trên mobile, tablet và desktop, không che nội dung hoặc cắt nhãn.
6. Tạo nền tảng design system đủ rõ để các phiên bản sau phát triển nhất quán.

Kế hoạch này không cho phép thay đổi route, API contract, database schema, công thức
nghiệp vụ hoặc cơ chế phân quyền nếu chưa có yêu cầu riêng được duyệt.

## 2. Design Read và nguyên tắc Taste

**Design Read:** SmartStock là ứng dụng vận hành bán lẻ dành cho chủ cửa hàng và
nhân viên tại Việt Nam, theo ngôn ngữ trust-first, nhanh, rõ số liệu, thân thiện,
dựa trên Material 3 và nhận diện xanh dương hiện có.

### 2.1 Ba mức điều chỉnh

| Thuộc tính | Mức đề xuất | Lý do |
|---|---:|---|
| `DESIGN_VARIANCE` | 4/10 | Có điểm nhấn nhưng không phá cấu trúc quen thuộc của dashboard |
| `MOTION_INTENSITY` | 3/10 | Chỉ dùng chuyển động cho phản hồi và thay đổi trạng thái |
| `VISUAL_DENSITY` | 6/10 | Đủ thông tin cho vận hành hằng ngày, không biến thành cockpit dày đặc |

Taste skill không được dùng như bộ pattern landing page cho SmartStock vì đây là
dashboard, có bảng dữ liệu và nhiều luồng nghiệp vụ. Các nguyên tắc phù hợp được giữ:

- Một accent chính tại một thời điểm.
- Không dùng AI-purple, glow hoặc gradient để tạo cảm giác "công nghệ".
- Không dùng card cho mọi nhóm nội dung.
- Không dùng emoji làm icon chức năng chính.
- Không dùng animation chỉ để trang trí.
- Loading, empty, error và disabled state là thành phần bắt buộc.
- Ưu tiên Material 3, HugeIcons và các component Flutter đang có.
- Giữ route, luồng dữ liệu và hành vi nghiệp vụ hiện tại.

## 3. Người dùng mục tiêu và nhu cầu thực tế

### 3.1 Chủ cửa hàng

Nhu cầu chính:

- Biết hôm nay bán được bao nhiêu, còn bao nhiêu tiền và khoản nào cần xử lý.
- Mở POS nhanh.
- Nhận cảnh báo tồn kho, công nợ, thuế và dữ liệu thiếu.
- Xem tổng quan nhưng vẫn truy được về giao dịch gốc.
- Phân quyền nhân viên mà không cần hiểu thuật ngữ kỹ thuật.

Thiết kế phải ưu tiên:

- KPI có kỳ báo cáo và thời điểm cập nhật.
- Cảnh báo kèm CTA xử lý.
- Ngôn ngữ rõ ràng, tránh từ viết tắt không giải thích.
- Trạng thái "chưa đủ dữ liệu" thay vì hiển thị `0` gây hiểu nhầm.

### 3.2 Nhân viên bán hàng

Nhu cầu chính:

- Tìm sản phẩm nhanh.
- Biết rõ sản phẩm còn hàng hay hết hàng.
- Thêm khách hàng, phương thức thanh toán và hoàn tất đơn với ít thao tác.
- Không bị các tính năng phụ che nút thanh toán.

Thiết kế phải ưu tiên:

- POS là màn tập trung, không hiển thị trợ lý nổi.
- Touch target lớn, thao tác bằng một tay trên mobile.
- Giỏ hàng và CTA thanh toán luôn nhìn thấy.
- Phản hồi rõ khi hết hàng, lỗi mạng hoặc thanh toán thất bại.

### 3.3 Nhân viên kho

Nhu cầu chính:

- Nhìn thấy sản phẩm sắp hết trước.
- Tìm kho, lô, sản phẩm và phiếu kiểm kê nhanh.
- Phân biệt tồn hệ thống với tồn kiểm kê thực tế.
- Biết tác động của điều chỉnh trước khi lưu.

### 3.4 Người phụ trách tài chính và thuế

Nhu cầu chính:

- Hiểu số dư là tại thời điểm nào và doanh thu thuộc kỳ nào.
- Đối soát được từ báo cáo về chứng từ.
- Biết dữ liệu nào còn thiếu, đặc biệt là mã số thuế và hóa đơn.
- Phân biệt số ước tính với số có thể dùng để kê khai.

## 4. Hiện trạng cần cải thiện

Nguồn đánh giá:

- [Báo cáo UI/UX production](06_UI_UX_AUDIT_REPORT.md)
- [Báo cáo xác minh hiện trạng](09_CURRENT_STATE_VERIFICATION_REPORT.md)
- [Product backlog](10_PRODUCT_BACKLOG_AND_RELEASE_ROADMAP.md)
- Ảnh tại [production-audit-2026-07-25](assets/production-audit-2026-07-25/)

### 4.1 Điểm nên giữ

- Màu xanh dương thương hiệu dễ nhận biết.
- Outfit cho tiêu đề tạo cá tính tốt hơn font mặc định.
- HugeIcons phù hợp phong cách outline hiện tại.
- Sidebar desktop và bottom navigation mobile đã tạo được muscle memory.
- Hệ thống đã có light/dark theme và semantic color cơ bản.
- Một số màn đã có skeleton, empty state và error state dùng chung.
- POS mobile có CTA thanh toán cố định.
- Sổ nợ mobile đã chuyển sang card, phù hợp màn hình nhỏ.

### 4.2 Điểm cần loại bỏ hoặc giảm mạnh

- Gradient xanh và diffusion shadow xuất hiện ở quá nhiều vị trí.
- Card bo 24px được dùng như container mặc định cho cả nội dung không cần elevation.
- AI FAB nằm trên mọi màn hình và che nội dung.
- Emoji robot, emoji chào hỏi và copy "100%" tạo cảm giác trình diễn AI.
- Chip ngang bị cắt nhưng không có dấu hiệu cho biết có thể cuộn.
- Tiêu đề dùng Title Case không nhất quán.
- Một số biểu đồ quá lớn so với lượng dữ liệu truyền tải.
- Nhãn bị rút gọn sớm, đặc biệt trên dashboard, settings và debt summary.
- Số liệu thiếu kỳ, bộ lọc, công thức hoặc thời điểm cập nhật.
- Dữ liệu mô phỏng xuất hiện như dữ liệu thật trên production.

## 5. Design system mục tiêu

### 5.1 Nền tảng

- Giữ Flutter, Material 3, Riverpod, GoRouter và cấu trúc feature hiện có.
- Không thêm design system thứ hai.
- Tập trung chuẩn hóa token và component dùng chung trong theme hiện tại.
- Mọi component mới phải có light mode, dark mode và reduced motion.

### 5.2 Màu sắc

| Token | Light mode đề xuất | Dark mode đề xuất | Cách dùng |
|---|---|---|---|
| Background | Slate 50 | Midnight slate | Nền trang |
| Surface | White | Slate 900 | App bar, panel |
| Surface secondary | Slate 100 | Slate 800 | Nhóm nội dung nhẹ |
| Text primary | Slate 900 | Slate 50 | Tiêu đề, số chính |
| Text secondary | Slate 600 | Slate 300 | Mô tả |
| Text muted | Slate 500 | Slate 400 | Metadata |
| Accent | Brand color đang chọn | Brand color đã hiệu chỉnh | CTA và active state |
| Success | Emerald | Emerald sáng hơn | Trạng thái tốt |
| Warning | Amber | Amber sáng hơn | Cần chú ý |
| Danger | Red | Red sáng hơn | Lỗi, quá hạn, hết hàng |

Quy tắc:

- Mỗi shop hoặc theme chỉ có một accent chính tại một thời điểm.
- Semantic color không bị đổi theo brand color.
- Không dùng gradient cho card KPI mặc định.
- Gradient chỉ được dùng cho một điểm nhận diện có chủ đích, không dùng cho dữ liệu.
- Không dùng pure black hoặc pure white làm toàn bộ nền.
- Không dùng màu để truyền đạt trạng thái nếu không có icon hoặc label.

### 5.3 Typography

| Vai trò | Font | Kích thước mục tiêu | Quy tắc |
|---|---|---|---|
| Page title | Outfit 700 | 24-28 desktop, 20-22 mobile | Sentence case |
| Section title | Outfit 600 | 18-20 | Không dùng all caps |
| Card title | Outfit 600 | 14-16 | Tối đa 2 dòng |
| Body | Inter 400/500 | 14-16 | Line height 1.4-1.55 |
| Label | Inter 500/600 | 12-14 | Ngắn, trực tiếp |
| KPI/tiền | JetBrains Mono, tabular | 20-32 | Căn số ổn định |
| Bảng dữ liệu | Inter + tabular figures | 13-14 | Ưu tiên đọc nhanh |

Không thay font chỉ để tạo mới lạ. Outfit, Inter và JetBrains Mono hiện đã đáp ứng
được phân cấp cần thiết khi dùng đúng vai trò.

Khi triển khai nên đóng gói font cùng ứng dụng thay vì phụ thuộc tải font động.

### 5.4 Spacing

Thang spacing duy nhất:

`4, 8, 12, 16, 24, 32, 40, 48`

Quy tắc:

- Padding trang mobile: 16px.
- Padding trang tablet: 20-24px.
- Padding trang desktop: 24-32px.
- Khoảng cách section: 32px desktop, 24px mobile.
- Khoảng cách field: 16px.
- Không sử dụng giá trị lẻ nếu không có lý do căn chỉnh quang học.

### 5.5 Shape

| Thành phần | Radius |
|---|---:|
| Input, button, compact control | 12px |
| Card nghiệp vụ | 16px |
| Modal, drawer, bottom sheet | 20px |
| Pill filter, status chip | Full radius |
| Data table, section không elevation | 0-12px tùy bề mặt |

Bo 24px không còn là mặc định cho mọi card. Pill chỉ dành cho filter hoặc trạng
thái, không dùng cho mọi nút.

### 5.6 Elevation và border

- Card thông thường dùng surface tint hoặc divider, không dùng shadow.
- Shadow chỉ dùng cho modal, drawer, bottom sheet, sticky cart và menu nổi.
- Shadow phải cùng tông nền, blur vừa phải và có hướng ánh sáng nhất quán.
- Không dùng diffusion shadow 40px cho danh sách hoặc bảng dữ liệu.
- Không dùng border và shadow cùng lúc nếu một trong hai đã đủ phân cấp.

### 5.7 Icon

- Giữ HugeIcons làm family chính.
- Kích thước chuẩn: 20px compact, 24px navigation, 28px empty state.
- Material Icons chỉ dùng khi HugeIcons không có biểu tượng tương ứng.
- Không dùng emoji làm icon điều hướng hoặc chức năng.
- Icon luôn có tooltip trên desktop và semantics label trên mọi nền tảng.

## 6. Cấu trúc app shell mục tiêu

### 6.1 Desktop từ 1024px

- Sidebar rộng 240-260px, có chế độ thu gọn 72px.
- Logo, shop switcher và primary navigation nằm cùng một hệ thống phân cấp.
- Active route dùng accent + surface tint, không dùng glow.
- Header nội dung gồm page title, context/filter và tối đa hai hành động.
- Search hoặc command entry dùng cho điều hướng nhanh, không làm một ô tìm kiếm giả.
- Trợ giúp nghiệp vụ mở bằng icon trong header, không dùng FAB che nội dung.

### 6.2 Tablet 700-1023px

- Navigation rail 72-80px hoặc drawer, không sử dụng sidebar nửa rộng.
- Bộ lọc dài chuyển thành filter sheet.
- Bảng có thể scroll ngang nhưng phải giữ cột chính và header.
- Không đổi navigation pattern giữa các route.

### 6.3 Mobile dưới 700px

- Bottom navigation giữ 5 mục chính.
- Page action chính nằm trong app bar hoặc sticky action vùng dưới.
- Không có AI FAB trên nội dung.
- Mọi màn có bottom padding bằng nav + safe area + sticky action.
- Filter dùng wrap, segmented control hoặc filter sheet.
- Không để nửa card hoặc nửa chip bị cắt ở mép phải.

## 7. Kế hoạch nâng cấp theo màn hình

### 7.1 Dashboard

Vấn đề:

- Header chào hỏi quá cao trên mobile.
- Alert và quick action bị cắt ngang.
- KPI dùng nhiều card và gradient.
- AI FAB che card đơn hàng.
- Số liệu chưa ghi kỳ và thời điểm cập nhật.

Thiết kế mục tiêu:

1. Header compact gồm tên người dùng, tên cửa hàng và shop switcher.
2. CTA "Bán hàng" là hành động chính duy nhất ở đầu trang.
3. KPI dùng dải 2x2 mobile và 4 cột desktop:
   - Doanh thu trong kỳ.
   - Đơn hàng trong kỳ.
   - Lợi nhuận gộp trong kỳ.
   - Số dư tiền tại thời điểm.
4. Mỗi KPI có `period` hoặc `asOf`, trạng thái tải và link drill-down.
5. Alert chuyển thành danh sách dọc có mức độ, mô tả và CTA xử lý.
6. Quick action chỉ giữ 4 tác vụ thường dùng, các tác vụ còn lại mở từ "Xem thêm".
7. Biểu đồ chỉ xuất hiện khi đủ dữ liệu; nếu ít điểm thì dùng sparkline hoặc thông
   báo chưa đủ dữ liệu.

Tiêu chí nghiệm thu:

- 390x844 không có overflow, clip hoặc overlay.
- CTA POS nhìn thấy trong viewport đầu.
- Mọi KPI phân biệt `trong kỳ` và `tại thời điểm`.
- Giá trị lỗi không hiển thị thành `0`.
- Alert kho dẫn đúng đến danh sách sản phẩm cần xử lý.

### 7.2 Bán hàng và lịch sử đơn

Vấn đề:

- Summary theo tháng nhưng list hiển thị toàn bộ thời gian.
- Chart lớn dù chỉ có ít điểm dữ liệu.
- Dữ liệu mô phỏng xuất hiện như dữ liệu thật.
- FAB và AI che danh sách.

Thiết kế mục tiêu:

1. Một period selector dùng chung cho summary, chart và list.
2. Desktop dùng table có cột: mã đơn, thời gian, khách hàng, tổng, đã trả, trạng
   thái và thao tác.
3. Mobile dùng order card, ưu tiên mã đơn, khách hàng, tổng tiền và trạng thái.
4. Search, status và period nằm trong filter bar có thể thu gọn.
5. Chart chỉ hiển thị khi có từ 3 điểm trở lên.
6. CTA "Mở POS" nằm trong app bar, không dùng FAB.
7. Dữ liệu demo phải có nhãn môi trường hoặc bị loại khỏi production.

Tiêu chí nghiệm thu:

- Summary và list dùng cùng khoảng thời gian.
- Tổng số đơn khớp với filter đang hiển thị.
- Không có `Simulated Customer`, `Temp Product` hoặc `sim_tag` trên production.
- Tên khách và mã đơn không bị mất thông tin quan trọng trên mobile.

### 7.3 POS

Vấn đề:

- Sản phẩm tồn 0 vẫn có affordance thêm giỏ.
- Tên sản phẩm dài bị rút gọn khiến khó phân biệt.
- Tag nội bộ xuất hiện trên production.
- Không gian mobile chật khi giỏ hàng có nhiều sản phẩm.

Thiết kế mục tiêu:

1. Header ưu tiên search barcode/tên/SKU.
2. Category/tag dùng scroll có affordance hoặc filter sheet.
3. Product row cho phép tên 2 dòng và hiển thị SKU nhỏ bên dưới.
4. Tồn 0 dùng trạng thái disabled rõ ràng, không có nút thêm.
5. Khi số lượng trong giỏ đạt tồn khả dụng, nút tăng bị disabled và có helper text.
6. Mobile có sticky cart bar: số món, tổng tiền và CTA "Thanh toán".
7. Cart mở thành bottom sheet full-height có khách hàng, giảm giá, thanh toán và
   xác nhận.
8. Không hiển thị trợ lý AI trong toàn bộ luồng POS và QR payment.

Tiêu chí nghiệm thu:

- Không thể thêm hoặc tăng vượt tồn từ UI.
- Backend vẫn giữ kiểm tra tồn độc lập.
- CTA thanh toán không bị bàn phím ảo hoặc safe area che.
- Luồng từ tìm sản phẩm đến tạo đơn hoàn thành được bằng một tay trên mobile.
- Lỗi tạo đơn giữ nguyên giỏ và cho phép thử lại an toàn.

### 7.4 Kho hàng

Vấn đề:

- Donut chart chiếm nhiều diện tích.
- Cảnh báo tồn thấp bị đẩy xuống dưới.
- Back arrow không nhất quán với sidebar.
- Thao tác kiểm kê và nhập hàng chưa được ưu tiên rõ.

Thiết kế mục tiêu:

1. KPI compact: tổng sản phẩm, dưới định mức, sắp hết hạn, giá trị tồn.
2. Danh sách "Cần xử lý" nằm trước biểu đồ.
3. Donut chart được thay bằng stacked bar nhỏ hoặc danh sách phân bố có số cụ thể.
4. Desktop dùng table; mobile dùng stock card.
5. Hai primary action theo context: "Nhập hàng" và "Kiểm kê".
6. Không hiển thị back arrow ở top-level route.

Tiêu chí nghiệm thu:

- Người dùng thấy sản phẩm cần xử lý trong viewport đầu.
- Filter kho và category không mất khi quay lại từ chi tiết.
- Điều chỉnh kho hiển thị số trước, số sau và tác động trước khi xác nhận.

### 7.5 Tài chính

Vấn đề:

- Số dư quỹ và dòng tiền trong kỳ đặt gần nhau nhưng thiếu định nghĩa.
- Trục biểu đồ có đơn vị khó hiểu.
- Card chi phí trống tạo khoảng trắng lớn.
- AI FAB che công cụ tài chính.

Thiết kế mục tiêu:

1. Tách rõ:
   - Số dư hiện tại, có `asOf`.
   - Thu trong kỳ.
   - Chi trong kỳ.
   - Dòng tiền thuần trong kỳ.
2. Period selector dùng chung cho mọi metric theo kỳ.
3. Đơn vị biểu đồ dùng `đ`, `triệu`, `tỷ` với tooltip số đầy đủ.
4. Empty category dùng full-width empty state có CTA ghi chi phí.
5. Công cụ tài chính dùng grid 2 cột mobile, 3-4 cột desktop, không dùng card nếu
   chỉ là link điều hướng.
6. Số liệu luôn có đường dẫn đến giao dịch nguồn.

Tiêu chí nghiệm thu:

- Người dùng phân biệt được balance và cash flow.
- Không có đơn vị lạ như `N`.
- Tổng biểu đồ khớp summary và danh sách giao dịch cùng kỳ.
- Empty state không tạo vùng trắng mất cân đối.

### 7.6 Công nợ khách hàng

Vấn đề:

- Nhãn summary thứ hai bị cắt trên mobile.
- CTA thu nợ và xuất file chưa phân cấp rõ.
- AI FAB nằm gần bottom navigation.

Thiết kế mục tiêu:

1. Summary dùng 2 card cân bằng: tổng còn nợ, đã quá hạn.
2. Card khách hàng hiển thị tên, số liên hệ đã che bớt, số đơn nợ, còn nợ và hạn gần
   nhất.
3. "Thu nợ" là primary action; "Xuất CSV" là secondary action ở toolbar.
4. Empty state có CTA tạo đơn mua thiếu hoặc xem hướng dẫn.
5. Không có FAB phụ trên màn này.

Tiêu chí nghiệm thu:

- Nhãn không bị truncate ở 360px.
- Tổng summary bằng tổng các khoản trong scope.
- File xuất ghi rõ kỳ, thời điểm và tổng kiểm soát.

### 7.7 Thuế và khai báo

Vấn đề:

- Người dùng dễ hiểu số ước tính là kết quả kê khai.
- MST chưa có chỉ hiển thị `N/A`.
- Chính sách thuế có version nhưng UI chưa thể hiện đầy đủ.

Thiết kế mục tiêu:

1. Header luôn ghi `Ước tính hỗ trợ`, kỳ tính và ngày hiệu lực của policy.
2. Source link, source code và ngày kiểm chứng nằm cạnh công thức.
3. Input doanh thu, ngành nghề và tỷ lệ được nhóm theo trình tự tính.
4. Kết quả tách GTGT, TNCN, tổng và cảnh báo dữ liệu thiếu.
5. Nếu chưa có MST, hiển thị readiness card:
   - "Chưa cập nhật mã số thuế".
   - CTA "Cập nhật hồ sơ".
   - Disable xuất XML.
6. Export success phải cho biết kỳ, file và thời điểm tạo.

Tiêu chí nghiệm thu:

- Không dùng `N/A` cho dữ liệu bắt buộc.
- Không xuất XML khi MST hoặc kỳ không hợp lệ.
- Người dùng nhìn thấy nguồn và trạng thái "ước tính".
- UI không khẳng định đạt chuẩn HTKK nếu chưa có biên bản kiểm thử.

### 7.8 Settings và phân quyền

Vấn đề:

- Trang dài, thiếu search.
- Title Case không nhất quán.
- Tên shop bị cắt.
- Thiết lập AI dùng ngôn ngữ tuyệt đối.

Thiết kế mục tiêu:

1. Search settings theo tên chức năng.
2. Nhóm:
   - Cửa hàng và hồ sơ.
   - Nhân viên và quyền.
   - Bán hàng và kho.
   - Tài chính và thuế.
   - Giao diện và thông báo.
   - Trợ giúp và nguồn tài liệu.
3. Mỗi row có title, mô tả ngắn và trạng thái nếu cần.
4. Readiness card ở đầu trang cho MST, hồ sơ và cấu hình bắt buộc.
5. Dùng sentence case cho toàn bộ title.
6. Trợ lý AI đổi thành "Trợ giúp nghiệp vụ" hoặc "Tra cứu tài liệu".

Tiêu chí nghiệm thu:

- Tìm được một thiết lập trong tối đa 3 thao tác.
- Tên shop quan trọng hiển thị tối đa 2 dòng.
- Employee không nhìn thấy setting không có quyền.
- Không có copy "100%" hoặc cam kết không thể chứng minh.

### 7.9 Auth và onboarding

Thiết kế mục tiêu:

1. Form có label phía trên, helper và error phía dưới.
2. OTP thể hiện thời gian chờ, gửi lại và số lần thử còn lại mà không lộ thông tin.
3. Onboarding chia theo mục tiêu: tài khoản, cửa hàng, hồ sơ thuế, hoàn tất.
4. Có progress rõ nhưng không dùng các nhãn chung kiểu "Bước 1".
5. Khi hoàn tất, đưa người dùng tới checklist khởi tạo dữ liệu thay vì dashboard rỗng.

## 8. Làm giao diện bớt "AI"

### 8.1 Thay đổi định vị

Không trình bày AI như nhân vật trung tâm của ứng dụng. SmartStock là công cụ quản
lý cửa hàng; AI chỉ là lớp hỗ trợ.

Tên đề xuất:

| Hiện tại | Đề xuất |
|---|---|
| Hỏi AI Trí Thức | Tra cứu hướng dẫn |
| Trợ Lý AI Tri Thức (RAG) | Trợ giúp nghiệp vụ |
| Kiểm Soát Tri Thức Trợ Lý AI 100% | Nguồn tài liệu đang sử dụng |
| AI chỉ trả lời từ... | Câu trả lời ưu tiên các nguồn đã bật |
| AI học | Thêm vào nguồn tham khảo |

Nếu backend chưa có truy xuất ngữ nghĩa, citation và phân quyền nguồn, UI phải dùng
tên "Tra cứu tài liệu cục bộ", không dùng từ RAG.

### 8.2 Vị trí và hình thức

Desktop:

- Một icon `help/search` trong header.
- Mở side panel 380-420px.
- Panel không che main navigation.
- Có nút mở trang quản lý nguồn riêng.

Mobile:

- Mở full-screen sheet từ app bar hoặc menu "Trợ giúp".
- Không dùng bubble nổi.
- Không hiển thị trong POS, QR payment hoặc modal xác nhận.

Visual:

- Nền surface trung tính.
- Không robot emoji.
- Không gradient tím, glow hoặc animation loop.
- Accent chỉ dùng cho send button, source link và focus state.
- Answer dùng typography thông thường, không dùng chat bubble cho đoạn dài.

### 8.3 Cấu trúc câu trả lời

1. Kết luận ngắn.
2. Nội dung có cấu trúc.
3. Nguồn tham khảo.
4. Ngày hiệu lực hoặc ngày cập nhật.
5. Trạng thái "không đủ nguồn" khi không thể trả lời.

### 8.4 Các trạng thái bắt buộc

- Chưa nhập câu hỏi.
- Đang tìm nguồn.
- Có câu trả lời và citation.
- Không đủ nguồn.
- Nguồn hết hiệu lực.
- Lỗi mạng.
- Người dùng không có quyền xem nguồn.

## 9. Component dùng chung cần chuẩn hóa

| Component | Nội dung bắt buộc |
|---|---|
| `AppPageHeader` | Title, subtitle/context, tối đa 2 actions |
| `MetricTile` | Label, value, period/asOf, trend, state, drill-down |
| `StatusBanner` | Severity, message, action, dismiss policy |
| `FilterBar` | Search, period, status, filter count, reset |
| `AppDataTable` | Sort, empty, error, loading, mobile fallback |
| `AppListCard` | Primary identity, metadata, status, primary action |
| `AppSkeleton` | Hình dạng khớp layout thật |
| `AppEmpty` | Lý do, hướng xử lý, một CTA |
| `AppError` | Lỗi an toàn, retry, support ID nếu có |
| `StickyActionBar` | Safe area, keyboard inset, disabled/loading |
| `ReadinessCard` | Dữ liệu bắt buộc còn thiếu và CTA hoàn thiện |
| `SourceCitation` | Tên nguồn, version, hiệu lực, link |

## 10. Loading, empty, error và offline

### Loading

- Skeleton phải giống hình dạng dữ liệu thật.
- Summary và list dùng cùng trạng thái period/filter.
- Không hiển thị `0` trong lúc đang tải.
- Không dùng spinner toàn trang nếu vẫn có thể giữ dữ liệu cũ.

### Empty

- Giải thích vì sao trống.
- Có một hành động phù hợp.
- Không dùng minh họa robot hoặc copy vui quá mức.
- Nếu do filter, CTA là "Xóa bộ lọc".

### Error

- Lỗi inline tại vùng bị ảnh hưởng.
- Giữ các khu vực khác vẫn dùng được.
- Không lộ stack trace hoặc tên bảng.
- Retry không tạo giao dịch trùng.

### Offline hoặc mạng yếu

- Cho biết dữ liệu đang hiển thị có thể cũ.
- Hiển thị thời điểm cập nhật gần nhất.
- Không cho xác nhận giao dịch nếu trạng thái server chưa rõ.

## 11. Motion và phản hồi tương tác

Mục tiêu motion là phản hồi, không phải trình diễn.

| Tình huống | Motion đề xuất |
|---|---|
| Button press | Scale nhẹ 0.98 trong 80-120ms |
| Route transition | Fade/slide 160-200ms |
| Filter thay đổi | Cross-fade dữ liệu 160ms |
| Bottom sheet | Material spring nhẹ |
| Expand/collapse | Height + opacity 180-220ms |
| Success | Check icon ngắn, không confetti |
| Loading | Skeleton shimmer chậm |

Quy tắc:

- Chỉ animate transform và opacity khi có thể.
- Tôn trọng reduced motion.
- Không dùng perpetual floating, pulse hoặc shimmer ngoài loading.
- Không animate KPI từ 0 nếu có thể làm người dùng hiểu sai số.
- Không dùng animation khi cập nhật hàng loạt bảng dữ liệu.

## 12. Responsive và accessibility

### 12.1 Viewport nghiệm thu

- 360x800: Android nhỏ.
- 390x844: mobile chuẩn audit.
- 430x932: mobile lớn.
- 768x1024: tablet portrait.
- 1024x768: tablet landscape.
- 1366x768: laptop.
- 1440x900: desktop chuẩn audit.

### 12.2 Tiêu chí responsive

- Không overflow ngang ngoài data table có chủ đích.
- Không component bị cắt nửa ở mép viewport.
- Không overlay che CTA, nav hoặc dữ liệu cuối trang.
- Sticky action tôn trọng safe area và bàn phím ảo.
- Nội dung quan trọng tối đa 2 dòng trước khi truncate.
- Mọi table có mobile fallback được xác định.

### 12.3 Tiêu chí accessibility cần kiểm thử

- Contrast body text tối thiểu 4.5:1.
- Contrast text lớn và icon chức năng tối thiểu 3:1.
- Touch target tối thiểu 44x44.
- Focus ring luôn nhìn thấy trên Flutter Web.
- Dùng được bằng bàn phím theo thứ tự hợp lý.
- Mọi icon-only button có semantic label và tooltip.
- Screen reader đọc đúng title, value, unit và trạng thái KPI.
- Zoom 200% không mất chức năng.
- Reduced motion tắt motion không cần thiết.

Không ghi nhận accessibility đạt chuẩn trước khi chạy kiểm thử chuyên biệt.

## 13. Thứ tự triển khai chi tiết

### Giai đoạn A: Khóa nền tảng thiết kế

Mục tiêu:

- Có token và component rules thống nhất trước khi sửa từng màn.

Công việc:

1. Chụp baseline desktop/mobile cho các route chính.
2. Kiểm kê font, màu, radius, spacing, icon, shadow và z-index.
3. Chốt semantic tokens light/dark.
4. Chốt typography scale.
5. Chốt radius và spacing scale.
6. Định nghĩa responsive breakpoints và safe-area policy.
7. Lập component inventory và mapping component cũ sang component mục tiêu.

Đầu ra:

- Design token specification.
- Component inventory.
- Screenshot baseline.
- UI Definition of Done.

Độ khó: M
Phụ thuộc: Không
Không thay đổi API hoặc nghiệp vụ.

### Giai đoạn B: App shell và navigation

Mục tiêu:

- Loại mọi vấn đề che nội dung và tạo cấu trúc nhất quán.

Công việc:

1. Chuẩn hóa sidebar, navigation rail và bottom navigation.
2. Chuẩn hóa page header.
3. Di chuyển trợ giúp khỏi FAB.
4. Chuẩn hóa content max width và page padding.
5. Xây safe-area calculation chung.
6. Kiểm tra route active state và permission visibility.

Đầu ra:

- Shell responsive hoàn chỉnh.
- Không còn AI FAB.
- Header và navigation thống nhất.

Độ khó: M
Phụ thuộc: Giai đoạn A.

### Giai đoạn C: Luồng bán hàng cốt lõi

Mục tiêu:

- Tối ưu tác vụ tạo đơn và quản lý đơn.

Công việc:

1. Nâng cấp POS.
2. Chuẩn hóa product row và stock disabled state.
3. Hoàn thiện sticky cart và checkout sheet.
4. Nâng cấp sales summary, period/filter và list.
5. Chuẩn hóa order detail, return, cancel và payment states.
6. Kiểm thử mobile với bàn phím ảo.

Độ khó: L
Phụ thuộc: Giai đoạn A, B và metric contract cho sales.

### Giai đoạn D: Dashboard, kho, tài chính và công nợ

Mục tiêu:

- Tạo một hệ thống số liệu rõ nguồn, rõ kỳ và dễ xử lý.

Công việc:

1. Nâng cấp `MetricTile` và period/asOf.
2. Tái cấu trúc dashboard.
3. Ưu tiên inventory action list.
4. Tách balance khỏi cash flow.
5. Chuẩn hóa debt summary và debt card.
6. Thay chart không phù hợp bằng dạng thông tin gọn hơn.

Độ khó: L
Phụ thuộc: Metric contract và đối soát dữ liệu.

### Giai đoạn E: Thuế, settings và trợ giúp nghiệp vụ

Mục tiêu:

- Tăng độ tin cậy, giảm ngôn ngữ AI và hỗ trợ hoàn thiện hồ sơ.

Công việc:

1. Tạo readiness card.
2. Nâng cấp settings search và grouping.
3. Thiết kế tax source/version presentation.
4. Thay AI FAB bằng help entry và source-first panel.
5. Chuẩn hóa copy, error và permission state.
6. Bổ sung trạng thái nguồn hết hiệu lực và không đủ nguồn.

Độ khó: M-L
Phụ thuộc: Tax policy metadata và quyết định sản phẩm về AI thật hay tra cứu cục bộ.

### Giai đoạn F: QA, rollout và đo lường

Mục tiêu:

- Chứng minh bản nâng cấp đẹp, dùng được và không làm hỏng nghiệp vụ.

Công việc:

1. Golden/screenshot regression cho route chính.
2. Widget test cho loading, empty, error và responsive.
3. Keyboard, screen reader, contrast, zoom và reduced motion.
4. Smoke test production desktop/mobile.
5. Kiểm tra không có dữ liệu demo.
6. Theo dõi runtime error, API error và thời gian tải sau release.
7. Thu phản hồi từ chủ cửa hàng và nhân viên bán hàng.

Độ khó: M
Phụ thuộc: Hoàn tất các giai đoạn triển khai.

## 14. Backlog UI/UX đề xuất

| ID | Hạng mục | Ưu tiên | Độ khó | Phụ thuộc | Tiêu chí đóng |
|---|---|---|---|---|---|
| UI-P0-01 | Loại AI FAB và vùng che nội dung | P0 | M | App shell | Không overlay tại mọi viewport |
| UI-P0-02 | Disabled sản phẩm hết hàng trong POS | P0 | S | Stock contract | Không thể thêm vượt tồn |
| UI-P0-03 | Đồng bộ period/filter sales | P0 | M | Metric contract | Summary, chart, list khớp |
| UI-P0-04 | Phân biệt balance và flow | P0 | M | Finance contract | Label, period, asOf rõ |
| UI-P0-05 | Loại dữ liệu demo khỏi production UI | P0 | M | Data cleanup plan | Không còn sim/test label |
| UI-11-01 | Chuẩn hóa token và component | V1.1 | M | Không | Theme và component spec được duyệt |
| UI-11-02 | App shell responsive | V1.1 | M | UI-11-01 | 7 viewport đạt |
| UI-11-03 | Dashboard hierarchy mới | V1.1 | M | MetricTile | KPI và alert rõ |
| UI-11-04 | POS mobile tối ưu một tay | V1.1 | L | Shell, stock | Luồng thanh toán hoàn tất |
| UI-11-05 | Sales table/card mới | V1.1 | M | FilterBar | Desktop/mobile đạt |
| UI-11-06 | Inventory action-first | V1.1 | M | MetricTile | Cần xử lý nằm đầu |
| UI-11-07 | Finance source-first | V1.1 | M | Finance contract | Drill-down được |
| UI-11-08 | Debt card và export hierarchy | V1.1 | S | Debt API | Nhãn không cắt |
| UI-12-01 | Tax readiness và source version | V1.2 | M | Tax metadata | Không nhầm ước tính/kê khai |
| UI-12-02 | Settings search và grouping | V1.2 | M | Permission map | Tìm trong 3 thao tác |
| UI-12-03 | Trợ giúp nghiệp vụ source-first | V1.2 | L | Product decision | Citation và trạng thái đủ |
| UI-12-04 | Accessibility hardening | V1.2 | L | Component chuẩn | Test chuyên biệt đạt |
| UI-12-05 | Screenshot regression | V1.2 | M | Stable UI | CI phát hiện lệch giao diện |

## 15. Rủi ro và cách kiểm soát

| Rủi ro | Tác động | Kiểm soát |
|---|---|---|
| Đẹp hơn nhưng chậm thao tác | Giảm năng suất | Test task completion với người dùng thật |
| Đổi vị trí nav làm người dùng lạc | Mất muscle memory | Giữ label và route, rollout theo shell trước |
| Thay KPI layout khi metric chưa chuẩn | Làm sai lệch rõ hơn | Chốt metric contract trước dashboard |
| Quá nhiều motion trên máy yếu | Giật, khó dùng | Motion 3/10, reduced motion, profiling |
| Dark mode thiếu contrast | Khó đọc | Token test và contrast audit |
| AI đổi tên nhưng năng lực vẫn mơ hồ | Mất niềm tin | Label theo năng lực thật, citation-first |
| Component rewrite diện rộng | Regression | Thay từng nhóm, screenshot regression |
| Font tải mạng chậm | Flash text và CLS | Bundle font, preload phù hợp |

## 16. Chiến lược rollout

1. Hoàn thiện token và component trong phạm vi nội bộ.
2. Nâng cấp shell và một màn mẫu là dashboard.
3. So sánh bản cũ và bản mới trên cùng dữ liệu.
4. Nghiệm thu với ít nhất một chủ cửa hàng và một nhân viên bán hàng.
5. Mở rộng sang POS và sales.
6. Mở rộng sang kho, tài chính, công nợ.
7. Hoàn thiện settings, tax và trợ giúp.
8. Deploy staging, chạy screenshot regression và accessibility test.
9. Release production theo từng nhóm route, không gom tất cả vào một đợt.
10. Theo dõi lỗi, thời gian hoàn thành tác vụ và phản hồi sau release.

## 17. Chỉ số đánh giá thành công

### Hiệu quả tác vụ

- Mở POS từ dashboard trong tối đa 1 thao tác.
- Tạo đơn cơ bản giảm số thao tác không cần thiết.
- Tìm một setting trong tối đa 3 thao tác.
- Xác định sản phẩm cần nhập lại trong tối đa 10 giây.
- Xác định kỳ của KPI mà không cần mở tooltip.

### Chất lượng giao diện

- Không overflow hoặc overlay tại 7 viewport chuẩn.
- Không copy tuyệt đối như "100%" nếu không có bằng chứng.
- Không emoji làm icon chức năng.
- Không dùng gradient hoặc shadow trên card dữ liệu thông thường.
- Không có Title Case không cần thiết.
- Không có dữ liệu demo trên production.

### Chất lượng hệ thống

- Flutter analyze và test đạt.
- Backend build, lint và P0 test đạt.
- Screenshot regression đạt.
- Không tăng runtime error sau release.
- Core Web/Flutter Web load performance không giảm đáng kể so với baseline.

## 18. Definition of Done cho từng màn

Một màn chỉ được coi là hoàn tất khi:

1. Có bản desktop, tablet và mobile.
2. Có loading, empty, error, disabled và permission-denied state phù hợp.
3. Không bị overflow, clip hoặc overlay.
4. Text, số, ngày và tiền dùng format nhất quán.
5. KPI có period hoặc asOf.
6. CTA chính rõ và không có CTA trùng ý định.
7. Keyboard, screen reader, focus và contrast đã kiểm tra.
8. Reduced motion hoạt động.
9. Widget test và screenshot regression đạt.
10. Smoke test production trên dữ liệu không phá hủy đạt.
11. BA acceptance criteria và traceability được cập nhật.
12. Không thay đổi nghiệp vụ ngoài yêu cầu đã duyệt.

## 19. Phạm vi chưa thực hiện trong tài liệu này

- Chưa sửa code Flutter.
- Chưa thay đổi API hoặc database.
- Chưa xóa dữ liệu demo.
- Chưa thiết kế Figma chi tiết từng màn.
- Chưa thay logo hoặc tên SmartStock.
- Chưa xây backend RAG.
- Chưa công nhận accessibility hoặc HTKK đạt chuẩn.
- Chưa ước lượng chi phí chính thức.

## 20. Đầu ra cần tạo khi kế hoạch được duyệt

1. UI inventory và token specification.
2. Wireframe desktop/mobile cho 9 nhóm màn.
3. Prototype tương tác cho dashboard, POS và tax.
4. Component specification cho 12 component dùng chung.
5. Copy deck tiếng Việt.
6. Responsive behavior matrix.
7. Accessibility checklist.
8. Screenshot regression baseline.
9. Implementation tickets theo backlog tại mục 14.
10. Biên bản nghiệm thu người dùng.

## 21. Khuyến nghị quyết định

Nên chọn hướng **targeted evolution**, không redesign toàn bộ từ đầu.

Lý do:

- Kiến trúc điều hướng và nhận diện hiện tại vẫn dùng được.
- Material 3, Outfit, HugeIcons và semantic colors đã có nền tảng tốt.
- Vấn đề lớn nằm ở hierarchy, consistency, data clarity, responsive và AI
  presentation.
- Targeted evolution giảm rủi ro phá luồng bán hàng và muscle memory.

Thứ tự nên duyệt:

1. Design system và app shell.
2. POS và sales.
3. Dashboard và metric presentation.
4. Kho, tài chính và công nợ.
5. Thuế, settings và trợ giúp nghiệp vụ.
6. Accessibility, regression và rollout.
