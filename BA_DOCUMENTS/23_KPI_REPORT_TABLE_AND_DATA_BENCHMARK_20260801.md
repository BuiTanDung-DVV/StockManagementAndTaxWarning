# Khung KPI, báo cáo, bảng dữ liệu và benchmark hệ thống lớn — 01/08/2026

## 1. Kết luận điều hành

SmartStock đã có dữ liệu và API đủ để vận hành các luồng bán hàng, kho, công nợ và tài chính cơ bản, nhưng hệ
thống báo cáo chưa đạt mức của một sản phẩm bán lẻ lớn. Khoảng trống không nằm ở việc “thêm thật nhiều biểu
đồ”, mà ở bốn lớp nền:

1. Chưa có hợp đồng KPI thống nhất về kỳ, cửa hàng, trạng thái đơn, hàng hoàn, đơn vị và thời điểm chốt dữ liệu.
2. Một số chứng từ chưa tự đối soát được từ header xuống dòng hàng.
3. Báo cáo hiện chủ yếu là card và biểu đồ; thiếu bảng chi tiết đi kèm để drill-down, lọc, sắp xếp và xuất toàn bộ.
4. Thành phần bảng dùng chung chưa có phân trang, sort, chọn cột, tổng theo bộ lọc hoặc cách trình bày riêng cho mobile.

Hướng tối ưu là xây `metric contract + reporting read model + AppPagedTable/AppRecordCardList` trước, sau đó
mới bổ sung biểu đồ. Làm theo thứ tự này tránh tình trạng giao diện đẹp nhưng số liệu không thể giải thích.

## 2. Phạm vi và mức bằng chứng

| Nguồn | Phạm vi | Trạng thái |
|---|---|---|
| Production API | 48 endpoint đọc, 47 route protected, hai cửa hàng | Đã xác minh |
| Đối soát DB chỉ đọc | 24 quy tắc trên shop 34 và 35 | Đã chạy ngày 01/08/2026 |
| Flutter/backend code | Chart, bảng, entity, service tổng hợp | Đã đối chiếu |
| Ảnh production public hiện tại | 10 trạng thái auth desktop/mobile | Đã chấp nhận |
| Ảnh production protected hiện tại | Canvas Flutter timeout khi chụp | Chưa đủ bằng chứng trực quan |
| Accessibility chuyên biệt | Keyboard, focus, screen reader, contrast, zoom | Chưa xác minh |

Không dùng tài liệu của hệ thống khác để khẳng định SmartStock đã hoạt động đúng. Các nguồn bên ngoài chỉ được
dùng làm benchmark cho cấu trúc báo cáo và cách trình bày.

## 3. Benchmark từ hệ thống thực tế

| Hệ thống | Cách họ tổ chức | Bài học áp dụng cho SmartStock |
|---|---|---|
| Shopify Analytics | Dashboard cho phép thêm, bỏ, sắp xếp, chia section, resize card; có kỳ so sánh và insight | Dashboard cần cấu hình theo vai trò, nhưng chỉ triển khai sau khi metric contract ổn định |
| Shopify Reports | Mỗi báo cáo có visualization và bảng chi tiết; danh sách tối đa 1.000 dòng, dữ liệu lớn xuất file | Biểu đồ SmartStock phải có bảng drill-down; phân trang UI không được làm sai tổng toàn bộ |
| Shopify Inventory | Sell-through, days of inventory, inventory value, ABC, sold daily, adjustment history | Kho hiện thiếu sell-through, số ngày tồn, ABC và lịch sử điều chỉnh có tổng kiểm soát |
| Square Dashboard | Bộ điều khiển metric, location, grouping và filter nằm trong khối report; định nghĩa metric đi kèm | Filter phải thể hiện rõ phạm vi, không đặt lẫn giữa biểu đồ và danh sách gây hiểu nhầm |
| Square Custom Reports | Ghép các block: key statistics, sales, payment, item, category, employee, discount, tax | SmartStock nên có report preset theo vai trò trước khi cho tự tạo dashboard |
| Microsoft Dynamics 365 Commerce | Báo cáo theo năm, giờ, top product/customer/discount, category, store và margin | Cần báo cáo theo giờ/ngày trong tuần và bảng so sánh các cửa hàng |
| Lightspeed Retail | Inventory performance kết hợp tồn, bán hàng, sell-through, days to sell, retail value; có inventory turns/COGS | Không tách báo cáo tồn khỏi tốc độ bán và giá vốn |
| Odoo | Inventory valuation drill-down theo sản phẩm, ngày, số lượng, tổng giá trị; có “Inventory At Date” và liên kết kế toán | Giá trị tồn phải có phương pháp định giá, thời điểm chốt và đường truy vết về giao dịch/sổ cái |

