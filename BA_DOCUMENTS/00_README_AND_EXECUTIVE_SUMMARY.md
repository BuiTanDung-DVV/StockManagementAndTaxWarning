# Bộ tài liệu BA SmartStock

> **Cập nhật ngày 01/08/2026:** đã kiểm kê lại cấu trúc UI, luồng dữ liệu, bảng biểu và
> benchmark báo cáo với Shopify, Square, Lightspeed, Odoo và Dynamics 365. Xem
> [Audit tổng thể UI, luồng và hệ thống báo cáo](20_COMPREHENSIVE_UI_FLOW_REPORTING_AUDIT_20260801.md)
> và [Khung KPI, bảng dữ liệu và benchmark](23_KPI_REPORT_TABLE_AND_DATA_BENCHMARK_20260801.md).
> Đã xác minh 47 route protected và 48 API đọc bằng phiên production; công cụ chụp canvas Flutter
> protected vẫn hết thời gian phản hồi, vì vậy chưa dùng ảnh cũ để khẳng định giao diện hiện tại.

> **Cập nhật ngày 30/07/2026:** đã chụp và audit 43 route production ở desktop
> `1280×800` và mobile `390×844` (86 ảnh). Xem
> [Báo cáo audit production UI, nghiệp vụ và code](18_PRODUCTION_UI_BUSINESS_CODE_AUDIT_20260730.md).

> **Cập nhật ngày 26/07/2026:** vòng đánh giá UI/UX thứ hai đã kiểm tra 18 màn
> desktop và 7 màn mobile. Ảnh As-Is và các thay đổi giao diện mới được ghi tại
> [Báo cáo UI/UX vòng 2](13_PRODUCTION_UI_REVIEW_ROUND_2.md). Thay đổi chỉ được
> coi là đã xác minh production sau khi deploy đúng commit và smoke test lại.

### Tóm tắt trạng thái sau bản vá local

| Nhóm | Bằng chứng local | Trạng thái production sau bản vá |
|---|---|---|
| RBAC và multi-shop | Parser shop scope fail-closed; membership/role phải active và cùng shop; test permission/shop-scope đạt | Chưa deploy, chưa chạy negative test production |
| Sales summary | Chuẩn hóa status hoàn tất hiện tại/cũ; query dùng property path TypeORM; kỳ tháng dùng helper chung | Chưa đối soát lại API/list/summary trên production |
| Dashboard và báo cáo | Bổ sung error/retry thay cho fallback gây hiểu nhầm; dashboard/sales/finance dùng cùng kỳ tháng hiện tại | Chưa chụp và kiểm tra production sau bản vá |
| Invoice | Chỉ còn một entity sở hữu bảng `invoices`; route invoice trùng đã loại; metadata test đạt | Chưa smoke test CRUD invoice production |
| Thuế | Ngưỡng 2026 có nguồn hiện có; chặn MST placeholder; số phải nộp không âm và giữ riêng số nộp thừa | Chưa deploy; XML vẫn chưa được chứng nhận import HTKK |
| Công nợ khách hàng | Màn hình dùng `/customer-receivables`; CSV sinh từ dữ liệu API, escape công thức và có tổng kiểm soát | Chưa đối chiếu CSV với dữ liệu production |
| Mobile POS/AI | Chừa vùng cho CTA thanh toán; ẩn AI trên POS mobile; dispose controller | Chưa kiểm tra thiết bị/viewport production sau bản vá |

Nguồn test và code liên quan được truy vết tại
[Ma trận truy vết](08_REQUIREMENTS_TRACEABILITY_MATRIX.md),
[Báo cáo xác minh](09_CURRENT_STATE_VERIFICATION_REPORT.md) và
[Danh mục nghiệm thu](11_ACCEPTANCE_TEST_CATALOG.md).

## 1. Baseline được xác minh

