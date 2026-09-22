import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/costing_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/shop_provider.dart';
import '../providers/system_provider.dart';
import '../../../core/widgets/app_avatar.dart';
import 'shop_payment_qr_dialog.dart';
import 'theme_appearance_modal.dart';

bool settingsShouldLoadShopProfile(ShopState state) =>
    !state.isAllShops &&
    state.currentShopId != null &&
    (state.userShops.isEmpty ||
        state.isOwner ||
        state.hasPermission('settings'));

int settingsActiveShopCount(ShopState state) => state.userShops
    .where((shop) => shop['status'] == 'ACTIVE' && shop['isActive'] != false)
    .length;

String settingsAllShopsSummary(ShopState state) {
  final count = settingsActiveShopCount(state);
  return 'Đang xem dữ liệu tổng hợp của $count cửa hàng.';
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _searchQuery = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    Future.microtask(
      () => ref.read(costingProvider.notifier).loadCostingMethod(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final shopState = ref.watch(shopProvider);
    final AsyncValue<Map<String, dynamic>>? shopAsync =
        settingsShouldLoadShopProfile(shopState)
        ? ref.watch(shopProfileProvider)
        : null;
    final auth = ref.watch(authProvider);
    final notifications = ref.watch(notificationProvider);
    final brandColor = ref.watch(brandColorProvider);
    final appLanguage = ref.watch(localeProvider);
    final tr = context.tr;
    final costing = ref.watch(costingProvider);
    final canManageSettings =
        shopState.isOwner || shopState.hasPermission('settings');
    final canManageProducts =
        shopState.isOwner || shopState.hasPermission('products');
    final canManageStaff = shopState.isOwner;
    final canViewFinance =
        shopState.isOwner || shopState.hasPermission('finance');

    final sections = <_SettingsSectionData>[
      _SettingsSectionData(
        title: tr.settings.sectionAccountSecurity,
        icon: Icons.shield_outlined,
        iconColor: const Color(0xFF2563EB),
        entries: [
          _SettingsEntry(
            label: tr.settings.profile,
            description: tr.settings.profileDesc,
            icon: Icons.person_outline_rounded,
            iconColor: const Color(0xFF2563EB),
            onTap: () => context.push('/profile'),
          ),
          _SettingsEntry(
            label: tr.settings.changePassword,
            description: tr.settings.changePasswordDesc,
            icon: Icons.lock_reset_rounded,
            iconColor: const Color(0xFF3B82F6),
            onTap: () => context.push('/change-password'),
          ),
          if (shopState.userShops.length > 1)
            _SettingsEntry(
              label: tr.settings.switchShop,
              description: tr.settings.viewingShop(
                shopState.currentShopName ?? tr.settings.allShops,
              ),
              icon: Icons.swap_horiz_rounded,
              iconColor: const Color(0xFF6366F1),
              onTap: () => _showShopSwitcher(context, shopState),
            ),
        ],
      ),
      if (canManageStaff)
        _SettingsSectionData(
          title: tr.settings.sectionStaffRoles,
          icon: Icons.badge_outlined,
          iconColor: const Color(0xFFD97706),
          entries: [
            _SettingsEntry(
              label: tr.settings.staffList,
              description: tr.settings.staffListDesc,
              icon: Icons.people_alt_outlined,
              iconColor: const Color(0xFFD97706),
              onTap: () => context.push('/staff'),
            ),
            _SettingsEntry(
              label: tr.settings.rolesAndPermissions,
              description: tr.settings.rolesAndPermissionsDesc,
              icon: Icons.admin_panel_settings_outlined,
              iconColor: const Color(0xFFF59E0B),
              onTap: () => context.push('/roles'),
            ),
          ],
        ),
      _SettingsSectionData(
        title: tr.settings.sectionGoodsLogistics,
        icon: Icons.inventory_2_outlined,
        iconColor: const Color(0xFF0D9488),
        entries: [
          if (canManageProducts)
            _SettingsEntry(
              label: tr.settings.productCategories,
              description: tr.settings.productCategoriesDesc,
              icon: Icons.category_outlined,
              iconColor: const Color(0xFF0D9488),
              onTap: () => context.push('/settings/product-categories'),
            ),
          if (canManageSettings)
            _SettingsEntry(
              label: tr.settings.activityLogs,
              description: tr.settings.activityLogsDesc,
              icon: Icons.history_rounded,
              iconColor: const Color(0xFF14B8A6),
              onTap: () => context.push('/activity-logs'),
            ),
          if (canManageSettings)
            _SettingsEntry(
              label: tr.settings.costingMethod,
              description: costing.isLoading
                  ? tr.settings.costingMethodLoading
                  : costing.errorMessage != null || !costing.hasData
                  ? tr.settings.costingMethodError
                  : costing.method == 'FIFO'
                  ? tr.settings.costingMethodFifo
                  : tr.settings.costingMethodAvg,
              icon: Icons.calculate_outlined,
              iconColor: const Color(0xFF0284C7),
              onTap: costing.isLoading || !costing.hasData
                  ? null
                  : () => _showCostingMethodPicker(context),
            ),
          if (canManageProducts)
            _SettingsEntry(
              label: tr.settings.minStockAlert,
              description: tr.settings.minStockAlertDesc,
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFE11D48),
              onTap: () => context.push('/inventory'),
            ),
        ],
      ),
      _SettingsSectionData(
        title: tr.settings.sectionShopPayment,
        icon: Icons.storefront_rounded,
        iconColor: const Color(0xFF059669),
        entries: [
          if (canManageSettings)
            _SettingsEntry(
              label: tr.settings.shopProfile,
              description: tr.settings.shopProfileDesc,
              icon: Icons.store_outlined,
              iconColor: const Color(0xFF059669),
              onTap: () => context.push('/shop-profile'),
            ),
          if (canManageSettings)
            _SettingsEntry(
              label: tr.settings.paymentQr,
              description: tr.settings.paymentQrDesc,
              icon: Icons.qr_code_2_rounded,
              iconColor: const Color(0xFF10B981),
              onTap: () => showShopPaymentQrDialog(context, canManage: true),
            ),
          if (canManageSettings)
            _SettingsEntry(
              label: tr.settings.receiptTemplate,
              description: tr.settings.receiptTemplateDesc,
              icon: Icons.receipt_long_outlined,
              iconColor: const Color(0xFF34D399),
              onTap: () => context.push('/settings/receipt-template'),
            ),
          if (canManageSettings)
            _SettingsEntry(
              label: tr.settings.shippingCarriers,
              description: tr.settings.shippingCarriersDesc,
              icon: Icons.local_shipping_outlined,
              iconColor: const Color(0xFF059669),
              onTap: () => context.push('/settings/shipping-carriers'),
            ),
        ],
      ),
      _SettingsSectionData(
        title: tr.settings.sectionTaxSupport,
        icon: Icons.account_balance_outlined,
        iconColor: const Color(0xFF7C3AED),
        entries: [
          if (canManageSettings)
            _SettingsEntry(
              label: tr.settings.taxConfig,
              description: tr.settings.taxConfigDesc,
              icon: Icons.tune_rounded,
              iconColor: const Color(0xFF7C3AED),
              onTap: () => context.push('/tax-config'),
            ),
          if (canViewFinance)
            _SettingsEntry(
              label: tr.settings.taxSupport,
              description: tr.settings.taxSupportDesc,
              icon: Icons.support_agent_rounded,
              iconColor: const Color(0xFF8B5CF6),
              onTap: () => context.push('/tax-support'),
            ),
          if (canManageSettings)
            _SettingsEntry(
              label: tr.settings.aiKnowledge,
              description: tr.settings.aiKnowledgeDesc,
              icon: Icons.menu_book_outlined,
              iconColor: const Color(0xFFA855F7),
              onTap: () => context.push('/settings/ai-knowledge'),
            ),
          if (canViewFinance)
            _SettingsEntry(
              label: tr.settings.taxPortal,
              description: tr.settings.taxPortalDesc,
              icon: Icons.open_in_new_rounded,
              iconColor: const Color(0xFF7C3AED),
              onTap: () => context.push('/tax-support'),
            ),
        ],
      ),
      _SettingsSectionData(
        title: tr.settings.sectionSystemInterface,
        icon: Icons.settings_suggest_outlined,
        iconColor: const Color(0xFF4F46E5),
        entries: [
          _SettingsEntry(
            label: tr.settings.notificationCenter,
            description: tr.settings.notificationCenterDesc,
            icon: Icons.notifications_none_rounded,
            iconColor: const Color(0xFF4F46E5),
            badge: notifications.unreadCount > 0
                ? tr.settings.unreadCountBadge(notifications.unreadCount)
                : null,
            onTap: () => context.push('/notifications'),
          ),
          _SettingsEntry(
            label: tr.settings.language,
            description: tr.settings.currentLanguage(
              '${appLanguage.flag} ${appLanguage.label}',
            ),
            icon: Icons.language_rounded,
            iconColor: const Color(0xFF0284C7),
            onTap: () => _showLanguagePicker(context, appLanguage),
          ),
          _SettingsEntry(
            label: 'Giao diện & Hình nền',
            description: tr.settings.currentBrandColor(brandColor.label),
            assetPath: AppAssets.palette,
            iconColor: brandColor.color,
            onTap: () => ThemeAppearanceModal.show(context),
          ),
          if (shopState.isOwner)
            _SettingsEntry(
              label: tr.settings.backupRestore,
              description: tr.settings.backupRestoreDesc,
              icon: Icons.cloud_sync_outlined,
              iconColor: const Color(0xFF6366F1),
              onTap: () => context.push('/settings/backup-restore'),
            ),
          _SettingsEntry(
            label: tr.settings.appInfo,
            description: tr.settings.appInfoDesc,
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF64748B),
            onTap: () => _showAbout(context),
          ),
        ],
      ),
    ];

    final query = _searchQuery.trim().toLowerCase();
    final filteredSections = sections
        .map(
          (section) => _SettingsSectionData(
            title: section.title,
            icon: section.icon,
            iconColor: section.iconColor,
            entries: section.entries.where((entry) {
              if (query.isEmpty) return true;
              return entry.label.toLowerCase().contains(query) ||
                  entry.description.toLowerCase().contains(query) ||
                  section.title.toLowerCase().contains(query);
            }).toList(),
          ),
        )
        .where((section) => section.entries.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: colors.bg,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(shopProfileProvider);
          await Future.wait([
            ref.read(costingProvider.notifier).loadCostingMethod(),
            ref.read(notificationProvider.notifier).loadNotifications(),
            ref.read(shopProvider.notifier).loadUserShops(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: AppResponsiveContent(
            maxWidth: 1200,
            verticalPadding: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppPageHeader(
                  title: tr.settings.systemSettings,
                  subtitle: tr.settings.subtitle,
                  dense: true,
                  action: featureGuideButton(context, 'settings'),
                  compactAction: featureGuideButton(context, 'settings'),
                ),
                _SettingsProfileCard(
                  shopAsync: shopAsync,
                  user: auth.user,
                  shopState: shopState,
                  onOpenProfile: () => context.push('/profile'),
                  onSwitchShop: shopState.userShops.length > 1
                      ? () => _showShopSwitcher(context, shopState)
                      : null,
                  onRetry: shopAsync != null
                      ? () => ref.refresh(shopProfileProvider)
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.divider.withValues(alpha: 0.8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      if (value != _searchQuery) {
                        setState(() => _searchQuery = value);
                      }
                    },
                    style: GoogleFonts.inter(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: tr.settings.searchHint,
                      hintStyle: GoogleFonts.inter(
                        color: colors.textMuted,
                        fontSize: 13.5,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 10),
                        child: Icon(
                          Icons.search_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              color: colors.textSecondary,
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                if (_searchQuery.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_list_rounded,
                          size: 16,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tr.settings.searchResultsFound(
                            filteredSections.fold<int>(
                              0,
                              (sum, s) => sum + s.entries.length,
                            ),
                          ),
                          style: GoogleFonts.inter(
                            color: colors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.close_rounded, size: 14),
                          label: Text(tr.settings.clearFilter),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: colors.textSecondary,
                            textStyle: GoogleFonts.inter(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (filteredSections.isEmpty)
                  AppCardContainer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xl,
                      ),
                      child: Center(
                        child: Text(
                          tr.settings.noSettingsFound,
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ),
                    ),
                  )
                else
                  AppFillGrid(
                    minItemWidth: 420,
                    maxColumns: 2,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      for (final section in filteredSections)
                        _SettingsSection(section: section),
                    ],
                  ),
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(tr.settings.logoutButton),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.35),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await AppConfirmModal.show(
      context,
      title: 'Xác nhận đăng xuất',
      message:
          'Bạn có chắc muốn đăng xuất khỏi ứng dụng? Hãy hoàn tất các thay đổi chưa lưu trước khi tiếp tục.',
      confirmText: 'Đăng xuất',
      cancelText: 'Ở lại',
      isDestructive: true,
    );
    if (confirmed != true) return;

    await ref.read(authProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }

  void _showShopSwitcher(BuildContext context, ShopState shopState) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colors = AppThemeColors.of(sheetContext);
        final availableShops = shopState.userShops
            .where(
              (shop) => shop['status'] == 'ACTIVE' && shop['isActive'] != false,
            )
            .toList();
        final canViewAll = availableShops.any(
          (shop) => shop['memberType'] == 'OWNER',
        );

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chuyển cửa hàng',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Dữ liệu trên màn hình sẽ đổi theo cửa hàng được chọn.',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: ListView(
                      children: [
                        if (canViewAll)
                          _ShopOption(
                            title: 'Tất cả cửa hàng',
                            subtitle: 'Xem dữ liệu tổng hợp của các cửa hàng.',
                            selected: shopState.isAllShops,
                            onTap: () {
                              ref.read(shopProvider.notifier).switchShop(-1);
                              Navigator.pop(sheetContext);
                            },
                          ),
                        for (final shop in availableShops)
                          _ShopOption(
                            title:
                                shop['shopName']?.toString() ??
                                'Cửa hàng #${shop['shopId']}',
                            subtitle: shop['memberType'] == 'OWNER'
                                ? 'Chủ sở hữu'
                                : (shop['role']?['name']?.toString() ??
                                      'Nhân viên'),
                            selected:
                                parseShopRecordId(shop['shopId']) ==
                                    shopState.currentShopId &&
                                !shopState.isAllShops,
                            onTap: () {
                              final shopId = int.tryParse(
                                shop['shopId']?.toString() ?? '',
                              );
                              if (shopId == null) return;
                              ref
                                  .read(shopProvider.notifier)
                                  .switchShop(shopId);
                              Navigator.pop(sheetContext);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLanguagePicker(BuildContext context, AppLanguage current) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colors = AppThemeColors.of(sheetContext);
        final tr = sheetContext.tr;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.settings.selectLanguage,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  tr.settings.languageSubtitle,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final item in AppLanguage.values)
                  _LanguageOption(
                    item: item,
                    selected: item == current,
                    onTap: () {
                      ref.read(localeProvider.notifier).setLanguage(item);
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCostingMethodPicker(BuildContext context) {
    final costing = ref.read(costingProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final colors = AppThemeColors.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phương pháp tính giá vốn',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Cấu hình này được dùng để tính giá vốn và lợi nhuận.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.lg),
                _CostingOption(
                  title: 'Bình quân gia quyền (AVG)',
                  description: 'Tính giá bình quân từ các lô hàng còn tồn kho.',
                  selected: costing.method == 'AVG',
                  onTap: () => _updateCostingMethod(sheetContext, 'AVG'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _CostingOption(
                  title: 'Nhập trước – xuất trước (FIFO)',
                  description:
                      'Ưu tiên giá của lô nhập kho sớm hơn khi xuất bán.',
                  selected: costing.method == 'FIFO',
                  onTap: () => _updateCostingMethod(sheetContext, 'FIFO'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateCostingMethod(
    BuildContext sheetContext,
    String method,
  ) async {
    final currentMethod = ref.read(costingProvider).method;
    Navigator.pop(sheetContext);
    if (method == currentMethod) return;

    final confirmed = await AppConfirmModal.show(
      context,
      title: 'Đổi phương pháp tính giá vốn',
      message:
          'Theo chế độ kế toán và Thông tư 88/2021/TT-BTC, phương pháp tính giá vốn cần áp dụng nhất quán trong niên độ kế toán. Thay đổi giữa kỳ có thể ảnh hưởng đến giá trị tồn kho và lợi nhuận.\n\nBạn có chắc chắn muốn chuyển sang ${method == 'FIFO' ? 'Nhập trước – xuất trước (FIFO)' : 'Bình quân gia quyền (AVG)'}?',
      confirmText: 'Xác nhận thay đổi',
      cancelText: 'Hủy bỏ',
    );
    if (confirmed != true) return;

    final success = await ref
        .read(costingProvider.notifier)
        .updateCostingMethod(method);
    if (success) {
      ToastService.showSuccess('Đã cập nhật phương pháp tính giá vốn.');
    } else {
      ToastService.showError('Không thể cập nhật phương pháp tính giá vốn.');
    }
  }

  Future<void> _showAbout(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    showAboutDialog(
      context: context,
      applicationIcon: const AppAssetIcon(
        assetPath: AppAssets.appIcon,
        size: 44,
        semanticLabel: 'SmartStock',
      ),
      applicationName: 'SmartStock',
      applicationVersion: packageInfo.version,
      applicationLegalese:
          'SmartStock - Quản lý bán hàng & Cảnh báo thuế Hộ Kinh Doanh',
      children: [
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Hệ thống ghi nhận giao dịch bán hàng, quản lý tồn kho, dòng tiền và cảnh báo nghĩa vụ thuế cho Hộ Kinh Doanh tại Việt Nam.',
          style: TextStyle(fontSize: 13, height: 1.45),
        ),
      ],
    );
  }
}

class _SettingsProfileCard extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>>? shopAsync;
  final Map<String, dynamic>? user;
  final ShopState shopState;
  final VoidCallback onOpenProfile;
  final VoidCallback? onSwitchShop;
  final VoidCallback? onRetry;

  const _SettingsProfileCard({
    required this.shopAsync,
    required this.user,
    required this.shopState,
    required this.onOpenProfile,
    required this.onSwitchShop,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final fullName = user?['fullName']?.toString().trim();
    final displayName = fullName == null || fullName.isEmpty
        ? 'Người dùng SmartStock'
        : fullName;

    if (shopState.isAllShops || shopAsync == null) {
      final currentShop = shopState.userShops
          .where(
            (s) => parseShopRecordId(s['shopId']) == shopState.currentShopId,
          )
          .firstOrNull;
      final shopName =
          shopState.currentShopName ??
          currentShop?['shopName']?.toString() ??
          (shopState.currentShopId != null
              ? 'Cửa hàng #${shopState.currentShopId}'
              : 'Tất cả cửa hàng');
      final roleName = shopState.isOwner
          ? 'Chủ sở hữu'
          : (currentShop?['role']?['name']?.toString() ??
                (shopState.memberType == 'OWNER' ? 'Chủ sở hữu' : 'Nhân viên'));

      return AppCardContainer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  shopState.isAllShops
                      ? settingsAllShopsSummary(shopState)
                      : shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  shopState.isAllShops
                      ? 'Chọn một cửa hàng để xem và chỉnh sửa cấu hình riêng.'
                      : 'Vai trò: $roleName${shopState.shopCode != null ? '  ·  Mã CH: ${shopState.shopCode}' : ''}',
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ],
            );
            final actions = Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: onOpenProfile,
                  child: const Text('Xem hồ sơ'),
                ),
                if (onSwitchShop != null)
                  FilledButton.tonal(
                    onPressed: onSwitchShop,
                    child: const Text('Chọn cửa hàng'),
                  ),
              ],
            );

            if (constraints.maxWidth < 640) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppAvatar(
                        size: 48,
                        displayName: displayName,
                        showEditBadge: true,
                        onTap: () => ThemeAppearanceModal.show(context),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: details),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  actions,
                ],
              );
            }

            return Row(
              children: [
                AppAvatar(
                  size: 48,
                  displayName: displayName,
                  showEditBadge: true,
                  onTap: () => ThemeAppearanceModal.show(context),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: details),
                const SizedBox(width: AppSpacing.md),
                actions,
              ],
            );
          },
        ),
      );
    }

    return AppCardContainer(
      child: shopAsync!.when(
        data: (shop) => LayoutBuilder(
          builder: (context, constraints) {
            final shopName =
                shop['shopName']?.toString() ??
                shop['name']?.toString() ??
                'Cửa hàng của tôi';
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'MST: ${shop['taxCode']?.toString() ?? 'Chưa cập nhật'}'
                  '${shopState.isOwner && shopState.shopCode != null ? '  ·  Mã CH: ${shopState.shopCode}' : ''}',
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ],
            );
            final actions = Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: onOpenProfile,
                  child: const Text('Xem hồ sơ'),
                ),
                if (onSwitchShop != null)
                  OutlinedButton(
                    onPressed: onSwitchShop,
                    child: const Text('Đổi cửa hàng'),
                  ),
              ],
            );

            if (constraints.maxWidth < 640) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppAvatar(
                        size: 48,
                        displayName: displayName,
                        showEditBadge: true,
                        onTap: () => ThemeAppearanceModal.show(context),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: details),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  actions,
                ],
              );
            }

            return Row(
              children: [
                AppAvatar(
                  size: 48,
                  displayName: displayName,
                  showEditBadge: true,
                  onTap: () => ThemeAppearanceModal.show(context),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: details),
                const SizedBox(width: AppSpacing.md),
                actions,
              ],
            );
          },
        ),
        loading: () => const SizedBox(
          height: 72,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => Row(
          children: [
            const AppAssetIcon(
              assetPath: AppAssets.appIcon,
              size: 44,
              semanticLabel: 'SmartStock',
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Chưa tải được thông tin chi tiết cửa hàng.',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (onRetry != null)
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Thử lại'),
              ),
            const SizedBox(width: AppSpacing.xs),
            TextButton(
              onPressed: onOpenProfile,
              child: const Text('Xem hồ sơ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionData {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<_SettingsEntry> entries;

  const _SettingsSectionData({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.entries,
  });
}

class _SettingsEntry {
  final String label;
  final String description;
  final IconData? icon;
  final String? assetPath;
  final Color? iconColor;
  final String? badge;
  final VoidCallback? onTap;

  const _SettingsEntry({
    required this.label,
    required this.description,
    this.icon,
    this.assetPath,
    this.iconColor,
    this.badge,
    required this.onTap,
  });
}

class _SettingsSection extends StatelessWidget {
  final _SettingsSectionData section;

  const _SettingsSection({required this.section});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.divider.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section Header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: colors.card,
                border: Border(
                  bottom: BorderSide(
                    color: colors.divider.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: section.iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      section.icon,
                      color: section.iconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      section.title,
                      style: GoogleFonts.manrope(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.divider.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      context.tr.settings.itemsCount(section.entries.length),
                      style: GoogleFonts.inter(
                        color: colors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Entries List
            for (var index = 0; index < section.entries.length; index++)
              _SettingsActionRow(
                entry: section.entries[index],
                showDivider: index < section.entries.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  final _SettingsEntry entry;
  final bool showDivider;

  const _SettingsActionRow({required this.entry, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final iconColor = entry.iconColor ?? colors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: entry.onTap,
        hoverColor: AppColors.primary.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(
                    bottom: BorderSide(
                      color: colors.divider.withValues(alpha: 0.5),
                    ),
                  )
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: entry.assetPath != null
                    ? AppAssetIcon(
                        assetPath: entry.assetPath!,
                        size: 20,
                        color: iconColor,
                        semanticLabel: entry.label,
                      )
                    : (entry.icon != null
                          ? Icon(entry.icon, size: 20, color: iconColor)
                          : const SizedBox.shrink()),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label,
                      style: GoogleFonts.manrope(
                        color: entry.onTap == null
                            ? colors.textMuted
                            : colors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.description,
                      style: GoogleFonts.inter(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (entry.badge != null)
                AppStatusBadge(
                  label: entry.badge!,
                  color: Theme.of(context).colorScheme.primary,
                )
              else if (entry.onTap == null)
                Text(
                  'Đang tải',
                  style: GoogleFonts.inter(
                    color: colors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: colors.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ShopOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected ? primary.withValues(alpha: 0.07) : colors.card,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: selected ? primary : colors.divider),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  AppStatusBadge(label: 'Đang dùng', color: primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CostingOption extends StatelessWidget {
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _CostingOption({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? primary.withValues(alpha: 0.07) : colors.card,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: selected ? primary : colors.divider),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      description,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: AppSpacing.md),
                AppStatusBadge(label: 'Đang dùng', color: primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final AppLanguage item;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected ? primary.withValues(alpha: 0.08) : colors.card,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: selected ? primary : colors.divider,
            width: selected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 4,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.divider),
                  ),
                  alignment: Alignment.center,
                  child: Text(item.flag, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.englishLabel,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: primary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
