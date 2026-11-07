import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Tập trung toàn bộ tài nguyên hình ảnh dùng trong giao diện.
///
/// Màn hình chỉ tham chiếu các hằng số tại đây để tránh trộn icon hệ thống với
/// bộ nhận diện của ứng dụng.
abstract final class AppAssets {
  static const String appIcon = 'assets/icon/app_icon.png';
  static const String aiMascot = 'assets/icon/ai_mascot.png';
  static const String revenue = 'assets/icon/revenue_icon.svg';
  static const String orders = 'assets/icon/orders_icon.svg';
  static const String inventory = 'assets/icon/inventory_icon.svg';
  static const String profit = 'assets/icon/profit_icon.svg';
  static const String cash = 'assets/icon/cash_icon.svg';
  static const String tax = 'assets/icon/tax_icon.svg';
  static const String home = 'assets/icon/home_icon.svg';
  static const String settings = 'assets/icon/settings_icon.svg';
  static const String notification = 'assets/icon/notification_icon.svg';
  static const String qrPayment = 'assets/icon/qr_payment_icon.svg';
  static const String help = 'assets/icon/help_icon.svg';
  static const String add = 'assets/icon/add_icon.svg';
  static const String edit = 'assets/icon/edit_icon.svg';
  static const String search = 'assets/icon/search_icon.svg';
  static const String calendar = 'assets/icon/calendar_icon.svg';
  static const String emptyGeneric = 'assets/icon/empty_generic.svg';
  static const String emptyInventory = 'assets/icon/empty_inventory.svg';
  static const String emptySales = 'assets/icon/empty_sales.svg';
  static const String emptyPeople = 'assets/icon/empty_people.svg';
  static const String emptyFinance = 'assets/icon/empty_finance.svg';
  static const String emptyDocument = 'assets/icon/empty_document.svg';
  static const String emptyTax = 'assets/icon/empty_tax.svg';
  static const String copy = 'assets/icon/copy_icon.svg';
  static const String delete = 'assets/icon/delete_icon.svg';
  static const String eye = 'assets/icon/eye_icon.svg';
  static const String toggleOn = 'assets/icon/toggle_on_icon.svg';
  static const String toggleOff = 'assets/icon/toggle_off_icon.svg';
  static const String storage = 'assets/icon/storage_icon.svg';
  static const String book = 'assets/icon/book_icon.svg';
  static const String externalLink = 'assets/icon/external_link_icon.svg';
  static const String expand = 'assets/icon/expand_icon.svg';
  static const String collapse = 'assets/icon/collapse_icon.svg';
  static const String demoWarehouse = 'assets/icon/demo_warehouse.png';
  static const String authWarehousePanoramaV2 =
      'assets/icon/auth_warehouse_panorama_v2.png';
  static const String warehouseMotif = 'assets/icon/warehouse_motif.svg';
  static const String parcelBox = 'assets/icon/parcel_box.svg';
  static const String analyticsMotif = 'assets/icon/analytics_motif.svg';

  // Finance modules: Phosphor Duotone, same licensed family as navigation.
  static const String financeTransactions =
      'assets/icon/finance_transactions_icon.svg';
  static const String financeClosing = 'assets/icon/finance_closing_icon.svg';
  static const String financeExpenses = 'assets/icon/finance_expenses_icon.svg';
  static const String financeInvoices = 'assets/icon/finance_invoices_icon.svg';
  static const String financeScan = 'assets/icon/finance_scan_icon.svg';
  static const String financeResults = 'assets/icon/finance_results_icon.svg';
  static const String financeForecast = 'assets/icon/finance_forecast_icon.svg';
  static const String financeReceivables =
      'assets/icon/finance_receivables_icon.svg';
  static const String financePayables = 'assets/icon/finance_payables_icon.svg';
  static const String financeSalary = 'assets/icon/finance_salary_icon.svg';
  static const String financePurchaseLedger =
      'assets/icon/finance_purchase_ledger_icon.svg';
  static const String financeCalculator =
      'assets/icon/finance_calculator_icon.svg';
  static const String financeTaxObligations =
      'assets/icon/finance_tax_obligations_icon.svg';
  static const String financeTaxDeclaration =
      'assets/icon/finance_tax_declaration_icon.svg';
  static const String financeIncome = 'assets/icon/finance_income_icon.svg';
  static const String financeOutflow = 'assets/icon/finance_outflow_icon.svg';

