# Đối soát tổng quan dòng tiền — 20/08/2026

## 1. Nguồn và grain

- Màn: `/#/finance`.
- API: `/cash-transactions/summary`, `/cash-transactions/expenses-by-category`,
  `/cash-transactions`.
- Nguồn DB: `cash_transactions`, grain một giao dịch thu hoặc chi của một cửa hàng.
- Phạm vi tổng hợp nhiều cửa hàng lấy từ danh sách shop đã được middleware phân quyền.

## 2. Định nghĩa đang hiển thị

| Chỉ tiêu | Công thức |
|---|---|
| Tổng thu | Tổng `amount` của giao dịch `INCOME` trong kỳ |
| Tổng chi | Tổng `amount` của giao dịch `EXPENSE` trong kỳ |
| Dòng tiền thuần | Tổng thu − tổng chi trong kỳ |
| Quỹ tiền mặt | Thu tiền mặt − chi tiền mặt từ đầu dữ liệu đến ngày cuối kỳ |
| Tỷ trọng nhóm chi | Giá trị nhóm chi ÷ tổng tiền chi trong kỳ |

Các chỉ tiêu trên là **dòng tiền**, không đồng nghĩa doanh thu, lợi nhuận kế toán hoặc số dư
ngân hàng. Lợi nhuận tiếp tục lấy từ sổ cái 511/632/642 ở báo cáo kết quả kinh doanh.

## 3. Đối soát DB chỉ đọc

Shop 34+35, kỳ 01/07–28/07/2026:

| Chỉ tiêu | Kết quả |
|---|---:|
| Tổng thu | 1.303.137.000 đ |
| Tổng chi | 1.330.278.000 đ |
| Dòng tiền thuần | -27.141.000 đ |
| Quỹ tiền mặt tại 28/07/2026 | 2.736.649.000 đ |
| Số ngày trên biểu đồ | 28 |
| Số nhóm chi | 6 |

Tổng sáu nhóm chi bằng đúng tổng chi 1.330.278.000đ. Nhóm nhỏ thứ sáu là
`DELIVERY` 9.058.000đ (20 giao dịch), trước đây bị cắt khỏi giao diện vì UI chỉ lấy năm nhóm.

## 4. Cải thiện local

- Hiển thị đủ sáu nhóm chi hiện có trong DB và thêm tỷ trọng phần trăm cạnh số tiền.
- Việt hóa các mã `DELIVERY`, `CAPITAL`, `LOAN`; mã vẫn được giữ nguyên trong DB/API để
  không đổi hợp đồng dữ liệu.
- Thẻ Quỹ tiền mặt ghi rõ ngày `as-of` lấy từ `period.to` của backend thay vì nhãn mơ hồ
  “Hiện tại”.
- Không thêm KPI suy diễn hoặc dữ liệu nhập trực tiếp ở Flutter.

## 5. Giới hạn

- Dữ liệu demo dừng ở 28/07/2026 nên kỳ hiện tại tháng 08 không có phát sinh; UI hiển thị
  trạng thái rỗng là đúng với DB nhưng chưa đủ để đánh giá vận hành gần thời gian thực.
- Sai lệch lịch sử giữa giao dịch tiền và bút toán 111/112 đã được báo cáo riêng; vì vậy
  chưa nâng trạng thái đối soát kế toán lên “Đã xác minh”.
- Chưa có visual audit sau đăng nhập trong vòng này; mới xác minh code, công thức, DB và test.

## 6. Kiểm thử

- Backend P0 `161/161` đạt; build/lint đạt.
- Flutter analyze toàn dự án không lỗi; `101/101` test đạt trước thay đổi trình bày này.
- Test trọng tâm Việt hóa Tài chính `4/4` đạt sau thay đổi.
- Không deploy.
