# Ma trận truy vết yêu cầu

> **Trạng thái hiện hành 01/08/2026 — production `093b17ac`, local `cc800da3`:**
> bảng E2E ngay dưới là nguồn trạng thái mới nhất. Các bảng baseline 25/07 được giữ phía sau để
> truy vết lịch sử, không được dùng để kết luận production hiện tại đã đạt.

## 0. Ma trận xác minh luồng end-to-end hiện hành

Quy ước: `Đã xác minh`, `Đúng một phần`, `Không chính xác`, `Bị chặn`. Một luồng chỉ được ghi
`Đã xác minh` khi yêu cầu, UI, API, dữ liệu và test cùng chứng minh một kết quả.

| Luồng/yêu cầu | UI/điểm vào | API và dữ liệu chính | Bằng chứng production | Bằng chứng local/test | Trạng thái | Việc bắt buộc để đóng |
|---|---|---|---|---|---|---|
| AUTH — đăng ký, OTP, login, refresh, logout | `/login`, `/register`, `/verify-otp` | `/auth/*`; `users`, `otps`, refresh-token family | Login và protected route hoạt động ở commit cũ | Auth hardening + backend P0 57/57 đạt; schema check xác nhận migration auth chưa chạy và còn 14 OTP chờ | Bị chặn | Phê duyệt hủy OTP cũ, backup, migration, cold-start và test OTP/refresh/reuse/logout production |
| SALE — POS, giá bán, thanh toán | `/pos`, `/sales` | `/sales-orders`, payments; products, orders, cash, receivables | POS/list tải được và hiện giá bán | Local chỉ nhận giá bán lẻ/sỉ/khuyến mại đã cấu hình; chặn giá tùy ý, giảm giá sai và đơn rỗng; pricing test đạt | Đúng một phần — production chưa deploy | Smoke test giá bán; thiết kế override cần quyền/lý do/audit; TC-SALE-08/01/02 đạt production |
| SALE — detail, hoàn/hủy | `/sales/:id`, modal hoàn | order detail, cancel, return; items, COGS, movements | List/detail cùng mã khác khách; hoàn không chọn dòng/số lượng | `findOne` thiếu relation customer; return chưa có item-level COGS | Không chính xác | Join customer; return theo item/quantity/cost lot; test nhiều lần hoàn và idempotency |
| PRODUCT/MEDIA — ảnh và giá | `/products`, `/products/:id`, form | product CRUD + Cloudinary lifecycle; `products.image_url` | List có ảnh thật nhưng detail hiện icon mặc định | Lifecycle thay/xóa ảnh đạt unit test | Đúng một phần | Một DTO/image contract cho list/detail/form; regression ảnh cũ bị xóa sau replace |
| INV/PURCHASE — tồn, nhập, kiểm kê, XNT | `/inventory`, `/purchase-orders`, `/stock-take`, `/xnt-report` | inventory, PO, stock take, movements, lots | KPI `20`/`112` mâu thuẫn; form PO 404; XNT mobile mất cột; có quantity 0 | KPI/min-stock đã sửa local; route form đã khai báo; chưa có invariant DB/concurrency test | Không chính xác | Deploy bản sửa sau gate; quantity > 0; unique tồn; XNT reconciliation và responsive test |
| DEBT — công nợ và thu nợ | `/customer-debts`, `/debt-aging`, customer detail | receivables, payment history, cash transactions | 453 khoản nợ tải thật; thiếu pagination; nợ vượt hạn mức không cảnh báo | Helper thu nợ/remaining đạt unit test | Đúng một phần | Server pagination; exposure/limit control; thu nợ cập nhật debt+cash trong một transaction |
| FIN — sổ quỹ, chi phí, lương, chốt ca, P&L | `/finance`, `/expense-ledger`, `/salary-ledger`, `/daily-closing`, `/profit-loss` | cash transactions, summaries, closings | Chi phí tổng 0 nhưng có dòng ngoài kỳ; tháng lương sai; ô trống tạo chênh lệch âm trên production hiện tại | Local đã dùng cùng kỳ cho tổng/list, lọc lương tại API, giữ tiền thực tế nullable; backend P0 49/49, Flutter mục tiêu 5/5 và analyze sạch | Đúng một phần — production chưa deploy | Deploy khi được duyệt; chạy TC-FIN-04/05/06 với dữ liệu production và đối soát DB |
| TAX — ước tính, cấu hình, nghĩa vụ, kê khai | `/tax-*`, `/tax-declaration` | `/tax/config`, `/tax/estimate`, `/tax/export-htkk`; tax rules/profile | Ngưỡng 1 tỷ có nguồn; kỳ/sort chưa đúng; chart mobile vỡ; “Nộp” chỉ mở hướng dẫn | Tax policy/MST 47/47 suite đạt | Đúng một phần, rủi ro cao | Rule version/effective date; sort kỳ; đổi đúng copy; XML qua XSD/HTKK fixture |
| RBAC/MULTI-SHOP | menu, settings, chọn cửa hàng | middleware permission + shop scope; memberships, roles | “Tất cả cửa hàng” từng làm lỗi UI/khó quay lại; label quyền lẫn key kỹ thuật | Parser/scope/permission unit test đạt; route-policy FE/BE còn lệch | Không chính xác | Ma trận module×action dùng chung; negative test owner/view/edit/none ở single/all shops |
| REPORT/EXPORT — bảng, biểu đồ, file | dashboard và mọi màn báo cáo | summary/read model/export endpoints | Có chart/KPI cơ bản nhưng thiếu drill-down, pagination, scope/filter/asOf; “Excel” có chỗ là CSV | Benchmark và grain dữ liệu đã lập; chưa có report contract test toàn miền | Đúng một phần | Metric contract; AppPagedTable; export toàn tập; reconciliation + checksum + encoding test |
| AI/AUDIT | launcher, AI knowledge, activity log | knowledge documents, activity logs | AI che CTA; log ghi chung “Hệ thống/Cập nhật thông tin” | Có source quản lý tài liệu; chưa đủ actor/entity/before-after | Đúng một phần | Collision manager; source version/effective date; audit schema và negative-redaction test |
| RESPONSIVE/ACCESSIBILITY | toàn app | UI/component layer | 47 ảnh mobile: card reflow khá, nhưng XNT/chart/CTA còn lỗi | Chưa có keyboard, screen reader, zoom 200%, contrast gate | Không chính xác; accessibility bị chặn | Matrix viewport, screenshot regression, focus/semantic/zoom/contrast chuyên biệt |
| DATA QUALITY — invoice, master data, freshness | report/detail/export | invoices/items, products, movements, migrations | 60 invoice đầu vào thiếu item; 558 invoice không tự cân bằng giảm giá; tên sản phẩm chậm luân chuyển bị thiếu | Validator đọc đã phát hiện; chưa có migration/backfill được duyệt | Không chính xác | Data-quality gate trước báo cáo/export; backfill có đối soát và rollback |

