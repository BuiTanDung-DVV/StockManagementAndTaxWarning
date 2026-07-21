# HƯỚNG DẪN & QUY CHUẨN TUÂN THỦ THUẾ (TAX COMPLIANCE GUIDELINES)
## Hệ thống SmartStock FinTech - Quản lý Bán hàng & Hỗ trợ Cảnh báo Thuế

---

## 1. Kiểm soát phiên bản (Version Control)

| Phiên bản | Ngày | Người thực hiện | Nội dung thay đổi | Trạng thái |
| :--- | :--- | :--- | :--- | :--- |
| v1.0.0 | 2026-07-21 | Senior Business Analyst | Khởi tạo tài liệu Hướng dẫn Tuân thủ Thuế | Hoàn thành |

---

## 2. Bối Cảnh Pháp Lý (Legal Framework)

Hệ thống SmartStock FinTech được thiết kế và phát triển tuân thủ nghiêm ngặt hai văn bản pháp luật quan trọng nhất của Bộ Tài chính Việt Nam áp dụng cho hộ kinh doanh cá thể:
1. **Thông tư số 88/2021/TT-BTC:** Hướng dẫn chế độ kế toán cho hộ kinh doanh, hợp tác xã. Quy định rõ việc lập chứng từ kế toán, sổ sách kế toán kiểm soát doanh thu, chi phí đầu vào/đầu ra và tồn kho.
2. **Nghị định số 123/2020/NĐ-CP:** Quy định về hóa đơn, chứng từ hợp lệ, đặc biệt là hóa đơn điện tử khởi tạo từ máy tính tiền và các bảng kê thu mua hàng hóa dịch vụ không có hóa đơn.

---

## 3. Bảng Kê Thu Mua Hàng Hóa Không Hóa Đơn (Mẫu số 01/TNDN)

### 3.1. Mục đích nghiệp vụ
Theo quy định về thuế Thu nhập doanh nghiệp (và thuế Khoán đối với hộ kê khai), các hộ kinh doanh khi thu mua nông, lâm, thủy sản trực tiếp từ người dân tự đánh bắt, nuôi trồng, hoặc thu mua phế liệu, dịch vụ của cá nhân tự làm không có hóa đơn đỏ thì phải lập **Bảng kê thu mua hàng hóa, dịch vụ mua vào không có hóa đơn (Mẫu số 01/TNDN)**.
Bảng kê này là căn cứ pháp lý duy nhất để cơ quan thuế chấp thuận tính chi phí hợp lý được trừ cho hộ kinh doanh, tránh việc bị quy kết trốn thuế.

### 3.2. Cấu trúc và Quy tắc xác thực dữ liệu của Hệ thống
Để đảm bảo tính hợp lệ pháp lý, màn hình [purchase_no_invoice_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/finance/presentation/purchase_no_invoice_screen.dart) thực hiện các quy tắc xác thực sau:
- **Thông tin người bán:** Bắt buộc nhập đầy đủ:
  - *Họ và tên người bán* ($\ge 3$ ký tự, không chứa ký tự đặc biệt).
  - *Số CCCD/CMND* (đúng định dạng 9 hoặc 12 chữ số).
  - *Địa chỉ cư trú* (phải ghi nhận thông tin xã/huyện/tỉnh cụ thể để cơ quan thuế đối chiếu khi cần thiết).
- **Quy tắc chống mất mát dữ liệu (Auto-Complete):**
  - Khi người dùng đang nhập thông tin mặt hàng ở dòng cuối cùng (ví dụ nhập tên hàng: *"Xi măng Hà Tiên"*, số lượng: *10*, đơn giá: *80.000*) nhưng quên không bấm nút "Thêm vào danh sách" mà đã bấm nút "Lưu bảng kê", hệ thống sẽ tự động bắt sự kiện, nạp dòng đang nhập dở đó vào danh sách trước khi thực hiện gửi request API `POST /purchases/no-invoice` lên backend.
