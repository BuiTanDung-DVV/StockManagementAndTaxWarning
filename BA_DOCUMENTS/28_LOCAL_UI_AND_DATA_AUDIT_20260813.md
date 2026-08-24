# Đánh giá cục bộ giao diện và dữ liệu — 13/08/2026

## Phạm vi

- Source nền: commit `7549bcf5`, kèm thay đổi local chưa deploy.
- Đối chiếu: giao diện Flutter → provider/API → service/entity PostgreSQL → kiểm thử.
- Không chạy migration hoặc ghi dữ liệu production trong đợt này.
- Không kết luận đạt accessibility vì chưa có kiểm thử chuyên biệt.

## Kết quả chính

| Khu vực | Trạng thái | Kết luận |
|---|---|---|
| Dashboard | Đúng một phần | KPI lấy từ API/DB nhưng dữ liệu seed chưa nối dài đến kỳ hiện tại; số kỳ này bằng 0 là dữ liệu rỗng thật, không phải số giả |
| Bán hàng | Đã sửa local | Luồng đổi thành “Ghi nhận giao dịch bán”; giá và thuế được backend tính lại từ DB; biểu đồ 7 ngày luôn có trạng thái rỗng rõ ràng |
| Kho | Đã sửa local, dữ liệu đúng một phần | Sản phẩm, tồn, lô và cảnh báo lấy từ DB; đã đưa danh sách sắp/quá hạn lên khu vực hành động và chống dồn trạng thái trên màn nhỏ |
| Tài chính | Đã sửa local | Số liệu lấy từ API/DB; trạng thái biểu đồ rỗng được thu gọn, KPI mobile chuyển thành lưới 2 cột |
| Trợ lý AI | Đã sửa local | Context lấy theo cửa hàng cụ thể và DB; bỏ ngưỡng/khẳng định nghiệp vụ hard-code ở lời chào; panel desktop giới hạn 560 px |
| Ảnh/QR/chứng từ | Đã sửa local | Bytes gửi qua backend; Cloudinary API key, signature và secret không còn xuất hiện ở frontend |
| Thuế | Bị chặn production | Source đã chuyển sang cấu hình DB và fail-closed, nhưng production chưa chạy migration chính sách thuế đã chuẩn bị |

## Bằng chứng giao diện trước bản vá local cuối

- [Tài chính desktop](assets/local-audit-2026-08-13/05-finance-desktop.png): phát hiện overflow ở empty state; đã bổ sung widget test chống tràn và sửa local.
- [Bán hàng desktop](assets/local-audit-2026-08-13/02-sales-desktop.png): xác nhận số kỳ hiện tại bằng 0 nhưng bảng lịch sử vẫn lấy dữ liệu DB.
- [Ghi nhận giao dịch desktop](assets/local-audit-2026-08-13/08-sales-entry-desktop.png): xác nhận bố cục hai cột và dữ liệu sản phẩm từ API.
- [Kho mobile](assets/local-audit-2026-08-13/12-inventory-mobile.png): xác nhận responsive chính; text cảnh báo chậm luân chuyển còn dày.

## Bằng chứng production và bản sửa local mới nhất

- [Dashboard production](assets/production-audit-2026-08-13/01-dashboard-desktop.png): kỳ hiện tại không có doanh thu nhưng cột kỳ trước vẫn hiển thị, dễ bị hiểu nhầm nếu không có giải thích.
- [Kho production](assets/production-audit-2026-08-13/03-inventory-desktop.png): KPI có 8 sản phẩm sắp/quá hạn nhưng khu vực hành động chưa hiển thị danh sách tương ứng.
- [Tài chính production](assets/production-audit-2026-08-13/04-finance-desktop.png): empty state chiếm nhiều chiều cao và làm giảm mật độ thông tin.
- [Dashboard local sau sửa](assets/production-audit-2026-08-13/11-local-dashboard-fixed-desktop.png): có cảnh báo rõ khi biểu đồ chỉ còn dữ liệu kỳ trước.
- [Kho local sau sửa](assets/production-audit-2026-08-13/12-local-inventory-fixed-desktop.png): bổ sung danh sách sắp/quá hạn cùng số ngày và số lượng tồn.
- [Tài chính local sau sửa](assets/production-audit-2026-08-13/13-local-finance-fixed-desktop.png): empty state đã gọn hơn.
- [Tài chính local mobile](assets/production-audit-2026-08-13/15-local-finance-fixed-mobile.png): bốn KPI đã xếp thành hai cột; cần tiếp tục kiểm tra title/badge ở chiều rộng rất hẹp.
- [Top sản phẩm production — 6 tháng desktop](assets/production-audit-2026-08-13/16-dashboard-top-products-six-months-production.png): dữ liệu DB hiển thị đủ doanh thu, số lượng, biên lãi và tăng trưởng; bố cục desktop rõ ràng.
- [Top sản phẩm production — 6 tháng mobile](assets/production-audit-2026-08-13/17-dashboard-top-products-six-months-mobile.png): bảng cột làm tên sản phẩm bị cắt mạnh và nhãn tháng trên trục X dính liền nhau; đã sửa local sang hàng mobile và tăng khoảng trục.

