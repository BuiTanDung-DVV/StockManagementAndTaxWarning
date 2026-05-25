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
    *   *TC_LOGIN_002:* Nhập sai mật khẩu -> ✅ **PASSED** (Hệ thống từ chối đăng nhập với 401 Unauthorized, hiển thị thông báo "Không thể đăng nhập. Vui lòng thử lại", CORS validation: PASS).
    *   *TC_LOGIN_003:* Tài khoản bị khóa (`isActive: false`) -> Hiển thị "Tài khoản của bạn đã bị khóa".
    *   *TC_LOGIN_EMPTY:* Bỏ trống các trường và Submit -> ✅ **PASSED** (API 401 Unauthorized, hiển thị lỗi đỏ "Không thể đăng nhập. Vui lòng thử lại", CORS validation: PASS).

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
    *   *TC_REG_NAV:* Chuyển hướng từ Login sang Đăng ký -> ✅ **PASSED** (Màn hình render chuẩn, đầy đủ field và nút chọn loại tài khoản).
    *   *TC_REG_EMPTY:* Bỏ trống các trường và Submit -> ✅ **PASSED** (Validation client-side chặn ngay, hiển thị lỗi đỏ "Vui lòng điền đầy đủ thông tin", không gọi API).
    *   *TC_REG_MISMATCH:* Điền mật khẩu xác nhận không khớp -> ✅ **PASSED** (Validation client-side chặn ngay, báo "Mật khẩu xác nhận không khớp", không gọi API).
    *   *TC_REG_001:* Đăng ký trùng tên đăng nhập/SĐT -> ✅ **PASSED** (Backend chặn và UI hiển thị thông báo chi tiết: "Tên đăng nhập hoặc số điện thoại này đã được sử dụng. Vui lòng thử số khác.").
    *   *TC_REG_002:* Đăng ký thành công -> ✅ **PASSED** (API gọi POST thành công trả về 200 OK, DB lưu chính xác. App tự động quay lại `/login` kèm snackbar xanh "Đăng ký tài khoản thành công! Vui lòng đăng nhập.").

#### 1.3 Màn hình Quên Mật Khẩu (`/forgot-password` -> `ForgotPasswordScreen`)
*   **Các nút bấm & Tương tác:**
    *   `Nút Gửi yêu cầu`: Gửi mã xác nhận hoặc link đặt lại mật khẩu.
    *   `Nút Trở lại đăng nhập`: Điều hướng về `/login`.
*   **Trường dữ liệu & Ràng buộc Validate:**
    *   `Tên đăng nhập / SĐT`: Không trống, đúng định dạng.
*   **API tích hợp:** `POST /api/auth/forgot-password`
*   **Ca kiểm thử:**
    *   *TC_FP_EMPTY:* Bỏ trống ô SĐT/Email -> ✅ **PASSED** (Hiển thị lỗi "Vui lòng nhập số điện thoại hoặc email liên hệ").
    *   *TC_FP_001:* Gửi yêu cầu hợp lệ -> ✅ **PASSED** (Hiển thị popup "Yêu cầu thành công! Vui lòng kiểm tra điện thoại...").
    *   *TC_FP_INVALID:* Nhập sai định dạng (vd: "abc") -> ✅ **PASSED** (Đã bổ sung validation định dạng SĐT client-side, hiển thị lỗi "Định dạng số điện thoại không hợp lệ (10-12 số)" và chặn gửi request).

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
    *   *TC_ONB_EMPTY:* Submit form trống -> ✅ **PASSED** (Hiển thị cảnh báo "Vui lòng điền đầy đủ thông tin").
    *   *TC_ONB_001:* Nhập mã cửa hàng không tồn tại -> Báo lỗi "Không tìm thấy Cửa hàng khớp với yêu cầu của bạn".
    *   *TC_ONB_002:* Chủ Shop hoàn thành form hợp lệ -> ✅ **PASSED** (Lưu thành công, tự động chuyển hướng sang Dashboard `/`, Dashboard load đúng dữ liệu user "Xin chào, Nguyen Van Shop").

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
    *   *TC_POS_002:* Hoàn tất đơn hàng thanh toán Tiền mặt -> ✅ **PASSED** (Thêm SP vào giỏ, thanh toán Tiền mặt thành công. Giỏ hàng reset, tồn kho giảm chính xác ngay lập tức).

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
    *   *TC_PROD_EMPTY:* Bỏ trống form và Lưu -> ✅ **PASSED** (Hệ thống bắt lỗi các trường bắt buộc thành công).
    *   *TC_PROD_DUP_SKU:* Trùng SKU/Mã vạch -> ✅ **PASSED** (Hệ thống chặn trùng lặp data constraints).
    *   *TC_PROD_001:* Tạo sản phẩm thành công -> ✅ **PASSED** (Sản phẩm hiển thị ngay lên danh sách với đủ tồn kho và giá).
    *   *TC_PROD_PRICE:* Nhập giá bán nhỏ hơn 0 -> Báo lỗi "Giá bán không hợp lệ".

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
*   **Kết quả mong đợi:** Trả về mã HTTP 200 OK hoặc 204 No Content kèm các Header CORS đầy đủ:
    `Access-Control-Allow-Origin: https://smartstock-tax.vercel.app`
    `Access-Control-Allow-Credentials: true`
