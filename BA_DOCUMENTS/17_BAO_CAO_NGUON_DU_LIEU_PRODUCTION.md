# Báo cáo nguồn dữ liệu production

## 1. Phạm vi và kết luận

Ngày đối soát ban đầu: **28/07/2026**. Đối soát lại schema và dữ liệu:
**29/07/2026**.

Báo cáo này thay thế các kết luận cũ tại mục 2 và mục 3 của
`15_AUDIT_DU_LIEU_GIA_VA_KE_HOACH_DU_LIEU_3_NAM.md`.

Kết luận:

- Không phát hiện số liệu vận hành hard-code trong các màn hình chính.
- Dashboard, bán hàng, kho, công nợ, tài chính, hóa đơn, thuế và cấu hình đều lấy
  dữ liệu qua API và PostgreSQL.
- Không còn sản phẩm, khách hàng, đơn hàng, giao dịch tiền hoặc nhật ký mang marker
  dữ liệu mock cũ trên hai cửa hàng production.
- Các script seed thử nghiệm cũ đã bị loại khỏi mã nguồn. Chỉ giữ bộ import có
  transaction, xác nhận theo `shop_id` và đối soát tự động.
- Hai loại dữ liệu tệp đính kèm không được tạo giả: ảnh quét hóa đơn và chứng từ
  công nợ. Đây phải là tệp do người dùng tải lên.
- Schema legacy của chi tiết mua hàng chưa hóa đơn đã được nâng cấp tương thích
  với entity/API mới bằng migration `20260729_fix_purchase_without_invoice_item_compatibility.sql`.

## 2. Ma trận màn hình → API → database

| Khu vực | API chính | Bảng nguồn | Trạng thái |
|---|---|---|---|
| Dashboard | `/sales-orders/summary`, `/sales-orders/top-products`, `/cash-transactions/summary` | `sales_orders`, `sales_order_items`, `cash_transactions` | Đã xác minh |
| Sản phẩm | `/products`, `/categories`, `/tags`, `/cost-types` | `products`, `categories`, `tags`, `cost_types` | Đã xác minh |
| Giá vốn và quy đổi | `/products/:id/cost-items`, `/price-history`, `/batches`, `/conversions` | `product_cost_items`, `product_price_history`, `product_batches`, `unit_conversions` | Đã xác minh |
| Kho | `/inventory/stock`, `/movements`, `/xnt-report`, `/expiring-products`, `/slow-moving` | `inventory_stocks`, `inventory_movements`, `product_batches` | Đã xác minh |
| Kiểm kê | `/stock-takes` | `stock_takes`, `stock_take_items` | Đã xác minh |
| Nhập hàng | `/purchase-orders` | `purchase_orders`, `purchase_order_items`, `inventory_movements` | Đã xác minh |
| Bán hàng | `/sales-orders`, `/payments`, `/returns` | `sales_orders`, `sales_order_items`, `sales_order_payments`, `sales_returns` | Đã xác minh |
| Công nợ khách hàng | `/customer-receivables`, `/customers/:id/receivables` | `receivables`, `debt_payment_history`, `customers` | Đã xác minh |
| Công nợ nhà cung cấp | `/suppliers/:id/payables` | `payables`, `debt_payment_history`, `suppliers` | Đã xác minh |
| Dòng tiền | `/cash-transactions`, `/cash-accounts` | `cash_transactions`, `cash_accounts`, `financial_ledger` | Đã xác minh |
| Chốt quỹ | `/daily-closings` | `daily_closings` | Đã xác minh |
| Dự báo và ngân sách | `/cashflow-forecasts`, `/budget-plans` | `cashflow_forecasts`, `budget_plans` | Đã xác minh |
| Hóa đơn | `/invoices` | `invoices`, `invoice_items` | Đã xác minh |
| Mua hàng chưa hóa đơn | `/purchases-without-invoice` | `purchases_without_invoice`, `purchase_without_invoice_items` | Đã xác minh |
| Thuế | `/tax/estimate`, `/tax/config`, `/tax-obligations` | giao dịch bán hàng, `tax_configs`, `tax_obligations` | Đã xác minh nguồn dữ liệu; quy định pháp lý cần kiểm chứng riêng |
| Nhật ký | `/activity-logs` | `activity_logs` | Đã xác minh |
| Kiến thức AI | `/ai-knowledge` | `ai_knowledge_documents` | Đã xác minh |
| Quét hóa đơn | `/invoice-scans` | `invoice_scans` | API đã dùng DB; giao diện quét vẫn đang phát triển |
| Chứng từ công nợ | `/customers/receivables/:id/evidence` | `debt_evidences` | API đã dùng DB; không tạo tệp giả |

