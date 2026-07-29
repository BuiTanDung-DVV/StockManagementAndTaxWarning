# MockHunter production report

Ngày kiểm tra: **29/07/2026**  
Ứng dụng: `https://smartstock-tax.vercel.app/`

## Tóm tắt verdict

| Verdict | Số nhóm | Kết luận |
|---|---:|---|
| REAL | 17 | Màn hình/API chính lấy số liệu từ PostgreSQL theo `shop_id` |
| HARDCODED | 1 | Cấu hình giao diện và policy thuế trong mã; không phải giao dịch |
| MOCK | 0 | Không phát hiện marker mock trong sản phẩm, khách hàng, đơn hoặc giao dịch production |
| BROKEN | 0 | Luồng xuất XML cũ đã được nối vào API thật |
| UNKNOWN | 2 | Ảnh quét hóa đơn và chứng từ công nợ chưa có tệp người dùng tải lên |

## Phát hiện chính

| Khu vực | Verdict | Nguồn | Hành động |
|---|---|---|---|
| Dashboard, biểu đồ bán chạy | REAL | API bán hàng → `sales_orders`, `sales_order_items` | Giữ |
| Sản phẩm, giá vốn, lô, quy đổi | REAL | API sản phẩm → các bảng sản phẩm theo `shop_id` | Đã bổ sung dữ liệu |
| Nhập–xuất–tồn, kiểm kê, cảnh báo hạn | REAL | API kho → movement, stock, batch, stock take | Đã bổ sung dữ liệu |
| Bán hàng, thanh toán, trả hàng | REAL | API bán hàng → đơn, dòng hàng, payment, return | Đã đối soát |
| Công nợ | REAL | API khách hàng/nhà cung cấp → receivable/payable | Đã đối soát |
| Dòng tiền, ngân sách, dự báo | REAL | API tài chính → cash, ledger, budget, forecast | Đã bổ sung dữ liệu |
| Hóa đơn, bảng kê chưa hóa đơn | REAL | API tài chính → invoice và purchase-without-invoice | Đã sửa tương thích schema legacy |
| Thuế | REAL + HARDCODED | Giao dịch DB + policy/cấu hình thuế | Phải đối chiếu pháp lý riêng |
| Kiến thức AI | REAL | `/ai-knowledge` → `ai_knowledge_documents` | Đã chuyển khỏi local defaults |
| Quét hóa đơn | UNKNOWN | API dùng `invoice_scans`; Flutter chưa hoàn thiện camera/OCR | Không tạo ảnh giả |
| Chứng từ công nợ | UNKNOWN | API dùng `debt_evidences` | Chỉ ghi khi có tệp thật |
| Xuất XML ở màn khai thuế cũ | REAL | `TaxService.exportHTKK` → `/tax/export-htkk` → giao dịch DB | Đã sửa; chỉ mẫu 01/CNKD được bật |

## Bằng chứng database

- Shop 34: 250 sản phẩm, 7.595 đơn bán, 8.394 giao dịch tiền, 1.096 ngày chốt quỹ.
- Shop 35: 250 sản phẩm, 7.783 đơn bán, 8.561 giao dịch tiền, 1.096 ngày chốt quỹ.
- Cả hai cửa hàng: 0 marker sản phẩm giả, 0 khách hàng giả, 0 đơn/giao dịch ghi chú mock.
- Mỗi cửa hàng đạt 12/12 phép đối soát dữ liệu.
- Schema `purchase_without_invoice_items` đã tương thích API mới.
- Không còn `Future.delayed` giả lập kết quả xuất/nộp tờ khai; nộp trực tuyến chưa
  tích hợp được thông báo rõ thay vì báo thành công giả.

Chi tiết màn hình, API, bảng nguồn và số lượng xem tại
`17_BAO_CAO_NGUON_DU_LIEU_PRODUCTION.md`.

## Giới hạn kiểm tra giao diện

Trang public tải được và không ghi nhận lỗi console lúc mở. Flutter Web dựng nội dung
trong `flutter-view`, còn phiên trình duyệt kiểm tra không có đăng nhập nên không thể
đối chiếu trực quan từng số sau xác thực trong lần này. Bằng chứng REAL được xác nhận
bằng chuỗi mã nguồn → API → truy vấn DB production và bộ đối soát sau commit dữ liệu.
