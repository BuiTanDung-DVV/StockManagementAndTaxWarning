# Báo cáo audit production UI, nghiệp vụ và code — 30/07/2026

## 1. Phạm vi và cách xác minh

- Frontend: [smartstock-tax.vercel.app](https://smartstock-tax.vercel.app)
- Backend: [stock-management-and-tax-warning.vercel.app](https://stock-management-and-tax-warning.vercel.app)
- Bản giao diện được chụp: commit `99c53f06`
- Viewport: desktop `1280×800`, mobile `390×844`
- Phạm vi: 43 route, tổng cộng 86 ảnh production.
- Cách đối chiếu: giao diện production → route frontend → service/API backend → dữ liệu đã nạp.

Trạng thái dùng trong báo cáo:

- `Đã xác minh`: đã có bằng chứng phù hợp trên production và code/API.
- `Đúng một phần`: có chức năng nhưng còn thiếu quy tắc, phản hồi hoặc tính nhất quán.
- `Không chính xác`: hành vi hoặc dữ liệu có thể dẫn đến kết quả sai.
- `Bị chặn`: chưa đủ quyền, dữ liệu hoặc kiểm thử chuyên biệt để kết luận.

Không ghi nhận đạt chuẩn accessibility. Ảnh chụp chỉ giúp nhận diện rủi ro về
reflow, kích thước mục tiêu, tương phản và khả năng đọc; keyboard, screen reader,
zoom 200% và thứ tự focus chưa được kiểm thử chuyên biệt.

## 2. Kết luận điều hành

Ứng dụng đã có phạm vi nghiệp vụ rộng và toàn bộ 43 route được mở thành công trên
hai viewport, không gặp màn trắng. Giao diện có hệ thống màu, card và điều hướng
khá nhất quán hơn các bản trước. Tuy nhiên chưa nên coi đây là bản ổn định cho vận
hành thật vì còn một rủi ro toàn vẹn giá ở backend và một số lỗi responsive nghiêm
trọng.

Ưu tiên xử lý:

1. `P0` — backend phải tự xác định giá bán hợp lệ; hiện tại API tạo đơn tin vào
   `unitPrice` do trình duyệt gửi lên.
2. `P1` — sửa biểu đồ cảnh báo ngưỡng thuế trên mobile vì nhãn đang chồng, vỡ dòng
   và gần như không đọc được.
3. `P1` — thiết lập vùng an toàn cho trợ lý AI và các nút hành động nổi; hiện tại
   chúng che bảng, trường nhập, biểu đồ và che lẫn nhau.
4. `P1` — POS cần hỗ trợ quy tắc giá sỉ/khuyến mại hoặc phải ghi rõ chỉ bán theo
   giá lẻ. Hiện POS luôn lấy `sellingPrice`.
5. `P1` — báo cáo XNT trên mobile cần chuyển sang thẻ theo sản phẩm hoặc có chỉ
   báo cuộn ngang rõ ràng; các cột bên phải hiện bị khuất.

## 3. Điểm đã làm tốt

- Dashboard có KPI chính, cảnh báo ưu tiên, xu hướng và sản phẩm bán chạy với thứ
  bậc thông tin tốt hơn.
- Bộ lọc bán hàng đã nằm ngay trên danh sách đơn, tránh hiểu nhầm rằng bộ lọc tác
  động lên biểu đồ/KPI.
- Danh mục sản phẩm đặt tìm kiếm, tag lọc, trợ giúp, cấu hình và nút thêm gần đúng
  ngữ cảnh.
- Các màn form, loading, empty và error cơ bản đã có cấu trúc thống nhất.
- Đơn vị tiền được bổ sung ở nhiều biểu đồ; sản phẩm hiển thị đơn vị tính như
  `Bao`, `Bộ`.
- 500/500 sản phẩm, 2/2 logo, 2/2 QR, 16.955/16.955 ảnh biên nhận,
  4.901/4.901 ảnh hóa đơn, 48/48 avatar và ảnh định danh khách hàng đã có URL ảnh
  trong dữ liệu production test.

## 4. Phát hiện nghiệp vụ và code

| ID | Mức | Trạng thái | Phát hiện và bằng chứng | Ảnh hưởng | Đề xuất / tiêu chí nghiệm thu |
|---|---|---|---|---|---|
| LOG-01 | P0 | Không chính xác | `backend/src/services/sales.service.ts` chỉ từ chối `unitPrice < 0`, sau đó tính tổng trực tiếp từ giá client gửi lên. API chưa đối chiếu giá sản phẩm hoặc quyền ghi đè giá. | Người gọi API có thể bán với giá tùy ý không âm; sai doanh thu, lợi nhuận, công nợ và thuế. | Backend tự chọn giá từ sản phẩm/chính sách giá. Ghi đè giá phải có quyền, lý do, biên độ và audit log. Test phải chứng minh request sửa giá trái phép bị từ chối. |
| LOG-02 | P1 | Đúng một phần | POS lấy `sellingPrice` ở cả tìm barcode, danh sách và payload đơn hàng. `wholesalePrice` không được áp dụng. | Có dữ liệu giá sỉ nhưng người bán không thể chọn đúng chính sách giá. | Bổ sung loại giá theo khách/đơn/số lượng; tổng tiền và hóa đơn phải dùng cùng giá đã được backend xác nhận. |
| LOG-03 | P2 | Đúng một phần | `/staff` và `/employees` cùng trỏ đến `StaffManagementScreen`. | Hai mục điều hướng tạo cảm giác có hai nghiệp vụ nhưng thực chất trùng nhau. | Gộp thành một route hoặc tách rõ “tài khoản nhân viên” và “hồ sơ/chấm công/lương”. |
| LOG-04 | P2 | Đúng một phần | Chi tiết sản phẩm luôn hard-code biểu tượng kho; không đọc `imageUrl`, dù danh sách sản phẩm có ảnh thật. | Dữ liệu ảnh đã nạp nhưng người dùng không nhìn thấy ở màn quan trọng nhất. | Chi tiết sản phẩm dùng cùng component ảnh với danh sách, có loading/error/fallback. |
| LOG-05 | P2 | Đã xác minh, cần làm rõ | Dashboard mặc định “tháng này”; màn ước tính thuế mặc định “tháng 01”. Hai số doanh thu khác nhau do khác kỳ, không phải bằng chứng sai công thức. | Người dùng dễ hiểu nhầm số liệu mâu thuẫn nếu không chú ý bộ chọn kỳ. | Hiển thị kỳ ngay trong tiêu đề/KPI và mặc định cùng kỳ hiện tại; thêm liên kết đối chiếu nguồn số liệu. |
| LOG-06 | P2 | Đúng một phần | Dữ liệu test dùng ảnh hóa đơn/biên nhận/định danh mẫu lặp lại theo cửa hàng, không phải tài liệu riêng cho từng giao dịch. | Đủ để kiểm thử upload/download nhưng không phù hợp để đánh giá nhận dạng tài liệu hoặc chống trùng. | Khi kiểm thử OCR/đối soát, tạo mẫu riêng theo mã giao dịch và đóng watermark “DỮ LIỆU TEST”. |
| LOG-07 | P2 | Đúng một phần | Màn thuế ghi ngưỡng 1 tỷ và viện dẫn Nghị định 141/2026/NĐ-CP. Nghị định tồn tại, ban hành 29/04/2026 và có hiệu lực từ 01/01/2026 theo nguồn Chính phủ. | Nội dung pháp lý có nguồn nhưng công thức, ngành nghề và biểu mẫu vẫn cần chuyên gia thuế duyệt. | Lưu phiên bản chính sách, ngày hiệu lực, nguồn và lịch sử thay đổi; không cho cấu hình cũ âm thầm ghi đè. Nguồn: [Cổng TTĐT Chính phủ](https://vanban.chinhphu.vn/?classid=1&docid=217960&orggroupid=2&pageid=27160). |

## 5. Phát hiện UI/UX

| ID | Mức | Màn hình | Phát hiện | Hướng xử lý |
|---|---|---|---|---|
| UI-01 | P1 | Toàn hệ thống | Trợ lý AI nổi ở giữa vùng nội dung, thường che dữ liệu, trường nhập và tooltip. Nút đóng cũng tạo thêm một điểm che. | Dock mặc định ở giữa-trái như yêu cầu, thêm thuật toán tránh vùng FAB/form/table, nhớ vị trí theo viewport và thu nhỏ khi có modal. |
| UI-02 | P1 | Inventory, roles, staff, purchases-no-invoice, salary-ledger | Nút AI và FAB hành động cùng dùng một lớp nổi nên chồng nhau. | Xây `FloatingActionCoordinator` với các slot cố định, safe area và thứ tự ưu tiên. |
| UI-03 | P1 | Tax calculator mobile | Nhãn “900M”, phần trăm và ngưỡng 1 tỷ bị vỡ thành từng ký tự, không đọc được. | Mobile dùng progress/gauge một chiều; chỉ giữ 3 mốc, nhãn ngắn và số định dạng `900 triệu`, `1 tỷ`. |
| UI-04 | P1 | XNT report mobile | Bảng rộng hơn viewport; các cột nhập/xuất/tồn cuối bị khuất và không có dấu hiệu cuộn rõ. | Mobile chuyển thành card 2 hàng hoặc sticky cột sản phẩm + thanh cuộn/gradient chỉ báo. |
| UI-05 | P2 | Product detail | Ảnh sản phẩm không xuất hiện, vẫn dùng icon chung. | Dùng ảnh Cloudinary với thumbnail tối ưu, fallback chỉ khi URL lỗi/rỗng. |
| UI-06 | P2 | Salary ledger | Chỉ có một thẻ số liệu và khoảng trống rất lớn; không thể đọc xu hướng hay đối chiếu nhân viên. | Thêm kỳ lương, tổng gross/net, trạng thái trả, bảng nhân viên và so sánh kỳ trước. |
| UI-07 | P2 | Roles | Nhiều chip quyền nhỏ và dày; khó quét nhanh trên mobile. | Gom quyền theo module, checkbox cấp nhóm, mô tả quyền nguy hiểm, tìm kiếm quyền. |
| UI-08 | P2 | Expense ledger | Donut + chú giải chật trên mobile, trợ lý AI che vùng đồ thị. | Chuyển chú giải xuống danh sách xếp hạng; cho phép chọn nhóm để lọc giao dịch. |
| UI-09 | P2 | Purchase without invoice | Nội dung dài, hai nút duyệt/từ chối chiếm ngang và va chạm với nút nổi. | Tách chi tiết mở rộng; hành động theo menu hoặc thanh cố định cuối card. |
| UI-10 | P2 | Notifications | Nhiều yêu cầu tham gia lặp lại, chưa có gom nhóm hoặc thao tác hàng loạt. | Gom theo cửa hàng/ngày, “đọc tất cả”, duyệt/từ chối hàng loạt có xác nhận. |
| UI-11 | P2 | Charts | Một số nhãn trục/đơn vị nhỏ, tooltip chỉ hiện số thô và màu là tín hiệu chính. | Chuẩn hóa formatter `triệu/tỷ`, tooltip có đơn vị, thêm pattern/nhãn để không phụ thuộc màu. |
| UI-12 | P2 | Forms | AI có thể che input; lỗi validation chủ yếu xuất hiện sau thao tác, chưa kiểm tra focus/keyboard. | Tạm ẩn/thu gọn AI khi mở form; kiểm thử tab order, focus lỗi và bàn phím mobile. |

## 6. Danh mục 43 màn hình đã chụp

Mỗi dòng có ảnh desktop và mobile. `Khỏe` nghĩa là route tải được, không có lỗi
trắng màn hình; không đồng nghĩa toàn bộ nghiệp vụ đã được kiểm thử.

| # | Màn hình | Sức khỏe | Desktop | Mobile |
|---:|---|---|---|---|
| 1 | Dashboard | Khỏe, còn va chạm AI | [Ảnh](assets/ui-audit-20260730/desktop/dashboard.png) | [Ảnh](assets/ui-audit-20260730/mobile/dashboard.png) |
| 2 | Lịch sử bán hàng | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/sales.png) | [Ảnh](assets/ui-audit-20260730/mobile/sales.png) |
| 3 | POS | Khỏe, thiếu giá sỉ | [Ảnh](assets/ui-audit-20260730/desktop/pos.png) | [Ảnh](assets/ui-audit-20260730/mobile/pos.png) |
| 4 | Công nợ khách hàng | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/customer-debts.png) | [Ảnh](assets/ui-audit-20260730/mobile/customer-debts.png) |
| 5 | Danh mục sản phẩm | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/products.png) | [Ảnh](assets/ui-audit-20260730/mobile/products.png) |
| 6 | Tag sản phẩm | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/product-tags.png) | [Ảnh](assets/ui-audit-20260730/mobile/product-tags.png) |
| 7 | Form sản phẩm | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/product-form.png) | [Ảnh](assets/ui-audit-20260730/mobile/product-form.png) |
| 8 | Chi tiết sản phẩm 3036 | Đúng một phần: thiếu ảnh | [Ảnh](assets/ui-audit-20260730/desktop/product-detail-3036.png) | [Ảnh](assets/ui-audit-20260730/mobile/product-detail-3036.png) |
| 9 | Khách hàng | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/customers.png) | [Ảnh](assets/ui-audit-20260730/mobile/customers.png) |
| 10 | Form khách hàng | Khỏe, AI che form | [Ảnh](assets/ui-audit-20260730/desktop/customer-form.png) | [Ảnh](assets/ui-audit-20260730/mobile/customer-form.png) |
| 11 | Nhà cung cấp | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/suppliers.png) | [Ảnh](assets/ui-audit-20260730/mobile/suppliers.png) |
| 12 | Form nhà cung cấp | Khỏe, AI che form | [Ảnh](assets/ui-audit-20260730/desktop/supplier-form.png) | [Ảnh](assets/ui-audit-20260730/mobile/supplier-form.png) |
| 13 | Quản lý kho | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/inventory.png) | [Ảnh](assets/ui-audit-20260730/mobile/inventory.png) |
| 14 | Kiểm kê kho | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/stock-take.png) | [Ảnh](assets/ui-audit-20260730/mobile/stock-take.png) |
| 15 | Đơn nhập hàng | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/purchase-orders.png) | [Ảnh](assets/ui-audit-20260730/mobile/purchase-orders.png) |
| 16 | Báo cáo XNT | Đúng một phần: bảng mobile khuất | [Ảnh](assets/ui-audit-20260730/desktop/xnt-report.png) | [Ảnh](assets/ui-audit-20260730/mobile/xnt-report.png) |
| 17 | Tổng quan tài chính | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/finance.png) | [Ảnh](assets/ui-audit-20260730/mobile/finance.png) |
| 18 | Chốt sổ ngày | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/daily-closing.png) | [Ảnh](assets/ui-audit-20260730/mobile/daily-closing.png) |
| 19 | Lãi lỗ | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/profit-loss.png) | [Ảnh](assets/ui-audit-20260730/mobile/profit-loss.png) |
| 20 | Dự báo dòng tiền | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/cashflow-forecast.png) | [Ảnh](assets/ui-audit-20260730/mobile/cashflow-forecast.png) |
| 21 | Tuổi nợ | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/debt-aging.png) | [Ảnh](assets/ui-audit-20260730/mobile/debt-aging.png) |
| 22 | Hóa đơn | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/invoices.png) | [Ảnh](assets/ui-audit-20260730/mobile/invoices.png) |
| 23 | Mua chưa hóa đơn | Đúng một phần: card quá dày | [Ảnh](assets/ui-audit-20260730/desktop/purchases-no-invoice.png) | [Ảnh](assets/ui-audit-20260730/mobile/purchases-no-invoice.png) |
| 24 | Công cụ tính thuế | Lỗi responsive P1 | [Ảnh](assets/ui-audit-20260730/desktop/tax-calculator.png) | [Ảnh](assets/ui-audit-20260730/mobile/tax-calculator.png) |
| 25 | Sổ chi phí | Đúng một phần: chart chật | [Ảnh](assets/ui-audit-20260730/desktop/expense-ledger.png) | [Ảnh](assets/ui-audit-20260730/mobile/expense-ledger.png) |
| 26 | Nghĩa vụ thuế | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/tax-obligations.png) | [Ảnh](assets/ui-audit-20260730/mobile/tax-obligations.png) |
| 27 | Sổ lương | Đúng một phần: thiếu nội dung | [Ảnh](assets/ui-audit-20260730/desktop/salary-ledger.png) | [Ảnh](assets/ui-audit-20260730/mobile/salary-ledger.png) |
| 28 | Kê khai thuế | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/tax-declaration.png) | [Ảnh](assets/ui-audit-20260730/mobile/tax-declaration.png) |
| 29 | Giao dịch | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/transactions.png) | [Ảnh](assets/ui-audit-20260730/mobile/transactions.png) |
| 30 | Ước tính thuế | Khỏe, kỳ mặc định tháng 01 | [Ảnh](assets/ui-audit-20260730/desktop/tax-estimate.png) | [Ảnh](assets/ui-audit-20260730/mobile/tax-estimate.png) |
| 31 | Cài đặt | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/settings.png) | [Ảnh](assets/ui-audit-20260730/mobile/settings.png) |
| 32 | Kho tri thức AI | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/ai-knowledge.png) | [Ảnh](assets/ui-audit-20260730/mobile/ai-knowledge.png) |
| 33 | Nhật ký hoạt động | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/activity-logs.png) | [Ảnh](assets/ui-audit-20260730/mobile/activity-logs.png) |
| 34 | Cấu hình thuế | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/tax-config.png) | [Ảnh](assets/ui-audit-20260730/mobile/tax-config.png) |
| 35 | Hỗ trợ thuế | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/tax-support.png) | [Ảnh](assets/ui-audit-20260730/mobile/tax-support.png) |
| 36 | Cấu hình thanh toán | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/payment-config.png) | [Ảnh](assets/ui-audit-20260730/mobile/payment-config.png) |
| 37 | Thông báo | Đúng một phần: thiếu gom nhóm | [Ảnh](assets/ui-audit-20260730/desktop/notifications.png) | [Ảnh](assets/ui-audit-20260730/mobile/notifications.png) |
| 38 | Nhân viên (`/staff`) | Khỏe nhưng trùng route | [Ảnh](assets/ui-audit-20260730/desktop/staff.png) | [Ảnh](assets/ui-audit-20260730/mobile/staff.png) |
| 39 | Nhân viên (`/employees`) | Khỏe nhưng trùng route | [Ảnh](assets/ui-audit-20260730/desktop/employees.png) | [Ảnh](assets/ui-audit-20260730/mobile/employees.png) |
| 40 | Vai trò và quyền | Đúng một phần: khó quét | [Ảnh](assets/ui-audit-20260730/desktop/roles.png) | [Ảnh](assets/ui-audit-20260730/mobile/roles.png) |
| 41 | Hồ sơ cá nhân | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/profile.png) | [Ảnh](assets/ui-audit-20260730/mobile/profile.png) |
| 42 | Đổi mật khẩu | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/change-password.png) | [Ảnh](assets/ui-audit-20260730/mobile/change-password.png) |
| 43 | Hồ sơ cửa hàng | Khỏe | [Ảnh](assets/ui-audit-20260730/desktop/shop-profile.png) | [Ảnh](assets/ui-audit-20260730/mobile/shop-profile.png) |