Danh sách tỉnh/thành, nhãn trạng thái, màu sắc, câu hướng dẫn và nội dung empty state
là cấu hình giao diện, không phải số liệu nghiệp vụ.

## 3. Độ phủ dữ liệu theo từng cửa hàng

| Nhóm dữ liệu | Shop 34 | Shop 35 |
|---|---:|---:|
| Sản phẩm | 250 | 250 |
| Danh mục / tag | 6 / 9 | 6 / 9 |
| Loại chi phí / dòng chi phí sản phẩm | 4 / 63 | 4 / 63 |
| Quy đổi đơn vị | 48 | 124 |
| Lịch sử giá | 500 | 500 |
| Lô sản phẩm / lô tồn | 250 / 250 | 250 / 250 |
| Phiếu kiểm kê | 12 | 12 |
| Đơn nhập | 37 | 37 |
| Đơn bán | 7.595 | 7.783 |
| Phiếu trả hàng | 67 | 78 |
| Khoản phải thu | 1.323 | 1.307 |
| Giao dịch tiền / dòng sổ tài chính | 8.394 / 8.394 | 8.561 / 8.561 |
| Chốt quỹ ngày | 1.096 | 1.096 |
| Dự báo dòng tiền | 90 | 90 |
| Kế hoạch ngân sách | 37 | 37 |
| Hóa đơn | 2.380 | 2.521 |
| Bảng kê mua hàng chưa hóa đơn | 7 | 7 |
| Nghĩa vụ thuế | 13 | 13 |
| Nhật ký hoạt động | 57 | 57 |
| Tài liệu kiến thức AI | 3 | 3 |

Hai bảng `invoice_scans` và `debt_evidences` có số lượng bằng 0 theo chủ đích. Không
được tạo URL hoặc ảnh giả chỉ để làm đầy giao diện.

## 4. Kết quả kiểm tra tính đúng

Mỗi cửa hàng đạt **12/12** phép đối soát:

1. Tổng đơn bán khớp tổng dòng hàng.
2. Tiền đã trả không âm và không vượt tổng đơn.
3. Khoản phải thu không âm hoặc thu vượt.
4. Số dư khách hàng khớp công nợ còn lại.
5. Số dư nhà cung cấp khớp phải trả còn lại.
6. Tồn hiện tại khớp tổng nhập, xuất và trả hàng.
7. Mỗi bút toán có tổng Nợ bằng tổng Có.
8. Không có dòng đơn bán tham chiếu chéo cửa hàng.
9. Số dư tài khoản tiền khớp tổng giao dịch.
10. Chốt quỹ liên tục giữa các ngày.
11. Chốt quỹ không có chênh lệch ngoài giải trình.
12. Có bán hàng đủ 1.096 ngày trong khoảng ba năm.

Ngoài ra, bộ import bắt buộc kiểm tra đủ 250 sản phẩm, lô hàng, tồn theo lô, kiểm kê,
dự báo dòng tiền, bảng kê mua hàng chưa hóa đơn, nhật ký và số dòng sổ tài chính.

Kiểm tra mã nguồn sau cùng: backend build/lint đạt, 29/29 test P0 đạt,
`flutter analyze` không có lỗi và 33/33 Flutter test đạt.

## 5. Phần chưa được coi là hoàn thiện

- Màn quét hóa đơn Flutter hiện thông báo “đang phát triển”; backend đã có API DB
  nhưng chưa có luồng camera/OCR hoàn chỉnh.
- Xuất XML mẫu 01/CNKD đã dùng chung `TaxService.exportHTKK` và gọi
  `/tax/export-htkk` thật. Các mẫu XML khác và nộp trực tuyến được thông báo rõ là
  chưa hỗ trợ, không còn mô phỏng thành công.
- Ảnh quét hóa đơn và chứng từ công nợ chỉ được xác minh khi có tệp thật do người
  dùng tải lên.
- Các tỷ lệ thuế trong dữ liệu được dùng để kiểm thử chức năng, không phải tư vấn
  pháp lý và không được coi là quy định hiện hành nếu chưa đối chiếu nguồn chính thức.