*   **Trạng thái kiểm thử:** ✅ **ĐÃ ĐẠT (PASSED)** (Cập nhật ngày 25/05/2026)
    *   *Kết quả thực tế:* Đã deploy bản vá gộp động whitelist CORS kết hợp tối ưu hóa error callback sạch sẽ. Lệnh kiểm tra OPTIONS preflight thực tế trả về HTTP 204 No Content kèm đầy đủ các header CORS chuẩn:
        - `Access-Control-Allow-Origin: https://smartstock-tax.vercel.app`
        - `Access-Control-Allow-Credentials: true`
        - `Access-Control-Allow-Headers: Content-Type`
        - `Access-Control-Allow-Methods: GET,HEAD,PUT,PATCH,POST,DELETE`

---

## 📈 PHẦN IV: BÁO CÁO VÀ THEO DÕI LỖI (BUG TRACKING TEMPLATE)

### Các Lỗi Đã Ghi Nhận (Logged Bugs)

#### 1. [BUG - AUTH] Thông báo lỗi trên giao diện (UI) chưa đủ chi tiết
- **Mức độ:** P3 (Cải thiện UX)
- **Môi trường:** Deployed (Vercel Production)
- **Mô tả chi tiết:** Ở màn hình Login và Register, khi người dùng nhập sai thông tin hoặc thiếu thông tin, ứng dụng hiển thị các thông báo khá chung chung như "Không thể đăng nhập. Vui lòng thử lại" (kể cả khi sai pass hay tài khoản không tồn tại) hoặc "Vui lòng điền đầy đủ thông tin". 
- **Kết quả kỳ vọng:** Nên hiển thị thông báo chi tiết hơn (VD: "Sai mật khẩu", "Tài khoản không tồn tại", hoặc bôi đỏ chỉ rõ trường nào còn thiếu).
- **Trạng thái:** Mới ghi nhận.

#### 2. [BUG - AUTH] Thiếu Validation định dạng ở màn hình Quên mật khẩu
- **Mức độ:** P2 (Lỗi Logic UI)
- **Môi trường:** Deployed (Vercel Production)
- **Mô tả chi tiết:** Tại màn hình Quên mật khẩu, nếu nhập chuỗi không hợp lệ (VD: "abc"), UI vẫn chấp nhận và báo "Yêu cầu thành công...".
- **Kết quả kỳ vọng:** Validate định dạng SĐT/Email tại Client và báo lỗi nếu không đúng định dạng.
- **Trạng thái:** Mới ghi nhận.

#### 3. [FEATURE MISSING - AUTH] Thiếu các tính năng xác thực thực tế (SMS, Email, OTP)
- **Mức độ:** P1 (Tính năng cốt lõi)
- **Môi trường:** Đang rà soát chức năng
- **Mô tả chi tiết:** Ứng dụng hiện tại đang thiếu hoàn toàn các tính năng xác minh danh tính bao gồm: 
  - Xác thực số điện thoại (Gửi mã OTP qua SMS).
  - Tính năng Đăng ký tài khoản bằng Email và Xác thực Email.
  - Chức năng gửi Email / SMS thật để cấp lại mật khẩu (luồng Quên mật khẩu hiện tại mới chỉ có giao diện chứ chưa thực thi việc gửi tin).
