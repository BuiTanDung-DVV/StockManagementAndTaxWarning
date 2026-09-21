import 'app_translations.dart';

class ViTranslations implements AppTranslations {
  const ViTranslations();

  @override
  CommonTranslations get common => const _ViCommon();

  @override
  AuthTranslations get auth => const _ViAuth();

  @override
  NavTranslations get nav => const _ViNav();

  @override
  SettingsTranslations get settings => const _ViSettings();

  @override
  DashboardTranslations get dashboard => const _ViDashboard();

  @override
  TaxTranslations get tax => const _ViTax();

  @override
  InventoryTranslations get inventory => const _ViInventory();

  @override
  SalesTranslations get sales => const _ViSales();
}

class _ViCommon implements CommonTranslations {
  const _ViCommon();

  @override
  String get appTitle => 'SmartStock - Quản lý Bán hàng & Kho hàng';
  @override
  String get save => 'Lưu';
  @override
  String get cancel => 'Hủy bỏ';
  @override
  String get delete => 'Xóa';
  @override
  String get edit => 'Chỉnh sửa';
  @override
  String get create => 'Tạo mới';
  @override
  String get update => 'Cập nhật';
  @override
  String get search => 'Tìm kiếm';
  @override
  String get filter => 'Bộ lọc';
  @override
  String get clearFilter => 'Xóa bộ lọc';
  @override
  String get loading => 'Đang tải…';
  @override
  String get retry => 'Thử lại';
  @override
  String get confirm => 'Xác nhận';
  @override
  String get back => 'Quay lại';
  @override
  String get close => 'Đóng';
  @override
  String get done => 'Hoàn tất';
  @override
  String get status => 'Trạng thái';
  @override
  String get active => 'Hoạt động';
  @override
  String get inactive => 'Tạm dừng';
  @override
  String get success => 'Thành công';
  @override
  String get error => 'Đã có lỗi xảy ra';
  @override
  String get warning => 'Cảnh báo';
  @override
  String get info => 'Thông tin';
  @override
  String get all => 'Tất cả';
  @override
  String get notAvailable => 'Chưa có';
  @override
  String get noData => 'Không có dữ liệu';
  @override
  String get viewDetails => 'Xem chi tiết';
  @override
  String get actions => 'Thao tác';
}

class _ViAuth implements AuthTranslations {
  const _ViAuth();

  @override
  String get login => 'Đăng nhập';
  @override
  String get register => 'Đăng ký';
  @override
  String get forgotPassword => 'Quên mật khẩu';
  @override
  String get email => 'Email';
  @override
  String get username => 'Tên đăng nhập';
  @override
  String get password => 'Mật khẩu';
  @override
  String get confirmPassword => 'Xác nhận mật khẩu';
  @override
  String get rememberMe => 'Ghi nhớ đăng nhập';
  @override
  String get logout => 'Đăng xuất';
  @override
  String get logoutConfirmTitle => 'Xác nhận đăng xuất';
  @override
  String get logoutConfirmMsg =>
      'Bạn có chắc muốn đăng xuất khỏi ứng dụng? Hãy hoàn tất các thay đổi chưa lưu trước khi tiếp tục.';
  @override
  String get logoutConfirmBtn => 'Đăng xuất';
  @override
  String get stayBtn => 'Ở lại';
  @override
  String get loginRequired => 'Vui lòng đăng nhập để tiếp tục';
}

class _ViNav implements NavTranslations {
  const _ViNav();

  @override
  String get home => 'Trang chủ';
  @override
  String get sales => 'Bán hàng';
  @override
  String get inventory => 'Kho';
  @override
  String get finance => 'Tài chính';
  @override
  String get settings => 'Cài đặt';
  @override
  String get helpCenter => 'Trung tâm trợ giúp';
  @override
  String get collapse => 'Thu gọn';
  @override
  String get expand => 'Mở rộng';
  @override
  String get viewingScope => 'PHẠM VI ĐANG XEM';
}

class _ViSettings implements SettingsTranslations {
  const _ViSettings();

  @override
  String get systemSettings => 'Cài đặt hệ thống';
  @override
  String get subtitle =>
      'Quản lý tài khoản, cửa hàng, phân quyền và các cấu hình nghiệp vụ.';
  @override
  String get searchHint =>
      'Tìm nhanh một thiết lập, nhân viên, thuế, kho hàng...';
  @override
  String searchResultsFound(int count) => 'Tìm thấy $count thiết lập phù hợp';
  @override
  String get noSettingsFound => 'Không tìm thấy thiết lập phù hợp.';
  @override
  String get clearFilter => 'Xóa bộ lọc';
  @override
  String itemsCount(int count) => '$count mục';

