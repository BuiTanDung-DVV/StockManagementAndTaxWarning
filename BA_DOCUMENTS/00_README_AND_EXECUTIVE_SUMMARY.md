# Bộ tài liệu BA SmartStock

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

## 3. Kết luận điều hành

SmartStock đã có phạm vi chức năng rộng cho bán hàng, kho, tài chính, công nợ, thuế,
nhân viên và cấu hình. Hai deployment production hoạt động và dùng cùng commit.
Tuy nhiên, baseline hiện tại chưa phù hợp để coi là bản production tin cậy cho dữ
liệu tài chính/thuế nếu chưa xử lý các vấn đề P0 sau:

1. Luồng “tất cả cửa hàng” có thể bỏ qua kiểm tra quyền ở backend và tự xem là
   `OWNER` ở frontend.
2. Màn thuế và kho tri thức AI vẫn dùng ngưỡng miễn thuế 100 triệu đồng/năm; nguồn
   pháp lý hiện hành năm 2026 dùng ngưỡng khác.
3. Dashboard hiển thị VAT và thuế TNDN âm khi lợi nhuận âm; đây không phải kết quả
   thuế có thể dùng để kê khai.
4. Sổ nợ khách hàng và xuất Excel nợ đang dùng dữ liệu mẫu hard-code.
5. Hai entity khác nhau cùng ánh xạ bảng `invoices`, đồng thời hai nhóm route cùng
   khai báo `/invoices`.

Các vấn đề trên được mô tả với bằng chứng và tiêu chí nghiệm thu tại
[Báo cáo xác minh](09_CURRENT_STATE_VERIFICATION_REPORT.md) và
[Product backlog](10_PRODUCT_BACKLOG_AND_RELEASE_ROADMAP.md).

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

## 5. Nguồn bằng chứng

- Mã frontend: [`../lib/`](../lib/)
- Mã backend: [`../backend/src/`](../backend/src/)
- Migration/SQL: [`../backend/database/`](../backend/database/)
- Ảnh production: [`assets/production-audit-2026-07-25/`](assets/production-audit-2026-07-25/)
- Kết quả build: Flutter Web release và backend TypeScript build đều thành công.
- Kiểm thử Flutter bị chặn bởi toolchain C++/native asset `win32` trên máy kiểm thử.
- Backend lint bị chặn vì dự án chưa khai báo/cài executable `eslint`.

## 6. Quy tắc quản trị tài liệu

- Khi code, API và tài liệu mâu thuẫn, trạng thái mặc định là `Đúng một phần` hoặc
  `Không chính xác`, không tự chọn tài liệu làm nguồn đúng.
- Mọi thay đổi công thức, schema hoặc API contract phải có yêu cầu thay đổi riêng.
- Kết luận pháp lý phải dẫn nguồn chính thức và cần người có chuyên môn thuế duyệt
  trước khi phát hành.
- Mỗi bản phát hành phải cập nhật commit baseline, ảnh production, ma trận truy vết
  và báo cáo sai lệch.
