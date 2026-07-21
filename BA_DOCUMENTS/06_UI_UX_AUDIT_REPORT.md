# Báo Cáo Kiểm Toán UI/UX & Đánh Giá Chất Lượng Giao Diện Hệ Thống
**SmartStock FinTech - Hệ thống Quản lý Bán hàng & Cảnh báo Thuế**
*Ngày thực hiện:* 2026-07-21

---

## 1. Tóm Tắt Chung (Executive Summary)

Báo cáo này cung cấp đánh giá toàn diện về UI/UX, tính thẩm mỹ, khả năng hiển thị font chữ, khả năng phản hồi và logic tính toán nghiệp vụ của ứng dụng SmartStock FinTech (https://smartstock-tax.vercel.app/). 

Thông qua các phiên mô phỏng người dùng thực tế và kiểm tra trình duyệt thủ công, chúng tôi đã đánh giá ứng dụng dưới hai góc nhìn độc lập:
1.  **Nhà thiết kế chuyên nghiệp (Professional Designer):** Tập trung vào hệ thống màu sắc, lưới bố cục, nhịp điệu thị giác và typography.
2.  **Người dùng kinh doanh (Hộ kinh doanh cá thể - HKD/Thu ngân/Thủ kho):** Tập trung vào tốc độ giao dịch, tính dễ sử dụng và độ chính xác của báo cáo tài chính/thuế.

Mặc dù ứng dụng có giao diện hiện đại và khả năng thích ứng màn hình tốt, vẫn tồn tại một số lỗi logic và lỗi hiển thị cần được giải quyết trước khi đưa vào sản xuất.

---

## 2. Giao Diện Trực Quan Qua Các Phân Hệ (Screenshots)

Dưới đây là các ảnh chụp màn hình thực tế được ghi lại trong quá trình chạy kiểm thử Chrome:

````carousel
![Tổng quan Dashboard](file:///C:/Users/tandu/.gemini/antigravity/brain/de93b0d4-760e-4bfb-af58-af77ddd3aa01/dashboard.png)
<!-- slide -->
![Thiết bị POS Bán hàng](file:///C:/Users/tandu/.gemini/antigravity/brain/de93b0d4-760e-4bfb-af58-af77ddd3aa01/pos.png)
<!-- slide -->
![Quản lý Tồn kho](file:///C:/Users/tandu/.gemini/antigravity/brain/de93b0d4-760e-4bfb-af58-af77ddd3aa01/inventory.png)
<!-- slide -->
![Sổ cái Tài chính](file:///C:/Users/tandu/.gemini/antigravity/brain/de93b0d4-760e-4bfb-af58-af77ddd3aa01/finance.png)
<!-- slide -->
![Ước tính Thuế & Xuất XML](file:///C:/Users/tandu/.gemini/antigravity/brain/de93b0d4-760e-4bfb-af58-af77ddd3aa01/tax.png)
<!-- slide -->
![Cấu hình Hệ thống & Cửa hàng](file:///C:/Users/tandu/.gemini/antigravity/brain/de93b0d4-760e-4bfb-af58-af77ddd3aa01/settings.png)
````

---

## 3. Đánh Giá Chuyên Sâu

### 🎨 3.1. Góc Nhìn Của Nhà Thiết Kế Chuyên Nghiệp (Designer's Critique)
*   **Hài hòa màu sắc & Độ tương phản:** Hệ màu sắc được chọn lựa rất tinh tế (Xanh hoàng gia chủ đạo, xanh mòng két bổ trợ và sắc cam cảnh báo). Sự kết hợp này mang lại cảm giác tài chính công nghệ cao rất chuyên nghiệp. Độ tương phản chữ trên nền sáng đạt chuẩn, đảm bảo khả năng đọc tốt.
*   **Hệ thống lưới & Khoảng cách:** Bố cục dạng lưới bento được phân bổ hợp lý. Các thẻ thông tin trên Dashboard, Inventory và Settings có padding và border-radius (16px sau tối ưu) đồng bộ, hiện đại.
*   **Typography:** Phông chữ Outfit áp dụng cho số liệu và Roboto cho phần văn bản tạo độ tương phản tốt. Tuy nhiên, việc ký tự tiền tệ `₫` hiển thị thành dấu hỏi `?` trong widget chốt ca là một điểm trừ lớn về mặt hoàn thiện mỹ thuật.
*   **Nhịp điệu thị giác bị lỗi:** Trục X của biểu đồ dòng tiền hiển thị ngày bị lặp nhãn đôi (ví dụ: "01/07 01/07") gây rối mắt và làm giảm độ tin cậy của biểu đồ.

### 💼 3.2. Góc Nhìn Của Người Dùng Thực Tế (Business User's Critique)
*   **Tốc độ vận hành POS:** Giao diện POS phản hồi rất nhanh, thêm sản phẩm chỉ cần 1 click. Tuy nhiên, giỏ hàng POS chỉ hiển thị dưới dạng ngăn kéo trượt lên từ phía dưới. Trên màn hình máy tính lớn, nhân viên thu ngân thường thích giỏ hàng cố định bên phải màn hình hơn để họ dễ dàng quan sát danh sách mặt hàng và tổng tiền liên tục.
*   **Sai sót nghiêm trọng trong tính toán thuế:**
    *   *Lỗi:* Khi doanh nghiệp bị lỗ (Gross Profit < 0), giá trị thuế GTGT (10%) và TNDN/TNCN tạm tính hiển thị số âm (Ví dụ: Lợi nhuận gộp `-111.000 ₫` dẫn đến VAT `-11.100 ₫`).
    *   *Ảnh hưởng nghiệp vụ:* Về mặt pháp lý, thuế GTGT tính trên doanh thu bán ra chứ không tính trên lợi nhuận, và nghĩa vụ thuế không bao giờ có giá trị âm. Điều này gây hiểu lầm nghiêm trọng về nghĩa vụ thuế của HKD.
*   **Đồng bộ dữ liệu sổ quỹ:**
    *   *Lỗi:* Thẻ "Sổ quỹ tiền mặt" trên Dashboard hiển thị `0 ₫` trong khi số dư thực tế trong sổ cái tại màn hình `/finance` là `50.000 ₫`. Sự không đồng bộ này dễ khiến chủ cửa hàng hoang mang về dòng tiền thực tế.
*   **Thiếu chỉ dẫn trạng thái trống:**
    *   *Lỗi:* Widget lịch sử chốt ca hoàn toàn biến mất nếu chưa có dữ liệu. Người dùng mới sẽ không biết hệ thống có tính năng này để sử dụng.

---

## 4. Danh Sách Phát Hiện Lỗi & Đề Xuất Khắc Phục

| Phân hệ / Tính năng | Mô tả chi tiết lỗi phát hiện | Mức độ | Đề xuất hướng khắc phục |
| :--- | :--- | :---: | :--- |
| **Main Shell** | **Không có Semantics cho Sidebar:** Các nút điều hướng chính bên trái (Trang chủ, Bán hàng, Kho, Tài chính, Cài đặt) bị thiếu Semantic nodes của Flutter, khiến người khiếm thị sử dụng trình đọc màn hình không thể sử dụng. | **Cao** (Accessibility) | Bọc các Inkwell điều hướng trong thẻ `Semantics` với nhãn mô tả cụ thể. |
| **Dashboard** | **Giá trị thuế tạm tính bị âm:** VAT và TNDN/TNCN tạm tính hiển thị số âm khi lợi nhuận gộp âm. | **Trung bình** (Logic nghiệp vụ) | Áp dụng biên dưới tối thiểu là `0 ₫` cho tiền thuế và sửa lại công thức VAT theo doanh thu. |
| **Dashboard** | **Sổ quỹ tiền mặt không đồng bộ:** Dashboard hiển thị `0 ₫` lệch so với sổ cái tài chính (`50.000 ₫`). | **Trung bình** (Tính năng) | Đồng bộ hóa provider dòng tiền két giữa Dashboard và màn hình Tài chính. |
| **Dashboard** | **Ký hiệu tiền tệ hiển thị thành `?`:** Biểu tượng `₫` bị lỗi font chữ thành `?` ở widget lịch sử chốt ca. | **Thấp** (Hiển thị) | Khai báo font family `GoogleFonts.outfit` cho dòng chữ hiển thị giá trị. |
| **Dashboard** | **Ẩn hoàn toàn widget chốt ca:** Widget chốt ca tự ẩn đi bằng `SizedBox.shrink()` khi chưa có ca chốt nào. | **Thấp** (UX Design) | Thay thế bằng một thẻ trống thân thiện ghi *"Chưa có ca chốt nào được thực hiện"*. |
| **Inventory** | **Sản phẩm không tên đọng vốn:** Mục sản phẩm chậm luân chuyển hiện "Sản phẩm không tên" with số lượng tồn bằng 0. | **Trung bình** (Logic dữ liệu) | Loại bỏ các sản phẩm có số lượng tồn bằng 0 khỏi danh sách cảnh báo đọng vốn. |
| **Finance** | **Lặp nhãn trục X biểu đồ:** Ngày hiển thị trên trục hoành bị lặp đôi (e.g. "01/07 01/07"). | **Thấp** (Hiển thị) | Định dạng lại hàm định giá trị trục hoành biểu đồ để lọc trùng. |
| **Products (Tag Mgt)**| **Vi phạm BR-SYS-01:** Hiển thị lỗi tải nhãn chung chung: `Đã có lỗi xảy ra`. | **Thấp** (Nghiệp vụ) | Thay thế bằng mô tả lỗi chi tiết kèm mã lỗi cụ thể (ví dụ: `Mã lỗi: TAG-LOAD-FAIL`). |

---

## 5. Lỗ Hổng Bảo Mật & Xác Thực Cần Lưu Ý

> [!WARNING]
> **Bỏ qua xác thực mã OTP khi Đăng ký tài khoản**
> *   **Chi tiết lỗ hổng:** Hệ thống API ở backend chỉ yêu cầu xác thực OTP khi tên đăng ký (username) được phát hiện ở định dạng email hoặc số điện thoại. 
> *   **Ảnh hưởng:** Nếu nhập một chuỗi ký tự chữ thường đơn giản (Ví dụ: `testuser`), hệ thống sẽ bỏ qua hoàn toàn bước kiểm tra OTP và đăng ký tài khoản thành công ngay lập tức mà không cần xác nhận. 
> *   **Tệp tin liên quan:** `backend/src/services/auth.service.ts` (kiểm tra `isPhone || isEmail`).

---

## 6. Kết Luận & Kế Hoạch Hành Động

Để hệ thống SmartStock FinTech đạt trạng thái sẵn sàng vận hành thực tế:
1.  **Sửa ngay logic tính thuế âm** để bảo đảm tính tuân thủ pháp lý.
2.  **Khắc phục lỗi font chữ hiển thị tiền tệ** (`?` thay cho `₫`) và lặp nhãn trên biểu đồ tài chính.
3.  **Khôi phục Semantics** cho thanh Sidebar điều hướng để đảm bảo khả năng tiếp cận chuẩn.
4.  **Triển khai đồng bộ quy tắc `BR-SYS-01`** trên toàn bộ các màn hình hiển thị thông báo lỗi.
