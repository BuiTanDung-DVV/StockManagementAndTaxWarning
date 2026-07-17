# Kế Hoạch Kiểm Thử Toàn Diện (Comprehensive QA Test Plan)

Tài liệu này cung cấp kịch bản kiểm thử (Test Cases) chi tiết bao phủ toàn bộ các chức năng, giao diện, API liên kết và trường hợp biên của hệ sinh thái quản lý bán hàng và hỗ trợ cảnh báo thuế thông minh SmartStock FinTech.

---

## 1. Phân Hệ Xác Thực & Bảo Mật (Authentication & Security)

### 1.1. Đăng Ký Tài Khoản & OTP (TC-AUTH-REG)
| Mã Kịch Bản | Thao Tác Kiểm Thử | Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **TC-AUTH-REG-01** | Kiểm tra giao diện đăng ký | Truy cập màn hình đăng ký | Hiển thị các trường: Họ và tên, Email (Gmail), Mật khẩu, Xác nhận mật khẩu, và 2 nút Đăng ký qua Google, Facebook. Không còn trường SĐT. | |
| **TC-AUTH-REG-02** | Đo độ mạnh mật khẩu (Real-time) | Nhập mật khẩu yếu (vd: `123`) | 5 thanh màu hiển thị mức đỏ (Yếu). Checklist các tiêu chí (Độ dài, Chữ hoa, Chữ thường, Số, Ký tự đặc biệt) hiển thị chưa đạt. Nút Đăng ký bị vô hiệu hóa hoặc báo lỗi khi ấn. | |
| **TC-AUTH-REG-03** | Đạt độ mạnh mật khẩu chuẩn | Nhập mật khẩu: `Abc@12345` | 5 thanh màu chuyển sang Xanh lá (Cực mạnh). Checklist đổi màu xanh lá và hiển thị dấu `✓`. | |
| **TC-AUTH-REG-04** | Kiểm tra khớp mật khẩu (Real-time) | Nhập mật khẩu xác nhận khác mật khẩu chính | Hiển thị badge đỏ: `✗ Mật khẩu xác nhận chưa khớp` | |
| **TC-AUTH-REG-05** | Khớp mật khẩu hoàn toàn | Nhập mật khẩu xác nhận trùng với mật khẩu chính | Hiển thị badge xanh: `✓ Mật khẩu xác nhận trùng khớp` | |
| **TC-AUTH-REG-06** | Nhận mã OTP riêng biệt | Nhập thông tin hợp lệ -> Bấm đăng ký | Ứng dụng chuyển hướng sang màn hình nhập mã OTP riêng biệt, hiển thị đúng email nhận mã, có bộ đếm ngược 60 giây và nút Gửi lại mã. | |

### 1.2. Đăng Nhập & Quản Lý Phiên (TC-AUTH-LOG)
| Mã Kịch Bản | Thao Tác Kiểm Thử | Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **TC-AUTH-LOG-01** | Đăng nhập sai thông tin | Email/Mật khẩu không tồn tại hoặc sai | Hiển thị thông báo Toast cảnh báo lỗi đăng nhập, không cho phép truy cập. | |
| **TC-AUTH-LOG-02** | Đăng nhập đúng thông tin | Email/Mật khẩu chính xác | Đăng nhập thành công, chuyển hướng vào Dashboard, JWT Token được lưu an toàn. | |
| **TC-AUTH-LOG-03** | Đăng xuất tài khoản | Bấm Đăng xuất trong Cài đặt | Xóa sạch JWT Token, đưa người dùng về màn hình Đăng nhập, nhấn Back trên trình duyệt không thể quay lại Dashboard. | |

