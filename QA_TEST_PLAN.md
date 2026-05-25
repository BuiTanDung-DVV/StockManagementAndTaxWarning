# 📋 KẾ HOẠCH KIỂM THỬ SIÊU CHI TIẾT (ULTRA-COMPREHENSIVE QA TEST PLAN)
## Hệ Thống Quản Lý Kho, Bán Hàng & Cảnh Báo Thuế (SmartStock & Tax Warning 2.0)
**Mục tiêu:** Kiểm thử 100% tất cả các màn hình (46 màn hình), nút bấm, biểu mẫu dữ liệu, các ràng buộc validate đầu vào và tích hợp API backend để đảm bảo hệ thống đạt độ tin cậy tuyệt đối, không phát sinh bất kỳ lỗi nhỏ nào trong môi trường production.

---

## 🗺️ PHẦN I: DANH SÁCH 46 MÀN HÌNH & KỊCH BẢN KIỂM THỬ CHI TIẾT

---

### 1. 🔑 NHÓM MÀN HÌNH XÁC THỰC & KHỞI TẠO (AUTH & ONBOARDING)

#### 1.1 Màn hình Đăng Nhập (`/login` -> `LoginScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Đăng nhập`: Thực hiện gửi API đăng nhập.
    *   `Nút Đăng ký ngay`: Điều hướng sang `/register`.
    *   `Nút Quên mật khẩu?`: Điều hướng sang `/forgot-password`.
    *   `Icon Hiển thị/Ẩn mật khẩu`: Chuyển đổi trạng thái obscure text của mật khẩu.
*   **Trường dữ liệu & Ràng buộc Validate:**
    *   `Tên đăng nhập / SĐT`: Không được để trống. Phải tối thiểu 3 ký tự.
    *   `Mật khẩu`: Không được để trống. Phải tối thiểu 6 ký tự.
*   **API tích hợp:** `POST /api/auth/login`
*   **Ca kiểm thử:**
    *   *TC_LOGIN_001:* Nhập tài khoản/mật khẩu đúng -> Đăng nhập thành công, lưu Token, chuyển sang `/`.
    *   *TC_LOGIN_002:* Nhập sai mật khẩu -> Hiển thị thông báo đỏ "Sai tên đăng nhập hoặc mật khẩu gốc".
    *   *TC_LOGIN_003:* Tài khoản bị khóa (`isActive: false`) -> Hiển thị "Tài khoản của bạn đã bị khóa".

#### 1.2 Màn hình Đăng Ký (`/register` -> `RegisterScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Đăng ký`: Gửi API đăng ký tài khoản mới.
    *   `Nút Đăng nhập ngay`: Chuyển hướng về `/login`.
    *   `Nút Chọn loại tài khoản (Hộ kinh doanh / Cá nhân)`: Chuyển đổi trạng thái `accountType` giữa `'SHOP'` và `'PERSONAL'`.
*   **Trường dữ liệu & Ràng buộc Validate:**
    *   `Tên đăng nhập`: Không trống, không chứa ký tự đặc biệt, không chứa khoảng trắng.
    *   `Mật khẩu`: Tối thiểu 8 ký tự, gồm ít nhất 1 chữ cái viết hoa, 1 chữ số.
    *   `Nhập lại mật khẩu`: Phải trùng khớp 100% với trường Mật khẩu.
    *   `Số điện thoại`: Định dạng số điện thoại Việt Nam hợp lệ (10 số, bắt đầu bằng 0 hoặc +84).
*   **API tích hợp:** `POST /api/auth/register`
*   **Ca kiểm thử:**
    *   *TC_REG_001:* Đăng ký trùng tên đăng nhập/SĐT -> Trình duyệt hiển thị cảnh báo từ backend (409 Conflict): "Tên đăng nhập / Số điện thoại này đã tồn tại".
    *   *TC_REG_002:* Đăng ký thành công -> Chuyển hướng sang `/onboarding`.