- **Trạng thái:** Cần bổ sung vào lộ trình phát triển để hệ thống hoàn thiện.

#### 4. [FEATURE MISSING - ONBOARDING] Chưa tích hợp bản đồ (Map) khi nhập địa chỉ
- **Mức độ:** P2 (Cải thiện UX & Data)
- **Môi trường:** Đang rà soát chức năng
- **Mô tả chi tiết:** Ở màn hình Onboarding (Thiết lập thông tin cửa hàng), trường nhập "Địa chỉ kinh doanh" hiện tại mới chỉ là ô nhập văn bản (text input) thuần túy. Chưa có tích hợp API Bản đồ (như Google Maps / Mapbox) để hỗ trợ tìm kiếm nhanh, ghim vị trí tọa độ (Lat/Lng) và tự động điền địa chỉ chuẩn xác.
- **Trạng thái:** Cần bổ sung vào tính năng Onboarding.

#### 5. [BUG - PRODUCTS] Thiếu phần hiển thị Mô tả sản phẩm tại màn Chi tiết
- **Mức độ:** P3 (Hiển thị UI)
- **Môi trường:** Deployed (Vercel Production)
- **Mô tả chi tiết:** Tại màn hình Chi tiết sản phẩm (`/products/:id`), phần nội dung "Mô tả sản phẩm" (Description) không xuất hiện trên giao diện.
- **Kết quả kỳ vọng:** Giao diện chi tiết sản phẩm cần bổ sung layout để render trường mô tả sản phẩm cho nhân viên tiện theo dõi.
- **Trạng thái:** Mới ghi nhận.

#### 6. [BUG - PRODUCTS] Lỗi hiển thị (UX) và catch Exception khi trùng mã SKU / Mã vạch
- **Mức độ:** P2 (Lỗi Logic/UX)
- **Môi trường:** Deployed (Vercel Production) / Codebase Backend
- **Mô tả chi tiết:** Khi tạo sản phẩm mới, nếu bị trùng mã SKU thì API trả về lỗi tiếng Anh "SKU already exists" (Frontend có thể hiển thị tiếng Anh hoặc lỗi chung chung). Nguy hiểm hơn, **Mã vạch (Barcode)** bị trùng lặp chưa được backend kiểm tra trước khi lưu (`product.service.ts` dòng 53 chỉ check SKU), dẫn đến việc văng lỗi 500 từ raw Database Unique Constraint thay vì báo lỗi 409 hợp lệ.
- **Kết quả kỳ vọng:** Backend cần kiểm tra `findOne` cho cả `sku` và `barcode` trước khi save. Nếu trùng, trả về lỗi 409 với message tiếng Việt (VD: "Mã SKU hoặc Mã vạch này đã tồn tại trong hệ thống"). Frontend cần hiển thị toast đỏ rõ ràng.
- **Trạng thái:** Mới ghi nhận.

#### 7. [SYSTEM/UX] Chuẩn hóa toàn bộ thông báo (Toast/Error Message) trên hệ thống
- **Mức độ:** P2 (UX Toàn hệ thống)
- **Môi trường:** Toàn bộ Frontend & Backend
- **Mô tả chi tiết:** Hiện tại hệ thống xuất hiện tình trạng hiển thị các câu thông báo lỗi/thành công bằng tiếng Anh nguyên bản từ Backend (VD: "SKU already exists") hoặc các thông báo lỗi chung chung khó hiểu (vd: "Đăng ký không thành công" mà không nói rõ vì sao).
- **Kết quả kỳ vọng:** Cần rà soát và Việt hóa 100% các câu thông báo (toast message, alert, form validation error). Ngôn từ phải thân thiện, dễ hiểu, chỉ đích danh lỗi và cách khắc phục cho người dùng.
- **Trạng thái:** Mới ghi nhận.