### 1.3. Đổi Mật Khẩu (TC-AUTH-PWD)
| Mã Kịch Bản | Thao Tác Kiểm Thử | Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **TC-AUTH-PWD-01** | Điều hướng trang đổi mật khẩu | Nhấp vào mục Đổi mật khẩu trong Cài đặt | Chuyển hướng thành công sang màn hình Đổi mật khẩu chuyên biệt (`/change-password`). | |
| **TC-AUTH-PWD-02** | Kiểm tra độ mạnh & khớp mật khẩu | Nhập mật khẩu hiện tại, nhập mật khẩu mới và xác nhận | Áp dụng đầy đủ thanh đo 5 mức màu, checklist tiêu chí, và badge cảnh báo trùng khớp thời gian thực. | |
| **TC-AUTH-PWD-03** | Thực hiện đổi mật khẩu | Nhập thông tin đúng -> Bấm xác nhận | Gọi API đổi mật khẩu thành công, hiển thị Toast thông báo thành công và tự động quay về trang Cài đặt. | |

---

## 2. Quản Lý Cửa Hàng & Nhân Sự (Shop & Staff Management)

### 2.1. Luồng Chưa Có Cửa Hàng (TC-SHOP-NONE)
| Mã Kịch Bản | Thao Tác Kiểm Thử | Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **TC-SHOP-NONE-01** | Đăng nhập tài khoản mới chưa có shop | Tài khoản nhân viên mới | Giao diện hiển thị trạng thái "Chưa có cửa hàng", bị ẩn toàn bộ menu chức năng nghiệp vụ bán hàng/kho. | |
| **TC-SHOP-NONE-02** | Tìm kiếm & Xin gia nhập cửa hàng | Nhập mã cửa hàng hoặc tên cửa hàng | Hiển thị danh sách cửa hàng tìm thấy. Cho phép bấm "Xin gia nhập" và cập nhật trạng thái yêu cầu thành "Chờ phê duyệt". | |

### 2.2. Quản Lý Danh Sách Nhân Viên & Phê Duyệt (TC-SHOP-STAFF)
| Mã Kịch Bản | Thao Tác Kiểm Thử | Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **TC-SHOP-STAFF-01** | Duyệt yêu cầu xin gia nhập | Đăng nhập tài khoản Owner -> Cài đặt -> Quản lý nhân viên | Hiển thị yêu cầu xin gia nhập trong tab "Chờ duyệt". Cho phép Đồng ý hoặc Từ chối. | |
| **TC-SHOP-STAFF-02** | Phân quyền nhân viên | Chọn nhân viên -> Thay đổi quyền | Gán các vai trò (Thu ngân, Thủ kho, Quản lý). Kiểm tra tài khoản nhân viên tương ứng chỉ truy cập được đúng chức năng được phân quyền. | |

### 2.3. Chuyển Đổi Shop & Chế Độ Tất Cả Shop (TC-SHOP-SWITCH)
| Mã Kịch Bản | Thao Tác Kiểm Thử | Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **TC-SHOP-SWITCH-01** | Chuyển đổi giữa các shop | Chọn shop khác trên thanh chuyển đổi | Toàn bộ dữ liệu doanh thu, sản phẩm, kho của shop cũ bị xóa và tự động tải lại dữ liệu của shop mới. | |
| **TC-SHOP-SWITCH-02** | Chọn "Tất cả cửa hàng (Tổng quát)" | Chọn mục Tổng quát | Hệ thống hiển thị tổng quan số liệu tài chính, kho hàng cộng dồn của toàn bộ các cửa hàng do Owner làm chủ mà không bị crash. | |

---

## 3. Phân Hệ Sản Phẩm & Nhãn (Products & Tags)

### 3.1. Thêm/Sửa/Xóa Sản Phẩm (TC-PROD-CORE)
| Mã Kịch Bản | Thao Tác Kiểm Thử | Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **TC-PROD-CORE-01** | Kiểm tra trùng Barcode (Mã vạch) | Tạo sản phẩm mới có mã vạch đã tồn tại | Hệ thống chặn và báo lỗi rõ ràng "Mã vạch này đã tồn tại" thay vì lỗi hệ thống 500. | |
| **TC-PROD-CORE-02** | Ràng buộc giá trị sản phẩm | Giá nhập hoặc giá bán âm | Báo lỗi không hợp lệ tại chỗ (inline error). Giá trị lưu trữ tối thiểu phải từ 0 trở lên. | |
| **TC-PROD-CORE-03** | Thẻ thông tin mô tả chi tiết | Truy cập trang chi tiết sản phẩm | Hiển thị thẻ mô tả sản phẩm (Description) trực quan, định dạng rõ ràng, dễ đọc. | |