#### 1.3 Màn hình Quên Mật Khẩu (`/forgot-password` -> `ForgotPasswordScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Gửi yêu cầu`: Gửi mã xác nhận hoặc link đặt lại mật khẩu.
    *   `Nút Trở lại đăng nhập`: Điều hướng về `/login`.
*   **Trường dữ liệu & Ràng buộc Validate:**
    *   `Tên đăng nhập / SĐT`: Không trống, đúng định dạng.
*   **API tích hợp:** `POST /api/auth/forgot-password`
*   **Ca kiểm thử:**
    *   *TC_FP_001:* Gửi yêu cầu thành công -> Hiển thị popup "Yêu cầu đặt lại mật khẩu đã được gửi".

#### 1.4 Màn hình Thiết lập Ban Đầu (`/onboarding` -> `OnboardingScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Hoàn tất`: Gửi thông tin hồ sơ onboarding của cửa hàng hoặc cá nhân lên server.
    *   `Nút Tìm cửa hàng`: Tìm kiếm shop có sẵn qua `shopCode` (Dành cho tài khoản `PERSONAL` - nhân viên).
*   **Trường dữ liệu & Ràng buộc Validate:**
    *   *Nếu là Chủ cửa hàng (`SHOP`):*
        *   `Tên cửa hàng`: Không được để trống.
        *   `Địa chỉ cửa hàng`: Không được để trống.
        *   `Họ tên chủ shop`: Không được để trống.
    *   *Nếu là Nhân viên (`PERSONAL`):*
        *   `Mã cửa hàng (Shop Code)`: Yêu cầu bắt buộc 6 ký tự viết hoa.
*   **API tích hợp:** `POST /api/auth/complete-onboarding`, `GET /api/auth/search-shops`
*   **Ca kiểm thử:**
    *   *TC_ONB_001:* Nhập mã cửa hàng không tồn tại -> Báo lỗi "Không tìm thấy Cửa hàng khớp với yêu cầu của bạn".
    *   *TC_ONB_002:* Hoàn thành hợp lệ -> Chuyển sang `/` (đối với Shop) hoặc `/waiting-approval` (đối với nhân viên).

#### 1.5 Màn hình Chờ Phê Duyệt (`/waiting-approval` -> `WaitingApprovalScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Đăng xuất`: Thoát tài khoản.
    *   `Nút Kiểm tra lại`: Gọi lại API để kiểm tra xem chủ shop đã phê duyệt thành viên chưa.
*   **API tích hợp:** `GET /api/my-shops` (Kiểm tra trạng thái `ShopMember.status` là `'ACTIVE'`, `'PENDING'` hay `'REJECTED'`).
*   **Ca kiểm thử:**
    *   *TC_APP_001:* Nếu trạng thái là `'PENDING'` -> Tiếp tục hiển thị màn hình chờ.
    *   *TC_APP_002:* Chủ shop phê duyệt thành `'ACTIVE'` -> Tự động chuyển sang màn hình Dashboard chính `/`.

---

### 2. 📊 NHÓM MÀN HÌNH TRANG CHỦ & ĐIỀU HƯỚNG CHÍNH (SHELL & DASHBOARD)

#### 2.1 Khung Điều Hướng Ứng Dụng (`MainShell` - Responsive Layout)
*   **Các nút bấm & Tương tác:**
    *   `Menu Drawer (Mobile)`: Mở/Đóng ngăn điều hướng.
    *   `Sidebar Links (Desktop)`: Điều hướng nhanh sang các phân hệ.
    *   `Nút Đăng xuất`: Đăng xuất khỏi hệ thống.
    *   `Nút Đổi cửa hàng`: Chọn làm việc với cửa hàng khác (nếu tài khoản liên kết nhiều shop).
*   **Phân quyền (Router Guards - Rất quan trọng):**
    *   Kiểm tra quyền truy cập theo từng vai trò (Owner, Finance, POS, Inventory). Nếu không có quyền, tự động redirect về trang chủ `/` và hiển thị thông báo "Không có quyền truy cập".

