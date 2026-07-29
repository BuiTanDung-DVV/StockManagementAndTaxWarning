# Kiểm tra dữ liệu giả và kế hoạch dữ liệu vận hành 3 năm

> **Trạng thái tài liệu:** các phát hiện “trước khi thay dữ liệu” bên dưới được giữ
> làm lịch sử. Kết quả production mới nhất và ma trận màn hình → API → database
> được xác nhận tại `17_BAO_CAO_NGUON_DU_LIEU_PRODUCTION.md`.

## 1. Phạm vi kiểm tra

Phiên bản được kiểm tra: mã nguồn `main` tại ngày 28/07/2026.

Nguồn đối chiếu:

1. Provider và màn hình Flutter trong `lib/`.
2. Route, controller, service và entity trong `backend/src/`.
3. Các script seed trong `backend/src/scripts/`.
4. Dấu hiệu dữ liệu đang hiển thị trên production.

Phân loại:

- **DB**: dữ liệu nghiệp vụ được tải từ API/database.
- **CACHE**: bản sao cục bộ để tăng tốc hoặc hỗ trợ mất mạng.
- **CẤU HÌNH**: nhãn, màu, câu hướng dẫn hoặc danh mục tĩnh hợp lệ.
- **MÔ PHỎNG**: dữ liệu thử nghiệm được lưu trong database.
- **STUB**: API trả kết quả rỗng cố định, chưa có xử lý nghiệp vụ.

## 2. Kết quả

| Khu vực | Trạng thái | Bằng chứng | Đánh giá |
|---|---|---|---|
| Dashboard | DB | `salesSummaryProvider`, `cashSummaryProvider`, `topProductsProvider` gọi API | Không phát hiện số liệu biểu đồ giả |
| Sản phẩm | DB + MÔ PHỎNG | API tải sản phẩm; UI nhận diện tên `Temp Product` và tag `sim_tag_` | Dữ liệu thử nghiệm đã từng được ghi vào DB |
| Bán hàng | DB + MÔ PHỎNG | API tải đơn; UI nhận diện `Simulated Customer` | Dữ liệu thử nghiệm đã từng được ghi vào DB |
| Kho | DB | Tồn, nhập–xuất–tồn, cảnh báo và kiểm kê gọi API | Không phát hiện danh sách nghiệp vụ hard-code |
| Tài chính | DB | Giao dịch, công nợ, P&L, hóa đơn và thuế gọi API | Dữ liệu phụ thuộc độ đầy đủ của ledger trong DB |
| Cấu hình thuế | DB + CACHE | Tải `/tax/config`, sau đó lưu `SharedPreferences` | Cache hợp lệ; không được coi cache là nguồn chuẩn |
| Kiến thức AI | CỤC BỘ | `ai_knowledge_provider.dart` chứa 3 tài liệu mặc định và lưu `SharedPreferences` | Chưa đáp ứng yêu cầu mọi dữ liệu quản trị lấy từ DB |
| Tìm kiếm toàn cục | GIAO DIỆN MÔ PHỎNG | `global_search_delegate.dart` chỉ hiển thị chuỗi “Kết quả tìm kiếm...” | Chưa truy vấn sản phẩm, đơn hàng, khách hàng |
| Cấu hình giá vốn | SAI PHẠM VI CỬA HÀNG | Provider ghi vào `/system/shop-profile/1` | Có nguy cơ cập nhật nhầm cửa hàng |
| Quét hóa đơn | STUB | `system.controller.ts` trả `[]` hoặc `{}` cố định | Route này chưa đọc/ghi DB |
| Tạo công nợ thủ công | STUB | `customer.controller.ts` trả `{}` cố định | Chưa tạo bản ghi công nợ |
| Thêm chứng từ công nợ | STUB | `customer.controller.ts` trả `{}` cố định | Chưa lưu chứng từ vào DB |

Các danh sách tỉnh/thành, loại ngành nghề, màu tag, nhãn trạng thái, câu hỏi gợi ý và nội dung empty state là **cấu hình giao diện**, không phải dữ liệu giao dịch giả.