### 3.2. Quản Lý Nhãn Hàng Hóa (TC-PROD-TAGS)
| Mã Kịch Bản | Thao Tác Kiểm Thử | Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **TC-PROD-TAGS-01** | Thêm mới nhãn sản phẩm | Quản lý nhãn -> Thêm nhãn (Tên nhãn, Màu sắc) | Nhãn mới hiển thị trong danh sách quản lý. | |
| **TC-PROD-TAGS-02** | Gán nhãn cho sản phẩm | Tạo/Sửa sản phẩm -> Chọn nhãn | Sản phẩm được lưu với nhãn tương ứng. Nhãn hiển thị trực quan dưới dạng badge màu tại danh sách sản phẩm. | |
| **TC-PROD-TAGS-03** | Lọc sản phẩm theo nhãn | Chọn nhãn lọc trên danh mục | Bộ lọc chỉ hiển thị các sản phẩm có gán nhãn được chọn. | |

---

## 4. Giao Dịch Bán Hàng & POS (Sales & POS)

### 4.1. Giỏ Hàng & Thanh Toán POS (TC-POS-FLOW)
| Mã Kịch Bản | Thao Tác Kiểm Thử | Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **TC-POS-FLOW-01** | Quét/Thêm nhanh sản phẩm | Bấm chọn hoặc quét barcode sản phẩm | Sản phẩm cộng dồn số lượng chính xác vào giỏ hàng, cập nhật tổng số tiền thanh toán tức thì. | |
| **TC-POS-FLOW-02** | Tạo nhanh Khách hàng | Bấm nút thêm khách hàng tại màn hình POS | Khách hàng mới được tạo thành công và ID của khách hàng tự động được gắn luôn vào đơn hàng đang giao dịch. | |
| **TC-POS-FLOW-03** | Hủy đơn hàng nhạy cảm | Nhấp nút "Hủy đơn" hoặc "Xóa giỏ" | Hệ thống bật Modal xác nhận cảnh báo màu đỏ trước khi thực hiện xóa dữ liệu giỏ hàng. | |
| **TC-POS-FLOW-04** | Thanh toán QR Code tĩnh/động | Nhấp thanh toán QR | Giao diện hiển thị đúng QR Code kèm theo đúng số tiền cần thanh toán. | |

---

## 5. Quản Lý Kho & Kiểm Kê (Inventory & Stocktake)

### 5.1. Nhập Kho & Đặt Hàng Nhà Cung Cấp (TC-INV-PO)
| Mã Kịch Bản | Thao Tác Kiểm Thử | Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **TC-INV-PO-01** | Click xem chi tiết Đơn đặt hàng | Bấm vào thẻ PO tại danh sách PO | Chuyển hướng xem chi tiết thông tin PO thành công (Không bị lỗi đơ thẻ PO). | |
| **TC-INV-PO-02** | Cảnh báo tồn kho dưới hạn mức | Tồn kho thực tế < hạn mức tối thiểu | Danh sách cảnh báo trên Dashboard hiển thị đỏ và cảnh báo đúng sản phẩm cần nhập thêm. | |

### 5.2. Kiểm Kê & Cân Bằng Kho (TC-INV-AUDIT)
| Mã Kịch Bản | Thao Tác Kiểm Thử | Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **TC-INV-AUDIT-01** | Tạo phiếu kiểm kho | Nhập số lượng thực tế kiểm kê chênh lệch | Hiển thị phiếu chênh lệch thừa/thiếu, yêu cầu xác nhận lưu để cân bằng số liệu hệ thống. | |

