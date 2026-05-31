# Kế Hoạch & Nhật Ký Kiểm Thử (QA Test Plan)

Đây là tài liệu ghi chép lại các kịch bản kiểm thử thủ công và trạng thái các lỗi đã được xử lý trong hệ thống StockManagementAndTaxWarning, tuân thủ nguyên tắc "Surgical & Goal-oriented" (Karpathy Guidelines).

## 1. Trạng thái Sửa Lỗi (Bug Fixes Status)

| Mã Lỗi | Mô Tả | Trạng Thái | File Can Thiệp |
|--------|--------|------------|----------------|
| **Bug 22** | Treo ứng dụng (Crash 400) tại màn hình Dashboard khi `userShops` rỗng. | ✅ Hoàn thành | `dashboard_screen.dart` |
| **Bug 23** | Đóng băng DOM (Semantics Tree) khi chuyển hướng trang trên Flutter Web. | ✅ Hoàn thành | `index.html` (Thêm `--web-renderer canvaskit`) |
| **Bug 11** | Chức năng Xuất file XML HTKK không tải được file trên trình duyệt. | ✅ Hoàn thành | `tax_estimate_screen.dart` (Bỏ `externalApplication`) |
| **Bug 17** | Thẻ (Card) Thông tin Đơn đặt hàng (PO) không thể bấm vào để xem chi tiết. | ✅ Hoàn thành | `purchase_order_list_screen.dart` |
| **Bug 19** | Giỏ hàng POS không nhận ID khách hàng mới tạo. | ✅ Hoàn thành | `pos_screen.dart` (Callback `onCustomerSelected`) |
| **Bug 6** | API tạo sản phẩm gây lỗi 500 khi trùng `barcode` thay vì cảnh báo hợp lệ. | ✅ Hoàn thành | `product.service.ts` |
| **Bug 2** | Quên mật khẩu không validate Regex số điện thoại / email. OTP không bị giới hạn. | ✅ Hoàn thành | `forgot_password_screen.dart` |
| **Bug 9** | Lỗi mời nhân viên hiển thị thông báo Toast khó hiểu thay vì inline error. | ✅ Hoàn thành | `staff_management_screen.dart` |
| **Bug 13** | Màn hình Mua hàng không hóa đơn: Không tự thêm dòng đang nhập dở khi bấm Lưu. | ✅ Hoàn thành | `purchase_no_invoice_screen.dart` |
| **Bug 20** | Thiếu xác nhận (Confirm Modal) đối với các hành động nhạy cảm (Xóa/Hủy). | ✅ Hoàn thành | `app_confirm_modal.dart`, `qr_payment_screen.dart`, `purchase_order_detail_screen.dart`, `stock_take_form_screen.dart` |
| **Bug 4** | Trường nhập địa chỉ (Shop, Customer, Supplier) cần được cải thiện thành Dropdown Tỉnh/Thành. | ✅ Hoàn thành | `address_input_field.dart`, `shop_profile_screen.dart`, `customer_form_screen.dart`, `supplier_form_screen.dart` |
| **Bug 5** | Thiếu trường Mô tả sản phẩm (Description) rõ ràng trên trang chi tiết sản phẩm. | ✅ Hoàn thành | `product_detail_screen.dart` (Tạo thẻ Card riêng biệt) |
| **Bug 7** | Giao diện Toast messages (BotToast) hiển thị thô sơ, cần chuẩn hóa UI. | ✅ Hoàn thành | `toast_service.dart` (Dùng Custom Notification với Icon) |
| **Bug 14** | Lưu Cấu hình Thuế chưa có nút lưu xuống Database. | ✅ Hoàn thành | `tax_config_screen.dart` |
| **Bug 16** | Format hiển thị thời gian và mô tả thao tác trên màn Nhật ký hoạt động còn thô. | ✅ Hoàn thành | `activity_log_screen.dart` |

---

## 2. Kịch Bản Kiểm Thử Thủ Công Toàn Hệ Thống