### Bằng chứng kiểm thử mới nhất

- Backend `npm run test:p0` ngày 02/08/2026: **57/57 đạt**; lint và TypeScript build sạch;
  dependency production không có lỗ hổng theo `npm audit --omit=dev --audit-level=high`.
- Flutter analyze toàn dự án sạch, **61/61 test đạt** và Web release build thành công; production chưa deploy gói sửa này.
- Production vẫn ở `093b17ac`; mọi fix local phải giữ trạng thái `Chưa xác minh production` cho đến khi
  deployment và regression test hoàn tất.

> **Delta 25/07/2026:** trạng thái `Code/test đạt` dưới đây là bằng chứng local
> sau `bba0c5f5`; cột production cố ý để `Chưa xác minh` cho đến khi deploy.

## Ma trận delta bản vá local

| Yêu cầu | Màn hình | API/code | Test | Code/test | Production |
|---|---|---|---|---|---|
| RBAC-01 | menu theo quyền | auth/permission middleware | `permission.utils.test.js` | Đạt | Chưa xác minh |
| RBAC-02 | chọn tất cả shop | `shop-scope.utils.ts`, membership active/cùng shop | `shop-scope.utils.test.js`, permission tests | Đạt | Chưa xác minh |
| SALE-05 | `/#/sales` | list/summary status + `reporting_period.dart` | `sales-metric.utils.test.js`, `reporting_period_test.dart` | Backend test đạt; Flutter test chưa chạy lại | Chưa đối soát |
| UX-ERR-01 | dashboard/finance | Async error/retry components | widget/source review | Đúng một phần | Chưa xác minh |
| DATA-01 | invoice | một metadata owner và một route set | `invoice-metadata.test.js` | Đạt | Chưa smoke test |
| TAX-02 | dashboard/tax/finance | `calculateOutstandingTax`, normalize DTO/read model | `tax-policy.test.js` | Đạt | Chưa xác minh |
| TAX-04 | export XML | validator chặn thiếu/sai/placeholder MST | `tax-policy.test.js` | Đạt phạm vi MST | Chưa xác minh; XSD vẫn bị chặn |
| DEBT-01 | `/#/customer-debts` | `/customer-receivables` | `debt.utils.test.js` + source review | Đạt phạm vi tính/API mapping | Chưa đối soát |
| REP-CSV-01 | export công nợ | `buildCustomerDebtsCsv` | `excel_export_service_test.dart` | Test đã bổ sung, chưa chạy lại do toolchain | Chưa tải production |
| UX-MOB-01 | `/#/pos` | CTA safe margin + `shouldShowAiAssistant` | `main_shell_layout_test.dart` | Test đã bổ sung, chưa chạy lại do toolchain | Chưa kiểm tra viewport |
| REP-PERIOD-01 | dashboard/sales/finance | `currentMonthReportingPeriod` | `reporting_period_test.dart` | Test đã bổ sung, chưa chạy lại do toolchain | Chưa đối soát |