Nút trợ lý AI đã thu nhỏ từ `72×80` xuống `64×72`, vẫn giữ vị trí mặc định giữa bên trái và có thể kéo/ẩn theo yêu cầu, đồng thời giảm mức che nội dung. Các màn có nút hành động nổi desktop được chừa thêm vùng cuối trang để nút không che dòng dữ liệu cuối.

## Độ chính xác dữ liệu và công thức

- Đơn bán: backend lấy giá từ cấu hình sản phẩm trong DB, kiểm tra giá gửi lên, phân bổ chiết khấu rồi tính thuế/tổng tiền phía server.
- Tiền mặt: giao dịch quỹ dùng tổng tiền backend đã xác nhận.
- Hóa đơn: backend tính subtotal, VAT, tổng tiền từ dòng hàng và ghi header/items trong transaction.
- Dashboard/báo cáo: kỳ báo cáo dùng ngày hiện tại; seed cũ không có giao dịch tháng 08/2026 nên số 0 là hợp lệ với DB hiện tại nhưng chưa đạt yêu cầu dữ liệu mô phỏng liên tục.
- Thuế: production còn thiếu `tax_rules` và ngưỡng cũ; chưa thể xác nhận chính xác cho đến khi migration được duyệt và chạy.

## Bổ sung đối soát Tài chính — 13/08/2026

| Hạng mục | Trạng thái | Kết quả xác minh |
|---|---|---|
| Tổng thu, tổng chi, dòng tiền thuần | Đã xác minh code | Cùng lấy từ `cash_transactions` trong đúng kỳ; dòng tiền thuần = tổng thu − tổng chi. Đây là dòng tiền, không phải lợi nhuận. |
| Quỹ tiền mặt | Đã xác minh code | Cộng lũy kế giao dịch có phương thức `CASH` đến cuối kỳ; chuyển khoản/QR/thẻ không được đưa vào quỹ tiền mặt. |
| Báo cáo KQKD | Đã xác minh code | Doanh thu từ 511, giá vốn từ 632, chi phí vận hành từ 642; lợi nhuận gộp = doanh thu − giá vốn; lợi nhuận ròng = lợi nhuận gộp − chi phí vận hành. |
| Phân loại tiền vào độc lập | Đã sửa local | Vốn góp ghi 411, tiền vay ghi 341, bán hàng ghi 511, thu nhập khác ghi 711. Trước sửa, mọi giao dịch thu độc lập đều ghi 511 nên có thể làm tăng sai doanh thu/lợi nhuận. |
| Danh sách giao dịch | Đã sửa local | Hiển thị `notes` thực tế từ DB, Việt hóa phương thức, ưu tiên ngày nghiệp vụ `transactionDate`, và ẩn Sửa/Xóa với giao dịch sinh từ chứng từ gốc. |
| Nhóm tiền chi | Đã sửa nhãn local | Đổi từ “Nhóm chi phí lớn” thành “Nhóm tiền chi lớn” vì nguồn là dòng tiền ra; tránh hiểu nhầm với chi phí kế toán 642. |

Sửa phân loại tài khoản chỉ áp dụng cho giao dịch tạo/cập nhật sau khi code mới được triển khai. Chưa chạy backfill journal production. Dữ liệu demo hiện có vốn khởi tạo mang `reference_type = DATASET`; cần migration riêng nếu muốn báo cáo KQKD lịch sử loại đúng phần vốn từng được ghi 511.

## Bổ sung đối soát Hóa đơn — 13/08/2026

