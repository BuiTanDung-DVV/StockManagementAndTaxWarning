// Dữ liệu hướng dẫn tính năng — dành cho hộ kinh doanh nhỏ lẻ
//
// Mỗi screen có 1 [FeatureGuide] gồm:
// - title: Tên tính năng
// - items: Danh sách [{intro, example}]
//   + intro: Giới thiệu chức năng (gộp lý do + cách dùng)
//   + example: Ví dụ nhỏ minh họa

class FeatureGuideItem {
  final String heading;
  final String intro;
  final String example;
  const FeatureGuideItem({
    this.heading = '',
    required this.intro,
    required this.example,
  });
}

class FeatureGuide {
  final String title;
  final String icon; // emoji
  final List<FeatureGuideItem> items;
  const FeatureGuide({
    required this.title,
    required this.icon,
    required this.items,
  });
}

const productImportGuideItems = <FeatureGuideItem>[
  FeatureGuideItem(
    heading: 'Chuẩn bị và chọn file',
    intro:
        'Mở Nhập danh mục sản phẩm, nhấn Tải mẫu Excel. Thay hai dòng minh họa bằng dữ liệu của bạn, lưu file .xlsx rồi chọn file trong app. Mỗi lượt tối đa 500 sản phẩm, file tối đa 5 MB. Nếu có nhiều sheet, chọn đúng sheet cần nhập.',
    example: '',
  ),
  FeatureGuideItem(
    heading: 'Mã hàng, tên và đơn vị',
    intro:
        'SKU là mã hàng, bắt buộc và duy nhất trong cửa hàng. Hàng mới phải có tên. Đơn vị phải khớp với sản phẩm đã có. Giữ cột SKU và Mã vạch ở dạng Text trong Excel để không mất số 0 đầu.',
    example:
        'SKU 000123 và mã vạch 0000123456789 phải giữ nguyên các số 0 đầu.',
  ),
  FeatureGuideItem(
    heading: 'Giá và mức tối thiểu',
    intro:
        'Giá nhập, Giá bán và Giá bán sỉ là ô số không âm. Mức tối thiểu là số nguyên không âm dùng để cảnh báo sắp hết hàng, không phải số lượng tồn ban đầu. Với ô có công thức, sao chép và dán giá trị trước khi nhập.',
    example: '',
  ),
  FeatureGuideItem(
    heading: 'Danh mục, nhãn và mô tả',
    intro:
        'Điền đúng tên danh mục và nhãn đã tạo trong cửa hàng, hoặc để trống. Ngăn nhiều nhãn bằng dấu |. Mô tả là ghi chú ngắn về hàng. Không nhập ảnh hoặc đường dẫn ảnh qua file; cập nhật ảnh riêng trong màn sửa sản phẩm.',
    example: 'Hai nhãn: Hàng cần theo dõi|Bán chạy.',
  ),
  FeatureGuideItem(
    heading: 'Kiểm tra trước khi nhập',
    intro:
        'SKU mới tạo sản phẩm mới; SKU đã có cập nhật thông tin được điền. Ô trống giữ dữ liệu cũ; nhập 0 nếu muốn đặt giá trị số bằng 0. Xem trước từng dòng và sửa lỗi trước khi xác nhận. Nhập danh mục không tăng tồn kho, ghi tiền hoặc tạo công nợ.',
    example: '',
  ),
];

