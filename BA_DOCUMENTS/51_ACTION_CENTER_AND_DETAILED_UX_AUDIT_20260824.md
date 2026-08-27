# Action Center chuẩn hóa và audit UX chi tiết

## 1. Phạm vi và phiên bản bằng chứng

- Ngày kiểm tra: 24/08/2026.
- Phạm vi thay đổi: Dashboard Action Center, điều hướng có bộ lọc và tài liệu audit.
- Không thay đổi database schema, migration, công thức thuế hoặc dữ liệu production.
- Không deploy trong vòng này.
- Bằng chứng dùng: yêu cầu nghiệp vụ, mã nguồn, API contract, build web cục bộ, kiểm thử tự động và ảnh chụp cục bộ.
- Production chưa có endpoint mới nên trạng thái dữ liệu Action Center trên production là **Chưa xác minh** cho tới khi frontend/backend cùng được deploy.

## 2. Nguyên nhân gốc đã xác minh

| Hạng mục | Trước thay đổi | Kết luận |
|---|---|---|
| Thứ tự việc cần làm | Flutter tự ghép `Thuế → Kho → Công nợ` | Không chính xác: màu được gán sau khi ghép, không tham gia xếp ưu tiên |
| Nguồn severity | Suy luận rời rạc tại từng provider Flutter | Không có nguồn chuẩn thống nhất |
| Trạng thái API lỗi | Ba nguồn tải riêng, khó phân biệt lỗi toàn khối | Có nguy cơ hiểu nhầm dữ liệu thiếu |
| Chiều cao desktop | Biểu đồ 440px, danh sách giới hạn 344px | Hai khối mất cân đối |
| Mobile | Danh sách có vùng cuộn riêng | Có nguy cơ cuộn lồng với trang chính |

## 3. Contract đã triển khai

`GET /api/dashboard/action-items`

```text
asOf
items[]
  actionKey
  severity: CRITICAL | WARNING | INFO | HEALTHY
  priorityScore
  title
  detail
  badge
  count
  amount
  dueAt
  sourceUpdatedAt
healthySummary[]
```

Quy tắc đã áp dụng:

1. Backend xếp `severity → priorityScore → dueAt → actionKey`.
2. Điểm ưu tiên dùng số ngày quá hạn, số bản ghi bị ảnh hưởng, số tiền và mức thiếu tồn.
3. Hết hàng, lô đã hết hạn, nợ quá hạn và nghĩa vụ thuế quá hạn là `CRITICAL`.
4. Dưới `min_stock`, nghĩa vụ thuế sắp đến hạn và cấu hình thuế không hợp lệ là `WARNING`.
5. Cảnh báo sắp hết hạn chỉ xuất hiện khi DB có `INVENTORY_EXPIRY_WARNING_DAYS`; cảnh báo nghĩa vụ thuế sắp đến hạn chỉ xuất hiện khi có `TAX_OBLIGATION_WARNING_DAYS`. Flutter không tự đặt ngưỡng.
6. Quyền Kho, Công nợ và Tài chính được lọc độc lập theo từng membership và từng cửa hàng.
7. Backend không trả route Flutter; frontend ánh xạ `actionKey` sang route và query filter.
8. API lỗi được hiển thị là lỗi có nút thử lại; không đổi thành số 0 hoặc trạng thái ổn định.

## 4. Trạng thái nghiệm thu Dashboard

| Tiêu chí | Trạng thái | Bằng chứng |
|---|---|---|
| CRITICAL đứng trước WARNING/INFO/HEALTHY | Đã xác minh | Backend test thứ tự và tie-break đạt 5/5 |
| RBAC và tất cả cửa hàng | Đã xác minh một phần | Pure test xác nhận chỉ giữ shop có quyền; cần integration test có DB riêng để kiểm chứng truy vấn đầy đủ |
| Typed model, không fallback giả | Đã xác minh | Flutter unit test đạt 3/3; parser từ chối contract thiếu/sai nhóm |
| 0 việc cần xử lý | Đã xác minh | Widget test hiển thị “Không có việc cần xử lý ngay” |
| 1, 3 và trên 5 việc | Đã xác minh | Test click với 1 mục, mobile với 3 mục và desktop với 6 mục |
| Trên 5 mục có cuộn | Đã xác minh | Widget test với 6 mục, danh sách desktop có scroll |
| Click mở bộ lọc đúng | Đã xác minh | Widget test công nợ mở `status=overdue`; route Kho/Thuế nhận query tương ứng |
| Desktop hai khối cùng cao | Đã xác minh | Build cục bộ 1440px: biểu đồ và Action Center cùng 440px |
| Mobile không cuộn lồng | Đã xác minh bằng code/test phạm vi | Mobile dùng `Column`, không tạo `ListView` riêng trong Action Center |
| Loading/error/retry | Đã xác minh | Ảnh cục bộ thấy skeleton theo hàng và lỗi có “Thử lại” khi endpoint production chưa tồn tại |
| Dữ liệu DB production của endpoint mới | Bị chặn | Chưa deploy backend mới; không được phép coi lỗi API là “ổn định” |