| Hạng mục | Trạng thái | Kết quả xác minh |
|---|---|---|
| Tổng dòng và tổng hóa đơn | Đã xác minh code, có test | Backend tính `subtotal = quantity × unitPrice`, VAT từng dòng, rồi cộng lại header; không tin `subtotal`, `taxAmount` hoặc `totalAmount` do client gửi. |
| Hóa đơn liên kết chứng từ | Đã sửa local, có test | Hóa đơn có `referenceType/referenceId` không còn được sửa/xóa từ sổ hóa đơn; backend buộc xử lý từ đơn bán/đơn nhập gốc, UI hiển thị khóa. Client cũng không được tự gắn tham chiếu nguồn khi tạo hóa đơn thủ công. |
| Xóa hóa đơn thủ công | Đã sửa local, có test | Backend xóa `invoice_items` rồi xóa header trong cùng transaction; tránh lỗi khóa ngoại hoặc để chứng từ ở trạng thái dở dang. |
| Quyền sửa hóa đơn | Đã sửa local | Người chỉ có quyền xem tài chính không còn thấy nút thêm/sửa/xóa; backend tiếp tục yêu cầu quyền `finance.edit`. |
| Đối chiếu VAT | Đã sửa nhãn local | Hiển thị mốc ngày thực tế và gọi là “chênh lệch đầu vào/đầu ra”; bổ sung cảnh báo đây là đối chiếu hóa đơn, không thay thế nghĩa vụ trên tờ khai. |
| Chi tiết hóa đơn lịch sử | Không chính xác | Mỗi cửa hàng còn 30 hóa đơn đầu vào không có `invoice_items`; cần backfill từ đơn nhập gốc trước khi có thể drill-down và đối soát độc lập. |
| Chiết khấu hóa đơn bán lịch sử | Đúng một phần | Header đã dùng giá trị sau giảm nhưng schema chưa có trường chiết khấu; 268 dòng shop 34 và 290 dòng shop 35 chỉ giải thích được khi join đơn bán. |
| Số lượng thập phân trên dòng hóa đơn | Bị chặn schema | `invoice_items.quantity` hiện là số nguyên. Nếu nghiệp vụ cần bán theo kg/mét/m² lẻ thì phải migration sang decimal; chưa tự đổi schema khi chưa được duyệt. |

## Bổ sung đối soát Dashboard/Bán hàng/KQKD — 13/08/2026

| Hạng mục | Trạng thái | Kết quả xác minh |
|---|---|---|
| Doanh thu bán hàng trên KPI và biểu đồ | Đã sửa local, có test | KPI/biểu đồ dùng doanh thu hàng hóa sau chiết khấu và hàng trả, không gồm VAT đầu ra. API bổ sung `netSalesRevenue`; frontend ưu tiên trường này và chỉ fallback `totalRevenue` để tương thích backend cũ. |
| Lợi nhuận gộp | Đã sửa local, có test | `grossProfit = netSalesRevenue − totalCogs`; không còn lấy tổng tiền khách phải trả có VAT để trừ giá vốn. Nhãn Dashboard và Bán hàng đều ghi rõ “Lợi nhuận gộp”. |
| KQKD | Đã xác minh code và dữ liệu chỉ đọc | KQKD vẫn lấy 511−632−642. Validator xác nhận doanh thu đơn sau hàng trả khớp 511 và giá vốn khớp 632 ở cả shop 34/35. Giao dịch doanh thu độc lập ghi trực tiếp 511, nếu có, vẫn thuộc KQKD nhưng không thuộc thống kê đơn bán. |
| Tương thích cảnh báo thuế | Giữ nguyên phạm vi hiện tại | `totalRevenue` vẫn giữ nghĩa tổng tiền bán sau trả như API cũ để không âm thầm đổi ngưỡng/công thức thuế. Việc xác định doanh thu tính thuế đúng pháp luật cần được kiểm chứng riêng theo chính sách có hiệu lực; vòng này không đổi logic thuế. |

## Bổ sung truy vết dữ liệu hard-code và khóa bí mật — 13/08/2026