  // --- Theme & Appearance UI Assets ---
  static const String palette = 'assets/icon/palette_icon.svg';
  static const String wallpaper = 'assets/icon/wallpaper_icon.svg';
  static const String avatar = 'assets/icon/avatar_icon.svg';
  static const String check = 'assets/icon/check_icon.svg';
  static const String close = 'assets/icon/close_icon.svg';
  static const String sun = 'assets/icon/sun_icon.svg';
  static const String moon = 'assets/icon/moon_icon.svg';
  static const String systemMode = 'assets/icon/system_mode_icon.svg';
  static const String upload = 'assets/icon/upload_icon.svg';
  static const String refresh = 'assets/icon/refresh_icon.svg';
  static const String image = 'assets/icon/image_icon.svg';
  static const String shield = 'assets/icon/shield_icon.svg';
  static const String person = 'assets/icon/person_icon.svg';
  static const String key = 'assets/icon/key_icon.svg';
  static const String switchShop = 'assets/icon/switch_icon.svg';
  static const String badge = 'assets/icon/badge_icon.svg';
  static const String people = 'assets/icon/people_icon.svg';
  static const String roles = 'assets/icon/roles_icon.svg';
  static const String category = 'assets/icon/category_icon.svg';
  static const String history = 'assets/icon/history_icon.svg';
  static const String calculator = 'assets/icon/calculator_icon.svg';
  static const String warning = 'assets/icon/warning_icon.svg';
  static const String store = 'assets/icon/store_icon.svg';
  static const String shipping = 'assets/icon/shipping_icon.svg';
  static const String tune = 'assets/icon/tune_icon.svg';
  static const String support = 'assets/icon/support_icon.svg';
  static const String language = 'assets/icon/language_icon.svg';
  static const String backup = 'assets/icon/backup_icon.svg';
  static const String info = 'assets/icon/info_icon.svg';
  static const String filter = 'assets/icon/filter_icon.svg';
  static const String logout = 'assets/icon/logout_icon.svg';
  static const String next = 'assets/icon/next_icon.svg';
  static const String back = 'assets/icon/back_icon.svg';
  static const String forward = 'assets/icon/forward_icon.svg';
  static const String checkCircle = 'assets/icon/check_circle_icon.svg';
  static const String error = 'assets/icon/error_icon.svg';
  static const String clock = 'assets/icon/clock_icon.svg';
  static const String verified = 'assets/icon/verified_icon.svg';
  static const String quickAction = 'assets/icon/quick_action_icon.svg';
  static const String table = 'assets/icon/table_icon.svg';
  static const String pending = 'assets/icon/pending_icon.svg';
  static const String disabled = 'assets/icon/disabled_icon.svg';
  static const String eyeOff = 'assets/icon/eye_off_icon.svg';
  static const String chart = 'assets/icon/chart_icon.svg';
  static const String assistant = 'assets/icon/assistant_icon.svg';
  static const String folder = 'assets/icon/folder_icon.svg';
  static const String save = 'assets/icon/save_icon.svg';
  static const String lock = 'assets/icon/lock_icon.svg';
  static const String mail = 'assets/icon/mail_icon.svg';
  static const String phone = 'assets/icon/phone_icon.svg';
  static const String document = 'assets/icon/document_icon.svg';
  static const String offline = 'assets/icon/offline_icon.svg';
  static const String panelExpand = 'assets/icon/panel_expand_icon.svg';
  static const String panelCollapse = 'assets/icon/panel_collapse_icon.svg';
  static const String banknote = 'assets/icon/banknote_icon.svg';
  static const String bank = 'assets/icon/bank_icon.svg';
  static const String print = 'assets/icon/print_icon.svg';
  static const String returnGoods = 'assets/icon/return_icon.svg';
  static const String minus = 'assets/icon/minus_icon.svg';
  static const String more = 'assets/icon/more_icon.svg';
  static const String list = 'assets/icon/list_icon.svg';
  static const String clearFilter = 'assets/icon/clear_filter_icon.svg';
  static const String bag = 'assets/icon/bag_icon.svg';