#### 8. [BUG - UI/UX] Thông báo (Toast Message) bị treo cứng, không tự động đóng
- **Mức độ:** P3 (Hiển thị UI)
- **Môi trường:** Deployed (Toàn hệ thống)
- **Mô tả chi tiết:** Các thông báo lỗi (vd: "Lỗi: SKU already exists") xuất hiện dưới dạng popup/toast ở góc màn hình nhưng bị treo cứng (lingering), không tự động biến mất (auto-hide) sau vài giây và cũng không mất đi khi người dùng chuyển sang các trang khác (Sales, Inventory, Finance). Hiện tượng treo này che khuất các nút bấm quan trọng ở góc dưới màn hình (ví dụ nút (+) thêm khách hàng).
- **Kết quả kỳ vọng:** Component hiển thị Toast (Snackbar) cần được cấu hình thời gian tự động đóng (timeout ~3-5s) hoặc tự động clear khi chuyển Route.
- **Trạng thái:** Mới ghi nhận.

#### 9. [BUG - STAFF] Mất thông báo lỗi (Silent Failure) khi thêm nhân viên không tồn tại
- **Mức độ:** P2 (Lỗi UI/UX)
- **Môi trường:** Deployed (Quản lý Nhân viên)
- **Mô tả chi tiết:** Khi thêm/mời nhân viên bằng username (SĐT) chưa từng đăng ký tài khoản trên hệ thống, Backend trả về lỗi 400 (`Không tìm thấy tài khoản với username này`) nhưng Frontend **không hiển thị bất kỳ thông báo lỗi nào**. Form nhập tự động đóng lại (silently dismissed) làm người dùng hoang mang không biết vì sao thêm nhân viên thất bại.
- **Kết quả kỳ vọng:** Frontend phải bắt lỗi HTTP 400 này, hiển thị Toast đỏ thông báo: "Không tìm thấy người dùng này trên hệ thống. Vui lòng kiểm tra lại". Không đóng form nếu thao tác thất bại.
- **Trạng thái:** Mới ghi nhận.

#### 10. [BUG - FINANCE] Thiếu validation bắt buộc nhập Giải trình khi chốt ca lệch tiền
- **Mức độ:** P2 (Lỗi Logic/Validation)
- **Môi trường:** Deployed (Chốt Ca Ngày)
- **Mô tả chi tiết:** Khi thực hiện Chốt ca, nếu số tiền thực tế bị lệch so với hệ thống (vd: hụt 20,000đ), UI đánh dấu trường "Ghi chú / Giải trình" là BẮT BUỘC. Tuy nhiên, nếu người dùng bỏ trống trường này và bấm Chốt ca, hệ thống vẫn cho phép lưu thành công "ĐÃ KẾT CA & KHÓA SỔ" mà không chặn lại.
- **Kết quả kỳ vọng:** Nếu có chênh lệch, bắt buộc phải validate (cả client & server) trường ghi chú không được rỗng.
- **Trạng thái:** Mới ghi nhận.

#### 11. [BUG - TAX] Nút "Xuất XML HTKK" bị liệt (Silent Failure)
- **Mức độ:** P1 (Tính năng cốt lõi lỗi)
- **Môi trường:** Deployed (Ước Tính Thuế)
- **Mô tả chi tiết:** Khi bấm nút "Xuất XML HTKK (Mẫu 01/CNKD)", hệ thống không có bất kỳ phản hồi nào: Không có file tải xuống, không có thông báo lỗi UI, cũng không có request lỗi bắn ra Console. Tính năng xuất tờ khai đang bị tê liệt.
- **Kết quả kỳ vọng:** Nút bấm phải kích hoạt gọi API, sinh file XML và trigger trình duyệt tải file.
- **Trạng thái:** Mới ghi nhận.

#### 12. [BUG - A11Y] Thẻ Cảnh báo Thuế không hỗ trợ Trình đọc màn hình (Screen Reader)
- **Mức độ:** P3 (Khả năng truy cập - Accessibility)
- **Môi trường:** Deployed (Ước Tính Thuế - Flutter Web)
- **Mô tả chi tiết:** Các số liệu quan trọng trong thẻ "Cảnh báo Nghĩa vụ Thuế" (Tổng doanh thu, VAT ước tính) hiển thị bằng mắt thì thấy, nhưng lại bị "tàng hình" trong cây Semantics (Accessibility tree) của Flutter. 
- **Kết quả kỳ vọng:** Cần bọc các Text quan trọng bằng widget `Semantics` để trình đọc màn hình hỗ trợ người dùng có thị lực kém.
- **Trạng thái:** Mới ghi nhận.

