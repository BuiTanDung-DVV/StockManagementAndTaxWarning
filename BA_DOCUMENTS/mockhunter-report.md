# MockHunter production report

Ngày cập nhật: **09/08/2026**
Ứng dụng: `https://smartstock-tax.vercel.app/`

## Tóm tắt verdict

| Verdict | Số nhóm | Kết luận |
|---|---:|---|
| REAL | 17 | Màn hình/API chính lấy số liệu từ PostgreSQL theo `shop_id` |
| HARDCODED | 1 | Cấu hình giao diện và policy thuế trong mã; không phải giao dịch |
| MOCK | 0 | Không phát hiện marker mock trong sản phẩm, khách hàng, đơn hoặc giao dịch production |
| BROKEN | 2 | Quét hóa đơn chưa hoàn thiện; dữ liệu hóa đơn còn thiếu dòng/chiết khấu |
| UNKNOWN | 2 | Chưa kiểm tra trực quan các màn cần đăng nhập ở bản local mới; HTKK chưa được import thử |

## Phát hiện chính

| Khu vực | Verdict | Nguồn | Hành động |
|---|---|---|---|
| Dashboard, biểu đồ bán chạy | REAL | API bán hàng → `sales_orders`, `sales_order_items` | Giữ |
| Sản phẩm, giá vốn, lô, quy đổi | REAL | API sản phẩm → các bảng sản phẩm theo `shop_id` | Đã bổ sung dữ liệu |
| Nhập–xuất–tồn, kiểm kê, cảnh báo hạn | REAL | API kho → movement, stock, batch, stock take | Đã bổ sung dữ liệu |
| Bán hàng, thanh toán, trả hàng | REAL | API bán hàng → đơn, dòng hàng, payment, return | Đã đối soát |
| Công nợ | REAL | API khách hàng/nhà cung cấp → receivable/payable | Đã đối soát |
| Dòng tiền, ngân sách, dự báo | REAL | API tài chính → cash, ledger, budget, forecast | Đã bổ sung dữ liệu |
| Hóa đơn, bảng kê chưa hóa đơn | REAL + BROKEN | API tài chính → invoice và purchase-without-invoice | 30 hóa đơn/cửa hàng thiếu dòng; chưa mô hình hóa chiết khấu |
| Thuế | REAL + HARDCODED | Giao dịch DB + policy/cấu hình thuế | Phải đối chiếu pháp lý riêng |
| Kiến thức AI | REAL | `/ai-knowledge` → `ai_knowledge_documents` | Đã chuyển khỏi local defaults |
| Quét hóa đơn | BROKEN | Có bảng `invoice_scans` nhưng màn hình chưa hoàn thiện camera/OCR | Không giả lập kết quả OCR; đưa vào backlog |
| Chứng từ công nợ | REAL, chưa production | Cloudinary + `debt_evidences` + hồ sơ khách hàng | Đã nối tải/xem/xóa ảnh; DB hiện chưa có bản ghi người dùng |
| Nhắc nợ | REAL, chưa production | Nội dung dựng từ tên khách và số nợ API | Đã bỏ thông báo giả mở ứng dụng; chỉ xác nhận sao chép nội dung để người dùng tự gửi |
| Xuất XML ở màn khai thuế cũ | REAL | `TaxService.exportHTKK` → `/tax/export-htkk` → giao dịch DB | Đã sửa; chỉ mẫu 01/CNKD được bật |

## Bằng chứng database

- Shop 34: 250 sản phẩm, 7.595 đơn bán, 8.394 giao dịch tiền, 1.096 ngày chốt quỹ.
- Shop 35: 250 sản phẩm, 7.783 đơn bán, 8.561 giao dịch tiền, 1.096 ngày chốt quỹ.
- Cả hai cửa hàng: 0 marker sản phẩm giả, 0 khách hàng giả, 0 đơn/giao dịch ghi chú mock.
- Mỗi cửa hàng đạt 28/32 nhóm đối soát; ba nhóm lỗi gồm dòng hóa đơn,
  chiết khấu hóa đơn và phân loại 111/112 lịch sử; một cảnh báo là dữ liệu chưa
  nối dài đến ngày kiểm tra.
- Schema `purchase_without_invoice_items` đã tương thích API mới.
- Không còn `Future.delayed` giả lập kết quả xuất/nộp tờ khai; nộp trực tuyến chưa
  tích hợp được thông báo rõ thay vì báo thành công giả.

Chi tiết màn hình, API, bảng nguồn và số lượng xem tại
`17_BAO_CAO_NGUON_DU_LIEU_PRODUCTION.md`.

## Giới hạn kiểm tra giao diện

Trang public tải được. Các thay đổi ngày 09/08 mới được xác minh bằng chuỗi mã nguồn →
API → truy vấn DB chỉ đọc → kiểm thử local; chưa được xem là đã xác minh trên production.
Không tạo giao dịch, xóa dữ liệu hoặc tải tệp vào production trong đợt kiểm tra này.
