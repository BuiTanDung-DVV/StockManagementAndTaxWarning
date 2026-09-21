import 'app_translations.dart';

class EnTranslations implements AppTranslations {
  const EnTranslations();

  @override
  CommonTranslations get common => const _EnCommon();

  @override
  AuthTranslations get auth => const _EnAuth();

  @override
  NavTranslations get nav => const _EnNav();

  @override
  SettingsTranslations get settings => const _EnSettings();

  @override
  DashboardTranslations get dashboard => const _EnDashboard();

  @override
  TaxTranslations get tax => const _EnTax();

  @override
  InventoryTranslations get inventory => const _EnInventory();

  @override
  SalesTranslations get sales => const _EnSales();
}

class _EnCommon implements CommonTranslations {
  const _EnCommon();

  @override
  String get appTitle => 'SmartStock - Sales & Inventory Management';
  @override
  String get save => 'Save';
  @override
  String get cancel => 'Cancel';
  @override
  String get delete => 'Delete';
  @override
  String get edit => 'Edit';
  @override
  String get create => 'Create';
  @override
  String get update => 'Update';
  @override
  String get search => 'Search';
  @override
  String get filter => 'Filter';
  @override
  String get clearFilter => 'Clear filter';
  @override
  String get loading => 'Loading…';
  @override
  String get retry => 'Retry';
  @override
  String get confirm => 'Confirm';
  @override
  String get back => 'Back';
  @override
  String get close => 'Close';
  @override
  String get done => 'Done';
  @override
  String get status => 'Status';
  @override
  String get active => 'Active';
  @override
  String get inactive => 'Inactive';
  @override
  String get success => 'Success';
  @override
  String get error => 'An error occurred';
  @override
  String get warning => 'Warning';
  @override
  String get info => 'Information';
  @override
  String get all => 'All';
  @override
  String get notAvailable => 'N/A';
  @override
  String get noData => 'No data found';
  @override
  String get viewDetails => 'View details';
  @override
  String get actions => 'Actions';
}

class _EnAuth implements AuthTranslations {
  const _EnAuth();

  @override
  String get login => 'Log In';
  @override
  String get register => 'Sign Up';
  @override
  String get forgotPassword => 'Forgot Password';
  @override
  String get email => 'Email';
  @override
  String get username => 'Username';
  @override
  String get password => 'Password';
  @override
  String get confirmPassword => 'Confirm Password';
  @override
  String get rememberMe => 'Remember me';
  @override
  String get logout => 'Log Out';
  @override
  String get logoutConfirmTitle => 'Confirm Logout';
  @override
  String get logoutConfirmMsg =>
      'Are you sure you want to log out? Please save any pending changes before proceeding.';
  @override
  String get logoutConfirmBtn => 'Log Out';
  @override
  String get stayBtn => 'Stay';
  @override
  String get loginRequired => 'Please log in to continue';
}

class _EnNav implements NavTranslations {
  const _EnNav();

  @override
  String get home => 'Dashboard';
  @override
  String get sales => 'Sales';
  @override
  String get inventory => 'Inventory';
  @override
  String get finance => 'Finance';
  @override
  String get settings => 'Settings';
  @override
  String get helpCenter => 'Help Center';
  @override
  String get collapse => 'Collapse';
  @override
  String get expand => 'Expand';
  @override
  String get viewingScope => 'ACTIVE STORE';
}

class _EnSettings implements SettingsTranslations {
  const _EnSettings();

  @override
  String get systemSettings => 'System Settings';
  @override
  String get subtitle =>
      'Manage accounts, stores, role permissions, and business configurations.';
  @override
  String get searchHint => 'Quick search settings, staff, tax, inventory...';
  @override
  String searchResultsFound(int count) => 'Found $count matching settings';
  @override
  String get noSettingsFound => 'No matching settings found.';
  @override
  String get clearFilter => 'Clear filter';
  @override
  String itemsCount(int count) => '$count items';