#### 13. [BUG - FINANCE] Bảng kê Không Hóa Đơn bị lỗi Silent Failure khi không có mặt hàng
- **Mức độ:** P2 (Lỗi UI/UX)
- **Môi trường:** Deployed (Bảng kê không hóa đơn)
- **Mô tả chi tiết:** Khi tạo bảng kê, nếu để trống phần "Chi tiết hàng hóa" (không thêm dòng sản phẩm nào) và bấm Lưu, màn hình không có bất kỳ phản hồi nào (Silent Failure). Form không đóng, không gọi API, và cũng không hiện báo lỗi yêu cầu phải có ít nhất 1 mặt hàng.
- **Kết quả kỳ vọng:** Phải hiện Toast/Validation đỏ: "Vui lòng nhập ít nhất một mặt hàng vào bảng kê".
- **Trạng thái:** Mới ghi nhận.

#### 14. [BUG - SETTINGS] Màn hình Cấu Hình Thuế hoàn toàn là giao diện "giả" (Fake UI)
- **Mức độ:** P1 (Tính năng bị thiếu)
- **Môi trường:** Deployed (Cấu Hình Thuế)
- **Mô tả chi tiết:** Giao diện cho phép chọn "Ngành nghề" và gạt công tắc "Giảm thuế VAT 20%", tỷ lệ thuế có thay đổi theo trên UI. **TUY NHIÊN, màn hình này KHÔNG CÓ NÚT LƯU**, và khi thay đổi công tắc cũng **không kích hoạt bất kỳ API nào**. Dữ liệu chỉ nằm ở biến tạm (State) và mất sạch khi F5.
- **Kết quả kỳ vọng:** Bổ sung nút Lưu (Save) hoặc tự động call API `POST /api/tax/config` ngay khi thao tác thay đổi.
- **Trạng thái:** Mới ghi nhận.

#### 15. [BUG - SYSTEM/AUTH] Mất phiên đăng nhập (Session) khi ấn F5 / Reload trang
- **Mức độ:** P1 (Lỗi hệ thống cốt lõi)
- **Môi trường:** Deployed (Toàn bộ Web App)
- **Mô tả chi tiết:** Khi đang đăng nhập và dùng app bình thường, nếu thực hiện F5 (Reload trình duyệt), hệ thống **đẩy văng người dùng về màn hình Login** `/login`. Token đăng nhập dường như không được lưu bền vững vào `localStorage` hoặc thiếu logic khôi phục phiên.
- **Kết quả kỳ vọng:** Cần lưu JWT vào `localStorage` và tự động đọc lại token khi app khởi động (hydration) để giữ người dùng luôn đăng nhập.
- **Trạng thái:** Mới ghi nhận.

#### 16. [BUG - UI/UX] Nhật ký hoạt động (Activity Logs) hiển thị dữ liệu thô, vô nghĩa
- **Mức độ:** P3 (Lỗi hiển thị dữ liệu/Trải nghiệm)
- **Môi trường:** Deployed (Nhật Ký Hoạt Động)
- **Mô tả chi tiết:** Các thao tác có được backend lưu lại, nhưng UI hiển thị rất thiếu thông tin:
  1. Người thực hiện luôn hiển thị là "Hệ thống" thay vì tài khoản thực tế (`shop_0988776655`).
  2. Thời gian hiển thị chuỗi ISO thô (`2026-05-25T09:15:22.198Z`) chưa được format (DD/MM/YYYY).
  3. KHÔNG có chi tiết hành động. Chỉ hiện chữ `CREATE` hoặc `UPDATE` trống không, hoàn toàn không biết là tạo hay sửa đối tượng nào (vd: Thêm mới sản phẩm A, Cập nhật thông tin B).
