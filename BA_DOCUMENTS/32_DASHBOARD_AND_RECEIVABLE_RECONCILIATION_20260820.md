# Đối soát Dashboard và công nợ phải thu — 20/08/2026

## 1. Dashboard ↔ Bán hàng ↔ Sổ cái

Grain đối soát: một cửa hàng, kỳ 01/07–28/07/2026. Nguồn gồm đơn bán, dòng hàng,
hàng trả và bút toán 511/632. Script tái lập:
`backend/src/scripts/audit-kpi-reconciliation.ts`.

| Cửa hàng | Doanh thu thuần | Giá vốn | Lợi nhuận gộp | Chênh Dashboard ↔ sổ cái |
|---:|---:|---:|---:|---:|
| 34 | 649.165.000 đ | 498.135.000 đ | 151.030.000 đ | 0 đ |
| 35 | 785.480.000 đ | 647.082.000 đ | 138.398.000 đ | 0 đ |

Tổng doanh thu của 28 điểm biểu đồ bằng KPI; tổng số đơn trên biểu đồ bằng số đơn header
ở từng cửa hàng và khi tổng hợp shop 34+35. Các KPI doanh thu/giá vốn/lợi nhuận gộp đủ
bằng chứng để dùng cho kỳ đã kiểm tra. Kết luận không mở rộng sang bút toán tiền 111/112.

Lỗi UI đã sửa: thao tác kéo làm mới trước đây chỉ refresh doanh thu khi người dùng đồng thời
có quyền Tài chính. Vai trò chỉ có `sales` hoặc `dashboard` nay refresh đúng sales summary và
top sản phẩm, độc lập với quyền xem quỹ.

## 2. Grain công nợ phải thu

Nguồn: `receivables` và `customers`; chỉ lấy khoản chưa `PAID/CANCELLED` và còn số dư dương.
Script tái lập: `backend/src/scripts/audit-receivables-quality.ts`.

| Cửa hàng | Khoản phải thu | Khách hàng duy nhất | Còn phải thu | Quá hạn | Cache khách hàng lệch |
|---:|---:|---:|---:|---:|---:|
| 34 | 453 | 24 | 904.500.000 đ | 886.365.000 đ | 0 đ |
| 35 | 473 | 24 | 1.208.989.000 đ | 1.179.820.000 đ | 0 đ |

Không có khoản mồ côi khách hàng, số âm hoặc `paid_amount > amount` trong phạm vi kiểm tra.

## 3. Sai lệch UI đã sửa local

- “Khách hàng còn nợ” trước đây dùng số dòng khoản phải thu: 453/473 thay vì 24/24.
- Thẻ “Đã thu hồi” chỉ cộng tiền đã thu trên khoản còn mở và hiện bằng 0, không đại diện tổng
  thu hồi lịch sử. Thẻ được thay bằng “Nợ quá hạn”.
- KPI nay tách rõ số khách duy nhất và số khoản theo đơn.
- Bảng desktop/mobile hiển thị hạn thu hoặc số ngày quá hạn.
- UI ưu tiên trường `remaining` do backend tính; chỉ fallback `totalAmount - paidAmount` cho
  response cũ.

## 4. Trạng thái và giới hạn

- **Đã xác minh**: số dư công nợ mở, số khách duy nhất, số khoản, số quá hạn và cache balance
  của hai shop tại thời điểm chạy.
- **Đã sửa local, có test**: grain KPI và refresh Dashboard.
- **Chưa visual audit production**: trình duyệt hiện chỉ ở login và chức năng chụp ảnh của tab
  bị lỗi; không dùng ảnh cũ để thay bằng chứng mới.
- Dữ liệu demo dừng 28/07/2026 nên tỷ lệ quá hạn cao là hệ quả freshness, không tự động kết
  luận chất lượng thu hồi nợ thực tế của cửa hàng.

## 5. Kiểm thử trọng tâm

- Dashboard refresh theo quyền: `4/4` đạt.
- KPI/grain công nợ và hạn thu: `2/2` đạt.
- Backend build cho hai script đối soát: đạt.
- Toàn bộ Flutter: `104/104` unit/widget test đạt; analyze toàn dự án sạch.
- Backend: build/lint sạch; toàn bộ `161/161` kiểm thử P0 đạt, gồm kiểm tra ranh giới bí mật frontend/backend.
- Không ghi DB, không deploy.