  // Section 1
  @override
  String get sectionAccountSecurity => 'Account & Security';
  @override
  String get profile => 'Personal Profile';
  @override
  String get profileDesc =>
      'Update account details, contact info, and preferences.';
  @override
  String get changePassword => 'Change Password';
  @override
  String get changePasswordDesc =>
      'Set up a new secure password for this account.';
  @override
  String get switchShop => 'Switch Store';
  @override
  String viewingShop(String shopName) => 'Active: $shopName.';
  @override
  String get viewProfile => 'View profile';
  @override
  String get switchShopBtn => 'Switch store';
  @override
  String get switchShopTitle => 'Switch Store';
  @override
  String get switchShopSubtitle =>
      'Data will automatically filter by the selected store.';
  @override
  String get allShops => 'All Stores';
  @override
  String allShopsSummary(int count) =>
      'Viewing consolidated data across $count stores.';
  @override
  String get owner => 'Owner';
  @override
  String get staff => 'Staff';

  // Section 2
  @override
  String get sectionStaffRoles => 'Staff & Permissions';
  @override
  String get staffList => 'Staff Members';
  @override
  String get staffListDesc =>
      'Manage team members working across store branches.';
  @override
  String get rolesAndPermissions => 'Roles & Permissions';
  @override
  String get rolesAndPermissionsDesc =>
      'Define operational access permissions for each role.';

  // Section 3
  @override
  String get sectionGoodsLogistics => 'Products & Logistics';
  @override
  String get productCategories => 'Product Categories';
  @override
  String get productCategoriesDesc =>
      'Organize product groups for reporting and POS lookups.';
  @override
  String get activityLogs => 'Activity Logs';
  @override
  String get activityLogsDesc =>
      'Audit sensitive actions and operations performed in the system.';
  @override
  String get costingMethod => 'Costing Method';
  @override
  String get costingMethodLoading => 'Loading configuration…';
  @override
  String get costingMethodError =>
      'Unable to load configuration from database.';
  @override
  String get costingMethodFifo => 'Active: First-In First-Out (FIFO).';
  @override
  String get costingMethodAvg => 'Active: Weighted Average (AVG).';
  @override
  String get costingMethodFifoShort => 'First-In First-Out (FIFO)';
  @override
  String get costingMethodAvgShort => 'Weighted Average (AVG)';
  @override
  String get costingMethodDialogTitle => 'Select Costing Method';
  @override
  String get costingMethodDialogSubtitle =>
      'Inventory costing method directly impacts valuation and gross profit margin.';
  @override
  String get costingMethodConfirmTitle => 'Change Costing Method';
  @override
  String get costingMethodConfirmMsg =>
      'According to Circular 88/2021/TT-BTC, inventory valuation methods must remain consistent throughout an accounting period. Are you sure you want to proceed?';
  @override
  String get costingMethodActiveBadge => 'Active';
  @override
  String get minStockAlert => 'Safety Stock Threshold';
  @override
  String get minStockAlertDesc =>
      'Set low stock warning levels to prevent supply shortages.';

  // Section 4
  @override
  String get sectionShopPayment => 'Store & Payments';
  @override
  String get shopProfile => 'Store Information';
  @override
  String get shopProfileDesc =>
      'Update company name, business address, tax code, and hotline.';
  @override
  String get paymentQr => 'Payment QR Code';
  @override
  String get paymentQrDesc =>
      'Upload or update banking QR code for customer payments.';
  @override
  String get receiptTemplate => 'Receipt Template';
  @override
  String get receiptTemplateDesc =>
      'Customize bill header, store logo, and footer notice.';
  @override
  String get shippingCarriers => 'Shipping Partners';
  @override
  String get shippingCarriersDesc =>
      'Configure courier integration and delivery rates.';

  // Section 5
  @override
  String get sectionTaxSupport => 'Tax & Advisory';
  @override
  String get taxConfig => 'Tax Configuration';
  @override
  String get taxConfigDesc =>
      'Adjust VAT & PIT rates, deduction brackets, and thresholds.';
  @override
  String get taxSupport => 'Tax Support Desk';
  @override
  String get taxSupportDesc =>
      'Access official accounting guidelines and tax advisory contacts.';
  @override
  String get aiKnowledge => 'Knowledge Base';
  @override
  String get aiKnowledgeDesc =>
      'Manage tax legal references and AI assistant knowledge.';
  @override
  String get taxPortal => 'e-Tax Authority Portal';
  @override
  String get taxPortalDesc =>
      'Direct link to check obligations on thuedientu.gdt.gov.vn.';