#### 2.2 Màn hình Bảng Điều Khiển (`/` -> `DashboardScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Bộ lọc thời gian (Hôm nay / Tuần này / Tháng này / Quý này)`: Cập nhật biểu đồ doanh thu và chi phí.
    *   `Nút Xem chi tiết công nợ`: Chuyển hướng sang màn hình `/debt-aging`.
    *   `Popup thông báo cảnh báo thuế`: Click chuyển sang màn hình `/tax-estimate`.
*   **Các Widget hiển thị:**
    *   *Biểu đồ Doanh thu & Chi phí (fl_chart)*: Trực quan hóa dữ liệu.
    *   *Widget Low Stock Warning*: Danh sách sản phẩm tồn dưới định mức.
    *   *Widget Tax Alert*: Hiển thị trạng thái cảnh báo nghĩa vụ thuế biên sắp đạt ngưỡng đóng thuế khoán 100M/năm.

---

### 3. 🛒 NHÓM MÀN HÌNH BÁN HÀNG & QUẢN LÝ ĐƠN HÀNG (POS & SALES)

#### 3.1 Màn hình Bán Hàng Điểm POS (`/pos` -> `PosScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Quét mã vạch / Tìm sản phẩm`: Thêm sản phẩm vào giỏ hàng.
    *   `Nút Tăng/Giảm số lượng sản phẩm (+ / -)`: Cập nhật trực tiếp số lượng trong giỏ.
    *   `Nút Chọn Khách Hàng`: Tìm kiếm và gán khách hàng vào đơn để tính công nợ.
    *   `Nút Nhập Chiết Khấu (Discount)`: Mở dialog nhập số tiền hoặc % giảm giá.
    *   `Nút Thanh Toán`: Mở dialog chọn phương thức (Tiền mặt / Chuyển khoản / Ghi nợ).
    *   `Nút Hủy giỏ hàng`: Xóa sạch toàn bộ giỏ.
*   **Trường dữ liệu & Ràng buộc Validate:**
    *   `Số lượng bán`: Không được phép vượt quá số lượng hàng tồn kho thực tế nếu cấu hình "Không cho bán âm kho" hoạt động.
    *   `Chiết khấu`: Không được lớn hơn tổng tiền đơn hàng.
*   **API tích hợp:** `POST /api/sales/orders`
*   **Ca kiểm thử:**
    *   *TC_POS_001:* Đơn hàng ghi nợ mà không chọn Khách hàng -> Báo lỗi validate: "Vui lòng chọn khách hàng để thực hiện bán nợ".
    *   *TC_POS_002:* Hoàn tất đơn hàng thanh toán Tiền mặt -> Tạo hóa đơn thành công, in biên lai, giảm tồn kho tương ứng, ghi nhận bút toán Nợ TK 111 / Có TK 511.

#### 3.2 Màn hình Danh Sách Đơn Hàng Bán (`/sales` -> `SalesListScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Thanh tìm kiếm`: Tìm kiếm đơn hàng theo Mã đơn hoặc tên khách hàng.
    *   `Bộ lọc Bộ phận / Phương thức thanh toán`.
    *   `Nút Xuất Excel`: Kết xuất báo cáo danh sách đơn hàng.
*   **API tích hợp:** `GET /api/sales/orders`

#### 3.3 Màn hình Chi Tiết Đơn Hàng (`/sales/:id` -> `OrderDetailScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút In Hóa Đơn`: Gửi lệnh in HTML/PDF biên lai.
    *   `Nút Trả Hàng (Return)`: Tạo đơn trả hàng cho một phần hoặc toàn bộ đơn cũ.
