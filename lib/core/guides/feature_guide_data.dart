// Dữ liệu hướng dẫn tính năng — dành cho hộ kinh doanh nhỏ lẻ
//
// Mỗi screen có 1 [FeatureGuide] gồm:
// - title: Tên tính năng
// - items: Danh sách [{intro, example}]
//   + intro: Giới thiệu chức năng (gộp lý do + cách dùng)
//   + example: Ví dụ nhỏ minh họa

class FeatureGuideItem {
  final String intro;
  final String example;
  const FeatureGuideItem({required this.intro, required this.example});
}

class FeatureGuide {
  final String title;
  final String icon; // emoji
  final List<FeatureGuideItem> items;
  const FeatureGuide({required this.title, required this.icon, required this.items});
}

const Map<String, FeatureGuide> featureGuides = {

  // ── 1. Dashboard ──
  'dashboard': FeatureGuide(
    title: 'Trang chủ',
    icon: '📊',
    items: [
      FeatureGuideItem(
        intro: 'Hiển thị tổng quan kinh doanh: doanh thu, đơn hàng, trung bình/đơn. Mở app là thấy ngay tình hình hôm nay mà không cần giở sổ.',
        example: 'Sáng mở app thấy hôm qua bán 2.5 triệu từ 15 đơn → biết ngay buôn bán tốt.',
      ),
      FeatureGuideItem(
        intro: 'Cảnh báo tự động khi sản phẩm sắp hết hàng. Nhấn vào SP cảnh báo để nhập thêm ngay.',
        example: 'App báo "Sữa TH chỉ còn 3 hộp" → gọi nhà cung cấp nhập thêm.',
      ),
      FeatureGuideItem(
        intro: 'Thao tác nhanh: nhấn 1 nút vào ngay Bán hàng, Nhập hàng, Kiểm kho, Nhân viên.',
        example: 'Lúc đông khách, nhấn nhanh "Bán hàng" là vào POS ngay.',
      ),
      FeatureGuideItem(
        intro: 'Tự nhắc khi đến hạn kê khai hoặc nộp thuế, tránh bị phạt vì trễ hạn.',
        example: 'Gần ngày 20/01 → app nhắc "Sắp đến hạn nộp tờ khai VAT quý 4".',
      ),
    ],
  ),

  // ── 2. Bán hàng POS ──
  'pos': FeatureGuide(
    title: 'Bán hàng (POS)',
    icon: '🛒',
    items: [
      FeatureGuideItem(
        intro: 'Màn hình bán hàng chính: chọn sản phẩm → nhập số lượng → chọn thanh toán → xác nhận. Hỗ trợ quét barcode, tự động tính tổng.',
        example: 'Khách mua 3 món, chọn từng SP, app tính tổng 450k, nhận tiền mặt, xong.',
      ),
    ],
  ),

  // ── 3. Danh sách đơn hàng ──
  'sales_list': FeatureGuide(
    title: 'Danh sách đơn hàng',
    icon: '📋',
    items: [
      FeatureGuideItem(
        intro: 'Toàn bộ lịch sử bán hàng, lọc theo trạng thái (Chờ/Hoàn thành/Hủy), tìm kiếm nhanh.',
        example: 'Khách hỏi "Đơn hôm qua bao nhiêu?" → tìm ngay trong danh sách.',
      ),
    ],
  ),

  // ── 4. Chi tiết đơn hàng ──
  'order_detail': FeatureGuide(
    title: 'Chi tiết đơn hàng',
    icon: '🧾',
    items: [
      FeatureGuideItem(
        intro: 'Xem chính xác đơn hàng gồm sản phẩm gì, số lượng, giá, ai mua, thanh toán ra sao.',
        example: 'Khách nói thiếu 1 món → mở chi tiết đơn #SO123 đối chiếu.',
      ),
    ],
  ),

  // ── 5. Thanh toán QR ──
  'qr_payment': FeatureGuide(
    title: 'Thanh toán QR',
    icon: '📱',
    items: [
      FeatureGuideItem(
        intro: 'Tạo mã QR chuyển khoản cho khách quét. Giảm rủi ro tiền giả, dễ đối soát cuối ngày.',
        example: 'Khách không mang tiền mặt → quét QR chuyển 500k → app tự ghi nhận.',
      ),
    ],
  ),

  // ── 6. Sản phẩm ──
  'product_list': FeatureGuide(
    title: 'Quản lý sản phẩm',
    icon: '📦',
    items: [
      FeatureGuideItem(
        intro: 'Quản lý danh mục SP: thêm tên, giá nhập, giá bán, danh mục, barcode. Tìm kiếm và lọc nhanh.',
        example: 'Bán thêm "Nước giặt Omo 3kg" → thêm vào app giá nhập 85k, bán 95k.',
      ),
    ],
  ),

  'product_detail': FeatureGuide(
    title: 'Chi tiết sản phẩm',
    icon: '🏷️',
    items: [
      FeatureGuideItem(
        intro: 'Xem giá vốn, giá bán, biên lợi nhuận. Giúp quyết định có nên tăng/giảm giá.',
        example: '"Sữa TH" nhập 28k bán 32k → biên lợi nhuận 12.5%.',
      ),
      FeatureGuideItem(
        intro: 'Quản lý lô hàng: xem hạn sử dụng, số lượng từng lô. Ưu tiên bán lô cũ trước.',
        example: 'Lô sữa HSD 1/4 còn 20 hộp → giảm giá để bán kịp.',
      ),
    ],
  ),

  // ── 7. Khách hàng ──
  'customer_list': FeatureGuide(
    title: 'Quản lý khách hàng',
    icon: '👥',
    items: [
      FeatureGuideItem(
        intro: 'Lưu thông tin khách quen: tên, SĐT, địa chỉ. Tự gắn vào đơn hàng khi bán, tra nợ nhanh.',
        example: 'Chú Ba mua chịu thường xuyên → lưu lại, tra nợ ngay.',
      ),
    ],
  ),

  'customer_detail': FeatureGuide(
    title: 'Chi tiết khách hàng',
    icon: '👤',
    items: [
      FeatureGuideItem(
        intro: 'Xem công nợ, ghi nhận thu tiền. Biết khách nợ bao nhiêu, tránh quên.',
        example: 'Cuối tháng thấy Chú Ba nợ 2.3 triệu → nhắc thanh toán.',
      ),
      FeatureGuideItem(
        intro: 'Lịch sử mua hàng: biết khách hay mua gì để tư vấn và chăm sóc tốt hơn.',
        example: 'Chị Hoa hay mua bột giặt A → khi có KM → báo chị.',
      ),
    ],
  ),

  // ── 8. Nhà cung cấp ──
  'supplier_list': FeatureGuide(
    title: 'Quản lý nhà cung cấp',
    icon: '🏭',
    items: [
      FeatureGuideItem(
        intro: 'Lưu thông tin nơi bạn nhập hàng: tên, SĐT, email. Dễ liên lạc và so sánh giá giữa các NCC.',
        example: 'Nhập sữa từ 3 NCC → so sánh xem NCC nào giá tốt nhất.',
      ),
    ],
  ),

  'supplier_detail': FeatureGuide(
    title: 'Chi tiết nhà cung cấp',
    icon: '🤝',
    items: [
      FeatureGuideItem(
        intro: 'Xem lịch sử nhập hàng từ NCC: đã nhập gì, giá bao nhiêu lần. Dùng để đàm phán giá.',
        example: '"3 tháng nhập từ Hải Phát 50 triệu" → thương lượng chiết khấu.',
      ),
    ],
  ),

  // ── 9. Kho hàng ──
  'inventory': FeatureGuide(
    title: 'Tổng quan tồn kho',
    icon: '🏪',
    items: [
      FeatureGuideItem(
        intro: 'Xem toàn bộ SP và số lượng tồn hiện tại. Tránh nhập thừa hoặc thiếu.',
        example: 'Kiểm tra thấy bột giặt còn 50 gói → chưa cần nhập thêm.',
      ),
    ],
  ),

  'purchase_order': FeatureGuide(
    title: 'Nhập hàng (Đơn mua)',
    icon: '📥',
    items: [
      FeatureGuideItem(
        intro: 'Ghi nhận nhập hàng: chọn NCC → thêm SP + số lượng + giá nhập → Lưu. Tồn kho tự cập nhật.',
        example: 'Nhập 100 thùng mì giá 95k/thùng từ Phú Thành → tồn kho tự tăng.',
      ),
    ],
  ),

  'stock_take': FeatureGuide(
    title: 'Kiểm kho',
    icon: '📝',
    items: [
      FeatureGuideItem(
        intro: 'Đối chiếu hàng thực tế vs hệ thống: tạo phiên kiểm → nhập số lượng đếm → so sánh.',
        example: 'Đếm 95 gói, hệ thống ghi 100 → chênh 5 gói → điều tra.',
      ),
    ],
  ),

  'xnt_report': FeatureGuide(
    title: 'Báo cáo Xuất-Nhập-Tồn',
    icon: '📊',
    items: [
      FeatureGuideItem(
        intro: 'Báo cáo chi tiết hàng xuất/nhập/tồn trong kỳ. Chọn thời gian → xem cho từng SP.',
        example: 'Tháng 3: Tồn đầu 100, Nhập 50, Xuất 80, Tồn cuối 70.',
      ),
    ],
  ),

  // ── 10. Tài chính ──
  'finance': FeatureGuide(
    title: 'Tài chính',
    icon: '💰',
    items: [
      FeatureGuideItem(
        intro: 'Tổng quan tài chính: số dư quỹ, thu/chi hôm nay, giao dịch gần đây.',
        example: 'Cuối ngày: thu 5 triệu, chi 2 triệu, quỹ còn 15 triệu.',
      ),
    ],
  ),

  'transaction_history': FeatureGuide(
    title: 'Lịch sử giao dịch',
    icon: '📒',
    items: [
      FeatureGuideItem(
        intro: 'Toàn bộ phiếu thu/chi, thay sổ giấy. Lọc theo loại (thu/chi), danh mục, thời gian.',
        example: '"Tuần này chi điện 500k, thuê 3 triệu, mua hàng 10 triệu".',
      ),
    ],
  ),

  'profit_loss': FeatureGuide(
    title: 'Báo cáo Lãi/Lỗ',
    icon: '📈',
    items: [
      FeatureGuideItem(
        intro: 'Báo cáo quan trọng nhất: Doanh thu − Giá vốn = Lãi gộp − Chi phí = Lãi ròng. Biết rõ đang lãi hay lỗ.',
        example: 'DT 50tr − GVHB 35tr − CP 10tr = Lãi ròng 5 triệu.',
      ),
    ],
  ),

  'cashflow_forecast': FeatureGuide(
    title: 'Dự báo dòng tiền',
    icon: '🔮',
    items: [
      FeatureGuideItem(
        intro: 'Biểu đồ dự báo thu/chi 5-7 ngày tới. Biết trước khi nào sắp hết tiền.',
        example: 'Tuần sau trả NCC 20 triệu mà quỹ 15 triệu → cần thu nợ gấp.',
      ),
    ],
  ),

  'daily_closing': FeatureGuide(
    title: 'Chốt sổ cuối ngày',
    icon: '🔒',
    items: [
      FeatureGuideItem(
        intro: 'Đếm tiền mặt thực tế → nhập vào hệ thống → so sánh với số liệu tự động. Phát hiện sai lệch.',
        example: 'Đếm 5.350k, hệ thống ghi 5.500k → chênh 150k → kiểm tra.',
      ),
    ],
  ),

  'debt_aging': FeatureGuide(
    title: 'Phân tích tuổi nợ',
    icon: '⏳',
    items: [
      FeatureGuideItem(
        intro: 'Phân loại nợ theo thời gian: <30 ngày, 30-60, 60-90, >90 ngày. Nợ càng cũ → rủi ro mất càng cao.',
        example: '3 triệu nợ quá 90 ngày → ưu tiên đòi trước.',
      ),
    ],
  ),

  'invoices': FeatureGuide(
    title: 'Quản lý hóa đơn',
    icon: '🧾',
    items: [
      FeatureGuideItem(
        intro: 'Lưu hóa đơn mua (đầu vào) và bán (đầu ra). Hệ thống tổng hợp VAT phục vụ kê khai.',
        example: 'Mua 10 triệu có hóa đơn → lưu lại → cuối quý khấu trừ VAT.',
      ),
    ],
  ),

  'purchase_no_invoice': FeatureGuide(
    title: 'Mua không hóa đơn',
    icon: '📄',
    items: [
      FeatureGuideItem(
        intro: 'Mua hàng nhỏ lẻ không có hóa đơn? Nhập CCCD + tên người bán → lập bảng kê hợp pháp.',
        example: 'Mua rau chợ 2 triệu → bảng kê có CCCD → hợp lệ khi thuế kiểm tra.',
      ),
    ],
  ),

  'tax_calculator': FeatureGuide(
    title: 'Tính thuế HKD',
    icon: '🧮',
    items: [
      FeatureGuideItem(
        intro: 'Nhập doanh thu + loại hình kinh doanh → hệ thống tính VAT và PIT tự động.',
        example: 'DT 500 triệu, bán lẻ → VAT 1% = 5tr, PIT 0.5% = 2.5tr.',
      ),
    ],
  ),

  'expense_ledger': FeatureGuide(
    title: 'Sổ chi phí SXKD',
    icon: '💸',
    items: [
      FeatureGuideItem(
        intro: 'Phân loại chi phí: mua hàng, thuê mặt bằng, điện nước, lương... Biết tiền đi đâu.',
        example: 'Tháng này: mua hàng 30tr (60%), thuê 5tr (10%), lương 8tr (16%).',
      ),
    ],
  ),

  'tax_obligations': FeatureGuide(
    title: 'Nghĩa vụ thuế',
    icon: '📑',
    items: [
      FeatureGuideItem(
        intro: 'Theo dõi thuế đã nộp, chưa nộp, còn thiếu. Trạng thái rõ ràng cho từng kỳ.',
        example: 'VAT Q1 nộp 5tr ✅, PIT Q1 chưa nộp 2.5tr ⚠️.',
      ),
    ],
  ),

  'salary_ledger': FeatureGuide(
    title: 'Sổ lương',
    icon: '💳',
    items: [
      FeatureGuideItem(
        intro: 'Ghi nhận chi lương nhân viên: ai, bao nhiêu, ngày nào. Làm bằng chứng khi kê khai thuế.',
        example: 'Tháng 3 chi lương 3 NV tổng 24 triệu → có bằng chứng báo cáo.',
      ),
    ],
  ),

  'tax_declaration': FeatureGuide(
    title: 'Kê khai thuế',
    icon: '📝',
    items: [
      FeatureGuideItem(
        intro: 'Tổng hợp dữ liệu kê khai: doanh thu, VAT đầu vào/ra. Dùng để điền tờ khai thuế.',
        example: 'Cuối quý: DT 150tr, VAT ra 1.5tr, VAT vào 800k.',
      ),
    ],
  ),

  // ── 11. Cài đặt ──
  'settings': FeatureGuide(
    title: 'Cài đặt',
    icon: '⚙️',
    items: [
      FeatureGuideItem(
        intro: 'Quản lý tài khoản cá nhân: sửa tên, email, SĐT, đổi mật khẩu.',
        example: 'Đổi SĐT mới → cập nhật ngay trong hồ sơ.',
      ),
      FeatureGuideItem(
        intro: 'Giao diện Sáng/Tối cho phù hợp thói quen và điều kiện ánh sáng.',
        example: 'Bán ca đêm → Dark Mode dễ nhìn, đỡ chói.',
      ),
      FeatureGuideItem(
        intro: 'Giá vốn hàng bán (COGS): chọn FIFO (hàng nhập trước xuất trước) hoặc Bình quân gia quyền.',
        example: 'Nhập 100 SP giá 10k + 100 SP giá 12k → AVG xuất giá 11k.',
      ),
      FeatureGuideItem(
        intro: 'Nhân viên & Phân quyền: thêm nhân viên, gán vai trò, quyết định ai được làm gì.',
        example: 'Thu ngân chỉ bán hàng, không xem tài chính.',
      ),
      FeatureGuideItem(
        intro: 'Nhật ký hoạt động: theo dõi ai đã thao tác gì trên hệ thống.',
        example: '"NV Minh xóa 1 đơn lúc 14:00" → hỏi lý do.',
      ),
    ],
  ),
};