  // Section 6
  @override
  String get sectionSystemInterface => 'System & Appearance';
  @override
  String get notificationCenter => 'Notifications';
  @override
  String get notificationCenterDesc =>
      'Review operations alerts, tax deadlines, and updates.';
  @override
  String unreadCountBadge(int count) => '$count unread';
  @override
  String get brandColor => 'Theme & Brand Color';
  @override
  String currentBrandColor(String name) => 'Active: $name.';
  @override
  String get selectBrandColor => 'Select Brand Color';
  @override
  String get brandColorDesc =>
      'Applies to primary buttons, highlights, and active badges.';
  @override
  String get language => 'Display Language';
  @override
  String currentLanguage(String name) => 'Active: $name.';
  @override
  String get selectLanguage => 'Select Display Language';
  @override
  String get languageSubtitle =>
      'Applies language across all screens, receipts, and reports.';
  @override
  String get backupRestore => 'Backup & Restore';
  @override
  String get backupRestoreDesc =>
      'Generate database snapshots and restore points.';
  @override
  String get appInfo => 'About Application';
  @override
  String get appInfoDesc =>
      'View application version, license, and release notes.';
  @override
  String get version => 'Version';
  @override
  String get copyright => 'SmartStock © 2026. All rights reserved.';
  @override
  String get logoutButton => 'Log Out Account';
}

class _EnDashboard implements DashboardTranslations {
  const _EnDashboard();

  @override
  String get overview => 'Overview';
  @override
  String welcomeUser(String name) => 'Welcome back, $name!';
  @override
  String get revenue => 'Revenue';
  @override
  String get grossProfit => 'Gross Profit';
  @override
  String get cashBalance => 'Cash Balance';
  @override
  String get taxEstimate => 'Estimated Tax';
  @override
  String get safeThreshold => 'Within Safe Limit';
  @override
  String get nearThreshold => 'Approaching Threshold';
  @override
  String get exceededThreshold => 'Exceeded Lump-Sum Limit';
  @override
  String get recentOrders => 'Recent Orders';
  @override
  String get quickActions => 'Quick Actions';
  @override
  String get monthlySalesTarget => 'Monthly Sales Target';
}

class _EnTax implements TaxTranslations {
  const _EnTax();

  @override
  String get taxConfiguration => 'Tax Configuration';
  @override
  String get householdTax => 'Household Business Tax';
  @override
  String get vatRate => 'VAT Rate';
  @override
  String get pitRate => 'PIT Rate';
  @override
  String get taxExemptionThreshold => 'Exemption Threshold';
  @override
  String get taxCalculationNotice =>
      'Automated calculation following General Department of Taxation regulations.';
  @override
  String get overdueObligation => 'Overdue';
  @override
  String get dueToday => 'Due Today';
  @override
  String get pendingPayment => 'Pending';
  @override
  String get paid => 'Paid';
  @override
  String get circular88 => 'Circular 88/2021/TT-BTC';
}

class _EnInventory implements InventoryTranslations {
  const _EnInventory();

  @override
  String get inventoryTitle => 'Inventory Management';
  @override
  String get stockOnHand => 'Stock on Hand';
  @override
  String get lowStockWarning => 'Low Stock Warning';
  @override
  String get outOfStock => 'Out of Stock';
  @override
  String get inbound => 'Stock In';
  @override
  String get outbound => 'Stock Out';
  @override
  String get inventoryCheck => 'Stock Count';
}

class _EnSales implements SalesTranslations {
  const _EnSales();

  @override
  String get salesTitle => 'POS & Cashier';
  @override
  String get createInvoice => 'Create Invoice';
  @override
  String get orderList => 'Orders';
  @override
  String get customer => 'Customer';
  @override
  String get totalAmount => 'Total Amount';
  @override
  String get paymentMethod => 'Payment Method';
  @override
  String get printReceipt => 'Print Receipt';
  @override
  String get completed => 'Completed';
}