*   **API tích hợp:** `GET /api/sales/orders/:id`, `POST /api/sales/returns`
*   **Ca kiểm thử:**
    *   *TC_RET_001:* Trả hàng vượt quá số lượng đã mua -> Hệ thống báo lỗi.
    *   *TC_RET_002:* Trả hàng thành công -> Cập nhật tăng lại kho, giảm công nợ hoặc trả tiền mặt cho khách, ghi nhận giá vốn đảo ngược.

---

### 4. 📦 NHÓM MÀN HÌNH QUẢN LÝ SẢN PHẨM & TỒN KHO (PRODUCTS & INVENTORY)

#### 4.1 Màn hình Danh Sách Sản Phẩm (`/products` -> `ProductListScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Thêm sản phẩm`: Điều hướng sang `/products/form` với trạng thái [NEW].
    *   `Nút Sửa sản phẩm`: Điều hướng sang `/products/form` với dữ liệu sản phẩm có sẵn.
    *   `Bộ lọc Danh mục`: Lọc sản phẩm theo danh mục.
*   **API tích hợp:** `GET /api/products`

#### 4.2 Màn hình Thêm/Sửa Sản Phẩm (`/products/form` -> `ProductFormScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Lưu`: Gửi dữ liệu tạo mới hoặc cập nhật lên server.
    *   `Nút Tải ảnh lên`: Chọn và upload hình ảnh sản phẩm.
*   **Trường dữ liệu & Ràng buộc Validate:**
    *   `Tên sản phẩm`: Không được để trống.
    *   `Mã vạch (SKU/BarCode)`: Không được trùng lặp.
    *   `Giá bán`: Không được âm, phải lớn hơn hoặc bằng giá vốn.
    *   `Đơn vị tính`: Không được để trống.
*   **API tích hợp:** `POST /api/products`, `PUT /api/products/:id`
*   **Ca kiểm thử:**
    *   *TC_PROD_001:* Nhập giá bán nhỏ hơn 0 -> Báo lỗi "Giá bán không hợp lệ".

#### 4.3 Màn hình Chi Tiết Sản Phẩm (`/products/:id` -> `ProductDetailScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Tab Biến động kho`: Xem lịch sử xuất/nhập của sản phẩm.
    *   `Nút Xem lịch sử giá`: Biểu đồ lịch sử thay đổi giá bán.
*   **API tích hợp:** `GET /api/products/:id`

#### 4.4 Màn hình Tổng Quan Kho (`/inventory` -> `InventoryScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Điều chuyển kho`: Chuyển hàng giữa các kho nội bộ.
    *   `Bộ lọc kho (Kho chính, Kho phụ)`.
*   **API tích hợp:** `GET /api/inventory/stocks`

#### 4.5 Màn hình Kiểm Kho (`/stock-take` -> `StockTakeScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Tạo phiếu kiểm kho`: Khởi tạo phiên kiểm kho mới.
    *   `Nút Quét sản phẩm kiểm`: Thêm sản phẩm vào danh sách kiểm.
    *   `Nút Cân đối kho (Hoàn tất kiểm kho)`: Xác nhận điều chỉnh số lượng tồn thực tế trên hệ thống.
*   **Trường dữ liệu & Ràng buộc Validate:**
    *   `Số lượng đếm thực tế`: Phải là số nguyên lớn hơn hoặc bằng 0.
*   **API tích hợp:** `POST /api/inventory/stock-takes`
*   **Ca kiểm thử:**
    *   *TC_STK_001:* Cân đối kho khi có lệch thừa/thiếu -> Hệ thống tự động tạo bút toán điều chỉnh kho (Inventory Movement type 'ADJUST') và sinh nhật ký giá vốn tương ứng.

#### 4.6 Màn hình Đơn Mua Hàng (`/purchase-orders` -> `PurchaseOrderScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Tạo đơn mua`: Lên kế hoạch nhập hàng từ nhà cung cấp.
    *   `Nút Duyệt nhập kho`: Nhập hàng thực tế vào kho từ đơn mua.
*   **API tích hợp:** `POST /api/inventory/purchase-orders`