## 5. Audit năm màn lõi

### 5.1 Dashboard `/`

| Phát hiện | Mức | Nguyên nhân | Hướng xử lý / tiêu chí nghiệm thu |
|---|---:|---|---|
| Action Center hard-code sai ưu tiên | P0 | UI tự ghép ba provider | **Đã sửa**: backend là nguồn chuẩn; mục đỏ đầu tiên mang số 1 |
| Hai cột mất cân đối | P1 | 440px so với max 344px | **Đã sửa**: desktop cùng 440px; mobile tự co |
| Dữ liệu lỗi có thể bị hiểu là 0 | P0 | Fallback phân tán | **Đã sửa**: lỗi riêng, retry, không dựng số |
| Biểu đồ rộng có thanh cuộn ngang ở 1440px | P2 | Nhiều cột theo ngày và bề rộng tối thiểu | Giữ nếu cần đọc đủ ngày; bổ sung affordance “Kéo để xem” và test bàn phím trước V1.2 |
| FAB có thể che phần cuối bảng sản phẩm bán chạy | P1 | FAB cố định, khoảng đệm phụ thuộc màn | Kiểm tra lại tại 390/768/1440; hàng cuối phải nhìn và bấm được hoàn toàn |

### 5.2 Bán hàng `/sales`

| Phát hiện | Mức | Trạng thái / hướng xử lý |
|---|---:|---|
| Bộ lọc nằm sát “Danh sách đơn hàng” và có mô tả phạm vi | Đạt | Không còn gây hiểu nhầm lọc biểu đồ/KPI |
| Kỳ, tìm kiếm, trạng thái thay đổi query danh sách | Đã xác minh bằng code | Cần integration test ghi nhận query backend thực tế |
| Danh sách dùng `ListView` không cuộn bên trong trang | Đạt | Tránh xung đột scroll |
| FAB “Ghi nhận bán hàng” có khoảng đệm cuối 112px | Đạt một phần | Cần screenshot regression tại danh sách dài và 390px |
| KPI/bảng cần mô tả đơn vị và thời điểm nhất quán | P1 | Dùng cùng period label; cần audit dữ liệu production sau deploy |

### 5.3 Kho `/inventory`

| Phát hiện | Mức | Trạng thái / hướng xử lý |
|---|---:|---|
| KPI có route thao tác nhanh | Đạt | Tổng SP, dưới định mức, sắp/quá hạn, giá trị tồn đều có route |
| Click Action Center cần mở đúng vấn đề | Đã sửa | `issue=low-stock/expired/expiring` làm nổi đúng panel liên quan |
| Cảnh báo hết hạn trước đây dùng mặc định 30 ngày | P0 dữ liệu | Action Center mới chỉ sinh “sắp hết hạn” khi DB có cấu hình ngày cảnh báo |
| Số lượng khác đơn vị không được cộng thành một tổng vật lý | Đạt một phần | UI dùng số SKU/giá trị; tiếp tục cấm cộng bao+mét+bộ thành “tổng số lượng” |
| Panel ít dữ liệu tự co | Đạt | Không kéo một dòng thành card cao cố định |

### 5.4 Tài chính `/finance`

| Phát hiện | Mức | Trạng thái / hướng xử lý |
|---|---:|---|
| Bốn KPI đã bấm được | Đạt | Có `onTap` và `navigationHint` |
| Hai panel chính cân bằng loading 406px | Đạt desktop | Mobile xếp dọc; cần regression tại dữ liệu rỗng |
| 12 công cụ là danh mục route tĩnh, không phải dữ liệu nghiệp vụ giả | Đúng | Nội dung giao dịch và biểu đồ vẫn lấy API/DB |
| Màn nghĩa vụ thuế còn nút icon 28×28 | P1 | Tăng vùng bấm tối thiểu 44×44 và giữ tooltip/semantic label |
| Màn nghĩa vụ thuế dùng gradient/radius riêng, lệch design system | P2 | Chuẩn hóa về card token hiện hành sau vòng Action Center |

### 5.5 Cài đặt `/settings`

| Phát hiện | Mức | Trạng thái / hướng xử lý |
|---|---:|---|
| Tìm kiếm nằm sát phạm vi danh sách thiết lập | Đạt | Lọc trực tiếp sections/entries |
| Các mục “Sắp có” vẫn bấm được và mở toast | P2 | Chuyển sang trạng thái disabled có mô tả hoặc route roadmap; không làm giống chức năng sẵn sàng |
| Trung tâm thông báo chưa tách “thông báo” và “cần xử lý” | Đã sửa một phần | Query `filter=actionable` mở Action Center đầy đủ; thông báo thường giữ luồng cũ |
| Card thông báo thường dùng `GestureDetector` | P1 accessibility | Đổi sang `Material + InkWell + Semantics`, đảm bảo focus và phản hồi bấm |

## 6. Audit toàn bộ route

Đã kiểm kê 58 route trong `app_router.dart`. Trạng thái dưới đây là audit mã nguồn; không được hiểu là tất cả đã qua kiểm thử production.