const Map<String, FeatureGuide> featureGuides = {
  'product_import': FeatureGuide(
    title: 'Nhập sản phẩm từ Excel',
    icon: '',
    items: productImportGuideItems,
  ),
  // ── 1. Dashboard ──
  'dashboard': FeatureGuide(
    title: 'Trang chủ',
    icon: '📊',
    items: [
      FeatureGuideItem(
        heading: 'Đọc số liệu theo kỳ',
        intro:
            'Doanh thu thuần, lợi nhuận gộp và số đơn được tính trong kỳ đang chọn. Số dư quỹ là tiền mặt đã ghi nhận đến hiện tại. Nhấn một chỉ số để mở dữ liệu liên quan.',
        example: '',
      ),
      FeatureGuideItem(
        heading: 'Ưu tiên việc cần xử lý',
        intro:
            'Xem hàng hết hoặc chạm định mức tồn, công nợ quá hạn và nghĩa vụ thuế đã ghi. Đối chiếu dữ liệu nguồn trước khi xử lý.',
        example: '',
      ),
      FeatureGuideItem(
        heading: 'Ghi nhận nghiệp vụ',
        intro:
            'Ghi nghiệp vụ khi phát sinh hoặc nhập lại từ sổ, hóa đơn có sẵn tại các mục Kho, Tài chính và Bán hàng. Chọn đúng ngày nghiệp vụ và cửa hàng.',
        example: '',
      ),
    ],
  ),

  // ── 2. Ghi nhận giao dịch bán hàng ──
  'pos': FeatureGuide(
    title: 'Ghi nhận giao dịch bán hàng',
    icon: '🛒',
    items: [
      FeatureGuideItem(
        intro:
            'Chọn sản phẩm → nhập số lượng → chọn khách hàng và cách thanh toán → xác nhận giao dịch. Hệ thống tự tính tổng và ghi nhận công nợ khi cần.',
        example:
            'Khách mua 3 món, chọn từng SP, app tính tổng 450k, nhận tiền mặt, xong.',
      ),
    ],
  ),

  // ── 3. Danh sách đơn hàng ──
  'sales_list': FeatureGuide(
    title: 'Danh sách đơn hàng',
    icon: '📋',
    items: [
      FeatureGuideItem(
        intro:
            'Toàn bộ lịch sử bán hàng, lọc theo trạng thái (Chờ/Hoàn thành/Hủy), tìm kiếm nhanh.',
        example:
            'Khách hỏi "Đơn hôm qua bao nhiêu?" → tìm ngay trong danh sách.',
      ),
    ],
  ),

  // ── 4. Chi tiết đơn hàng ──
  'order_detail': FeatureGuide(
    title: 'Chi tiết đơn hàng',
    icon: '🧾',
    items: [
      FeatureGuideItem(
        intro:
            'Xem chính xác đơn hàng gồm sản phẩm gì, số lượng, giá, ai mua, thanh toán ra sao.',
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
        intro:
            'Tạo mã QR chuyển khoản cho khách quét. Giảm rủi ro tiền giả, dễ đối soát cuối ngày.',
        example:
            'Khách không mang tiền mặt → quét QR chuyển 500k → app tự ghi nhận.',
      ),
    ],
  ),

  // ── 6. Sản phẩm ──
  'product_list': FeatureGuide(
    title: 'Quản lý sản phẩm',
    icon: '📦',
    items: [
      FeatureGuideItem(
        heading: 'Tìm và lọc sản phẩm',
        intro:
            'Nhập tên hoặc SKU, chọn một nhãn để thu hẹp danh sách. “Tất cả” bỏ lọc nhãn; “Bỏ lọc” xóa cả nhãn và nội dung tìm kiếm.',
        example: '',
      ),
      FeatureGuideItem(
        heading: 'Xem chi tiết và xuất dữ liệu',
        intro:
            'Chuyển giữa danh sách và lưới ảnh. Chọn sản phẩm để xem thông tin; đánh dấu ô chọn rồi dùng “Xuất Excel”. Chọn tất cả áp dụng cho toàn bộ kết quả đang lọc, kể cả các trang khác; có thể bỏ chọn từng sản phẩm.',
        example: '“Chọn trang này” chỉ chọn các sản phẩm thuộc trang đang xem.',
      ),
      ...productImportGuideItems,
    ],
  ),

  'product_detail': FeatureGuide(
    title: 'Chi tiết sản phẩm',
    icon: '🏷️',
    items: [
      FeatureGuideItem(
        intro:
            'Xem giá vốn, giá bán, biên lợi nhuận. Giúp quyết định có nên tăng/giảm giá.',
        example: '"Sữa TH" nhập 28k bán 32k → biên lợi nhuận 12.5%.',
      ),
      FeatureGuideItem(
        intro:
            'Quản lý lô hàng: xem hạn sử dụng, số lượng từng lô. Ưu tiên bán lô cũ trước.',
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
        intro:
            'Lưu thông tin khách quen: tên, SĐT, địa chỉ. Tự gắn vào đơn hàng khi bán, tra nợ nhanh.',
        example: 'Chú Ba mua chịu thường xuyên → lưu lại, tra nợ ngay.',
      ),
    ],
  ),

  'customer_detail': FeatureGuide(
    title: 'Chi tiết khách hàng',
    icon: '👤',
    items: [
      FeatureGuideItem(
        intro:
            'Xem công nợ, ghi nhận thu tiền. Biết khách nợ bao nhiêu, tránh quên.',
        example: 'Cuối tháng thấy Chú Ba nợ 2.3 triệu → nhắc thanh toán.',
      ),
      FeatureGuideItem(
        intro:
            'Lịch sử mua hàng: biết khách hay mua gì để tư vấn và chăm sóc tốt hơn.',
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
        intro:
            'Lưu thông tin nơi bạn nhập hàng: tên, SĐT, email. Dễ liên lạc và so sánh giá giữa các NCC.',
        example: 'Nhập sữa từ 3 NCC → so sánh xem NCC nào giá tốt nhất.',
      ),
    ],
  ),

  'supplier_detail': FeatureGuide(
    title: 'Chi tiết nhà cung cấp',
    icon: '🤝',
    items: [
      FeatureGuideItem(
        intro:
            'Xem lịch sử nhập hàng từ NCC: đã nhập gì, giá bao nhiêu lần. Dùng để đàm phán giá.',
        example:
            '"3 tháng nhập từ Hải Phát 50 triệu" → thương lượng chiết khấu.',
      ),
    ],
  ),

  // ── 9. Kho hàng ──
  'inventory': FeatureGuide(
    title: 'Tổng quan tồn kho',
    icon: '🏪',
    items: [
      FeatureGuideItem(
        intro:
            'Xem toàn bộ SP và số lượng tồn hiện tại. Tránh nhập thừa hoặc thiếu.',
        example: 'Kiểm tra thấy bột giặt còn 50 gói → chưa cần nhập thêm.',
      ),
    ],
  ),

  'purchase_order': FeatureGuide(
    title: 'Nhập hàng (Đơn mua)',
    icon: '📥',
    items: [
      FeatureGuideItem(
        intro:
            'Ghi nhận nhập hàng: chọn NCC → thêm SP + số lượng + giá nhập → Lưu. Tồn kho tự cập nhật.',
        example:
            'Nhập 100 thùng mì giá 95k/thùng từ Phú Thành → tồn kho tự tăng.',
      ),
    ],
  ),

  'stock_take': FeatureGuide(
    title: 'Kiểm kho',
    icon: '📝',
    items: [
      FeatureGuideItem(
        intro:
            'Đối chiếu hàng thực tế vs hệ thống: tạo phiên kiểm → nhập số lượng đếm → so sánh.',
        example: 'Đếm 95 gói, hệ thống ghi 100 → chênh 5 gói → điều tra.',
      ),
    ],
  ),

  'xnt_report': FeatureGuide(
    title: 'Báo cáo Xuất-Nhập-Tồn',
    icon: '📊',
    items: [
      FeatureGuideItem(
        intro:
            'Báo cáo chi tiết hàng xuất/nhập/tồn trong kỳ. Chọn thời gian → xem cho từng SP.',
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
        intro:
            'Tổng quan tài chính: số dư quỹ, thu/chi hôm nay, giao dịch gần đây.',
        example: 'Cuối ngày: thu 5 triệu, chi 2 triệu, quỹ còn 15 triệu.',
      ),
    ],
  ),

  'transaction_history': FeatureGuide(
    title: 'Lịch sử giao dịch',
    icon: '📒',
    items: [
      FeatureGuideItem(
        intro:
            'Toàn bộ phiếu thu/chi, thay sổ giấy. Lọc theo loại (thu/chi), danh mục, thời gian.',
        example: '"Tuần này chi điện 500k, thuê 3 triệu, mua hàng 10 triệu".',
      ),
    ],
  ),

  'profit_loss': FeatureGuide(
    title: 'Báo cáo Lãi/Lỗ',
    icon: '📈',
    items: [
      FeatureGuideItem(
        intro:
            'Báo cáo quan trọng nhất: Doanh thu − Giá vốn = Lãi gộp − Chi phí = Lãi ròng. Biết rõ đang lãi hay lỗ.',
        example: 'DT 50tr − GVHB 35tr − CP 10tr = Lãi ròng 5 triệu.',
      ),
    ],
  ),

  'cashflow_forecast': FeatureGuide(
    title: 'Dự báo dòng tiền',
    icon: '🔮',
    items: [
      FeatureGuideItem(
        intro:
            'Biểu đồ dự báo thu/chi 5-7 ngày tới. Biết trước khi nào sắp hết tiền.',
        example: 'Tuần sau trả NCC 20 triệu mà quỹ 15 triệu → cần thu nợ gấp.',
      ),
    ],
  ),

  'daily_closing': FeatureGuide(
    title: 'Chốt sổ cuối ngày',
    icon: '🔒',
    items: [
      FeatureGuideItem(
        intro:
            'Đếm tiền mặt thực tế → nhập vào hệ thống → so sánh với số liệu tự động. Phát hiện sai lệch.',
        example: 'Đếm 5.350k, hệ thống ghi 5.500k → chênh 150k → kiểm tra.',
      ),
    ],
  ),

  'debt_aging': FeatureGuide(
    title: 'Phân tích tuổi nợ',
    icon: '⏳',
    items: [
      FeatureGuideItem(
        intro:
            'Phân loại nợ theo thời gian: <30 ngày, 30-60, 60-90, >90 ngày. Nợ càng cũ → rủi ro mất càng cao.',
        example: '3 triệu nợ quá 90 ngày → ưu tiên đòi trước.',
      ),
    ],
  ),

  'invoices': FeatureGuide(
    title: 'Quản lý hóa đơn',
    icon: '🧾',
    items: [
      FeatureGuideItem(
        intro:
            'Lưu hóa đơn mua (đầu vào) và bán (đầu ra). Hệ thống tổng hợp VAT phục vụ kê khai.',
        example: 'Mua 10 triệu có hóa đơn → lưu lại → cuối quý khấu trừ VAT.',
      ),
    ],
  ),

  'purchase_no_invoice': FeatureGuide(
    title: 'Mua không hóa đơn',
    icon: '📄',
    items: [
      FeatureGuideItem(
        intro:
            'Mua hàng nhỏ lẻ không có hóa đơn? Nhập CCCD + tên người bán → lập bảng kê hợp pháp.',
        example:
            'Mua rau chợ 2 triệu → bảng kê có CCCD → hợp lệ khi thuế kiểm tra.',
      ),
    ],
  ),

  'tax_calculator': FeatureGuide(
    title: 'Tính thuế HKD',
    icon: '🧮',
    items: [
      FeatureGuideItem(
        intro:
            'Nhập doanh thu + loại hình kinh doanh → hệ thống tính VAT và PIT tự động.',
        example: 'DT 500 triệu, bán lẻ → VAT 1% = 5tr, PIT 0.5% = 2.5tr.',
      ),
    ],
  ),

  'expense_ledger': FeatureGuide(
    title: 'Sổ chi phí SXKD',
    icon: '💸',
    items: [
      FeatureGuideItem(
        intro:
            'Phân loại chi phí: mua hàng, thuê mặt bằng, điện nước, lương... Biết tiền đi đâu.',
        example:
            'Tháng này: mua hàng 30tr (60%), thuê 5tr (10%), lương 8tr (16%).',
      ),
    ],
  ),

  'tax_obligations': FeatureGuide(
    title: 'Nghĩa vụ thuế',
    icon: '📑',
    items: [
      FeatureGuideItem(
        intro:
            'Theo dõi thuế đã nộp, chưa nộp, còn thiếu. Trạng thái rõ ràng cho từng kỳ.',
        example: 'VAT Q1 nộp 5tr ✅, PIT Q1 chưa nộp 2.5tr ⚠️.',
      ),
    ],
  ),

  'salary_ledger': FeatureGuide(
    title: 'Sổ lương',
    icon: '💳',
    items: [
      FeatureGuideItem(
        intro:
            'Ghi nhận chi lương nhân viên: ai, bao nhiêu, ngày nào. Làm bằng chứng khi kê khai thuế.',
        example:
            'Tháng 3 chi lương 3 NV tổng 24 triệu → có bằng chứng báo cáo.',
      ),
    ],
  ),

  'tax_declaration': FeatureGuide(
    title: 'Kê khai thuế',
    icon: '📝',
    items: [
      FeatureGuideItem(
        intro:
            'Tổng hợp dữ liệu kê khai: doanh thu, VAT đầu vào/ra. Dùng để điền tờ khai thuế.',
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
        intro:
            'Giao diện Sáng/Tối cho phù hợp thói quen và điều kiện ánh sáng.',
        example: 'Bán ca đêm → Dark Mode dễ nhìn, đỡ chói.',
      ),
      FeatureGuideItem(
        intro:
            'Giá vốn hàng bán (COGS): chọn FIFO (hàng nhập trước xuất trước) hoặc Bình quân gia quyền.',
        example: 'Nhập 100 SP giá 10k + 100 SP giá 12k → AVG xuất giá 11k.',
      ),
      FeatureGuideItem(
        intro:
            'Nhân viên & Phân quyền: thêm nhân viên, gán vai trò, quyết định ai được làm gì.',
        example: 'Thu ngân chỉ bán hàng, không xem tài chính.',
      ),
      FeatureGuideItem(
        intro: 'Nhật ký hoạt động: theo dõi ai đã thao tác gì trên hệ thống.',
        example: '"NV Minh xóa 1 đơn lúc 14:00" → hỏi lý do.',
      ),
    ],
  ),
};