#### 4.7 Màn hình Báo Cáo Xuất Nhập Tồn (`/xnt-report` -> `XntReportScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Xem báo cáo`: Tải dữ liệu kỳ kế toán đã chọn.
    *   `Nút Xuất PDF / Excel`: Tải file báo cáo XNT về máy.
*   **API tích hợp:** `GET /api/inventory/xnt-report`

---

### 5. 👥 NHÓM MÀN HÌNH QUẢN LÝ ĐỐI TÁC (PARTNERS - CUSTOMERS & SUPPLIERS)

#### 5.1 Màn hình Danh Sách Khách Hàng (`/customers` -> `CustomerListScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Thêm khách hàng`: Mở form `/customers/form`.
*   **API tích hợp:** `GET /api/customers`

#### 5.2 Màn hình Thêm/Sửa Khách Hàng (`/customers/form` -> `CustomerFormScreen`)
*   **Trường dữ liệu & Ràng buộc Validate:**
    *   `Tên khách hàng`: Không trống.
    *   `SĐT`: 10 chữ số hợp lệ.
*   **API tích hợp:** `POST /api/customers`

#### 5.3 Màn hình Chi Tiết & Công Nợ Khách Hàng (`/customers/:id` -> `CustomerDetailScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Thu Nợ`: Dialog ghi nhận khách trả tiền nợ (Tiền mặt / Chuyển khoản).
*   **API tích hợp:** `POST /api/customers/:id/pay-debt`
*   **Ca kiểm thử:**
    *   *TC_CUST_PAY:* Khách trả nợ 10M -> Giảm số dư nợ trên hệ thống, tăng tài khoản tiền mặt (Nợ TK 111 / Có TK 131 - Phải thu khách hàng).

#### 5.4 Màn hình Danh Sách Nhà Cung Cấp (`/suppliers` -> `SupplierListScreen`)
#### 5.5 Màn hình Thêm/Sửa Nhà Cung Cấp (`/suppliers/form` -> `SupplierFormScreen`)
#### 5.6 Màn hình Chi Tiết Nhà Cung Cấp (`/suppliers/:id` -> `SupplierDetailScreen`)
*   **Tương tác tương tự phân hệ Khách hàng:** Nhưng quản lý công nợ phải trả (Tài khoản 331 - Phải trả người bán) và nút `Trả nợ nhà cung cấp` (Có TK 111 / Nợ TK 331).

---

### 6. 💵 NHÓM MÀN HÌNH TÀI CHÍNH & KẾ TOÁN (FINANCE & LEDGER)

#### 6.1 Màn hình Báo Cáo Tài Chính Tổng Hợp (`/finance` -> `FinanceScreen`)
*   Hiển thị dòng tiền mặt, số dư tài khoản ngân hàng, tổng tài sản.

#### 6.2 Màn hình Chốt Ca Ngày (`/daily-closing` -> `DailyClosingScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Chốt Ca`: Mở dialog điền số tiền mặt thực tế kiểm kê.
*   **Trường dữ liệu & Ràng buộc Validate:**
    *   `Tiền mặt thực tế đếm`: Không được để trống.
    *   `Ghi chú giải trình`: **Bắt buộc** nhập nếu chênh lệch giữa tiền mặt thực tế đếm và tiền lý thuyết hệ thống lớn hơn 50.000 VNĐ.
*   **API tích hợp:** `POST /api/finance/daily-closings`
*   **Ca kiểm thử:**
    *   *TC_CLOSE_001:* Tiền lệch 100.000 VNĐ không nhập ghi chú -> Báo lỗi validate: "Chênh lệch két vượt quá 50,000đ. Vui lòng nhập lý do giải trình".
    *   *TC_CLOSE_002:* Nhập ghi chú hợp lệ -> Lưu chốt ca thành công, khóa toàn bộ giao dịch trong ngày đã chốt.

