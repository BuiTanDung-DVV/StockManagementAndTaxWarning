# Ma trận truy vết yêu cầu

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

## 2. Ma trận

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
