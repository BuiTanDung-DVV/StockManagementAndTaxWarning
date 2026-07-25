# Danh mục kiểm thử nghiệm thu

## 1. Tiền điều kiện chung

- Môi trường staging tách production.
- Seed data có hai shop, một owner, một employee theo từng cấp quyền.
- Múi giờ kiểm thử: `Asia/Saigon`.
- Có sản phẩm thường, dưới định mức, hết hàng, quản lý theo lô và không theo lô.
- Có đơn tiền mặt, chuyển khoản, mua thiếu, hoàn một phần và hủy.
- Có bộ expected result do BA/kế toán xác nhận.

## 2. Authentication

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-AUTH-01 | Đăng nhập đúng/sai, tài khoản inactive | Đúng trả token + shops; sai/inactive trả 401, không lộ stack/secret |
| TC-AUTH-02 | OTP đúng, sai, hết hạn, dùng lại, gửi nhiều lần | Chỉ OTP đúng/còn hạn/dùng một lần tạo tài khoản; có rate limit |
| TC-AUTH-03 | Access hết hạn, refresh hợp lệ/hết hạn/bị revoke | Rotation đúng; token cũ không tái dùng; UI xử lý logout rõ |
| TC-AUTH-04 | Đổi mật khẩu khi có nhiều phiên | Phiên theo chính sách bị thu hồi; audit log được ghi |

## 3. RBAC và shop scope

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-RBAC-01 | User A gửi shopId của shop không thuộc về | 403 ở mọi endpoint shop-scoped |
| TC-RBAC-02 | Employee có `view`, `edit`, `none` theo module | View chỉ đọc; edit ghi đúng phạm vi; none nhận 403 |
| TC-RBAC-03 | Employee gửi `x-shop-id: all` | Không nâng quyền; chỉ tổng hợp shop được phép và đúng permission |
| TC-RBAC-04 | Owner đổi role của chính mình/chủ cuối cùng | Bị chặn theo rule tránh shop mất owner |
| TC-RBAC-05 | Customer/supplier/tag/tax-config | Kiểm tra đủ owner/view/edit/none ở API, không chỉ ẩn menu |

## 4. Bán hàng, thanh toán, hoàn/hủy

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-SALE-01 | Bán 2 mặt hàng tiền mặt | Một đơn, đúng item/tổng/thuế; tồn giảm; sổ quỹ tăng; audit có correlation ID |
| TC-SALE-02 | Thanh toán hỗn hợp tiền mặt + chuyển khoản + nợ | Tổng payment = tổng đơn; từng nguồn vào đúng account; receivable bằng phần thiếu |
| TC-SALE-03 | Hoàn một phần rồi retry callback | Tồn/tiền/công nợ đảo đúng một lần; retry không nhân đôi |
| TC-SALE-04 | Hủy đơn trước/sau thanh toán | Rule trạng thái rõ; không để movement/payment mồ côi |
| TC-SALE-05 | So sánh summary và list theo 4 trạng thái/kỳ | Số đơn, doanh thu, lợi nhuận khớp dữ liệu chi tiết |
| TC-SALE-06 | POS 390×844 | Tìm hàng, thêm giỏ, chọn khách, thanh toán và thấy kết quả không bị che |

## 5. Kho và giá vốn

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-INV-01 | Sản phẩm dưới min stock | Dashboard và kho cùng số lượng/danh sách |
| TC-INV-02 | Nhận PO có phí mua hàng | Tồn/lô tăng; landed cost phân bổ đúng; journal/movement liên kết PO |
| TC-INV-03 | Kiểm kê thừa/thiếu | Chênh lệch cần duyệt; movement có actor/reason; tồn cuối đúng |
| TC-INV-04 | Báo cáo XNT | `tồn đầu + nhập - xuất ± điều chỉnh = tồn cuối` cho từng SKU/lô |
| TC-INV-05 | Bán/hoàn theo FIFO hoặc bình quân | COGS đúng cấu hình và đảo đúng khi hoàn |
| TC-INV-06 | Hai request bán đồng thời gần hết tồn | Không âm tồn hoặc oversell ngoài rule |