### Đối chiếu database production trước khi thay dữ liệu ngày 28/07/2026

| Shop ID | Cửa hàng | Đơn hàng | Sản phẩm | Khách hàng | Dấu hiệu đơn sinh tự động | Sản phẩm thử nghiệm | Khách thử nghiệm |
|---:|---|---:|---:|---:|---:|---:|---:|
| 34 | Cửa Hàng VLXD & Nội Thất Kiến Tạo | 700 | 13 | 22 | 346 | 2 | 2 |
| 35 | Đại Lý Phân Bón & VTNN Kiến Tạo | 300 | 23 | 20 | 0 | 0 | 0 |

Kết luận tại thời điểm trước import: database production **có dữ liệu mô phỏng**,
rõ nhất tại shop `34`. Dữ liệu này đã được thay thế sau khi người dùng xác nhận.

Script kiểm tra chỉ đọc: `backend/src/scripts/audit-store-data.ts`.

Kết quả đối soát chéo:

| Shop ID | Sản phẩm lệch tồn so với nhập–xuất | Ngày không có đơn trong khoảng dữ liệu | Kết luận |
|---:|---:|---:|---|
| 34 | 12 | 43 | Không đạt |
| 35 | 23 | 37 | Không đạt |

Các kiểm tra tổng tiền đơn, phạm vi tiền đã trả, số dư công nợ, cân bằng bút toán và phạm vi shop hiện không phát hiện sai lệch. Tuy nhiên sai tồn kho là lỗi nghiêm trọng nên không thể coi dữ liệu hiện tại là bộ lịch sử vận hành đáng tin cậy.

Script đối soát: `backend/src/scripts/validate-store-data.ts`.

### Thay đổi đã chuẩn bị trong mã nguồn

- Tìm kiếm toàn cục đã truy vấn API thật thay cho màn hình kết quả mô phỏng.
- Cấu hình giá vốn đã dùng `/shop-profile` theo shop hiện tại, không còn cố định ID `1`.
- Kiến thức AI đã chuyển sang API/bảng `ai_knowledge_documents`.
- Migration cần áp dụng trước khi deploy backend:
  `backend/database/20260728_create_ai_knowledge_documents.sql`.
- Bộ sinh dữ liệu an toàn:
  `backend/src/scripts/seed-three-year-store.ts`.

Migration và bộ dữ liệu mới đã được áp dụng production ngày 28/07/2026. Phần triển
khai mã nguồn chỉ hoàn tất khi commit tương ứng được Vercel nhận.

### Kết quả production sau khi thay dữ liệu

| Shop ID | Hồ sơ ngành | Sản phẩm | Đơn bán | Dòng hàng | Đơn nhập | Ngày hoạt động | Kết quả |
|---:|---|---:|---:|---:|---:|---:|---|
| 34 | Vật liệu xây dựng, gia dụng, thiết bị phòng tắm | 250 | 7.595 | 18.933 | 37 | 1.096 | PASS |
| 35 | Phân bón và vật tư nông nghiệp | 250 | 7.783 | 19.238 | 37 | 1.096 | PASS |

Mỗi cửa hàng đạt 12/12 phép đối soát: tổng đơn, thanh toán, phải thu, số dư
khách hàng/nhà cung cấp, tồn kho, bút toán, phạm vi cửa hàng, tài khoản tiền,
chốt quỹ liên tục và lịch sử bán hàng không khuyết ngày. Không còn marker sản
phẩm/khách hàng mô phỏng cũ.

## 3. Rủi ro cần xử lý

### P0

1. Không chạy lại các script `seed-6-months.ts`, `seed-fertilizer*.ts` trên production. Các script này dùng số ngẫu nhiên không kiểm soát và không bảo đảm đối soát tồn kho, công nợ, dòng tiền.
2. Sửa cấu hình giá vốn để luôn dùng cửa hàng đang chọn.
3. Không che tên dữ liệu thử nghiệm tại UI; cần nhận diện và dọn đúng bản ghi trong DB bằng truy vấn có kiểm soát.

