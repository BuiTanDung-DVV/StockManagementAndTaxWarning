# Kiểm tra hợp đồng dữ liệu UI và tính chính xác số liệu — 20/08/2026

## 1. Phạm vi

- Đọc code Flutter và backend hiện tại.
- Chạy kiểm thử backend/Flutter liên quan.
- Đối soát chỉ đọc DB cho cửa hàng 34 và 35.
- Không ghi DB, không migration, không deploy.

Audit trực quan production chưa được chấp nhận làm bằng chứng trong lượt này vì công cụ
trình duyệt mở được trang nhưng không chụp được ảnh hợp lệ. Không kết luận accessibility
hoặc chất lượng toàn bộ màn hình từ code tĩnh.

## 2. Nguồn dữ liệu và ranh giới khóa

- Dữ liệu nghiệp vụ đi theo luồng `PostgreSQL → backend API → Flutter`.
- Gemini, Cloudinary secret, DB URL, JWT/OTP secret chỉ được đọc ở backend.
- Flutter không chứa chuỗi kết nối PostgreSQL hoặc tên khóa bí mật backend.
- `API_URL` và Google OAuth Client ID là cấu hình công khai bắt buộc của web, không phải
  secret; Google Client ID phải được giới hạn bằng domain và redirect URI.
- Provider của bán hàng, kho, tài chính, khách hàng, nhà cung cấp và công nợ từ chối
  response thiếu contract thay vì dựng danh sách rỗng hoặc KPI 0 giả.
- Ngành nghề trong cấu hình thuế thiếu hoặc không thuộc `TRADE/PRODUCTION/SERVICE/OTHER`
  nay gây lỗi cấu hình; không tự rơi về `TRADE`.

## 3. Bảng và biểu đồ hiện có

| Phân hệ | Thành phần quyết định chính | Nguồn |
|---|---|---|
| Tổng quan | Doanh thu so sánh kỳ, top 10 sản phẩm + tăng trưởng + biên lãi, ưu tiên công việc, đơn gần đây | Sales/finance/inventory DB qua API |
| Bán hàng | Doanh thu thuần và lợi nhuận gộp 7 ngày, tiền thu theo phương thức, KPI doanh thu/lợi nhuận/hàng trả, top hàng trả, bảng đơn | Sales order/payment/return DB |
| Kho | KPI SKU/tồn thấp/hết hạn/chậm luân chuyển/vốn tồn, phân bổ danh mục, ABC, danh sách ưu tiên | Inventory stock/lot/movement/product DB |
| Tài chính | Dòng tiền thu–chi theo ngày, nhóm tiền chi, giao dịch gần đây, lãi lỗ | Cash transaction/journal DB |
| Công nợ | Tuổi nợ phải thu/phải trả, nhóm quá hạn, danh sách đối tác ưu tiên | Receivable/payable DB |
| Hóa đơn/thuế | VAT đầu vào/đầu ra, chất lượng hóa đơn, nghĩa vụ và policy theo năm hiệu lực | Invoice/tax policy DB |

Số lượng biểu đồ hiện tại đủ cho màn vận hành V1.1. Không nên thêm biểu đồ chỉ để lấp
chỗ. Ba biểu đồ còn có giá trị cho V1.2 khi backend có contract đối soát riêng:

1. Biên lợi nhuận theo tháng và nhóm hàng — đặt dưới biểu đồ doanh thu trên Tổng quan.
2. Vốn tồn và ngày tồn bình quân theo tháng — đặt trong Kho, trước danh sách chậm luân chuyển.
3. Vốn lưu động `phải thu - phải trả` theo kỳ — đặt trong Tài chính, cạnh báo cáo tuổi nợ.

Mỗi biểu đồ mới phải lấy chuỗi thời gian tổng hợp từ backend; Flutter không tự cộng từ
trang danh sách hoặc dữ liệu đang hiển thị.

## 4. Kết quả đối soát DB

Kỳ kiểm tra: `01/07/2026–28/07/2026`.

| Kiểm tra | Cửa hàng 34 | Cửa hàng 35 | Trạng thái |
|---|---:|---:|---|
| Doanh thu thuần | 649.165.000đ | 785.480.000đ | Khớp sổ cái, lệch 0đ |
| Giá vốn | 498.135.000đ | 647.082.000đ | Khớp sổ cái, lệch 0đ |
| Lợi nhuận gộp | 151.030.000đ | 138.398.000đ | Khớp sổ cái, lệch 0đ |
| Tổng chuỗi ngày doanh thu/giá vốn/lợi nhuận | Lệch 0/0/0đ | Lệch 0/0/0đ | Khớp tổng kỳ và sổ cái |
| Top sản phẩm | 10 dòng | 10 dòng | Lệch hạng/chỉ số/tăng trưởng: 0 |
| Nhập/Xuất | 4.519/4.437 | 1.746/1.726 | Lệch DB: 0; phương trình XNT lệch 0 |
| Tồn master/Tồn lô | 22.380/22.380 | 5.430/5.430 | Không có SKU lệch hoặc thiếu lô |
| Công nợ phải thu | 904.500.000đ | 1.208.989.000đ | Tổng/bucket/số khoản/số khách lệch 0 |