- **Quy tắc khống chế thanh toán tiền mặt:**
  - Để chi phí mua hàng theo Bảng kê 01/TNDN được chấp nhận là chi phí hợp lý được trừ khi tính thuế TNDN, các giao dịch có tổng giá trị từ **20 triệu VNĐ trở lên** bắt buộc phải thực hiện thanh toán qua ngân hàng (chuyển khoản). Hệ thống thực hiện chặn hoàn toàn và báo lỗi nếu người dùng chọn phương thức thanh toán tiền mặt (`CASH`) đối với các bảng kê có giá trị $\ge 20$ triệu VNĐ.

---

## 4. Quy Tắc Tính Thuế Suất Dành Cho Hộ Kinh Doanh Kê Khai

Theo biểu thuế ban hành kèm theo Thông tư 40/2021/TT-BTC, hộ kinh doanh kê khai phải chịu hai loại thuế là **Thuế Giá trị gia tăng (GTGT)** và **Thuế Thu nhập cá nhân (TNCN)** tính theo tỷ lệ phần trăm trên doanh thu bán ra. 

Hệ thống tích hợp biểu thuế suất tự động dựa trên cấu hình ngành nghề kinh doanh (`business_sector`) của cửa hàng:

| Nhóm Ngành Nghề | Tỷ lệ thuế GTGT | Tỷ lệ thuế TNCN | Tổng cộng thuế suất |
| :--- | :---: | :---: | :---: |
| **Phân phối, cung cấp hàng hóa (TRADE)** | 1.0% | 0.5% | **1.5%** |
| **Dịch vụ, xây dựng không bao thầu nguyên vật liệu (SERVICE)**| 5.0% | 2.0% | **7.0%** |
| **Sản xuất, vận tải, dịch vụ có gắn với hàng hóa, xây dựng có bao thầu (PRODUCTION)**| 3.0% | 1.5% | **4.5%** |
| **Hoạt động kinh doanh khác** | 2.0% | 1.0% | **3.0%** |

### 4.1. Cơ chế giảm thuế VAT theo chính sách Nhà nước
Khi chủ shop bật cấu hình giảm VAT (ví dụ theo Nghị quyết giảm 2% thuế suất GTGT cho một số nhóm ngành hàng):
- Hệ thống sẽ áp dụng giảm **20% mức tỷ lệ tính thuế GTGT** khi lập hóa đơn cho khách hàng.
- Công thức tính VAT giảm:
  $$\text{Tỷ lệ VAT mới} = \text{Tỷ lệ VAT mặc định} \times (1 - 0.2)$$
  *Ví dụ: Ngành thương mại có tỷ lệ GTGT là 1%. Khi áp dụng chính sách giảm, tỷ lệ tính GTGT mới sẽ là: $1\% \times 0.8 = 0.8\%$.*

### 4.2. Ngưỡng miễn thuế doanh thu dưới 100 triệu VNĐ/năm
- Theo quy định tại Điều 4 Thông tư 40/2021/TT-BTC, hộ kinh doanh có doanh thu từ hoạt động sản xuất, kinh doanh trong năm dương lịch từ **100 triệu đồng trở xuống** thuộc diện không phải nộp thuế GTGT và thuế TNCN.
- Hệ thống tự động tính toán tổng doanh thu tích lũy cả năm dương lịch hiện tại (`yearlyRevenue`). Nếu con số này $\le 100.000.000$ VNĐ, các khoản thuế GTGT và TNCN phải nộp thực tế sẽ được tự động điều chỉnh về **0**.
- Trạng thái miễn thuế (`taxExempt: true`) sẽ được hiển thị rõ ràng trên biểu khai thuế. Khi doanh thu đạt từ 90 triệu VNĐ trở lên, hệ thống sẽ hiển thị cảnh báo tiệm cận ngưỡng chịu thuế để người dùng chủ động lập kế hoạch kinh doanh.

---