| Nhóm | Route | Trạng thái audit |
|---|---|---|
| Xác thực | `/login`, `/register`, `/verify-otp`, `/forgot-password`, `/onboarding`, `/waiting-approval` | Đã soi cấu trúc; cần test bàn phím, autofill, Dynamic Type và Google OAuth trên domain deploy |
| Bán hàng | `/sales`, `/sales/new`, `/pos` redirect, `/sales/:id`, `/sales/returns/:id`, `/customer-debts` | Màn danh sách và công nợ đã soi sâu; form/chi tiết cần regression giao dịch thành công, hủy, hoàn và thanh toán |
| Sản phẩm | `/products`, `/products/tags`, `/products/form`, `/products/:id` | Đã soi route và state chính; cần test ảnh, đơn vị quy đổi, lịch sử giá, lô/hạn dùng với dữ liệu dài |
| Đối tác | `/customers*`, `/suppliers*` | Đã soi route; cần test empty/error, bảng dài, ảnh chứng từ và quyền sửa/xóa |
| Kho | `/inventory`, `/stock-take`, `/purchase-orders*`, `/xnt-report` | Dashboard kho đã soi sâu; cần test biểu mẫu 390px và nội dung không bị CTA che |
| Tài chính | `/finance`, `/daily-closing`, `/profit-loss`, `/cashflow-forecast`, `/debt-aging`, `/supplier-payables-aging`, `/invoices`, `/purchases-no-invoice`, `/tax-calculator`, `/expense-ledger`, `/tax-obligations`, `/salary-ledger`, `/tax-declaration`, `/transactions*`, `/tax-estimate` | Màn tổng quan đã soi sâu; các màn cũ còn mật độ/radius/touch target chưa đồng nhất, ưu tiên xử lý P1 trước |
| Cài đặt | `/settings`, `/settings/ai-knowledge`, `/activity-logs`, `/tax-config`, `/tax-support`, `/payment-config`, `/notifications`, `/staff`, `/employees`, `/roles`, `/profile`, `/change-password`, `/shop-profile` | Tổng quan đã soi sâu; staff/role cần test RBAC và bảng dài, notifications cần nâng accessibility |

## 7. Backlog sau vòng chuẩn hóa UX

| Ưu tiên | Vấn đề | Giải pháp | Tiêu chí nghiệm thu |
|---:|---|---|---|
| P0 | Chưa có integration test truy vấn Action Center với DB fixture | Tạo DB test cô lập cho 1 shop, all-shops, mixed RBAC | Đối soát count/amount/dueAt với SQL kiểm soát |
| P1 | Touch target 28px ở nghĩa vụ thuế | Chuẩn hóa icon button ≥44px | Bấm được bằng touch và keyboard, tooltip/semantic đúng |
| P1 | FAB có nguy cơ che hàng cuối | Chuẩn hóa bottom inset theo shell/FAB | Hàng cuối luôn hiển thị đủ ở 390/768/1440 |
| P1 | Chưa có screenshot regression tự động cho 5 màn | Tạo golden/widget harness với 0/ngắn/dài/lỗi | Sai khác layout bị CI phát hiện |
| P2 | “Sắp có” trông giống mục hoạt động | Disabled/roadmap state thống nhất | Không tạo kỳ vọng sai, vẫn giải thích được lý do |
| P2 | Một số màn tài chính dùng visual token cũ | Thay bằng AppCard/AppSpacing/AppRadius hiện hành | Không đổi nghiệp vụ; giao diện thống nhất 5 breakpoint |
| V1.2 | Lịch sử giá, đơn vị quy đổi, lô/hạn dùng chưa nổi bật | Đưa API hiện có lên Product Detail | Có loading/empty/error và audit log |
| V1.2 | Thiếu chuỗi chứng từ bán hàng | Báo giá → Đơn bán → Giao hàng → Hóa đơn | Truy vết được trạng thái và người thao tác |
| V1.2 | Thiếu thông tin giao công trình | Địa chỉ, lịch giao, bằng chứng giao | Mỗi đơn có timeline và chứng từ giao nhận |
| V1.2 | Chưa có đề xuất nhập hàng | Dùng tồn, tốc độ bán, min_stock, lead time | Giải thích được đầu vào; người dùng duyệt trước khi tạo đơn nhập |
| V2.0 | Chưa có so sánh NCC/điều chuyển | Chuẩn hóa báo giá NCC và luồng điều chuyển | Có quyền, audit và đối soát tồn hai đầu |

## 8. Kết luận

Action Center đã loại bỏ thứ tự hard-code và chuyển quyền quyết định severity/priority về backend. Vòng hiện tại **chưa hoàn thành xác minh production** vì endpoint mới chưa được deploy theo đúng yêu cầu “không deploy cho tới khi người dùng yêu cầu”. Sau khi được phép deploy, cần kiểm tra lại 5 màn ở 390, 768, 1440 và 1920px với dữ liệu rỗng/ngắn/dài trước khi đổi trạng thái production thành “Đã xác minh”.