#### 6.3 Màn hình Báo Cáo Lợi Nhuận P&L (`/profit-loss` -> `ProfitLossScreen`)
*   Xem doanh thu, giá vốn (COGS), chi phí hoạt động và lợi nhuận ròng. Tích hợp xuất PDF.

#### 6.4 Màn hình Dự Báo Dòng Tiền (`/cashflow-forecast` -> `CashflowForecastScreen`)
*   Giao diện lập lịch và hiển thị xu hướng dòng tiền tương lai.

#### 6.5 Màn hình Phân Tích Tuổi Nợ (`/debt-aging` -> `DebtAgingScreen`)
*   Phân tích các khoản công nợ trễ hạn theo các cột mốc: 1-30 ngày, 31-60 ngày, 61-90 ngày, >90 ngày.

#### 6.6 Màn hình Quản Lý Hóa Đơn (`/invoices` -> `InvoiceListScreen`)
*   Xem hóa đơn VAT điện tử lưu trong hệ thống.

#### 6.7 Màn hình Bảng Kê Không Hóa Đơn (`/purchases-no-invoice` -> `PurchaseNoInvoiceScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Tạo Bảng Kê`: Mở form nhập hàng nông/lâm/thủy sản mua trực tiếp của người dân không có hóa đơn (Bảng kê 01/TNDN).
    *   `Nút Phê Duyệt (Dành cho Chủ shop)`: Phê duyệt bảng kê do nhân viên tạo để nhập kho và xuất tiền mặt.
*   **Trường dữ liệu & Ràng buộc Validate:**
    *   `Tên người bán`: Không trống.
    *   `Số định danh (CCCD)`: Yêu cầu bắt buộc 12 chữ số.
    *   `Bảng mặt hàng`: Phải chứa tối thiểu 1 dòng mặt hàng với số lượng > 0 và đơn giá > 0.
*   **API tích hợp:** `POST /api/finance/purchases-no-invoice`, `PUT /api/finance/purchases-no-invoice/:id/approval`
*   **Ca kiểm thử:**
    *   *TC_NOINV_001:* Nhân viên tạo bảng kê -> Trạng thái lưu thành `PENDING` (Chờ duyệt).
    *   *TC_NOINV_002:* Chủ shop bấm Duyệt (`APPROVED`) -> Kho tăng số lượng hàng, tạo lô tính FIFO giá vốn, xuất bút toán chi tiền mặt (Nợ TK 156 / Có TK 111).

#### 6.8 Màn hình Tính Thuế Biên (`/tax-calculator` -> `TaxCalculatorScreen`)
*   Tính nhanh số thuế VAT & PIT phải nộp theo tỷ lệ phần trăm trên doanh thu.

#### 6.9 Màn hình Sổ Nhật Ký Chi Phí (`/expense-ledger` -> `ExpenseLedgerScreen`)
*   Ghi chép các khoản chi phí hoạt động trực tiếp ngoài bán hàng.

#### 6.10 Màn hình Nghĩa Vụ Thuế (`/tax-obligations` -> `TaxObligationScreen`)
*   Theo dõi và khai báo số thuế GTGT & TNCN đã nộp ngân sách nhà nước theo từng quý.

#### 6.11 Màn hình Bảng Lương Nhân Viên (`/salary-ledger` -> `SalaryLedgerScreen`)
*   Tính toán lương và các khoản giảm trừ gia cảnh của nhân sự.

#### 6.12 Màn hình Tờ Khai Thuế (`/tax-declaration` -> `TaxDeclarationScreen`)
*   Khai báo thuế theo kỳ (Tháng/Quý/Năm).

#### 6.13 Màn hình Lịch Sử Giao Dịch Sổ Quỹ (`/transactions` -> `TransactionHistoryScreen`)
*   Danh sách lịch sử toàn bộ các giao dịch tiền ra/vào.