Nguồn chính thức:

- [Shopify Analytics overview](https://help.shopify.com/en/manual/reports-and-analytics/shopify-reports/overview-dashboard)
- [Shopify Reports](https://help.shopify.com/en/manual/reports-and-analytics/shopify-reports/report-types)
- [Shopify Inventory reports](https://help.shopify.com/en/manual/reports-and-analytics/shopify-reports/report-types/default-reports/inventory-reports)
- [Square sales summary and trends](https://squareup.com/help/us/en/article/5381-in-app-summaries-and-reports)
- [Square custom reports](https://squareup.com/help/us/en/article/6104-creating-custom-reports-in-the-online-dashboard)
- [Square report export](https://squareup.com/help/us/en/article/8362-print-export-or-email-your-reports)
- [Dynamics 365 Commerce reports](https://learn.microsoft.com/en-us/dynamics365/commerce/generate-reports)
- [Dynamics 365 retail statements](https://learn.microsoft.com/en-us/dynamics365/commerce/retail-statements)
- [Lightspeed inventory performance](https://x-series-support.lightspeedhq.com/hc/en-us/articles/25534065421979-Using-the-inventory-performance-report)
- [Lightspeed inventory turns](https://x-series-support.lightspeedhq.com/hc/en-us/articles/39896690485787-Using-the-inventory-turns-report)
- [Odoo inventory valuation](https://www.odoo.com/documentation/19.0/applications/finance/accounting/get_started/inventory_valuation.html)

## 4. Mức đầy đủ hiện tại theo miền nghiệp vụ

| Miền | Đang có | Thiếu để ra quyết định | Đánh giá |
|---|---|---|---|
| Dashboard | Doanh thu theo kỳ, top sản phẩm, tồn theo nhóm, dòng tiền, phương thức thanh toán, đơn gần đây | Gross margin %, AOV, hàng hoàn, công nợ quá hạn, so sánh cửa hàng, chất lượng dữ liệu | Đúng một phần |
| Bán hàng | Summary, lịch sử đơn, doanh thu 7 ngày, top sản phẩm | Net quantity/revenue sau hoàn, AOV, UPT, sales theo giờ/ngày, category/customer/store | Đúng một phần |
| Kho | Tồn hiện tại, dưới định mức, sắp hết hạn, chậm luân chuyển, XNT, lô và valuation API | Sell-through, days on hand, turn, ABC, stockout, adjustment/shrinkage, valuation tại ngày | Đúng một phần |
| Mua hàng | Đơn nhập, nhà cung cấp, phải trả | Lead time, fill rate, on-time rate, purchase price variance, spend theo supplier/category | Thiếu báo cáo quản trị |
| Công nợ | Phải thu mở, quá hạn, aging, bằng chứng và lịch sử thu | Credit utilization, DSO, collector workflow, tổng kiểm soát theo filter | Khá nhưng chưa đủ |
| Tài chính | Thu/chi, P&L, nhóm chi phí, chốt quỹ, forecast, budget, invoice reconciliation | P&L waterfall, budget variance, AR/AP aging chung, cash actual vs forecast, drill-down sổ cái | Đúng một phần |
| Thuế | Estimate, config, obligation, invoice, XML | Trace từ chỉ tiêu đến hóa đơn, rule version/effective date, validator HTKK, data-quality gate | Đúng một phần |
| Khách hàng | Danh sách, chi tiết, công nợ | New/returning, repeat rate, retention, top customer, revenue/profit by segment | Thiếu phân tích |
| Nhiều cửa hàng | Tổng hợp một số KPI | Scorecard từng shop, rank/delta, cảnh báo chéo shop, scope đồng nhất mọi report | Đúng một phần |
| Chất lượng dữ liệu | Script đối soát | Dashboard freshness, reconciliation, missing master data, failed exports | Chưa có UI |

## 5. Khung KPI đề xuất

### 5.1 Ba KPI điều hành chính

| KPI | Công thức bắt buộc | Nguồn | Quyết định hỗ trợ |
|---|---|---|---|
| Doanh thu thuần | Gross item sales − discount − refund/return revenue | Đơn bán + dòng đơn + dòng hoàn | Tốc độ bán và hiệu quả chương trình giá |
| Biên lợi nhuận gộp | `(doanh thu thuần − COGS thuần sau hoàn) / doanh thu thuần` | Dòng bán + lot/COGS + dòng hoàn | Giá bán, danh mục, mua hàng |
| Tiền khả dụng | Tổng số dư tài khoản tiền tại `asOf`, không trộn với doanh thu | Cash account + cash transaction + closing | Khả năng chi trả ngắn hạn |

Ba KPI này phải luôn hiển thị `kỳ`, `cửa hàng`, `đơn vị`, `so sánh`, `asOf` và trạng thái chất lượng dữ liệu.

### 5.2 Driver và guardrail

| Nhóm | Metric | Công thức/ý nghĩa |
|---|---|---|
| Driver bán hàng | Số đơn, AOV, UPT | `order count`; `net sales / order count`; `net quantity / order count` |
| Driver kho | Sell-through, days on hand | `net sold / (net sold + ending stock)`; `ending stock / avg daily net sold` |
| Driver công nợ | Nợ quá hạn, DSO | Tổng remaining quá due date; kỳ thu tiền bình quân |
| Driver cửa hàng | Revenue/margin theo shop | So sánh cùng kỳ, không dùng tổng “all” thay bảng chi tiết |
| Guardrail | Return rate | Returned quantity hoặc refund / gross sales |
| Guardrail | Stockout rate | SKU hết hàng có nhu cầu / SKU hoạt động |
| Guardrail | Reconciliation pass rate | Số kiểm tra dữ liệu đạt / tổng kiểm tra bắt buộc |
| Guardrail | Freshness lag | `now − asOf` của nguồn chậm nhất trong report |

### 5.3 Metric contract chung

Mọi endpoint báo cáo nên trả thêm metadata sau, không chỉ trả một số hoặc mảng điểm:

```text
metricId, label, value, unit, currency,
period.from, period.to, comparison.from, comparison.to,
deltaValue, deltaPercent, shopScope, filters,
asOf, timezone, sourceVersion, qualityStatus
```

Không hard-code “triệu”, “tỷ” vào dữ liệu. API trả `value` và `unit=VND`; formatter UI quyết định hiển thị
`29,6 triệu ₫`, còn tooltip và bảng chi tiết phải có số đầy đủ.

## 6. Biểu đồ và bảng nên có

| Màn hình | Khối ưu tiên | Visualization | Bảng drill-down |
|---|---|---|---|
| Dashboard | Net sales + gross margin theo kỳ | Cột nhóm cho doanh thu, line cho margin % | Theo shop/category, current, prior, delta |
| Dashboard | Top 10 sản phẩm thuần | Thanh ngang, tên trái, số lượng và doanh thu cuối thanh | SKU, đơn vị, gross, return, net, margin |
| Sales | Sales trend | Line/bar đổi được; tuần/ngày/tháng; compare | Date, order, net sales, AOV, UPT, return |
| Sales | Nhu cầu theo thời gian | Heatmap ngày trong tuần × giờ | Hour/day, orders, net sales, margin |
| Inventory | ABC/Pareto | Đã triển khai local: thẻ A/B/C và thanh ngang top SKU theo doanh thu hàng hóa thuần chưa VAT | API trả SKU, grade, revenue share, cumulative share, quantity sold, stock và stock value; UI desktop/mobile dùng cùng dữ liệu |
| Inventory | Days on hand/sell-through | Thanh ngang Top/Bottom hoặc scatter | SKU, unit, ending qty, avg sold/day, days |
| Inventory | Aging/slow moving | Cột chồng theo 0–30/31–60/61–90/>90 ngày | Lot, received date, qty, cost value |
| Inventory | Valuation at date | Trend giá trị tồn + breakdown category | Product/lot, qty, unit cost, total, method |
| Purchase | Supplier performance | Cột nhóm on-time/fill rate; line price variance | PO, supplier, promised/received date, variance |
| Finance | P&L bridge | Waterfall Gross → discount → return → net → COGS → gross profit → expense | Account/category, current, prior, variance |
| Finance | Cash actual vs forecast | Hai line hoặc area không chồng gây hiểu sai | Date, opening, in, out, closing, forecast |
| Debt | AR/AP aging | Cột chồng theo bucket | Customer/supplier, due, remaining, age, owner |
| Tax | Tax traceability | KPI + trend obligation; không dùng chart trang trí | Chỉ tiêu → invoice → rule version → source |
| Multi-shop | Store scorecard | Bảng rank + sparkline nhỏ | Shop, net sales, margin %, stock turn, overdue, cash variance |
| Data quality | Health dashboard | Status strip + trend violation | Rule, severity, count, owner, first/last seen |

Không dùng donut khi có quá năm nhóm hoặc nhãn dài. Khi người dùng cần so sánh chính xác, ưu tiên thanh ngang hoặc
bảng. Biểu đồ luôn phải có đơn vị trên trục/tiêu đề, tooltip số đầy đủ và empty/error state rõ.

## 7. Chuẩn bố cục report

### 7.1 Desktop

1. Header gọn: tên report, mô tả một dòng, help icon, export icon.
2. Thanh scope: cửa hàng, kỳ, compare, timezone; áp dụng cho toàn report và có nhãn “Áp dụng toàn báo cáo”.
3. Ba KPI chính cùng hàng, mỗi card có số, delta, định nghĩa ngắn và thời điểm cập nhật.
4. Biểu đồ quyết định chính chiếm 2/3 chiều rộng; bảng cảnh báo/hạng mục cần hành động chiếm 1/3.
5. Bảng chi tiết toàn chiều rộng nằm ngay dưới biểu đồ tương ứng.
6. CTA nghiệp vụ tách khỏi filter: desktop đặt floating góc phải dưới như quy ước hiện tại.

### 7.2 Mobile

1. Header một dòng; primary action ở góc phải app bar.
2. Scope/filter mở bằng bottom sheet; khi áp dụng phải hiện chip tóm tắt ngay trên khối bị lọc.
3. KPI dùng lưới hai cột hoặc strip cuộn có snap; không dùng card quá cao.
4. Biểu đồ full-width, chiều cao tối thiểu 240 px; nhãn trục được rút gọn nhưng tooltip giữ đủ.
5. Bảng chuyển thành `AppRecordCardList`: ba trường chính, status, tổng tiền và hành động; không ép bảng 650 px để cuộn ngang.

## 8. Chuẩn thành phần bảng

`AppDataTable` hiện chỉ render header + list và trên mobile ép chiều rộng 650 px. Nó chưa có sort, pagination,
selection, sticky header, tổng theo filter hoặc column chooser. Chuẩn thay thế:

| Khả năng | Desktop | Mobile |
|---|---|---|
| Phân trang | Server-side 25/50/100, hiển thị `1–25 / 453` | Infinite load có tổng và retry |
| Sort | Một/nhiều cột, icon và thứ tự rõ | Sort trong bottom sheet |
| Filter | Đặt trong card của đúng dataset | Chip tóm tắt + bottom sheet |
| Tổng | Pinned summary từ server, không cộng trang hiện tại | Summary trên list |
| Cột | Sticky ID/name, align phải số/tiền, chooser | Record card chọn trường ưu tiên |
| Export | “Dòng đã chọn” hoặc “Toàn bộ kết quả lọc” | Export toàn bộ kết quả lọc |
| Trạng thái | Badge có text, không chỉ màu | Badge text tương tự |
| Loading/error | Skeleton đúng số cột, retry theo dataset | Skeleton card, retry |

Các cột tiền phải cùng formatter và cùng số lẻ; số lượng luôn kèm đơn vị sản phẩm. Không hiển thị mã enum tiếng Anh
như `PURCHASE`, `SALARY`, `RENT` trực tiếp cho người dùng.

## 9. Grain dữ liệu báo cáo đề xuất

| Dataset/read model | Grain | Measure chính | Dimension bắt buộc |
|---|---|---|---|
| `fact_sales_order_line` | Một dòng sản phẩm trong đơn | gross, discount allocated, tax, net, qty, cogs | date, shop, product, category, customer, employee, payment |
| `fact_sales_return_line` | Một dòng hoàn gắn dòng bán gốc | returned qty, refund, reversed cogs | return date, shop, product, reason, original sale |
| `fact_inventory_movement` | Một biến động sản phẩm/kho/lô | in/out/adjust qty, unit cost, value | date-time, shop, warehouse, product, lot, reason |
| `fact_inventory_snapshot_day` | Product × warehouse × ngày | ending qty, cost value, retail value | date, shop, product, category, warehouse |
| `fact_purchase_order_line` | Một dòng PO | ordered/received qty, unit cost, variance | supplier, promised/received date, product, shop |
| `fact_cash_transaction` | Một giao dịch tiền | income, expense, fee | date, shop, account, method, category, reference |
| `fact_invoice_line` | Một dòng hóa đơn | gross, discount, tax, total | invoice type, shop, partner, product, rule version |
| `fact_debt_snapshot_day` | Khoản nợ × ngày | remaining, overdue days | shop, customer/supplier, bucket, owner |

Giai đoạn V1.1 có thể dùng query/view thay vì data warehouse riêng. V2.0 mới cân nhắc materialized view hoặc data mart
khi p95 và chi phí serverless cho thấy cần thiết.

## 10. Kết quả chất lượng dữ liệu ngày 01/08/2026

Bộ `validate-store-data` đã mở rộng từ 12 lên 24 quy tắc. Hai cửa hàng cùng đạt các kiểm tra về tổng đơn,
thanh toán, công nợ, tồn, bút toán, chốt quỹ, uniqueness theo grain, ảnh, đơn vị, giá, định mức và cross-shop.

| Phát hiện | Shop 34 | Shop 35 | Mức độ | Ảnh hưởng |
|---|---:|---:|---|---|
| Hóa đơn đầu vào không có dòng hàng | 30 | 30 | Critical/P0 | Không thể drill-down, kiểm tra thuế hoặc truy giá mua từ invoice |
| Hóa đơn có dòng nhưng header sau giảm giá lệch tổng dòng; schema thiếu `discount_amount` | 268 | 290 | High/P0 | Báo cáo invoice không tự đối soát; phải join đơn bán mới giải thích được |
| Dữ liệu không có đơn hôm nay/hôm qua | 1 cảnh báo | 1 cảnh báo | Medium | Demo dừng ở 28/07/2026, dashboard ngày hiện tại có thể tạo khoảng trống |

Chi tiết nguyên nhân đã xác minh:

- 60 hóa đơn không dòng đều là hóa đơn `IN` tham chiếu `PURCHASE_ORDER`.
- Seed hóa đơn bán lưu `invoice.subtotal = order.subtotal - order.discount`, nhưng `invoice_items.subtotal` giữ giá
  trước giảm; entity `Invoice` không có cột discount.
- Tổng chênh lệch quan sát được gồm cả các hóa đơn đầu vào không có dòng: 13.592.573.000 ₫ ở shop 34 và
  18.887.823.000 ₫ ở shop 35.

Không tự sửa hoặc backfill production trong giai đoạn audit. Đây là migration nghiệp vụ cần kế hoạch rollback và
nghiệm thu với dữ liệu đối chứng.

## 11. Vấn đề schema ảnh hưởng báo cáo

| Vấn đề | Bằng chứng code | Hướng xử lý |
|---|---|---|
| `Category.name`, `Product.sku`, `Customer.code`, `Supplier.code`, `Warehouse.name` đang unique toàn DB | Các entity dùng `unique: true` riêng cột | Chuyển sang unique composite `(shop_id, normalized_key)` sau khi audit duplicate |
| Nhiều bảng nghiệp vụ cho phép `shop_id` null | Entity sản phẩm, đơn, tồn, invoice, tiền | Backfill, đặt NOT NULL và FK sau migration có kiểm soát |
| `SalesReturnItem` không gắn `sales_order_item_id` và không lưu reversed cost | Chỉ có return, product, quantity, price | Liên kết dòng bán gốc, lot/cost reversal để net COGS đúng |
| Invoice thiếu gross/discount và 60 hóa đơn không có item | Kết quả validator | Thêm contract header tự cân bằng và bắt buộc item cho invoice hợp lệ |
| Giá trị tồn dashboard dùng `quantity × products.cost_price`, trong khi COGS có lot | `inventory.service.ts` và `cogs.service.ts` | Một valuation service duy nhất, trả method và `asOf` |
| Status/category lưu chuỗi tự do | Nhiều entity chỉ dùng `varchar` | Enum/check constraint có version; mapper tiếng Việt ở UI |
| Có `financial_ledger` và `journal_entries/journal_lines` song song | Hai mô hình sổ tài chính | Chọn một bounded context chủ sở hữu, lập kế hoạch migrate/compatibility |

## 12. Lộ trình triển khai tối ưu

### P0 — Tính đúng trước giao diện

1. Chốt invoice contract: gross subtotal, discount, taxable amount, tax, total; bổ sung dòng cho 60 hóa đơn đầu vào.
2. Gắn hàng hoàn về dòng bán gốc và đảo đúng quantity/COGS theo lot.
3. Thêm automated checks hiện có vào CI và data-quality gate trước export thuế.
4. Chỉ chạy migration production sau backup, dry-run, reconciliation và phê duyệt.

### V1.1 — Nền báo cáo và bảng

1. Chuẩn hóa `MetricEnvelope`, date/shop scope và metric definition registry.
2. Xây `AppPagedTable` và `AppRecordCardList`; chuyển sales, products, customers, suppliers, invoice, debt trước.
3. Tạo report endpoint server-side cho net sales, margin, AOV/UPT, shop scorecard.
4. Mỗi chart chính có bảng drill-down và export toàn bộ kết quả lọc.

### V1.2 — Kho và tài chính quản trị

1. Inventory snapshot, sell-through, days on hand, ABC và valuation at date.
2. Purchase supplier performance và purchase price variance.
3. P&L waterfall, cash actual vs forecast, AR/AP aging thống nhất.
4. Tax traceability và validator HTKK có biên bản kiểm thử.

### V2.0 — Cá nhân hóa và phân tích nâng cao

1. Dashboard card có thể thêm/bỏ/sắp xếp/resize theo vai trò.
2. Insight có giải thích, nguồn, kỳ, scope và confidence; không tự khẳng định pháp lý.
3. Materialized read model/data mart chỉ khi benchmark p95 và chi phí chứng minh cần.

## 13. Tiêu chí nghiệm thu

- Một KPI có cùng giá trị ở dashboard, report và export khi dùng cùng kỳ/scope/filter.
- Mỗi KPI hiển thị định nghĩa, đơn vị, kỳ, comparison và `asOf`.
- Net sales/top product đã trừ hàng hoàn; gross margin đảo đúng COGS hoàn.
- Mọi invoice hợp lệ tự cân bằng từ dòng hàng mà không cần join chứng từ khác.
- Dataset 453 khoản nợ hoặc 500 sản phẩm duyệt đủ, sort/filter/page không lặp hoặc mất dòng.
- Tổng bảng lấy từ server cho toàn bộ kết quả lọc, không cộng trang hiện tại.
- Desktop 1440×900 và mobile 390×844 không overflow; mobile không bắt buộc cuộn ngang bảng nghiệp vụ chính.
- Biểu đồ có unit, tooltip số đầy đủ, empty/loading/error và bảng drill-down.
- Accessibility chỉ được ghi đạt sau test keyboard, focus, contrast, zoom và screen reader chuyên biệt.