  // Section 1
  @override
  String get sectionAccountSecurity => 'Tài khoản & bảo mật';
  @override
  String get profile => 'Thông tin cá nhân';
  @override
  String get profileDesc =>
      'Cập nhật hồ sơ và thông tin liên hệ của tài khoản.';
  @override
  String get changePassword => 'Đổi mật khẩu';
  @override
  String get changePasswordDesc =>
      'Thiết lập mật khẩu mới cho tài khoản đang đăng nhập.';
  @override
  String get switchShop => 'Chuyển cửa hàng';
  @override
  String viewingShop(String shopName) => 'Đang xem: $shopName.';
  @override
  String get viewProfile => 'Xem hồ sơ';
  @override
  String get switchShopBtn => 'Đổi cửa hàng';
  @override
  String get switchShopTitle => 'Chuyển cửa hàng';
  @override
  String get switchShopSubtitle =>
      'Dữ liệu trên màn hình sẽ đổi theo cửa hàng được chọn.';
  @override
  String get allShops => 'Tất cả cửa hàng';
  @override
  String allShopsSummary(int count) =>
      'Đang xem dữ liệu tổng hợp của $count cửa hàng.';
  @override
  String get owner => 'Chủ sở hữu';
  @override
  String get staff => 'Nhân viên';

  // Section 2
  @override
  String get sectionStaffRoles => 'Nhân viên & phân quyền';
  @override
  String get staffList => 'Danh sách nhân viên';
  @override
  String get staffListDesc => 'Quản lý thành viên đang làm việc tại cửa hàng.';
  @override
  String get rolesAndPermissions => 'Vai trò và quyền truy cập';
  @override
  String get rolesAndPermissionsDesc =>
      'Thiết lập phạm vi thao tác theo từng vai trò.';

  // Section 3
  @override
  String get sectionGoodsLogistics => 'Hàng hóa & kho vận';
  @override
  String get productCategories => 'Danh mục sản phẩm';
  @override
  String get productCategoriesDesc =>
      'Chuẩn hóa nhóm hàng phục vụ tra cứu và báo cáo.';
  @override
  String get activityLogs => 'Nhật ký hoạt động';
  @override
  String get activityLogsDesc =>
      'Tra cứu thao tác quan trọng đã thực hiện trong hệ thống.';
  @override
  String get costingMethod => 'Phương pháp tính giá vốn';
  @override
  String get costingMethodLoading => 'Đang tải cấu hình…';
  @override
  String get costingMethodError => 'Chưa tải được cấu hình từ cơ sở dữ liệu.';
  @override
  String get costingMethodFifo => 'Đang dùng: Nhập trước – xuất trước (FIFO).';
  @override
  String get costingMethodAvg => 'Đang dùng: Bình quân gia quyền (AVG).';
  @override
  String get costingMethodFifoShort => 'Nhập trước – xuất trước (FIFO)';
  @override
  String get costingMethodAvgShort => 'Bình quân gia quyền (AVG)';
  @override
  String get costingMethodDialogTitle => 'Chọn phương pháp tính giá vốn';
  @override
  String get costingMethodDialogSubtitle =>
      'Phương pháp tính giá vốn ảnh hưởng đến giá trị tồn kho và lợi nhuận gộp.';
  @override
  String get costingMethodConfirmTitle => 'Đổi phương pháp tính giá vốn';
  @override
  String get costingMethodConfirmMsg =>
      'Theo Thông tư 88/2021/TT-BTC, việc thay đổi phương pháp tính giá vốn phải được áp dụng nhất quán trong kỳ kế toán. Bạn có chắc muốn thay đổi?';
  @override
  String get costingMethodActiveBadge => 'Đang dùng';
  @override
  String get minStockAlert => 'Định mức tồn tối thiểu';
  @override
  String get minStockAlertDesc =>
      'Thiết lập ngưỡng cảnh báo khi mặt hàng chạm mức an toàn.';

  // Section 4
  @override
  String get sectionShopPayment => 'Cửa hàng & thanh toán';
  @override
  String get shopProfile => 'Thông tin cửa hàng';
  @override
  String get shopProfileDesc =>
      'Cập nhật tên, địa chỉ, mã số thuế và thông tin liên hệ.';
  @override
  String get paymentQr => 'Ảnh QR thanh toán';
  @override
  String get paymentQrDesc =>
      'Tải lên hoặc thay ảnh QR nhận tiền của cửa hàng.';
  @override
  String get receiptTemplate => 'Mẫu hóa đơn in';
  @override
  String get receiptTemplateDesc =>
      'Tùy chỉnh nội dung và nhận diện trên chứng từ bán hàng.';
  @override
  String get shippingCarriers => 'Đơn vị vận chuyển';
  @override
  String get shippingCarriersDesc =>
      'Quản lý đối tác giao hàng và cấu hình vận chuyển.';

  // Section 5
  @override
  String get sectionTaxSupport => 'Thuế & trợ giúp nghiệp vụ';
  @override
  String get taxConfig => 'Cấu hình thuế';
  @override
  String get taxConfigDesc =>
      'Thiết lập thông số dùng trong chức năng hỗ trợ tính thuế.';
  @override
  String get taxSupport => 'Kênh hỗ trợ thuế';
  @override
  String get taxSupportDesc =>
      'Xem đầu mối và tài liệu hỗ trợ khi cần làm rõ nghiệp vụ.';
  @override
  String get aiKnowledge => 'Nguồn tài liệu tham khảo';
  @override
  String get aiKnowledgeDesc =>
      'Quản lý nguồn kiến thức được dùng trong phần trợ giúp.';
  @override
  String get taxPortal => 'Cổng tra cứu Thuế điện tử';
  @override
  String get taxPortalDesc =>
      'Liên kết tra cứu nghĩa vụ thuế trên thuedientu.gdt.gov.vn.';