#### 6.14 Màn hình Ước Tính Thuế & Xuất Tờ Khai (`/tax-estimate` -> `TaxEstimateScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Bộ chọn Kỳ tính thuế (Tháng 01-12 / Quý 1-4)`: Chọn kỳ tính thuế.
    *   `Nút Tải file XML (Xuất HTKK)`: Xuất file XML tờ khai 01/CNKD.
*   **API tích hợp:** `GET /api/tax/estimate`, `GET /api/tax/export-htkk`
*   **Ca kiểm thử:**
    *   *TC_TAX_HTKK:* Bấm nút Xuất -> Tải về thành công file `.xml` đúng định dạng mã hóa UTF-8, cấu trúc tag `<HSoKhaiThue>` chuẩn hóa để import trực tiếp vào phần mềm HTKK của Tổng cục Thuế Việt Nam.

---

### 7. ⚙️ NHÓM MÀN HÌNH CẤU HÌNH & HỆ THỐNG (SETTINGS & SECURITY)

#### 7.1 Màn hình Thiết Lập Chung (`/settings` -> `SettingsScreen`)
#### 7.2 Màn hình Nhật Ký Hoạt Động (`/activity-logs` -> `ActivityLogScreen`)
*   Hiển thị lịch sử thao tác của nhân viên (Ai đã sửa giá, Ai đã xóa hóa đơn) để phát hiện gian lận.

#### 7.3 Màn hình Cấu Hình Thuế (`/tax-config` -> `TaxConfigScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Bộ chọn Ngành nghề kinh doanh`: Phân phối (VAT 1%/PIT 0.5%), Sản xuất (3%/1.5%), Dịch vụ (5%/2%), Khác (2%/1%).
    *   `Switch Giảm thuế VAT 20%`: Kích hoạt chính sách giảm thuế theo NQ của Chính phủ.
*   **API tích hợp:** `GET /api/tax/config`, `POST /api/tax/config`
*   **Ca kiểm thử:**
    *   *TC_CFG_VAT:* Bật giảm thuế -> Tính toán VAT đầu ra tự động nhân với hệ số `0.8` (Giảm 20% mức thuế suất).

#### 7.4 Màn hình Hỗ Trợ Pháp Lý Thuế (`/tax-support` -> `TaxSupportScreen`)
#### 7.5 Màn hình Cấu Hình Thanh Toán (`/payment-config` -> `PaymentConfigScreen`)
*   Cấu hình thông tin tài khoản ngân hàng để sinh mã QR VietQR động tại POS.

#### 7.6 Màn hình Danh Sách Thông Báo (`/notifications` -> `NotificationListScreen`)
#### 7.7 Màn hình Quản Lý Nhân Viên (`/staff` -> `StaffManagementScreen`)
*   Chủ cửa hàng thêm nhân viên mới và cấp quyền.

#### 7.8 Màn hình Cấu Hình Vai Trò/Quyền (`/roles` -> `RoleConfigScreen`)
*   Tùy chỉnh phân quyền chi tiết (Cho phép xem doanh thu, Cho phép duyệt đơn hàng).

#### 7.9 Màn hình Thông Tin Cá Nhân (`/profile` -> `ProfileScreen`)
*   Cập nhật Họ tên, đổi mật khẩu cá nhân.

#### 7.10 Màn hình Hồ Sơ Cửa Hàng (`/shop-profile` -> `ShopProfileScreen`)
*   Cấu hình Mã số thuế cửa hàng, Địa chỉ, logo in biên lai.

---

## 🔒 PHẦN II: KIỂM THỬ AN TOÀN BẢO MẬT & PHÂN QUYỀN TRÊN ROUTER GIAO DIỆN

Để đảm bảo bảo mật dữ liệu tuyệt đối giữa các nhân viên, bộ định tuyến `app_router.dart` được kiểm thử tự động với các kịch bản ma trận phân quyền sau:

