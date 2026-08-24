# Đối soát XNT và bố cục mobile

**Ngày kiểm tra:** 20/08/2026
**Trạng thái:** Đã xác minh và sửa local; chưa deploy

## 1. Đối soát dữ liệu

Script chỉ đọc: `backend/src/scripts/audit-xnt-reconciliation.ts`.

| Cửa hàng | Số phát sinh | Tổng nhập | Tổng xuất | SKU sai phương trình | SKU lệch tồn hiện tại |
|---|---:|---:|---:|---:|---:|
| 34 | 27.952 | 202.882 | 180.502 | 0 | 0 |
| 35 | 28.295 | 67.537 | 62.107 | 0 | 0 |

Kết quả:

- Tổng nhập/xuất báo cáo khớp truy vấn SQL độc lập, chênh lệch `0`.
- Từng SKU đạt `tồn đầu + nhập − xuất = tồn cuối`.
- Kỳ bao phủ tới sau phát sinh mới nhất 28/07/2026; tồn cuối của 500 SKU khớp
  tổng `inventory_stocks` theo sản phẩm.
- Tên, SKU và đơn vị lấy từ bảng `products`; không có dữ liệu mẫu Flutter.

## 2. Cải thiện giao diện

- Dưới 720px: bỏ bảng ngang khó đọc, dùng card từng sản phẩm.
- Mỗi card có mã, tên, đơn vị và lưới 2×2: tồn đầu, nhập, xuất, tồn cuối.
- Từ 720px: giữ bảng để so sánh nhiều dòng hiệu quả.
- Số lượng dùng phân cách tiếng Việt và giữ phần thập phân khi có.
- Cảnh báo chậm luân chuyển hiển thị đơn vị thực của sản phẩm thay vì chữ
  “sản phẩm” cố định.

Không bổ sung biểu đồ cộng tổng số lượng nhập/xuất vì dữ liệu gồm bao, mét, bộ,
cái… Cộng các đơn vị đó thành một cột sẽ tạo số liệu không có ý nghĩa. Bốn KPI chỉ
đếm SKU; chi tiết số lượng luôn giữ theo từng sản phẩm và đơn vị.

## 3. Kiểm thử

- Backend lint/build đạt; audit đọc DB thoát mã thành công.
- Flutter analyze hai tệp liên quan sạch.
- `9/9` kiểm thử XNT/kho mục tiêu đạt, gồm breakpoint 390/719/720/1440 và
  định dạng `1.234,5`.

## 4. Còn lại

- Chưa kiểm tra ảnh sau đăng nhập ở 390×844 và desktop.
- Chưa smoke test production vì chưa deploy.
- Chưa hỗ trợ giá trị XNT tại ngày lịch sử; movement hiện thiếu đơn giá/tồn
  trước–sau đủ tin cậy cho mọi bản ghi cũ.