| Thuộc tính | Giá trị |
|---|---|
| Ngày đánh giá | 25/07/2026 |
| Frontend production | [smartstock-tax.vercel.app](https://smartstock-tax.vercel.app) |
| Backend production | [stock-management-and-tax-warning.vercel.app](https://stock-management-and-tax-warning.vercel.app) |
| Commit ứng dụng | `f073c1285d...` |
| Frontend | Flutter Web, Riverpod, GoRouter |
| Backend | Express, TypeScript, TypeORM, PostgreSQL |
| Viewport đã kiểm tra | Desktop 1440×900; mobile 390×844 |

Commit trên là baseline mã nguồn ứng dụng dùng để kiểm thử. Commit tài liệu BA sau
baseline không thay đổi hành vi ứng dụng.

## 2. Cách đọc kết quả

Mỗi kết luận phải thuộc một trong bốn trạng thái:

| Trạng thái | Ý nghĩa |
|---|---|
| `Đã xác minh` | Yêu cầu, code, API/dữ liệu và hành vi production có đủ bằng chứng phù hợp |
| `Đúng một phần` | Có triển khai nhưng thiếu một phần nghiệp vụ, bằng chứng hoặc tính nhất quán |
| `Không chính xác` | Có mâu thuẫn, dữ liệu mẫu, lỗi công thức, lỗi quyền hoặc hành vi sai |
| `Bị chặn` | Không thể kết luận an toàn vì thiếu dữ liệu, quyền hoặc kiểm thử chuyên biệt |

Không dùng ảnh chụp giao diện để thay thế cho kiểm tra dữ liệu nguồn. Không ghi nhận
đạt chuẩn accessibility vì chưa thực hiện kiểm thử chuyên biệt.

## 3. Kết luận điều hành hiện tại

SmartStock có phạm vi chức năng rộng cho bán hàng, kho, tài chính, công nợ, thuế, nhân viên và cấu
hình. Tuy nhiên source local ngày 01/08/2026 chưa an toàn để coi là bản production tin cậy nếu chưa
xử lý các vấn đề ưu tiên sau:

1. API tạo đơn vẫn dùng `unitPrice` do client gửi, chỉ kiểm tra không âm; backend chưa quyết định giá
   theo sản phẩm/chính sách/quyền ghi đè.
2. Báo cáo giá vốn hàng hoàn có thể trừ toàn bộ `total_cogs` của đơn cho một lần hoàn một phần.
3. Nhiều danh sách và form chọn dữ liệu chỉ tải trang 1 mặc định 20 dòng, không có phân trang/tải tiếp.
4. Metadata TypeORM của auth đã được sửa và có regression test; production vẫn chưa có migration
   `20260801_harden_authentication.sql`, vì vậy chưa được deploy backend auth mới trước khi sao lưu,
   cấu hình ba secret riêng và chạy migration có kiểm soát.
5. `inventory_stocks` chưa có unique `(shop_id, warehouse_id, product_id)` trong entity/migration
   hiện có; `sales_return_items` cũng thiếu liên kết dòng bán gốc và cost snapshot.
6. Đối soát mở rộng phát hiện mỗi shop có 30 hóa đơn đầu vào không có dòng hàng; 268 hóa đơn bán
   ở shop 34 và 290 ở shop 35 không tự đối soát được vì header lưu sau giảm giá nhưng invoice thiếu
   trường `discount_amount`.

Hai kết luận cũ đã được đóng ở source hiện tại: chỉ còn một entity `invoices`, và màn Sổ nợ đã dùng
API `/customer-receivables` thay cho dữ liệu hard-code. Chi tiết mới nhất nằm tại
[Audit tổng thể 01/08](20_COMPREHENSIVE_UI_FLOW_REPORTING_AUDIT_20260801.md),
[Data Dictionary](03_DATA_DICTIONARY_AND_SCHEMA.md) và
[Ma trận chụp production](21_PRODUCTION_SCREEN_CAPTURE_MATRIX_20260801.md).

## 4. Danh mục tài liệu

| Tài liệu | Mục đích |
|---|---|
| [01 - BRD](01_BUSINESS_REQUIREMENT_DOCUMENT_BRD.md) | Mục tiêu, phạm vi và yêu cầu nghiệp vụ |
| [02 - SRS](02_SYSTEM_REQUIREMENT_SPECIFICATION_SRS.md) | Yêu cầu hệ thống, use case và tiêu chí chấp nhận |
| [03 - Data Dictionary & ERD](03_DATA_DICTIONARY_AND_SCHEMA.md) | Mô hình dữ liệu thực tế từ entity/migration |
| [04 - RBAC](04_USER_ROLES_AND_RBAC_MATRIX.md) | Vai trò, quyền hiện tại và quyền mục tiêu |
| [05 - Thuế](05_TAX_COMPLIANCE_GUIDELINES.md) | Tách hành vi code khỏi quy định pháp luật |
| [06 - UI/UX production](06_UI_UX_AUDIT_REPORT.md) | Đánh giá desktop/mobile bằng ảnh mới |
| [07 - As-Is / To-Be](07_AS_IS_TO_BE_WORKFLOWS.md) | Luồng hiện tại và luồng mục tiêu |
| [08 - Traceability Matrix](08_REQUIREMENTS_TRACEABILITY_MATRIX.md) | Yêu cầu → màn hình → API → dữ liệu → kiểm thử |
| [09 - Verification Report](09_CURRENT_STATE_VERIFICATION_REPORT.md) | Đúng/sai/chưa đủ bằng chứng và mức ảnh hưởng |
| [10 - Backlog & Roadmap](10_PRODUCT_BACKLOG_AND_RELEASE_ROADMAP.md) | P0, V1.1, V1.2, V2.0 |
| [11 - Acceptance Tests](11_ACCEPTANCE_TEST_CATALOG.md) | Danh mục kiểm thử nghiệm thu cho bản tiếp theo |
| [12 - UI/UX Visual Upgrade Plan](12_UI_UX_VISUAL_UPGRADE_MASTER_PLAN.md) | Kế hoạch nâng cấp giao diện theo Material 3 và nguyên tắc Taste |
| [13 - Production UI/UX vòng 2](13_PRODUCTION_UI_REVIEW_ROUND_2.md) | Audit 25 viewport/màn, phát hiện, bản vá và backlog tiếp theo |
| [14 - Responsive fill layout](14_RESPONSIVE_FILL_LAYOUT_UPGRADE.md) | Quy tắc, thành phần và kiểm thử cho bố cục tự co giãn theo vùng chứa |
| [20 - Audit UI, luồng và báo cáo 01/08](20_COMPREHENSIVE_UI_FLOW_REPORTING_AUDIT_20260801.md) | Đánh giá toàn hệ thống, benchmark, cấu trúc bảng/biểu đồ và lộ trình P0–V2.0 |
| [21 - Ma trận chụp production](21_PRODUCTION_SCREEN_CAPTURE_MATRIX_20260801.md) | Phạm vi 55 route, màn con, trạng thái và tiêu chí ảnh desktop/mobile |
| [22 - Smoke test production sau đăng nhập](22_PRODUCTION_AUTHENTICATED_SMOKE_TEST_20260801.md) | 48 API đọc, 47 route protected, đối soát hai shop và sai lệch Kho/Công nợ |
| [23 - KPI, report, table và data benchmark](23_KPI_REPORT_TABLE_AND_DATA_BENCHMARK_20260801.md) | Benchmark chính thức, KPI catalog, report/table blueprint, data grain và kết quả 24 quy tắc chất lượng dữ liệu |

## 5. Nguồn bằng chứng

- Mã frontend: [`../lib/`](../lib/)
- Mã backend: [`../backend/src/`](../backend/src/)
- Migration/SQL: [`../backend/database/`](../backend/database/)
- Ảnh production: [`assets/production-audit-2026-07-25/`](assets/production-audit-2026-07-25/)
- Ảnh production vòng 2: [`assets/production-ui-audit-2026-07-26-round2/`](assets/production-ui-audit-2026-07-26-round2/)
- Baseline trước bản vá: Flutter Web release và backend TypeScript build thành công.
- Vòng kiểm tra 01/08: backend build/lint và P0 suite `47/47` đạt; Flutter analyze sạch,
  Flutter suite `57/57` đạt và Flutter Web release build thành công. Kiểm toán DB chỉ đọc cũng chạy được;
  migration auth production vẫn là điều kiện chặn phát hành backend.
- Ảnh public production vòng 01/08: [`screenshots/20260801-production-audit-run2/`](screenshots/20260801-production-audit-run2/)
  gồm 10 trạng thái desktop/mobile; 55 route sau đăng nhập vẫn chờ phiên test hợp lệ.

## 6. Quy tắc quản trị tài liệu

- Khi code, API và tài liệu mâu thuẫn, trạng thái mặc định là `Đúng một phần` hoặc
  `Không chính xác`, không tự chọn tài liệu làm nguồn đúng.
- Mọi thay đổi công thức, schema hoặc API contract phải có yêu cầu thay đổi riêng.
- Kết luận pháp lý phải dẫn nguồn chính thức và cần người có chuyên môn thuế duyệt
  trước khi phát hành.
- Mỗi bản phát hành phải cập nhật commit baseline, ảnh production, ma trận truy vết
  và báo cáo sai lệch.
