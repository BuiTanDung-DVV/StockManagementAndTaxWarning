# Nâng cấp responsive và cơ chế fill giao diện

## 1. Mục tiêu

Chuẩn hóa thành phần giao diện theo chiều rộng thực tế của vùng chứa, không suy
đoán loại thiết bị. Các khối phải tự co giãn, tự đổi số cột và không làm vỡ màn
hình khi cửa sổ web được resize.

## 2. Phạm vi triển khai

| Thành phần | Hành vi mới |
|---|---|
| `AppFillGrid` | Tính 1–N cột từ `LayoutBuilder`; mỗi phần tử fill toàn bộ chiều rộng cột; cho phép cấu hình chiều rộng tối thiểu, số cột tối đa, khoảng cách và chiều cao |
| `AppResponsiveContent` | Fill màn nhỏ, dùng lề thích ứng và cho phép giới hạn chiều rộng trên màn rất lớn |
| Thanh tìm kiếm/bộ lọc | Tự chuyển thành hai hàng khi vùng chứa hẹp; action phụ dùng phần rộng còn lại |
| Tiêu đề bảng/section | Tiêu đề dài được wrap tối đa hai dòng; action không đẩy nội dung ra ngoài |
| Biểu đồ dòng tiền | Mật độ nhãn trục X giảm theo chiều rộng vùng biểu đồ |
| Công cụ tài chính | Tự chuyển từ một cột mobile sang tối đa ba cột desktop |

Không thay đổi API, database schema, route hoặc công thức nghiệp vụ.

## 3. Tiêu chí nghiệm thu

| ID | Tiêu chí | Kết quả |
|---|---|---|
| RWD-01 | Vùng 320 px hiển thị một cột, không overflow | Đạt bằng widget test |
| RWD-02 | Vùng 700 px tự chia ba cột và fill đủ chiều rộng | Đạt bằng widget test |
| RWD-03 | Nội dung desktop có thể giới hạn max-width và vẫn fill bên trong | Đạt bằng widget test |
| RWD-04 | Flutter analyze không có issue | Đạt |
| RWD-05 | Toàn bộ Flutter test không regression | Đạt 26/26 |
| RWD-06 | Flutter Web release build thành công | Đạt |

## 4. Giới hạn xác minh

- Build JavaScript hoạt động; cảnh báo Wasm của `flutter_tts` chưa chặn release.
- Font Cupertino chưa được bundle nhưng không ảnh hưởng các icon Material đang
  dùng ở những màn đã kiểm tra.
- Accessibility vẫn cần một vòng kiểm thử chuyên biệt; tài liệu này không kết
  luận ứng dụng đã đạt chuẩn accessibility.