| Hạng mục | Trạng thái | Kết quả xác minh |
|---|---|---|
| KPI, bảng và biểu đồ nghiệp vụ chính | Đã xác minh tĩnh | Dashboard, bán hàng, kho, công nợ và tài chính lấy dữ liệu qua provider/API; không phát hiện danh sách giao dịch hoặc KPI giả được dựng trong Flutter. Các mảng màu, nhãn trạng thái, cột bảng và nội dung hướng dẫn là metadata giao diện, không phải dữ liệu nghiệp vụ. |
| Tri thức AI | Đã sửa local, có test | Provider tải `/ai/knowledge` theo cửa hàng và giữ trạng thái DB gần nhất khi lỗi. Backend không còn chèn tên văn bản pháp luật mặc định khi DB rỗng; prompt phải báo thiếu căn cứ. Context doanh thu 30 ngày dùng doanh thu hàng hóa sau giảm giá/hàng trả, không gồm VAT. |
| Ảnh và khóa dịch vụ | Đã xác minh code, có test | Frontend chỉ gửi bytes đến backend; Cloudinary/Gemini và DB credentials chỉ đọc từ biến môi trường backend. Không phát hiện Cloudinary secret/API key trong Flutter. Google OAuth client ID là định danh công khai theo build, không phải client secret. |
| Danh mục ngân hàng VietQR | Đã sửa local, chờ migration | Xóa danh sách ngân hàng hard-code khỏi Flutter; `/payment-banks` đọc `VIETQR_BANKS` từ PostgreSQL và fail rõ khi thiếu/sai. Màn hình không cho lưu cho đến khi danh mục tải thành công. |
| Cập nhật hồ sơ cửa hàng | Đã sửa local, có test | Thay gán toàn bộ body bằng allowlist trường; mã ngân hàng được đối chiếu DB, tên ngân hàng do backend xác định; không cho client ghi `id`, `shopId` hoặc URL QR do luồng upload quản lý. |
| Kết luận nhanh của AI | Đã sửa local, có test | Bỏ khẳng định rộng “cửa hàng vận hành ổn định” khi thực tế chỉ kiểm tra tồn dưới định mức, nghĩa vụ thuế đang mở và công nợ; trạng thái mới ghi rõ phạm vi và không thay thế kiểm tra toàn bộ. |
| Nhãn tồn trên danh sách sản phẩm | Đã sửa local, có test | Bỏ ngưỡng cố định 10 ở Flutter; màu cảnh báo và tag “Sắp hết” dùng `minStock` của từng sản phẩm từ DB, khớp màn Kho/backend. |
| Tạo/sửa sản phẩm | Đã sửa local, có test | Backend chỉ nhận trường nghiệp vụ được phép, validate giá/thuế/tồn/đơn vị/nhãn, chặn ghi đè `shopId`, `id`, trạng thái và URL ảnh ngoài Cloudinary của shop. |
| Tồn kho trong form sản phẩm | Đã sửa local, có test | Tồn ban đầu chỉ được gửi lúc tạo; form sửa chuyển tồn hiện tại thành chỉ đọc. Điều chỉnh sau tạo phải đi qua nhập hàng/kiểm kê để giữ đúng lịch sử phát sinh và không ghi nhầm một kho mặc định. |
| Hồ sơ khách hàng/nhà cung cấp | Đã sửa local, có test | Backend chặn ghi đè mã, shop, trạng thái, số dư; chỉ nhận và validate trường hồ sơ nghiệp vụ. Công nợ/số dư tiếp tục do giao dịch phía server quyết định. |
| Kiểm kê kho | Đã sửa local, có test | Tạo phiếu nháp chỉ gửi số đếm thực tế; tồn hệ thống lấy lại từ DB. Lịch sử có Hoàn tất/Hủy/Xóa nháp; lúc hoàn tất server đối chiếu tồn mới nhất, ghi phát sinh và khóa phiếu đã kết thúc. |
| Đơn nhập hàng | Đã sửa local, có test | Backend tự tính tổng từ dòng hợp lệ, xác minh nhà cung cấp/sản phẩm/kho thuộc shop, chặn tổng/trạng thái/phạm vi do client chèn và không cho xóa đơn đã tác động tồn/bút toán. |
| Tồn theo kho trong kiểm kê | Đã sửa local, có test | `warehouseId` nay được controller chuyển xuống query DB và được kiểm tra thuộc shop; provider tải đủ tối đa 500 dòng thay vì 20 dòng đầu nên cột tồn hệ thống không còn lấy sai kho hoặc thiếu trang. |
| Lịch sử kiểm kê | Đã sửa local, có test | Hiển thị đúng `stockTakeCode`, `stockTakeDate`, `notes` từ DB; bổ sung số SKU và số dòng chênh lệch để người dùng nhận biết phiếu cần chú ý. |
| Dữ liệu chủ kho/sản phẩm | Đã sửa local, có test | Kho, danh mục, loại chi phí, lô và quy đổi đơn vị đều dùng hợp đồng backend rõ ràng, không còn nhận trực tiếp trường hệ thống từ body. |
| Lịch sử phát sinh theo sản phẩm | Đã sửa local, có test | Màn chi tiết sản phẩm đã gửi `productId` nhưng backend cũ bỏ qua nên có thể lẫn phát sinh của sản phẩm khác. Backend nay kiểm tra sản phẩm thuộc cửa hàng đang chọn và lọc `inventory_movements` theo đúng `shopId + productId`. |
| Ngày nghiệp vụ đơn nhập | Đã sửa local | Danh sách và chi tiết đơn nhập hiển thị `orderDate` lấy từ DB, không còn dùng `createdAt` và gọi nhầm là ngày nhập. |
| Danh sách kiểm kê đa kho | Đã sửa local | Mỗi dòng tồn hiển thị tên kho và đơn vị tính từ quan hệ DB; tránh nhầm hai dòng cùng sản phẩm ở các kho khác nhau hoặc đọc số lượng không rõ đơn vị. |
| Phản hồi khi validation/API thất bại | Đã sửa local | Các lỗi nhập sản phẩm, đơn nhập và lỗi duyệt bảng kê dùng thông báo lỗi; không còn hiển thị màu/thông điệp thành công khi DB chưa được cập nhật. |
| Ranh giới khóa frontend/backend | Đã xác minh tĩnh, có test | Flutter không chứa `DATABASE_URL`, Cloudinary secret, khóa Gemini/JWT/OTP hoặc chuỗi kết nối PostgreSQL. Google OAuth Client ID vẫn là định danh công khai bắt buộc ở client; backend xác minh token bằng danh sách Client ID cho phép. |
| Giá trị hàng trả trong báo cáo bán hàng | Đã sửa local, có test | Backend tính giá trị trả từ dòng hàng thực trả, phân bổ chiết khấu và thuế theo lượng; không còn lấy toàn bộ header đơn cho mỗi phiếu trả. |
| Khoảng ngày báo cáo XNT | Đã sửa local, có test | Báo cáo nhập–xuất–tồn dùng ranh giới ngày nghiệp vụ Việt Nam thống nhất với các báo cáo còn lại. |
| Lọc mua hàng chưa có hóa đơn | Đã sửa local, có test | Trạng thái được gửi tới backend và lọc trong DB trước phân trang; số dòng và tổng tiền phản ánh toàn bộ tập lọc, không chỉ trang đang xem. |
| Tài chính ở chế độ tất cả cửa hàng | Đã sửa local, có test | KPI, biểu đồ, nhóm chi và lịch sử giao dịch cùng dùng danh sách cửa hàng được phép; từng dòng vẫn có `shopId` để truy vết. |
| Tỷ lệ và bảng hàng trả | Đã sửa local, có test và truy vấn DB chỉ đọc | Tỷ lệ dùng giá trị hàng trả thuần sau phân bổ chiết khấu chia doanh thu hàng hóa trước trả. Bảng top 5 đọc sản phẩm, đơn vị, lượt trả, lượng trả, giá trị và lý do từ DB; nằm trước bộ lọc danh sách đơn để tách rõ phạm vi. |
| Responsive đăng nhập production | Đã xác minh lại bằng ảnh | Ảnh desktop và mobile ổn định không tràn ngang, console không có cảnh báo/lỗi. Ảnh chụp quá sớm trước khi Flutter reflow đã bị loại, không dùng làm kết luận. |

