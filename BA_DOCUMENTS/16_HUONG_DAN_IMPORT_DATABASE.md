# Hướng dẫn import dữ liệu cửa hàng

## 1. Mục đích và phạm vi

Tài liệu này hướng dẫn tạo mới hoặc thay thế dữ liệu nghiệp vụ của SmartStock Tax.
Bộ dữ liệu chuẩn mô phỏng cửa hàng hoạt động liên tục từ `2023-07-29` đến
`2026-07-28`, gồm bán hàng, nhập kho, tồn kho, công nợ, dòng tiền, sổ kế toán,
chốt quỹ và dữ liệu báo cáo.

Hai hồ sơ ngành được hỗ trợ:

| Hồ sơ | Cửa hàng mẫu | Phạm vi |
|---|---:|---|
| `construction` | 34 | Vật liệu xây dựng, điện nước, đồ gia dụng, nội thất và thiết bị phòng tắm |
| `agriculture` | 35 | Phân bón, hạt giống, bảo vệ thực vật, giá thể và vật tư nông nghiệp |

> Dữ liệu thuế trong bộ mẫu chỉ dùng để kiểm thử chức năng. Không coi tỷ lệ hoặc
> số thuế sinh tự động là tư vấn pháp lý hay quy định hiện hành.

## 2. Dữ liệu được giữ và dữ liệu bị thay thế

Khi dùng `--replace-existing`, script giữ nguyên:

- tài khoản đăng nhập và thông tin xác thực;
- hồ sơ cửa hàng;
- thành viên cửa hàng;
- vai trò và phân quyền;
- cấu hình hệ thống không thuộc dữ liệu nghiệp vụ.

Script xóa và tạo lại dữ liệu nghiệp vụ thuộc đúng `shop_id`, bao gồm:

- sản phẩm, danh mục, kho, khách hàng và nhà cung cấp;
- bán hàng, thanh toán, hóa đơn và trả hàng;
- nhập hàng, tồn kho, kiểm kê và luân chuyển kho;
- phải thu, phải trả và lịch sử thanh toán;
- giao dịch tiền, tài khoản tiền, ngân sách và chốt quỹ;
- sổ tài chính, bút toán, nghĩa vụ thuế;
- tài liệu kiến thức AI và nhật ký của bộ dữ liệu cũ.

Không xóa dữ liệu của cửa hàng khác.

## 3. Điều kiện trước khi import

1. Sao lưu database production tại nhà cung cấp PostgreSQL.
2. Xác nhận đúng `shop_id`, hồ sơ ngành và chủ sở hữu đang hoạt động.
3. Backend đã cài dependency và build thành công.
4. Database đã chạy:
   - `20260728_create_ai_knowledge_documents.sql`;
   - `20260728_fix_daily_closing_multi_shop_unique.sql`.
5. Biến môi trường kết nối database được cấu hình ở môi trường chạy. Không ghi
   mật khẩu database vào lệnh, tài liệu hoặc Git.

## 4. Quy trình an toàn

Chạy các lệnh sau tại thư mục `backend/`.

### 4.1. Chỉ xem kế hoạch

```powershell
node dist/scripts/seed-three-year-store.js --shop-id=34 --profile=construction
node dist/scripts/seed-three-year-store.js --shop-id=35 --profile=agriculture
```

### 4.2. Chạy thử và hoàn tác

Lệnh này thực hiện đủ thao tác xóa/ghi/đối soát trong transaction rồi rollback.
Database không thay đổi nếu lệnh thành công hoặc thất bại.

```powershell
node dist/scripts/seed-three-year-store.js --shop-id=34 --profile=construction --validate-write --replace-existing --confirm=REPLACE-34
node dist/scripts/seed-three-year-store.js --shop-id=35 --profile=agriculture --validate-write --replace-existing --confirm=REPLACE-35
```

Chỉ chuyển sang bước ghi thật khi màn hình có `Đối soát nội bộ: PASS`.

### 4.3. Ghi dữ liệu thật

```powershell
node dist/scripts/seed-three-year-store.js --shop-id=34 --profile=construction --apply --replace-existing --confirm=REPLACE-34
node dist/scripts/seed-three-year-store.js --shop-id=35 --profile=agriculture --apply --replace-existing --confirm=REPLACE-35
```

Mỗi cửa hàng được xử lý trong một transaction độc lập. Nếu một bước lỗi, toàn bộ
thay đổi của cửa hàng đó được rollback.

### 4.4. Đối soát sau import

```powershell
node dist/scripts/validate-store-data.js --shop-id=34
node dist/scripts/validate-store-data.js --shop-id=35
node dist/scripts/audit-store-data.js --shop-id=34
node dist/scripts/audit-store-data.js --shop-id=35
```

Kiểm tra thêm trên giao diện:

- Dashboard có doanh thu và biểu đồ đủ kỳ.
- Sản phẩm đúng ngành và tồn kho không âm.
- Danh sách bán hàng có dữ liệu liên tục.
- Công nợ khách hàng khớp tổng các khoản phải thu còn lại.
- Công nợ nhà cung cấp khớp tổng các khoản phải trả còn lại.
- Số dư tài khoản khớp tổng thu trừ tổng chi.
- Chốt quỹ có đủ từng ngày và không trùng trong cùng cửa hàng.

## 5. Cách thêm dữ liệu sau này

### Thêm qua giao diện hoặc API

Đây là cách ưu tiên cho dữ liệu phát sinh hằng ngày vì hệ thống tự tạo các bản ghi
liên quan và kiểm tra quyền:

1. Tạo danh mục, sản phẩm, khách hàng và nhà cung cấp.
2. Tạo đơn nhập và hoàn thành nhập kho.
3. Tạo đơn bán và ghi nhận thanh toán/công nợ.
4. Ghi nhận thu nợ, trả nợ, trả hàng và chi phí.
5. Chốt quỹ và đối soát báo cáo.

### Import hàng loạt

Thứ tự import bắt buộc:

1. `categories`
2. `products`, `customers`, `suppliers`, `warehouses`
3. `purchase_orders` và `purchase_order_items`
4. `inventory_movements`, sau đó tính lại `inventory_stocks`
5. `sales_orders`, `sales_order_items`, `sales_order_payments`
6. `receivables`, `payables` và lịch sử thanh toán
7. `cash_transactions`, `invoices`
8. `journal_entries`, `journal_lines`
9. `daily_closings`, báo cáo và dữ liệu tổng hợp

Không import trực tiếp số dư khách hàng, nhà cung cấp, tài khoản tiền hoặc tồn kho
nếu chưa import các chứng từ nguồn. Đây là dữ liệu dẫn xuất và phải được tính lại
từ giao dịch.

## 6. Trường dữ liệu tối thiểu

### Sản phẩm

| Trường | Bắt buộc | Quy tắc |
|---|---|---|
| `sku` | Có | Duy nhất toàn hệ thống, không tái sử dụng |
| `shop_id` | Có | Phải tồn tại và người import có quyền |
| `name` | Có | Tên hàng dễ nhận biết |
| `category_id` | Có | Thuộc cùng cửa hàng |
| `unit` | Có | Bao, Cái, Bộ, Kg, Mét, m³... |
| `cost_price` | Có | Không âm |
| `selling_price` | Có | Không âm, nên lớn hơn giá vốn |
| `min_stock` | Có | Không âm |

### Khách hàng và nhà cung cấp

`code`, `shop_id`, `name` là bắt buộc. Số điện thoại, địa chỉ và hạn mức công nợ
là tùy chọn. Không dùng thông tin cá nhân thật trong môi trường demo.

### Chứng từ

Mỗi chứng từ phải có mã duy nhất, `shop_id`, ngày, trạng thái, tổng tiền và người
tạo. Tổng chứng từ phải bằng tổng các dòng sau giảm giá và thuế. Thanh toán không
được vượt tổng tiền sau khi đã trừ khoản hoàn.

## 7. Cơ chế chống chạy nhầm và chạy lặp

- Script không tự chọn cửa hàng.
- Ghi thật cần cờ `--apply`.
- Thay dữ liệu cần thêm chuỗi xác nhận chính xác `REPLACE-<shop_id>`.
- Mỗi hồ sơ ghi một marker phiên bản trong `activity_logs`.
- Nếu marker đã tồn tại, script từ chối chạy lại trừ khi dùng chế độ thay thế.
- Mã dữ liệu có chứa khóa cửa hàng để tránh trùng giữa nhiều cửa hàng.

## 8. Hoàn tác và khôi phục

Nếu import đang chạy bị lỗi, transaction sẽ tự rollback. Nếu import đã commit nhưng
kết quả nghiệp vụ không đạt:

1. Dừng phát sinh giao dịch mới tại cửa hàng liên quan.
2. Lưu log import và kết quả đối soát.
3. Khôi phục từ bản sao lưu gần nhất; hoặc chạy lại chế độ thay thế nếu bộ dữ liệu
   nguồn đã được sửa và được duyệt.
4. Chạy lại toàn bộ bước đối soát.

Không sửa tay một vài số dư để “khớp số”, vì sẽ làm sai quan hệ giữa chứng từ,
tồn kho, công nợ và báo cáo.

## 9. Nhật ký mỗi lần import

Ghi lại tối thiểu:

- thời điểm và người thực hiện;
- commit backend;
- môi trường và `shop_id`;
- hồ sơ ngành, phiên bản bộ dữ liệu;
- số sản phẩm, đơn bán, đơn nhập và ngày chốt quỹ;
- kết quả build, chạy thử rollback và đối soát sau import;
- link bản sao lưu và phương án khôi phục.