## 6. Tài chính và công nợ

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-FIN-01 | Đối chiếu cash account, transactions và dashboard | Số dư đầu + thu - chi = cuối; cùng `asOf` cho kết quả giống nhau |
| TC-FIN-02 | P&L có sale, COGS, expense, return | Lợi nhuận khớp expected result; không trộn tiền mặt với doanh thu dồn tích |
| TC-FIN-03 | Đổi khoảng thời gian/timezone | Giao dịch biên ngày chỉ thuộc đúng một kỳ |
| TC-DEBT-01 | Tạo đơn mua thiếu | Receivable thật xuất hiện; không có bản ghi mẫu |
| TC-DEBT-02 | Thu nợ một phần/toàn bộ | Còn nợ, payment history và sổ quỹ cập nhật trong một transaction |
| TC-DEBT-03 | Xuất Excel nợ | Số dòng, tổng nợ/đã trả/còn nợ khớp API và có kỳ xuất |

## 7. Thuế và báo cáo

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-TAX-01 | Kỳ trước/sau ngày hiệu lực rule | Chọn đúng phiên bản rule; UI hiển thị nguồn và ngày hiệu lực |
| TC-TAX-02 | Doanh thu/lợi nhuận âm, 0, dương | Không tạo nghĩa vụ âm; trạng thái thiếu dữ liệu rõ |
| TC-TAX-03 | Xuất XML với bộ fixture | Pass XSD/validator và import HTKK đúng phiên bản |
| TC-TAX-04 | Thiếu/sai MST hoặc hồ sơ | Chặn xuất; chỉ rõ trường cần sửa; không dùng fallback |
| TC-TAX-05 | Export cùng dữ liệu hai lần | Nội dung deterministic hoặc metadata biến đổi được mô tả; có checksum/audit |
| TC-REP-01 | Excel/XML với dataset lớn và ký tự Việt | Không mất dòng, không lỗi encoding, tổng kiểm soát khớp |

## 8. Dữ liệu, migration và API

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-DATA-01 | Khởi tạo metadata TypeORM | Không trùng tên bảng/entity owner; không trùng route shadow |
| TC-DATA-02 | Chạy migration mới/rollback trên bản sao staging | Có checksum, idempotency theo thiết kế, không mất dữ liệu |
| TC-DATA-03 | Cold start Vercel | Chỉ kết nối DB; không chạy DDL; request đầu trong SLA |
| TC-API-01 | Validation sai và not-found | Dùng 400/404 phù hợp, response contract thống nhất |
| TC-API-02 | Lỗi server | Không lộ stack, SQL, token, secret hoặc PII nhạy cảm |

## 9. UX, responsive và accessibility

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-UX-01 | API chậm/rỗng/4xx/5xx ở 8 màn chính | Loading, empty, error và retry rõ; không treo/blank |
| TC-UX-02 | 390×844, 768×1024, 1440×900 | Không overflow/cắt CTA; FAB/nav không che nội dung |
| TC-UX-03 | Keyboard-only và focus | Thứ tự focus hợp lý, thao tác chính dùng được, focus visible |
| TC-UX-04 | Screen reader và semantic labels | Icon/button/input có tên; thay đổi trạng thái được thông báo |
| TC-UX-05 | Zoom 200% và contrast | Không mất nội dung/chức năng; contrast đạt chuẩn đã chọn |

Chỉ ghi `Accessibility đạt` sau khi TC-UX-03 đến TC-UX-05 được thực hiện bằng công
cụ và thiết bị hỗ trợ phù hợp.

## 10. AI và audit

| ID | Kịch bản | Kết quả mong đợi |
|---|---|---|
| TC-AI-01 | Hỏi thông tin thuế có nguồn còn/đã hết hiệu lực | Chỉ dùng nguồn được duyệt; có citation; nguồn hết hiệu lực bị loại |
| TC-AI-02 | Không có nguồn đủ tin cậy | Trả “chưa đủ dữ liệu”, không bịa hoặc khẳng định pháp lý |
| TC-AI-03 | Gỡ tài liệu | Tài liệu không còn được retrieval; có audit |
| TC-AUD-01 | Sale/return/stock/role/tax export | Log đủ actor/shop/action/time/correlation, redaction dữ liệu nhạy cảm |

## 11. Điều kiện đóng phiên bản

- P0 không còn test fail hoặc finding mở.
- Build, lint và automated tests chạy trong CI.
- Smoke test production không làm thay đổi dữ liệu ngoài kịch bản được duyệt.
- Verification report và traceability matrix được cập nhật bằng bằng chứng mới.
- Người phụ trách nghiệp vụ và chuyên gia thuế duyệt các công thức liên quan.