## 5. Đặc Tả Cấu Trúc Xuất Tờ Khai Thuế XML HTKK

Khi chủ shop thực hiện xuất tờ khai thuế tại [tax_estimate_screen.dart](file:///d:/StockManagementAndTaxWarning/lib/features/tax/screens/tax_estimate_screen.dart), backend gọi API `GET /api/tax/export-xml` và tạo ra tệp tin XML có cấu trúc tương thích 100% với phần mềm **HTKK (Hỗ trợ Kê khai)**.

### 5.1. Mô tả lược đồ cấu trúc XML (XML Schema)
Tệp XML xuất ra bao gồm các phần chính sau:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<HSoThueDTu xmlns="http://kekhaithue.gdt.gov.vn/TKhaiThue" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <!-- Phần 1: Thông tin chung về tờ khai và người nộp thuế -->
  <Header>
    <MaHSo>01_CNKD</MaHSo>
    <TenHSo>Tờ khai thuế đối với cá nhân kinh doanh</TenHSo>
    <PhienBanXML>2.0.8</PhienBanXML>
    <NguoiNopThue>
      <MaSoThue>0314567890</MaSoThue>
      <TenNNT>Trần Minh Tuấn</TenNNT>
      <DiaChi>123 Đường Số 4, Quận 7, TP.HCM</DiaChi>
      <DienThoai>0901234567</DienThoai>
    </NguoiNopThue>
    <CoQuanThue>
      <MaCQT>70115</MaCQT>
      <TenCQT>Chi cục Thuế Quận 7</TenCQT>
    </CoQuanThue>
  </Header>

  <!-- Phần 2: Số liệu chi tiết các chỉ tiêu doanh thu và nghĩa vụ thuế -->
  <Body>
    <ToKhai>
      <!-- Kỳ tính thuế (Tháng hoặc Quý) -->
      <KyTinhThue>
        <KieuKy>Q</KieuKy>
        <KyTinh>2/2026</KyTinh>
      </KyTinhThue>
      
      <!-- Số liệu tính toán các nhóm ngành hàng -->
      <ChiTietThue>
        <!-- Nhóm Phân phối, cung cấp hàng hóa -->
        <NganhHang>
          <MaNganh>TRADE</MaNganh>
          <DoanhThuTinhThue>120000000.00</DoanhThuTinhThue>
          <TyLeGTGT>1.0</TyLeGTGT>
          <ThueGTGTPhatSinh>1200000.00</ThueGTGTPhatSinh>
          <TyLeTNCN>0.5</TyLeTNCN>
          <ThueTNCNPhatSinh>600000.00</ThueTNCNPhatSinh>
        </NganhHang>
      </ChiTietThue>
      
      <!-- Tổng hợp nghĩa vụ thuế cuối cùng -->
      <TongHopThue>
        <TongDoanhThu>120000000.00</TongDoanhThu>
        <TongThueGTGTPhatSinh>1200000.00</TongThueGTGTPhatSinh>
        <TongThueTNCNPhatSinh>600000.00</TongThueTNCNPhatSinh>
        <TongPhaiNop>1800000.00</TongPhaiNop>
      </TongHopThue>
    </ToKhai>
  </Body>
</HSoThueDTu>
```

### 5.2. Các kiểm tra hợp lệ khi nạp vào HTKK (HTKK Validation Rules)
Để đảm bảo tệp XML được nhập thành công vào HTKK, hệ thống đảm bảo:
- Thẻ `<MaSoThue>` phải đúng 10 số (hoặc 13 số đối với chi nhánh) và phải vượt qua thuật toán check-digit của Tổng cục Thuế.
- Định dạng dấu phẩy thập phân phải đúng quy chuẩn hệ thống (sử dụng dấu chấm `.` cho phần thập phân trong XML).
- Mã cơ quan thuế `<MaCQT>` phải là mã 5 chữ số hợp lệ tương ứng với bảng danh mục cơ quan thuế của Tổng cục Thuế Việt Nam.