Contact sheet:

- [Desktop 1](assets/ui-audit-20260730/contact-desktop-1.jpg)
- [Desktop 2](assets/ui-audit-20260730/contact-desktop-2.jpg)
- [Desktop 3](assets/ui-audit-20260730/contact-desktop-3.jpg)
- [Desktop 4](assets/ui-audit-20260730/contact-desktop-4.jpg)
- [Mobile 1](assets/ui-audit-20260730/contact-mobile-1.jpg)
- [Mobile 2](assets/ui-audit-20260730/contact-mobile-2.jpg)
- [Mobile 3](assets/ui-audit-20260730/contact-mobile-3.jpg)

## 7. Lộ trình sửa đề xuất

### P0 — toàn vẹn giá bán

- Backend quyết định giá cuối cùng.
- Quyền ghi đè giá, lý do và audit log.
- Test API sửa `unitPrice`, giảm giá vượt biên độ, giá sỉ và hoàn hàng.

### V1.1 — responsive và vùng hành động

- Sửa tax threshold mobile.
- Điều phối AI/FAB, safe area, docking và lưu vị trí theo viewport.
- XNT mobile dạng card hoặc bảng có sticky column.
- Hiển thị ảnh ở chi tiết sản phẩm.

### V1.2 — hoàn thiện nghiệp vụ

- Chính sách giá lẻ/sỉ/khuyến mại thống nhất từ DB đến POS, đơn và hóa đơn.
- Hợp nhất hoặc tách rõ staff/employees.
- Nâng cấp sổ lương, quyền, thông báo và báo cáo.
- Chuẩn hóa formatter đơn vị và kỳ dữ liệu trên mọi KPI/biểu đồ.

## 8. Giới hạn bằng chứng

- Audit này xác minh khả năng tải và giao diện tĩnh của 43 route, không thay thế
  kiểm thử end-to-end cho mọi thao tác tạo/sửa/xóa.
- Console production không ghi nhận error/warning trong vòng điều hướng đã chụp,
  nhưng không chứng minh không có lỗi ở các trạng thái chưa kích hoạt.
- Chưa kiểm thử chuyên sâu accessibility, hiệu năng mạng chậm, thiết bị thật,
  upload file lớn, OCR, import HTKK hoặc khôi phục dữ liệu.
- Dữ liệu và ảnh production hiện là dữ liệu test; không dùng làm chứng từ thật.