## Kiểm tra giao diện local sau build

- Web release build ngày 13/08/2026 thành công và được mở trực tiếp trong trình duyệt Codex.
- Màn đăng nhập desktop: bố cục hai cột rõ, độ tương phản tốt, không phát hiện overflow hoặc lỗi console.
- Màn đăng nhập mobile 390×844: chuyển đúng sang một cột, nút và trường nhập đủ chiều rộng, không bị cắt chữ hoặc tràn ngang.
- Các màn sau đăng nhập chưa được xác minh trực quan trong lượt này vì trình duyệt local chưa có phiên đăng nhập và không tự đọc mật khẩu từ file. Việc kiểm tra code/widget vẫn tiếp tục độc lập; smoke test trực quan cần người dùng đăng nhập hoặc cung cấp một phiên test đã mở.
| Ngưỡng giải trình chốt ca | Đã sửa local, chờ migration | Bỏ số 50.000đ viết trực tiếp trong UI/service; backend đọc `DAILY_CLOSING_EXPLANATION_THRESHOLD` từ DB, trả cho màn chốt ca và tiếp tục kiểm tra bắt buộc phía server. |

Hai migration [`20260813_seed_vietqr_banks.sql`](../backend/database/20260813_seed_vietqr_banks.sql) và [`20260813_seed_daily_closing_threshold.sql`](../backend/database/20260813_seed_daily_closing_threshold.sql) mới chỉ được chuẩn bị. Chưa chạy trên production; backend mới sẽ fail rõ ở các chức năng tương ứng cho đến khi người dùng phê duyệt migration.