Dựa trên cấu trúc Code Graph của dự án, dưới đây là các luồng nghiệp vụ cần kiểm thử thủ công trên trình duyệt (http://127.0.0.1:5000):

### 2.1. Phân Hệ Xác Thực & Phân Quyền (Auth & Authorization)
- [ ] **TC-AUTH-01:** Đăng nhập thành công với tài khoản Owner và Staff. Xác nhận Token JWT được gắn vào Header.
- [ ] **TC-AUTH-02:** Quên mật khẩu: Nhập sai định dạng email/sđt phải báo lỗi. Nhập đúng phải chặn input sau khi gửi OTP, độ dài OTP đúng 6 ký tự.
- [ ] **TC-AUTH-03:** Phân quyền Nhân viên: Đăng nhập bằng tài khoản thu ngân (Cashier), xác nhận KHÔNG THỂ truy cập menu Quản lý nhân sự, Cấu hình thuế, và Báo cáo tài chính.
- [ ] **TC-AUTH-04:** Chuyển đổi Cửa hàng (Switch Shop): Đảm bảo dữ liệu (Sản phẩm, Đơn hàng) thay đổi tương ứng theo `shopId`. Owner của Shop 1 không thể xem dữ liệu của Shop 2 nếu không có quyền.

### 2.2. Phân Hệ Sản Phẩm & Kho (Products & Inventory)
- [ ] **TC-PROD-01:** Thêm mới sản phẩm với giá bán = 0 (Kỳ vọng: Báo lỗi).
- [ ] **TC-PROD-02:** Thêm mới sản phẩm với `barcode` đã tồn tại (Kỳ vọng: Báo lỗi "Mã vạch này đã tồn tại" từ Backend - Bug 6).
- [ ] **TC-PROD-03:** Xem chi tiết sản phẩm (Bug 5): Kiểm tra thẻ "Mô tả sản phẩm" hiển thị chính xác.
- [ ] **TC-INV-01:** Duyệt đơn đặt hàng (PO): Xác nhận modal cảnh báo xuất hiện (Bug 20). Duyệt thành công thì tồn kho sản phẩm phải tăng lên tương ứng.
- [ ] **TC-INV-02:** Tạo phiếu kiểm kê kho: Xác nhận modal cảnh báo xuất hiện khi lưu. Tồn kho thực tế bị ghi đè thành công.

### 2.3. Phân Hệ Bán Hàng (Sales & POS)
- [ ] **TC-POS-01:** Thêm sản phẩm vào giỏ hàng POS, quét mã vạch thành công.
- [ ] **TC-POS-02:** Tạo nhanh khách hàng mới ngay trong POS. Xác nhận ID khách hàng tự động được nạp vào đơn hàng hiện tại (Bug 19).
- [ ] **TC-POS-03:** Thanh toán bằng mã QR: Khi bấm "Hủy đơn", hệ thống phải hiện Modal đỏ xác nhận (Bug 20).
- [ ] **TC-POS-04:** Hoàn trả đơn hàng: Chọn đơn hàng cũ, nhập số lượng trả lại, xác nhận số tiền hoàn trả và tồn kho được cộng lại.

### 2.4. Phân Hệ Tài Chính & Thuế (Finance & Tax)
- [ ] **TC-FIN-01:** Mua hàng không hóa đơn: Nhập dở một dòng dữ liệu, chưa bấm "Thêm", bấm luôn "Lưu bảng kê" (Kỳ vọng: Dòng dữ liệu tự động được đẩy vào mảng và lưu thành công - Bug 13).
- [ ] **TC-FIN-02:** Lập sổ chi phí / sổ lương: Các tác vụ phát sinh dòng tiền phải hiển thị trên màn hình Dự phóng Dòng tiền (Cashflow).
- [ ] **TC-TAX-01:** Lưu cấu hình Thuế (Bug 14): Đổi tỷ lệ giảm VAT và lưu lại, refresh trang để xác nhận dữ liệu đã được persist.
- [ ] **TC-TAX-02:** Xuất tờ khai HTKK (Bug 11): Bấm nút xuất XML, xác nhận trình duyệt tự động tải xuống file `to_khai_thue.xml` hợp lệ.

### 2.5. Phân Hệ Cài Đặt (Settings)
- [ ] **TC-SET-01:** Cập nhật thông tin cửa hàng: Trường "Địa chỉ" phải là tổ hợp Dropdown Chọn Tỉnh/Thành và Textfield nhập chi tiết (Bug 4).
- [ ] **TC-SET-02:** Thêm/Sửa Khách hàng, Nhà cung cấp: Trường "Địa chỉ" hiển thị đúng Dropdown Tỉnh/Thành như cài đặt cửa hàng.
- [ ] **TC-SET-03:** Nhật ký hoạt động: Xác nhận các tác vụ (Create, Update, Delete) hiển thị icon và màu sắc phù hợp, thời gian ghi rõ "Hôm nay", "Hôm qua" (Bug 16).
- [ ] **TC-SET-04:** Giao diện thông báo Toast: Các cảnh báo lỗi, thành công phải dùng UI Card mới có icon thay vì text đen mặc định (Bug 7).

---

## 3. Tổng kết
Tất cả 15 bugs ưu tiên đã được xử lý mã nguồn thành công. Giao diện (UI/UX) và luồng xử lý (Logic) đã được bảo vệ chặt chẽ hơn qua các chốt chặn (Modal Confirm, Validation). 
Sẵn sàng cho người dùng thực hiện Manual QA theo kịch bản trên.
