# Audit Trang chủ và bộ chọn kỳ báo cáo

Ngày kiểm tra: 26/08/2026  
Phạm vi: Trang chủ, bộ chọn kỳ, KPI, biểu đồ doanh thu và trạng thái Action Center.

## Kết luận

Bộ chọn kỳ cũ chiếm nhiều chiều cao, lặp thông tin và làm người dùng khó nhận ra
đâu là kỳ đang xem, đâu là kỳ đối chiếu. Kỳ tùy chọn còn khởi tạo hai đầu mốc
không nhất quán; ngày không có giao dịch bị diễn giải thành cảnh báo giảm 100%.

Phiên bản mới dùng một thanh gọn trên desktop và một hàng tóm tắt trên mobile.
Ngày/Tuần cùng các lựa chọn nâng cao được đưa vào hộp chỉnh sửa; chỉ khi nhấn
`Áp dụng` thì Dashboard mới tải lại dữ liệu.

## Đối chiếu trước và sau

| Trạng thái | Bằng chứng | Kết quả |
|---|---|---|
| Trước sửa | `before/01-dashboard-header-overloaded.png` | KPI lặp ngày và phần trăm dài, dễ cắt chữ. |
| Desktop 1440 | `after/01-desktop-dashboard-1440.png` | Thanh kỳ gọn, KPI và biểu đồ lên cao hơn. |
| Tablet 768 | `after/02-tablet-dashboard-768.png` | Không overflow; bộ chọn vẫn giữ đủ thông tin. |
| Mobile 390 | `after/03-mobile-dashboard-390.png` | Chỉ còn một hàng tóm tắt và nút `Thay đổi`. |
| Hộp chỉnh sửa desktop | `after/04-desktop-editor.png` | Tách rõ loại kỳ, kỳ đang xem và kiểu đối chiếu. |
| Ngày không phát sinh | `after/05-day-dashboard-1440.png` | Hiển thị `Chưa phát sinh`, không cảnh báo giảm 100%. |
| Tuần | `after/06-week-dashboard-1440.png` | Đối chiếu cùng số ngày của tuần trước. |
| Quý | `after/07-quarter-dashboard-1440.png` | Kỳ hiện tại chỉ tính đến ngày đang xem. |
| Năm | `after/08-year-dashboard-1440.png` | Dữ liệu năm và kỳ trước đồng bộ trên KPI/biểu đồ. |
| Cùng kỳ năm trước | `after/09-same-period-last-year-1440.png` | Nhãn và khoảng ngày đối chiếu khớp nhau. |
| Tùy chọn | `after/10-custom-comparison-editor.png` | Hai đầu mốc hiển thị độc lập và hợp lệ. |
| Hộp chỉnh sửa mobile | `after/11-mobile-editor-390.png` | Bottom sheet không overflow và không bị nút AI che. |
| Loading | `after/12-loading-dashboard-1440.png` | Skeleton giữ đúng cấu trúc cuối, hạn chế giật layout. |

## Lỗi đã xử lý

1. Kỳ tùy chọn không còn khởi tạo `từ ngày = đến ngày`; mặc định dùng đầy đủ
   khoảng đối chiếu đang áp dụng.
2. Ngày tương lai bị chặn; nếu đảo hai đầu mốc, giao diện tự điều chỉnh để luôn
   có `từ ngày <= đến ngày`.
3. Ngày không có bán hàng hiển thị trạng thái trung tính `Chưa phát sinh`.
4. Nút AI được ẩn trong lúc mở bộ chọn kỳ và khôi phục khi đóng, tránh che form.
5. Action Center lỗi dùng thông báo ngắn, trung tính và nút `Thử lại`, không còn
   mảng cảnh báo đỏ chiếm toàn bộ khối.
6. Dashboard có thêm khoảng cuộn cuối trang để FAB không chặn nội dung cuối.

## Trạng thái chưa thuộc phạm vi sửa này

- Local frontend đang gọi backend production chưa có endpoint Action Center mới,
  nên trạng thái `Chưa tải được danh sách công việc` vẫn xuất hiện. UI không dựng
  dữ liệu giả và cho phép thử lại; backend cần được phát hành cùng commit phù hợp
  khi người dùng yêu cầu deploy.
- Nút AI là thành phần có thể kéo nên vẫn có thể nằm trên nội dung trong lúc duyệt;
  vòng này chỉ bảo đảm nó không che hộp chọn kỳ và nội dung cuối trang có thể cuộn
  ra khỏi vùng FAB.

## Kết quả kỹ thuật

- Phân tích tĩnh: không có lỗi hoặc cảnh báo trong phạm vi thay đổi.
- Kiểm thử: 32/32 test kỳ báo cáo, responsive, biểu đồ và Action Center đạt.
- Flutter Web release: build thành công; chưa deploy.