Liên kết test: [`../backend/test/`](../backend/test/) và
[`../test/`](../test/).

## 1. Quy ước

- `UI`: route production dùng hash, ví dụ `/#/pos`.
- `API`: prefix chung `/api`.
- `TC`: mã kiểm thử tại [11_ACCEPTANCE_TEST_CATALOG.md](11_ACCEPTANCE_TEST_CATALOG.md).
- Trạng thái là kết quả của baseline ngày 25/07/2026, không phải cam kết tương lai.

## 2. Ma trận baseline 25/07/2026 — lưu lịch sử

| ID | Yêu cầu | UI | API chính | Dữ liệu chính | TC | Trạng thái |
|---|---|---|---|---|---|---|
| AUTH-01 | Đăng nhập bằng tài khoản hợp lệ | `/#/login` | `POST /auth/login` | `users`, `shop_members` | TC-AUTH-01 | Đã xác minh |
| AUTH-02 | Đăng ký email có OTP | `/#/register`, `/#/verify-otp` | `POST /auth/send-otp`, `/auth/register` | `users`, `otps` | TC-AUTH-02 | Đúng một phần |
| AUTH-03 | Làm mới phiên an toàn | toàn app | `POST /auth/refresh-token` | token | TC-AUTH-03 | Đúng một phần |
| RBAC-01 | Chỉ truy cập shop có membership | shell/settings | mọi route shop-scoped | `shop_members` | TC-RBAC-01 | Đúng một phần |
| RBAC-02 | Quyền module được kiểm tra ở API | menu/module | middleware `requirePermission` | `shop_roles.permissions` | TC-RBAC-02 | Không chính xác |
| RBAC-03 | Tổng hợp nhiều shop không nâng quyền | chuyển shop | header `x-shop-id: all` | `shop_members` | TC-RBAC-03 | Không chính xác |
| SALE-01 | Tạo đơn tại POS | `/#/pos` | `POST /sales-orders` | `sales_orders`, `sales_order_items` | TC-SALE-01 | Đúng một phần |
| SALE-02 | Ghi nhận nhiều phương thức thanh toán | POS | payment endpoint trong sales routes | `sales_order_payments` | TC-SALE-02 | Đúng một phần |
| SALE-03 | Hoàn/hủy đảo tồn và tiền đúng | chi tiết đơn | return/cancel endpoints | `sales_returns`, movements, cash | TC-SALE-03 | Bị chặn |
| SALE-04 | QR thanh toán có trạng thái xác nhận | POS/payment config | payment integration | payment config/payment | TC-SALE-04 | Bị chặn |
| SALE-05 | Tổng hợp đơn khớp danh sách | `/#/sales` | `GET /sales-orders/summary` | `sales_orders` | TC-SALE-05 | Không chính xác |
| INV-01 | Xem tồn và cảnh báo dưới định mức | `/#/inventory` | `/inventory/stock`, `/low-stock` | `inventory_stocks`, `products` | TC-INV-01 | Đã xác minh |
| INV-02 | Nhập hàng tăng tồn và giá vốn | purchase order | purchase order receive | PO, items, stocks, lots | TC-INV-02 | Bị chặn |
| INV-03 | Kiểm kê sinh điều chỉnh có truy vết | `/#/stock-take` | `/stock-takes` | stock takes, movements | TC-INV-03 | Đúng một phần |
| INV-04 | Báo cáo XNT cân bằng | `/#/xnt-report` | `/inventory/xnt-report` | stocks, movements | TC-INV-04 | Bị chặn |
| FIN-01 | Sổ quỹ phản ánh thu/chi | `/#/finance` | `/cash-accounts`, `/cash-transactions/summary` | cash accounts/transactions | TC-FIN-01 | Đúng một phần |
| FIN-02 | Dashboard và tài chính dùng cùng định nghĩa số dư | `/`, `/#/finance` | sales + cash summaries | sales, cash | TC-FIN-02 | Không chính xác |
| FIN-03 | Lợi nhuận khớp doanh thu trừ giá vốn/chi phí | `/`, `/#/profit-loss` | profit-loss/summary | sales, COGS, cash | TC-FIN-03 | Đúng một phần |
| DEBT-01 | Sổ nợ lấy từ khoản phải thu thật | `/#/customer-debts` | customer receivables | `receivables`, payment history | TC-DEBT-01 | Không chính xác |
| DEBT-02 | Thu nợ cập nhật công nợ và sổ quỹ | sổ nợ | receivable payment | receivables, cash | TC-DEBT-02 | Bị chặn |
| DEBT-03 | Excel nợ phản ánh dữ liệu nguồn | sổ nợ | export | receivables | TC-DEBT-03 | Không chính xác |
| TAX-01 | Tính thuế theo quy định có hiệu lực | `/#/tax-estimate` | `/tax/estimate`, `/tax/config` | `tax_rules`, shop profile | TC-TAX-01 | Không chính xác |
| TAX-02 | Không sinh nghĩa vụ thuế âm | dashboard/tax | tax estimate | sales, tax rules | TC-TAX-02 | Không chính xác |
| TAX-03 | XML đúng schema và import HTKK được | `/#/tax-estimate` | `/tax/export-htkk` | tax data, shop profile | TC-TAX-03 | Bị chặn |
| TAX-04 | Không dùng MST giả/fallback trong tệp chính thức | tax export | `/tax/export-htkk` | `shop_profiles.tax_code` | TC-TAX-04 | Không chính xác |
| REPORT-01 | Xuất Excel có đủ cột, đúng tổng | các màn báo cáo | tùy module | dữ liệu module | TC-REP-01 | Bị chặn |
| DATA-01 | Mỗi bảng chỉ có một mô hình sở hữu rõ | N/A | finance/system routes | `invoices` | TC-DATA-01 | Không chính xác |
| DATA-02 | Schema thay đổi bằng migration có kiểm soát | N/A | startup/serverless | migrations | TC-DATA-02 | Không chính xác |
| UX-01 | Có loading/empty/error state rõ | toàn app | mọi API | N/A | TC-UX-01 | Đúng một phần |
| UX-02 | Luồng chính dùng được ở 390×844 | dashboard/POS/settings | N/A | N/A | TC-UX-02 | Không chính xác |
| UX-03 | Đạt chuẩn accessibility đã chọn | toàn app | N/A | N/A | TC-UX-03 | Bị chặn |
| AI-01 | Trợ lý chỉ dùng tri thức đã duyệt và còn hiệu lực | widget/kho tri thức | AI integration | knowledge store | TC-AI-01 | Không chính xác |
| AUDIT-01 | Thao tác quan trọng có audit log | settings/activity logs | `/activity-logs` | `activity_logs` | TC-AUD-01 | Đúng một phần |

## 3. Khoảng trống truy vết

1. Không có test tự động liên kết requirement ID với backend/frontend test.
2. Chưa có seed data chuẩn để tái tính dashboard, tồn, công nợ và thuế.
3. Tệp XML chưa có fixture kỳ vọng và biên bản import HTKK.
4. Dữ liệu mẫu đang xuất hiện trong màn nghiệp vụ production.
5. Migration không bao phủ toàn bộ DDL đang chạy trong `index.ts`.

## 4. Quy tắc cập nhật

Mỗi pull request nghiệp vụ phải:

- ghi requirement ID liên quan;
- thêm hoặc cập nhật TC;
- nêu entity/API bị ảnh hưởng;
- cập nhật trạng thái sau khi kiểm thử staging/production;
- đính kèm bằng chứng không chứa dữ liệu cá nhân nhạy cảm.