  static const String location = 'assets/icon/location_icon.svg';
  static const String map = 'assets/icon/map_icon.svg';
  static const String phoneCall = 'assets/icon/phoneCall_icon.svg';
  static const String mailRead = 'assets/icon/mailRead_icon.svg';
  static const String download = 'assets/icon/download_icon.svg';
  static const String camera = 'assets/icon/camera_icon.svg';
  static const String scan = 'assets/icon/scan_icon.svg';
  static const String pdf = 'assets/icon/pdf_icon.svg';
  static const String briefcase = 'assets/icon/briefcase_icon.svg';
  static const String arrowUp = 'assets/icon/arrowUp_icon.svg';
  static const String arrowDown = 'assets/icon/arrowDown_icon.svg';
  static const String previous = 'assets/icon/previous_icon.svg';
  static const String link = 'assets/icon/link_icon.svg';
  static const String linkOff = 'assets/icon/linkOff_icon.svg';
  static const String legal = 'assets/icon/legal_icon.svg';
  static const String idea = 'assets/icon/idea_icon.svg';
  static const String personAdd = 'assets/icon/personAdd_icon.svg';
  static const String personRemove = 'assets/icon/personRemove_icon.svg';
  static const String archive = 'assets/icon/archive_icon.svg';
  static const String barcode = 'assets/icon/barcode_icon.svg';
  static const String ruler = 'assets/icon/ruler_icon.svg';
  static const String note = 'assets/icon/note_icon.svg';
  static const String alignLeft = 'assets/icon/alignLeft_icon.svg';
  static const String code = 'assets/icon/code_icon.svg';
  static const String industry = 'assets/icon/industry_icon.svg';
  static const String tools = 'assets/icon/tools_icon.svg';
  static const String star = 'assets/icon/star_icon.svg';
  static const String arrowNorthEast = 'assets/icon/arrowNorthEast_icon.svg';
  static const String arrowSouthWest = 'assets/icon/arrowSouthWest_icon.svg';
  static const String login = 'assets/icon/login_icon.svg';
  static const String radar = 'assets/icon/radar_icon.svg';

  // --- Avatar Presets (Vector Illustration) ---
  static const String avatarAdminM = 'assets/icon/avatar_admin_m.svg';
  static const String avatarAdminF = 'assets/icon/avatar_admin_f.svg';
  static const String avatarAccountant = 'assets/icon/avatar_accountant.svg';
  static const String avatarCashier = 'assets/icon/avatar_cashier.svg';
  static const String avatarWarehouse = 'assets/icon/avatar_warehouse.svg';
  static const String avatarAiBot = 'assets/icon/avatar_ai_bot.svg';

  // --- Wallpaper / Background Presets ---
  static const String bgWarehouseGrid = 'assets/icon/bg_warehouse_grid.svg';
  static const String bgTechDots = 'assets/icon/bg_tech_dots.svg';
  static const String bgMeshEmerald = 'assets/icon/bg_mesh_emerald.svg';
  static const String bgGeometricShapes = 'assets/icon/bg_geometric_shapes.svg';
}

class AppAssetIcon extends StatelessWidget {
  final String assetPath;
  final double size;
  final Color? color;
  final String? semanticLabel;
  final BoxFit fit;

  const AppAssetIcon({
    super.key,
    required this.assetPath,
    this.size = 20,
    this.color,
    this.semanticLabel,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final isEmptyVisual = assetPath.startsWith('assets/icon/empty_');
    final isSymbol = assetPath.endsWith('_icon.svg') || isEmptyVisual;
    final resolvedColor =
        color ??
        (isEmptyVisual
            ? Theme.of(context).colorScheme.primary
            : isSymbol
            ? IconTheme.of(context).color
            : null);
    final icon = assetPath.toLowerCase().endsWith('.svg')
        ? SvgPicture.asset(
            assetPath,
            width: size,
            height: size,
            fit: fit,
            colorFilter: resolvedColor == null
                ? null
                : ColorFilter.mode(resolvedColor, BlendMode.srcIn),
            semanticsLabel: semanticLabel,
          )
        : Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: fit,
            color: color,
            colorBlendMode: color == null ? null : BlendMode.srcIn,
            semanticLabel: semanticLabel,
            // Không để lỗi tải ảnh biến logo thành một ô trắng. Điều này đặc
            // biệt quan trọng trên Web khi CDN/service worker còn giữ bản
            // asset cũ hoặc ảnh cửa hàng chưa có.
            errorBuilder: (context, error, stackTrace) {
              final fallbackColor =
                  color ?? Theme.of(context).colorScheme.primary;
              final isMascot = assetPath == AppAssets.aiMascot;
              return AppAssetIcon(
                assetPath: isMascot ? AppAssets.assistant : AppAssets.inventory,
                size: size * 0.78,
                color: fallbackColor,
                semanticLabel: semanticLabel,
              );
            },
          );

    return SizedBox.square(
      dimension: size,
      child: Center(child: icon),
    );
  }
}