## 5. Sai lệch và dữ liệu thiếu

| Vấn đề | Bằng chứng | Ảnh hưởng | Hướng xử lý |
|---|---|---|---|
| Hóa đơn nhập thiếu dòng | 1 hóa đơn/cửa hàng trong tháng 07 | Không thể đối soát chi tiết hàng mua | Backfill có kiểm soát sau khi duyệt nguồn dòng PO |
| Chiết khấu đơn bán chưa phân bổ vào dòng hóa đơn | 10 hóa đơn shop 34, 11 hóa đơn shop 35 | Tổng header đúng nhưng báo cáo theo dòng thiếu chiết khấu | Migration/backfill riêng, có backup và truy vấn hậu kiểm |
| Dữ liệu vận hành chậm | Đã nối dài đến 24/08/2026; bốn nguồn sales/cash/movement/invoice có độ trễ 0 ngày | Đã đủ để kiểm thử kỳ hiện tại tại thời điểm đối soát | Giữ banner độ mới và chạy script nối dài khi bộ demo ngừng phát sinh |
| Chứng từ công nợ và scan hóa đơn chưa có dữ liệu test | `debt_evidences=0`, `invoice_scans=0` ở shop 34/35 | Chưa smoke test được danh sách/preview ảnh bằng dữ liệu thật | Tạo bộ media test chỉ sau khi duyệt ghi DB/Cloudinary |
| Shop 36 chưa đủ dữ liệu | 1 sản phẩm, không đơn/khách/NCC | Không dùng làm cửa hàng mẫu | Hoàn thiện seed riêng hoặc loại khỏi phạm vi demo |

## 6. Thay đổi code trong lượt kiểm tra

- Backend lịch sử chốt ngày trả đủ `totalPages`.
- Provider tài chính bắt buộc contract phân trang giao dịch/hóa đơn/chốt ngày.
- Biểu đồ nhóm chi bắt buộc `categories`, `recentItems`, `total` và số liệu từng nhóm.
- Tổng hợp VAT bắt buộc đủ `vatIn/vatOut/vatOwed/vatCredit`.
- Provider khách hàng/nhà cung cấp bắt buộc metadata, bốn bucket và tổng tuổi nợ.
- Cấu hình thuế không còn dùng ngành nghề mặc định khi DB thiếu/sai.
- API bán hàng trả chuỗi ngày gồm doanh thu thuần, giá vốn, lợi nhuận gộp và biên lãi;
  số hoàn hàng và giá vốn hoàn được trừ đúng ngày phát sinh.
- Màn Bán hàng dùng biểu đồ cột nhóm 7 ngày: doanh thu ở cột trái, lợi nhuận gộp ở
  cột phải; có chú giải, đơn vị đồng, tooltip và hỗ trợ ngày lợi nhuận âm.
- Flutter kiểm tra đủ contract chuỗi ngày, không tự cộng lại dữ liệu từ bảng đơn hàng.

## 7. Bằng chứng kiểm thử

- Backend build: đạt.
- Backend P0: `198/198` đạt.
- Đối soát DB chuỗi ngày với tổng kỳ và sổ cái tại shop 34/35: mọi sai lệch bằng 0.
- Kiểm thử widget biểu đồ và bố cục liên quan: `18/18` đạt.
- Kiểm thử Flutter liên quan công nợ/hóa đơn/chốt ngày: `10/10` đạt.
- Kiểm thử cấu hình thuế DB: `7/7` đạt.
- Dart analyze các provider vừa sửa: không có lỗi.
- `git diff --check`: không có lỗi whitespace; chỉ có cảnh báo chuyển LF/CRLF của worktree.

## 8. Bổ sung dữ liệu ngày 24/08/2026

- Shop 34 và 35 mỗi nơi thêm 81 đơn bán, 27 hóa đơn bán, 27 khoản chi và 27 chốt quỹ
  cho khoảng 29/07–24/08/2026.
- Kỳ 01–24/08: doanh thu/giá vốn/lợi nhuận shop 34 lần lượt là
  76.566.000đ/59.295.000đ/17.271.000đ; shop 35 là
  56.897.000đ/43.285.000đ/13.612.000đ.
- Cả hai shop có chênh lệch KPI–sổ cái, chuỗi ngày, XNT, hạng/chỉ số/tăng trưởng
  top sản phẩm bằng 0.
- Sai lệch lịch sử 111/112 đã được sửa ngày 24/08 bằng 1.704 bút toán thu công nợ
  cân bằng; hậu kiểm shop 34/35 đều có 0 vi phạm.