## Đối soát trực tiếp PostgreSQL chỉ đọc

- Cửa hàng 34: 250 sản phẩm, 7.595 đơn, dữ liệu từ 29/07/2023 đến 28/07/2026 theo múi giờ Việt Nam.
- Cửa hàng 35: 250 sản phẩm, 7.783 đơn, đủ 1.096 ngày hoạt động liên tục trong cùng giai đoạn.
- Hai cửa hàng đều không có tên `Temp Product`, `Simulated Customer`, ghi chú `mock` hoặc activity log đánh dấu mock theo bộ quy tắc audit.
- Cả hai cửa hàng vượt qua các đối soát tổng đơn/dòng hàng, paid amount/payment, công nợ, tồn kho, cân bút toán, doanh thu thuần, giá vốn và số dư quỹ.
- Còn ba sai lệch dữ liệu lịch sử: cửa hàng 34 có 870 đơn và cửa hàng 35 có 834 đơn thiếu/lệch bút toán thu công nợ vào TK 112; mỗi cửa hàng có 30 hóa đơn mua thiếu dòng; hóa đơn bán có chiết khấu chưa tự giải thích được gồm 268 dòng kiểm tra ở cửa hàng 34 và 290 ở cửa hàng 35.
- Dữ liệu kết thúc ngày 28/07/2026 nên màn tháng 08/2026 hiển thị 0 là đúng với DB, nhưng không đạt mục tiêu demo “đến hiện tại”.
- Việc sửa 3 nhóm sai lệch trên cần migration/backfill có snapshot và transaction; chưa được chạy trong đợt kiểm tra chỉ đọc này.
- Top sản phẩm shop 34: kỳ 01–13/08 có 0 dòng; kỳ 01–13/07 trả đủ 10 dòng với tổng doanh thu top 10 khoảng 83,05 triệu đồng; kỳ 01/03–13/08 trả 10 dòng với khoảng 450,13 triệu đồng. Dashboard local dùng chính API này để hiện kỳ trước khi kỳ hiện tại rỗng, có nhãn rõ để không giả dữ liệu.
- Công thức biên lãi trước đây chặn lợi nhuận âm về 0. Bản sửa giữ nguyên giá trị âm và tính phần trăm âm; điều này không làm thay đổi dữ liệu DB, chỉ sửa logic báo cáo.
- Trạng thái đơn `CONFIRMED` trước đây bị UI gắn nhãn “Đã hủy” do nhánh mặc định. Bản sửa tách đầy đủ `PENDING`, `CONFIRMED`, `DELIVERED/COMPLETED`, `CANCELLED` và trạng thái không xác định. DB hiện tại chỉ có `PENDING`, `DELIVERED`, `CANCELLED`, nhưng mapping mới ngăn hiển thị sai khi quy trình xác nhận được sử dụng.

## Việc cần duyệt trước khi tiếp tục

1. Chạy migration thuế production: có thay đổi DB, cần phê duyệt riêng.
2. Nối dài dữ liệu seed đến ngày hiện tại: có ghi dữ liệu production, cần phê duyệt riêng.
3. Deploy frontend/backend để chụp lại toàn bộ màn hình production và kiểm tra luồng upload ảnh thực tế.
4. Duyệt migration backfill riêng cho bút toán thu công nợ và dòng hóa đơn lịch sử; không sửa trực tiếp dữ liệu khi chưa có snapshot/rollback.

## Cổng kiểm thử sau vòng cải thiện bảng/biểu đồ

- `flutter analyze`: đạt toàn dự án.
- `flutter test`: đạt toàn bộ bộ kiểm thử (bổ sung kiểm tra cảnh báo tồn theo `minStock` DB và ngưỡng giải trình chốt ca do backend trả); `flutter analyze` đạt.
- Backend `test:p0`: 160/160 đạt; build và lint đạt.
- Flutter `test`: 100/100 đạt; `flutter analyze` không còn cảnh báo.
- Web release build: thành công với API production; chưa deploy.
