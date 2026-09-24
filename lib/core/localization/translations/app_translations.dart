/// Lớp định nghĩa cấu trúc kho từ điển dịch thuật cho SmartStock.
abstract class AppTranslations {
  CommonTranslations get common;
  AuthTranslations get auth;
  NavTranslations get nav;
  SettingsTranslations get settings;
  DashboardTranslations get dashboard;
  TaxTranslations get tax;
  InventoryTranslations get inventory;
  SalesTranslations get sales;
}

abstract class CommonTranslations {
  String get appTitle;
  String get save;
  String get cancel;
  String get delete;
  String get edit;
  String get create;
  String get update;
  String get search;
  String get filter;
  String get clearFilter;
  String get loading;
  String get retry;
  String get confirm;
  String get back;
  String get close;
  String get done;
  String get status;
  String get active;
  String get inactive;
  String get success;
  String get error;
  String get warning;
  String get info;
  String get all;
  String get notAvailable;
  String get noData;
  String get viewDetails;
  String get actions;
}

abstract class AuthTranslations {
  String get login;
  String get register;
  String get forgotPassword;
  String get email;
  String get username;
  String get password;
  String get confirmPassword;
  String get rememberMe;
  String get logout;
  String get logoutConfirmTitle;
  String get logoutConfirmMsg;
  String get logoutConfirmBtn;
  String get stayBtn;
  String get loginRequired;
}

abstract class NavTranslations {
  String get home;
  String get sales;
  String get inventory;
  String get finance;
  String get settings;
  String get helpCenter;
  String get collapse;
  String get expand;
  String get viewingScope;
  String get store;
  String get mainNavigation;
  String get searchPlaceholder;
  String get collapseTooltip;
  String get expandTooltip;
}

abstract class SettingsTranslations {
  String get systemSettings;
  String get subtitle;
  String get searchHint;
  String searchResultsFound(int count);
  String get noSettingsFound;
  String get clearFilter;
  String itemsCount(int count);

  // Section 1: Account & Security
  String get sectionAccountSecurity;
  String get profile;
  String get profileDesc;
  String get changePassword;
  String get changePasswordDesc;
  String get switchShop;
  String viewingShop(String shopName);
  String get viewProfile;
  String get switchShopBtn;
  String get switchShopTitle;
  String get switchShopSubtitle;
  String get allShops;
  String allShopsSummary(int count);
  String get owner;
  String get staff;

  // Section 2: Staff & Roles
  String get sectionStaffRoles;
  String get staffList;
  String get staffListDesc;
  String get rolesAndPermissions;
  String get rolesAndPermissionsDesc;

  // Section 3: Goods & Logistics
  String get sectionGoodsLogistics;
  String get productCategories;
  String get productCategoriesDesc;
  String get activityLogs;
  String get activityLogsDesc;
  String get costingMethod;
  String get costingMethodLoading;
  String get costingMethodError;
  String get costingMethodFifo;
  String get costingMethodAvg;
  String get costingMethodFifoShort;
  String get costingMethodAvgShort;
  String get costingMethodDialogTitle;
  String get costingMethodDialogSubtitle;
  String get costingMethodConfirmTitle;
  String get costingMethodConfirmMsg;
  String get costingMethodActiveBadge;
  String get minStockAlert;
  String get minStockAlertDesc;

  // Section 4: Shop & Payment
  String get sectionShopPayment;
  String get shopProfile;
  String get shopProfileDesc;
  String get paymentQr;
  String get paymentQrDesc;
  String get receiptTemplate;
  String get receiptTemplateDesc;
  String get shippingCarriers;
  String get shippingCarriersDesc;

  // Section 5: Tax & Business Support
  String get sectionTaxSupport;
  String get taxConfig;
  String get taxConfigDesc;
  String get taxSupport;
  String get taxSupportDesc;
  String get aiKnowledge;
  String get aiKnowledgeDesc;
  String get taxPortal;
  String get taxPortalDesc;

  // Section 6: System & Interface
  String get sectionSystemInterface;
  String get notificationCenter;
  String get notificationCenterDesc;
  String unreadCountBadge(int count);
  String get brandColor;
  String currentBrandColor(String name);
  String get selectBrandColor;
  String get brandColorDesc;
  String get appearanceAndWallpaper;
  String get appearanceModalTitle;
  String get appearanceModalSubtitle;
  String get tabColorAndMode;
  String get tabWallpaper;
  String get tabAvatar;
  String get displayModeTitle;
  String get brandColorTitle;
  String get wallpaperTitle;
  String get wallpaperNotice;
  String get customWallpaperTitle;
  String get customWallpaperSubtitle;
  String get customWallpaperEmptyTitle;
  String get uploadFromDevice;
  String get changeImage;
  String get removeCustomImage;
  String get quickAvatarTitle;
  String get chooseAvatarPreset;
  String get resetDefaults;
  String get finish;
  String get chooseAvatarTitle;
  String get chooseAvatarSubtitle;
  String get enterpriseAvatarCollection;
  String get language;
  String currentLanguage(String name);
  String get selectLanguage;
  String get languageSubtitle;
  String get backupRestore;
  String get backupRestoreDesc;
  String get appInfo;
  String get appInfoDesc;
  String get version;
  String get copyright;
  String get logoutButton;
}

abstract class DashboardTranslations {
  String get overview;
  String welcomeUser(String name);
  String get revenue;
  String get grossProfit;
  String get cashBalance;
  String get taxEstimate;
  String get safeThreshold;
  String get nearThreshold;
  String get exceededThreshold;
  String get recentOrders;
  String get quickActions;
  String get monthlySalesTarget;
}

abstract class TaxTranslations {
  String get taxConfiguration;
  String get householdTax;
  String get vatRate;
  String get pitRate;
  String get taxExemptionThreshold;
  String get taxCalculationNotice;
  String get overdueObligation;
  String get dueToday;
  String get pendingPayment;
  String get paid;
  String get circular88;
}

abstract class InventoryTranslations {
  String get inventoryTitle;
  String get stockOnHand;
  String get lowStockWarning;
  String get outOfStock;
  String get inbound;
  String get outbound;
  String get inventoryCheck;
}

abstract class SalesTranslations {
  String get salesTitle;
  String get createInvoice;
  String get orderList;
  String get customer;
  String get totalAmount;
  String get paymentMethod;
  String get printReceipt;
  String get completed;
}