---

## 6. Tài Chỉ & Báo Cáo Thuế (Finance & Tax)

### 6.1. Bảng Kê Bán Hàng & Mua Hàng Không Hóa Đơn (TC-TAX-LEDGER)
| Mã Kịch Bản | Thao Tác Kiểm Thử | Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **TC-TAX-LEDGER-01** | Tự động hoàn thiện dòng đang nhập dở | Nhập thông tin sản phẩm tại bảng kê mua hàng không hóa đơn, không bấm "Thêm", bấm luôn "Lưu" | Hệ thống tự động lấy dòng thông tin đang nhập dở nạp vào danh sách và tiến hành lưu dữ liệu thành công. | |

### 6.2. Sổ Chi Phí & Lương Nhân Viên (TC-TAX-CASHFLOW)
| Mã Kịch Bản | Thao Tác Kiểm Thử | Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **TC-TAX-CASHFLOW-01**| Ghi nhận dòng tiền phát sinh | Lập phiếu chi lương hoặc chi phí vận hành | Dữ liệu lập tức cập nhật vào Báo cáo dự phòng dòng tiền (Cashflow Forecast). | |

### 6.3. Xuất Tờ Khai Thuế XML HTKK (TC-TAX-XML)
| Mã Kịch Bản | Thao Tác Kiểm Thử | Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **TC-TAX-XML-01** | Thay đổi cấu hình Thuế | Đổi cấu hình giảm VAT -> Lưu cấu hình | Dữ liệu cấu hình được ghi xuống Database, reload trang dữ liệu mới vẫn hiển thị. | |
| **TC-TAX-XML-02** | Xuất XML đúng định dạng HTKK | Bấm xuất tờ khai thuế XML | Trình duyệt lập tức tải xuống tệp tin `.xml` có cấu trúc thẻ XML khớp hoàn toàn với phần mềm HTKK của Tổng cục Thuế. | |

---

## 7. Giao Diện Hệ Thống & Kiểm Tra Lỗi Phông Chữ (System UI & Fonts)

### 7.1. Hiển Thị Tiếng Việt UTF-8 (TC-SYS-FONT)
| Mã Kịch Bản | Thao Tác Kiểm Thử | Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **TC-SYS-FONT-01** | Phông chữ Dashboard | Truy cập Dashboard | Các tiêu đề tiếng Việt như "Tổng quan hôm nay", "Đơn hàng", "Cửa hàng" hiển thị chuẩn xác, không bị biến dạng ký tự. | |
| **TC-SYS-FONT-02** | Phông chữ báo cáo biểu đồ | Xem các biểu đồ hình tròn/cột | Chữ hiển thị chú thích biểu đồ hiển thị chuẩn tiếng Việt UTF-8 không lỗi font. | |

### 7.2. Trải Nghiệm Giao Diện Chung (TC-SYS-UX)
| Mã Kịch Bản | Thao Tác Kiểm Thử | Dữ Liệu Đầu Vào | Kết Quả Kỳ Vọng | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **TC-SYS-UX-01** | Dropdown Tỉnh/Thành | Nhập địa chỉ khách hàng/shop | Hiển thị dropdown Tỉnh/Thành thay vì bắt gõ tay toàn bộ địa chỉ. | |
| **TC-SYS-UX-02** | Card Toast Notification | Phát sinh thông báo thành công/thất bại | Hiển thị Toast dạng hộp thoại (Card) có màu sắc tương ứng (Xanh: thành công, Đỏ: lỗi) kèm icon đặc trưng. | |
| **TC-SYS-UX-03** | Nhật ký hoạt động | Truy cập Nhật ký hoạt động | Thời gian ghi nhận thân thiện: "Hôm nay - 10:15", "Hôm qua - 08:30" kèm màu sắc phân biệt loại tác vụ. | |