```
+---------------------------------+--------------+-----------------+-----------------+
| Phân hệ chức năng               | Chủ (Owner)  | Kế toán (Fin)   | Bán hàng (POS)  |
+---------------------------------+--------------+-----------------+-----------------+
| Bảng điều khiển (Dashboard)     |   Cho phép   |    Cho phép     |    Cho phép     |
| Điểm bán hàng (POS)             |   Cho phép   |    Cho phép     |    Cho phép     |
| Quản lý Hóa đơn & Thuế          |   Cho phép   |    Cho phép     |  Bị CHẶN (=> /) |
| Chốt Ca Hàng Ngày (Daily Close) |   Cho phép   |    Cho phép     |  Bị CHẶN (=> /) |
| Nhập Kho & Đơn Mua Hàng         |   Cho phép   |  Bị CHẶN (=> /) |  Bị CHẶN (=> /) |
| Sổ Lương & Thiết Lập Hệ Thống   |   Cho phép   |  Bị CHẶN (=> /) |  Bị CHẶN (=> /) |
+---------------------------------+--------------+-----------------+-----------------+
```

---

## ☁️ PHẦN III: KIỂM THỬ ĐẶC THÙ MÔI TRƯỜNG SERVERLESS VERCEL

Do ứng dụng được deploy trên môi trường Serverless của Vercel kết nối DB Supabase PostgreSQL, chúng ta phải kiểm thử các điểm giới hạn hạ tầng sau:

### 1. Kiểm thử Fix Lỗi TypeORM dynamic scanning (Lỗi P0)
*   **Kịch bản kiểm thử:** Deploy bản sửa đổi `db.config.ts` (Sử dụng mảng `entities` import tường minh trực tiếp thay vì glob scanning). Thực hiện ngưng tương tác hệ thống trong 30 phút để Vercel thu hồi tài nguyên (Cold Boot). Sau đó, thực hiện Đăng nhập/Đăng ký.
*   **Kết quả mong đợi:** Ứng dụng khởi động ngay lập tức, kết nối DB thành công và không crash lỗi `RepositoryNotFoundError`.

### 2. Kiểm thử CORS preflight
*   **Kịch bản kiểm thử:** Dùng lệnh `curl` gửi request giả lập OPTIONS CORS từ origin khác:
    ```bash
    curl -X OPTIONS https://stock-management-and-tax-warning.vercel.app/api/auth/login \
      -H "Origin: https://smartstock-tax.vercel.app" \
      -H "Access-Control-Request-Method: POST"
    ```
*   **Kết quả mong đợi:** Trả về mã HTTP 200 OK kèm các Header CORS đầy đủ:
    `Access-Control-Allow-Origin: https://smartstock-tax.vercel.app`
    `Access-Control-Allow-Credentials: true`

---

## 📈 PHẦN IV: BÁO CÁO VÀ THEO DÕI LỖI (BUG TRACKING TEMPLATE)

Khi chạy kiểm thử theo Test Plan này, mọi lỗi phát hiện phải được tạo issue hoặc ghi nhận chính xác theo mẫu:

```markdown
### [BUG - MÃ MÀN HÌNH] Tiêu đề ngắn gọn mô tả lỗi
- **Mức độ:** P0 (Chặn đứng hệ thống) / P1 (Nghiêm trọng) / P2 (Bình thường) / P3 (Giao diện hiển thị)
- **Môi trường:** Local (Dev) / Deployed (Vercel Production)
- **Các bước tái hiện (Steps to Reproduce):**
  1. Vào màn hình [Tên màn hình] qua đường dẫn [Route]
  2. Click vào nút [Tên nút bấm] hoặc điền trường [Tên trường]
  3. Bấm xác nhận
- **Kết quả thực tế (Actual Result):** Trả về mã lỗi 500 hoặc hiển thị popup trắng...
- **Kết quả kỳ vọng (Expected Result):** Hệ thống hiển thị cảnh báo đỏ hoặc lưu trữ thành công...
- **Console Log / API Response đính kèm:** (Copy thông tin lỗi ở đây)
```