- **Kết quả kỳ vọng:** Giao diện cần format lại thời gian, hiển thị đúng người thao tác và trích xuất dữ liệu payload để render câu mô tả hành động chi tiết.
- **Trạng thái:** Mới ghi nhận.

#### 17. [BUG - INVENTORY] Không thể bấm vào Đơn Mua Hàng để duyệt Nhập Kho
- **Mức độ:** P1 (Chặn đứng luồng Nhập hàng)
- **Môi trường:** Deployed (Đơn Mua Hàng - `/purchase-orders`)
- **Mô tả chi tiết:** Người dùng tạo Đơn mua hàng thành công (trạng thái "Chờ xử lý"). Tuy nhiên, thẻ (card) đơn hàng trong danh sách lại **không thể bấm vào được** (unclickable UI). Do đó, không có cách nào mở chi tiết đơn hàng để bấm duyệt "Nhập kho". Quy trình mua hàng bị tê liệt hoàn toàn.
- **Kết quả kỳ vọng:** Gắn sự kiện `onTap` vào Card đơn hàng để mở popup/trang chi tiết, tại đó hiển thị nút "Duyệt nhập kho".
- **Trạng thái:** Mới ghi nhận.

#### 18. [BUG - SALES] Chức năng Trả hàng (Return) bị lỗi Silent Failure
- **Mức độ:** P1 (Chặn luồng Trả hàng/Hoàn tiền)
- **Môi trường:** Deployed (Chi tiết Đơn hàng - `/sales/:id`)
- **Mô tả chi tiết:** Trong chi tiết đơn bán thành công, khi bấm "Yêu cầu trả hàng", nhập số tiền và Xác nhận thì hệ thống xử lý im lặng (Silent Failure). Nút bấm biến mất nhưng đơn hàng không chuyển trạng thái "Đã trả", không ghi nhận hoàn tiền vào sổ quỹ, tồn kho không phục hồi. 
- **Kết quả kỳ vọng:** Gọi API Trả hàng phải thành công, tạo bút toán hoàn tiền và cập nhật số dư tồn kho. Có thông báo Toast thành công.
- **Trạng thái:** Mới ghi nhận.

#### 19. [BUG - POS] Lỗi state Không thể gán Khách hàng vào Giỏ hàng POS
- **Mức độ:** P1 (Chặn đứng luồng Công nợ/Bán nợ)
- **Môi trường:** Deployed (Bán hàng POS - `/pos`)
- **Mô tả chi tiết:** Tại màn POS, bấm nút chọn khách hàng. Dù chọn khách hàng cũ hay tạo mới, popup tắt đi nhưng **khách hàng không hề được gán vào giỏ hàng** (giao diện không đổi). Hậu quả: Không thể chọn thanh toán "Ghi Nợ" (bị validate chặn vì chưa chọn khách). Tính năng Bán nợ và Quản lý công nợ bị liệt hoàn toàn.
- **Kết quả kỳ vọng:** Chọn khách xong phải update State `selectedCustomer` của giỏ hàng hiện tại và render tên khách lên UI góc phải.
- **Trạng thái:** Mới ghi nhận.

#### 20. [BUG - UX/UI] Thiếu hoàn toàn Modal Xác nhận (Confirmation Dialog) cho các hành động nhạy cảm
- **Mức độ:** P2 (Trải nghiệm người dùng rủi ro cao)
- **Môi trường:** Toàn hệ thống (Đăng xuất, Xóa, Hủy đơn)
- **Mô tả chi tiết:** Ứng dụng không có cơ chế hỏi lại (Confirmation Modal) khi người dùng thực hiện các thao tác mang tính phá hủy hoặc thoát phiên. Ví dụ: Bấm "Đăng Xuất Tài Khoản" là lập tức văng ra ngoài mà không có popup hỏi "Bạn có chắc chắn muốn đăng xuất?". Điều này dễ gây thao tác nhầm lẫn tai hại.
- **Kết quả kỳ vọng:** Bất cứ thao tác Xóa, Hủy, hoặc Đăng xuất nào cũng phải gọi ra một `AppConfirmModal` với 2 nút Hủy (Xám) và Xác nhận (Đỏ/Xanh).
- **Trạng thái:** Mới ghi nhận.

---

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