  // Section 6
  @override
  String get sectionSystemInterface => 'Hệ thống & giao diện';
  @override
  String get notificationCenter => 'Trung tâm thông báo';
  @override
  String get notificationCenterDesc =>
      'Xem cảnh báo vận hành và thông báo cần xử lý.';
  @override
  String unreadCountBadge(int count) => '$count chưa đọc';
  @override
  String get brandColor => 'Màu giao diện';
  @override
  String currentBrandColor(String name) => 'Đang dùng: $name.';
  @override
  String get selectBrandColor => 'Chọn màu giao diện';
  @override
  String get brandColorDesc =>
      'Màu được áp dụng cho nút chính và trạng thái đang chọn.';
  @override
  String get language => 'Ngôn ngữ hiển thị';
  @override
  String currentLanguage(String name) => 'Đang dùng: $name.';
  @override
  String get selectLanguage => 'Chọn ngôn ngữ hiển thị';
  @override
  String get languageSubtitle =>
      'Ngôn ngữ được áp dụng cho toàn bộ giao diện và chứng từ.';
  @override
  String get backupRestore => 'Sao lưu và khôi phục';
  @override
  String get backupRestoreDesc =>
      'Tạo bản sao dữ liệu và khôi phục khi có sự cố.';
  @override
  String get appInfo => 'Thông tin phần mềm';
  @override
  String get appInfoDesc => 'Xem phiên bản và thông tin sản phẩm.';
  @override
  String get version => 'Phiên bản';
  @override
  String get copyright => 'Bản quyền thuộc SmartStock 2026';
  @override
  String get logoutButton => 'Đăng xuất tài khoản';
}

class _ViDashboard implements DashboardTranslations {
  const _ViDashboard();

  @override
  String get overview => 'Tổng quan';
  @override
  String welcomeUser(String name) => 'Xin chào, $name!';
  @override
  String get revenue => 'Doanh thu';
  @override
  String get grossProfit => 'Lợi nhuận gộp';
  @override
  String get cashBalance => 'Số dư tiền';
  @override
  String get taxEstimate => 'Ước tính thuế';
  @override
  String get safeThreshold => 'Trong ngưỡng an toàn';
  @override
  String get nearThreshold => 'Tiệm cận ngưỡng cảnh báo';
  @override
  String get exceededThreshold => 'Vượt ngưỡng thuế khoán';
  @override
  String get recentOrders => 'Đơn hàng gần đây';
  @override
  String get quickActions => 'Thao tác nhanh';
  @override
  String get monthlySalesTarget => 'Mục tiêu bán hàng tháng';
}

class _ViTax implements TaxTranslations {
  const _ViTax();

  @override
  String get taxConfiguration => 'Cấu hình thuế';
  @override
  String get householdTax => 'Thuế hộ kinh doanh';
  @override
  String get vatRate => 'Tỷ lệ thuế GTGT';
  @override
  String get pitRate => 'Tỷ lệ thuế TNCN';
  @override
  String get taxExemptionThreshold => 'Ngưỡng miễn thuế doanh thu';
  @override
  String get taxCalculationNotice =>
      'Hệ thống tự động tính toán thuế phát sinh theo quy định của Tổng cục Thuế.';
  @override
  String get overdueObligation => 'Quá hạn';
  @override
  String get dueToday => 'Đến hạn hôm nay';
  @override
  String get pendingPayment => 'Chờ nộp';
  @override
  String get paid => 'Đã nộp';
  @override
  String get circular88 => 'Thông tư 88/2021/TT-BTC';
}

class _ViInventory implements InventoryTranslations {
  const _ViInventory();

  @override
  String get inventoryTitle => 'Quản lý tồn kho';
  @override
  String get stockOnHand => 'Tồn kho thực tế';
  @override
  String get lowStockWarning => 'Cảnh báo sắp hết hàng';
  @override
  String get outOfStock => 'Hết hàng';
  @override
  String get inbound => 'Nhập kho';
  @override
  String get outbound => 'Xuất kho';
  @override
  String get inventoryCheck => 'Kiểm kê';
}

class _ViSales implements SalesTranslations {
  const _ViSales();

  @override
  String get salesTitle => 'Bán hàng & Thu ngân';
  @override
  String get createInvoice => 'Tạo hóa đơn';
  @override
  String get orderList => 'Danh sách đơn hàng';
  @override
  String get customer => 'Khách hàng';
  @override
  String get totalAmount => 'Tổng tiền';
  @override
  String get paymentMethod => 'Hình thức thanh toán';
  @override
  String get printReceipt => 'In hóa đơn';
  @override
  String get completed => 'Hoàn thành';
}