### P1

1. Chuyển tài liệu kiến thức AI sang bảng dữ liệu theo `shop_id`.
2. Thay tìm kiếm toàn cục mô phỏng bằng truy vấn API thật.
3. Hoàn thiện các API stub hoặc ẩn chức năng chưa sẵn sàng.

## 4. Bộ dữ liệu mô phỏng 3 năm

Khoảng thời gian chuẩn: **29/07/2023–28/07/2026**, đủ **1.096 ngày**.

Bộ dữ liệu phải có:

- Danh mục, sản phẩm, nhà cung cấp, khách hàng và kho.
- Đơn nhập hàng theo tháng, tồn đầu kỳ, nhập, xuất, trả hàng và kiểm kê.
- Đơn bán mỗi ngày, nhiều phương thức thanh toán, đơn hủy và đơn bán chịu.
- Công nợ phải thu/phải trả, lịch sử thu nợ và trạng thái quá hạn.
- Thu, chi, tài khoản tiền, chốt quỹ mỗi ngày.
- Hóa đơn đầu vào/đầu ra, nghĩa vụ thuế theo quý.
- Ngân sách theo tháng, dự báo dòng tiền và nhật ký hoạt động.
- Bút toán cân bằng cho doanh thu, giá vốn và chi phí vận hành.

Các bất biến đối soát bắt buộc:

1. `sales_orders.total_amount = tổng sales_order_items.subtotal - giảm giá + thuế`.
2. `paid_amount + công nợ ban đầu = total_amount`.
3. Tồn cuối = tồn đầu + nhập + trả hàng - xuất ± điều chỉnh.
4. Số dư công nợ khách hàng = tổng công nợ chưa thu.
5. Tổng Nợ = tổng Có trong từng bút toán.
6. Chốt quỹ ngày khớp giao dịch tiền mặt trong ngày.
7. Dữ liệu chạy lại không tạo bản sao; script phải từ chối khi phát hiện marker đã tồn tại.

### KPI của bộ dữ liệu production

| Chỉ số | Shop 34 | Shop 35 |
|---|---:|---:|
| Số ngày hoạt động | 1.096 | 1.096 |
| Sản phẩm | 250 | 250 |
| Đơn bán | 7.595 | 7.783 |
| Dòng hàng bán | 18.933 | 19.238 |
| Đơn nhập | 37 | 37 |
| Giao dịch tiền | 8.394 | 8.561 |
| Khoản phải thu | 1.323 | 1.307 |
| Doanh thu thuần 3 năm | 19.829.450.000 đ | 26.082.340.000 đ |
| Biên lợi nhuận gộp | 22,51% | 16,92% |
| Biên lợi nhuận ròng | 9,82% | 7,27% |
| Tỷ lệ trả hàng | 0,87% | 0,92% |
| Công nợ còn lại/doanh thu | 4,56% | 4,64% |
| Giá trị tồn cuối kỳ | 1.282.365.000 đ | 1.381.435.000 đ |

Các cổng chất lượng đã đạt: tồn không âm; tài khoản tiền mặt và ngân hàng không âm; doanh thu tăng trên 2% mỗi năm; biên gộp, biên ròng, trả hàng và công nợ nằm trong khoảng mục tiêu; doanh thu/giá vốn khớp ledger.

## 5. Nguyên tắc chạy

- Mặc định chỉ lập kế hoạch, không ghi DB.
- Bắt buộc chỉ định `shop_id`.
- Bắt buộc dùng cờ `--apply` mới được ghi.
- Toàn bộ thao tác nằm trong một transaction; có lỗi thì rollback.
- Chỉ xóa/thay dữ liệu nghiệp vụ khi có `--replace-existing` và chuỗi xác nhận
  chính xác cho `shop_id`; luôn giữ tài khoản, thành viên, vai trò và hồ sơ cửa hàng.
- Nên chạy trên một cửa hàng demo riêng. Không trộn với cửa hàng đang vận hành nếu chưa sao lưu và chấp thuận rõ ràng.
