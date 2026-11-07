import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/assets/app_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:google_fonts/google_fonts.dart';
import '../../core/assets/app_assets.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/translations/app_translations.dart';
import '../../core/network/api_client.dart';
import '../../core/providers/reporting_period_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_background_wrapper.dart';
import '../../core/utils/reporting_period.dart';
import '../../core/widgets/ai_assistant_widget.dart';
import '../../core/widgets/global_search_delegate.dart';
import '../../core/widgets/reporting_period_control.dart';
import '../settings/presentation/shop_payment_qr_dialog.dart';
import '../settings/providers/shop_provider.dart';
import '../settings/providers/notification_provider.dart';
import '../dashboard/providers/dashboard_action_provider.dart';

enum MainShellNavigationMode { bottomBar, rail, sidebar }

MainShellNavigationMode navigationModeForWidth(double width) {
  if (width < AppBreakpoints.compactNavigation) {
    return MainShellNavigationMode.bottomBar;
  }
  if (width < AppBreakpoints.expandedNavigation) {
    return MainShellNavigationMode.rail;
  }
  return MainShellNavigationMode.sidebar;
}

double mobileNavigationItemWidth(double width, int itemCount) {
  if (itemCount <= 0) return 0;
  final available = width - 16;
  if (itemCount <= 2) {
    return (available / itemCount).clamp(132.0, 190.0).toDouble();
  }
  return available / itemCount;
}

bool shouldShowAiAssistant({
  required String location,
  required double viewportWidth,
}) {
  final isSalesEntry =
      location == '/sales/new' ||
      location.startsWith('/sales/new/') ||
      location == '/pos' ||
      location.startsWith('/pos/');
  final isQr = location == '/qr-payment' || location.startsWith('/qr-payment/');
  return !isSalesEntry && !isQr;
}

bool shouldShowShellUtilityHeader(String location) {
  return const {
    '/',
    '/sales',
    '/products',
    '/customers',
    '/suppliers',
    '/inventory',
    '/finance',
    '/customer-debts',
    '/settings',
  }.contains(location);
}

bool shouldShowShopPaymentQr({required bool isAllShops}) => !isAllShops;

double desktopSidebarWidth(bool collapsed) => collapsed ? 72 : 232;

List<Map<String, dynamic>> shellSelectableShops(ShopState state) => state
    .userShops
    .where(
      (shop) =>
          shop['status'] == 'ACTIVE' &&
          shop['isActive'] != false &&
          parseShopRecordId(shop['shopId']) != null,
    )
    .toList(growable: false);

bool shellCanSwitchShops(ShopState state) =>
    shellSelectableShops(state).length > 1;

String shellShopContextLabel(ShopState state, [AppTranslations? tr]) {
  if (tr != null) {
    return shellCanSwitchShops(state) || state.isAllShops
        ? tr.nav.viewingScope
        : tr.nav.store;
  }
  return shellCanSwitchShops(state) || state.isAllShops
      ? 'PHẠM VI ĐANG XEM'
      : 'CỬA HÀNG';
}

class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  static const _sidebarCollapsedKey = 'main_sidebar_collapsed_v1';
  bool _sidebarCollapsed = false;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _restoreSidebarState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_refreshNotifications);
    _notificationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
        _refreshNotifications();
      }
    });
  }

  void _refreshNotifications() {
    if (!mounted) return;
    ref.read(notificationProvider.notifier).loadUnreadCount();
    if (canViewDashboardActions(ref.read(shopProvider))) {
      ref.invalidate(dashboardActionProvider);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshNotifications();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _restoreSidebarState() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sidebarCollapsed = preferences.getBool(_sidebarCollapsedKey) ?? false;
    });
  }

  Future<void> _toggleSidebar() async {
    final next = !_sidebarCollapsed;
    setState(() => _sidebarCollapsed = next);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_sidebarCollapsedKey, next);
  }

  int _currentIndex(BuildContext context, List<_NavDef> visibleTabs) {
    final location = GoRouterState.of(context).uri.toString();
    for (var i = 0; i < visibleTabs.length; i++) {
      if (visibleTabs[i].matchesRoute(location)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final tr = context.tr;
    final shop = ref.watch(shopProvider);
    final notifications = ref.watch(notificationProvider);
    final unread = notifications.unreadCount;
    final actionState = canViewDashboardActions(shop)
        ? ref.watch(dashboardActionProvider)
        : null;
    final actions = actionState?.asData?.value.items.length ?? 0;
    final countHint =
        notifications.errorMessage == 'Không thể tải số thông báo chưa đọc.'
        ? 'Chưa cập nhật được số thông báo chưa đọc'
        : '$unread thông báo tài khoản chưa đọc';
    final actionHint = actionState?.hasError == true
        ? 'Chưa tải được việc cần xử lý'
        : actionState?.isLoading == true
        ? 'Đang cập nhật việc cần xử lý'
        : '$actions nhóm việc cần xử lý';
    final notificationHint = '$countHint · $actionHint';
    final tabs = <_NavDef>[
      _NavDef(
        assetPath: AppAssets.home,
        label: tr.nav.home,
        route: '/',
        prefixes: const ['/'],
      ),
      if (!shop.isAllShops && shop.hasPermission('sales'))
        _NavDef(
          assetPath: AppAssets.orders,
          label: tr.nav.sales,
          route: '/sales',
          prefixes: const ['/sales', '/pos'],
        ),
      if (!shop.isAllShops && shop.hasPermission('inventory'))
        _NavDef(
          assetPath: AppAssets.inventory,
          label: tr.nav.inventory,
          route: '/inventory',
          prefixes: const [
            '/inventory',
            '/products',
            '/purchase-orders',
            '/stock',
            '/xnt',
          ],
        ),
      if (!shop.isAllShops && shop.hasPermission('finance'))
        _NavDef(
          assetPath: AppAssets.cash,
          label: tr.nav.finance,
          route: '/finance',
          prefixes: const [
            '/finance',
            '/daily',
            '/profit',
            '/cashflow',
            '/debt',
            '/invoices',
            '/tax-calculator',
            '/expense-ledger',
            '/tax-obligations',
            '/salary-ledger',
            '/tax-declaration',
            '/transactions',
            '/purchases-no-invoice',
            '/invoice-scans',
            '/tax-estimate',
            '/supplier-payables-aging',
          ],
        ),
      _NavDef(
        assetPath: AppAssets.settings,
        label: tr.nav.settings,
        route: '/settings',
        prefixes: const [
          '/settings',
          '/activity',
          '/tax-config',
          '/tax-support',
          '/payment-config',
          '/staff',
          '/roles',
          '/profile',
          '/shop-profile',
          '/notifications',
        ],
      ),
    ];
    final currentIndex = _currentIndex(context, tabs);

    return LayoutBuilder(
      builder: (context, constraints) {
        final mode = navigationModeForWidth(constraints.maxWidth);
        final location = GoRouterState.of(context).uri.path;
        final showUtilityHeader = shouldShowShellUtilityHeader(location);
        final showAi = shouldShowAiAssistant(
          location: location,
          viewportWidth: constraints.maxWidth,
        );
        final showAiHeaderAction = showAi;

        final page = Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                if (showUtilityHeader)
                  _ShellUtilityHeader(
                    compact: mode == MainShellNavigationMode.bottomBar,
                    shop: shop,
                    currentPath: location,
                    showAiRestore: showAiHeaderAction,
                    showShopQr: shouldShowShopPaymentQr(
                      isAllShops: shop.isAllShops,
                    ),
                    notificationCount: unread + actions,
                    notificationHint: notificationHint,
                    onSearch: () async {
                      final route = await showGlobalSearchPanel(
                        context,
                        api: ref.read(apiClientProvider),
                      );
                      if (route != null &&
                          route.isNotEmpty &&
                          context.mounted) {
                        context.go(route);
                      }
                    },
                    onNotifications: () => context.go('/notifications'),
                    onShopSelected: (shopId) =>
                        ref.read(shopProvider.notifier).switchShop(shopId),
                    onShopQr: () => showShopPaymentQrDialog(
                      context,
                      canManage:
                          shop.isOwner ||
                          shop.hasPermission('settings', 'edit'),
                    ),
                    onRestoreAi: () {
                      ref
                          .read(aiAssistantLauncherVisibleProvider.notifier)
                          .show();
                      ref.read(aiAssistantOpenProvider.notifier).open();
                    },
                  ),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey(
                      'shop-${shop.currentShopId}-${shop.isAllShops}',
                    ),
                    child: widget.child,
                  ),
                ),
              ],
            ),
            if (showAi)
              Positioned.fill(
                child: AiAssistantWidget(
                  showLauncher: false,
                  topSafeInset: showUtilityHeader
                      ? mode == MainShellNavigationMode.bottomBar
                            ? 60
                            : 68
                      : 0,
                ),
              ),
          ],
        );

        late final Widget navigationShell;
        if (mode == MainShellNavigationMode.sidebar) {
          navigationShell = Scaffold(
            backgroundColor: Colors.transparent,
            body: Row(
              children: [
                _NavigationSurface(
                  child: _DesktopSidebar(
                    tabs: tabs,
                    currentIndex: currentIndex,
                    collapsed: _sidebarCollapsed,
                    onToggleCollapsed: _toggleSidebar,
                  ),
                ),
                VerticalDivider(width: 1, color: colors.divider),
                Expanded(child: page),
              ],
            ),
          );
        } else if (mode == MainShellNavigationMode.rail) {
          navigationShell = Scaffold(
            backgroundColor: Colors.transparent,
            body: Row(
              children: [
                _NavigationSurface(
                  child: _TabletNavigationRail(
                    tabs: tabs,
                    currentIndex: currentIndex,
                  ),
                ),
                VerticalDivider(width: 1, color: colors.divider),
                Expanded(child: page),
              ],
            ),
          );
        } else {
          navigationShell = Scaffold(
            backgroundColor: Colors.transparent,
            body: page,
            bottomNavigationBar: _MobileNavigationBar(
              tabs: tabs,
              currentIndex: currentIndex,
            ),
          );
        }

        return ColoredBox(
          color: colors.bg,
          child: SafeArea(child: AppBackgroundWrapper(child: navigationShell)),
        );
      },
    );
  }
}

class _ShellUtilityHeader extends StatelessWidget {
  final bool compact;
  final ShopState shop;
  final String currentPath;
  final bool showAiRestore;
  final bool showShopQr;
  final int notificationCount;
  final String notificationHint;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final ValueChanged<int> onShopSelected;
  final VoidCallback onShopQr;
  final VoidCallback onRestoreAi;

  const _ShellUtilityHeader({
    required this.compact,
    required this.shop,
    required this.currentPath,
    required this.showAiRestore,
    required this.showShopQr,
    required this.notificationCount,
    required this.notificationHint,
    required this.onSearch,
    required this.onNotifications,
    required this.onShopSelected,
    required this.onShopQr,
    required this.onRestoreAi,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final resolvedShop = shop.currentShopName?.trim().isNotEmpty == true
        ? shop.currentShopName!
        : 'Cửa hàng';
    final selectableShops = shellSelectableShops(shop);
    final canSwitchShop = selectableShops.length > 1;
    final showPeriodFilter = !currentPath.startsWith('/settings');

    Widget shopSummary() => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact)
          Text(
            shellShopContextLabel(shop, context.tr),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                resolvedShop,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontSize: compact ? 14 : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (canSwitchShop) ...[
              const SizedBox(width: 4),
              AppIcon(
                Icons.keyboard_arrow_down_rounded,
                size: 15,
                color: colors.textSecondary,
              ),
            ],
          ],
        ),
      ],
    );

    final shopIdentity = canSwitchShop
        ? Semantics(
            button: true,
            label:
                '${context.tr.settings.switchShop}. ${context.tr.settings.viewingShop(resolvedShop)}',
            child: PopupMenuButton<int>(
              tooltip: context.tr.settings.switchShop,
              onSelected: onShopSelected,
              position: PopupMenuPosition.under,
              itemBuilder: (context) => [
                for (final item in selectableShops)
                  PopupMenuItem<int>(
                    value: parseShopRecordId(item['shopId']),
                    child: _ShopMenuItem(
                      name:
                          item['shopName']?.toString() ?? context.tr.nav.store,
                      selected:
                          !shop.isAllShops &&
                          parseShopRecordId(item['shopId']) ==
                              shop.currentShopId,
                    ),
                  ),
                const PopupMenuDivider(),
                PopupMenuItem<int>(
                  value: -1,
                  child: _ShopMenuItem(
                    name: context.tr.settings.allShops,
                    selected: shop.isAllShops,
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: shopSummary(),
              ),
            ),
          )
        : shopSummary();

    return Material(
      color: colors.surface,
      child: Container(
        height: compact ? 60 : 68,
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 24),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider)),
        ),
        child: Row(
          children: [
            if (compact) ...[
              Container(
                width: 28,
                height: 28,
                child: const AppAssetIcon(
                  assetPath: AppAssets.appIcon,
                  size: 26,
                  semanticLabel: 'SmartStock',
                ),
              ),
              const SizedBox(width: 11),
            ],
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Tooltip(message: resolvedShop, child: shopIdentity),
              ),
            ),
            if (compact) ...[
              if (showPeriodFilter) ...[
                _HeaderPeriodButtonCompact(currentPath: currentPath),
                const SizedBox(width: AppSpacing.xs),
              ],
              _HeaderAssetButton(
                assetPath: AppAssets.notification,
                semanticLabel: notificationHint,
                badgeCount: notificationCount,
                onPressed: onNotifications,
              ),
              if (showAiRestore || showShopQr)
                PopupMenuButton<String>(
                  tooltip: context.isEnglish ? 'Utilities' : 'Tiện ích',
                  icon: AppIcon(
                    Icons.more_horiz_rounded,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                  onSelected: (value) {
                    if (value == 'assistant') onRestoreAi();
                    if (value == 'qr') onShopQr();
                  },
                  itemBuilder: (_) => [
                    if (showAiRestore)
                      PopupMenuItem(
                        value: 'assistant',
                        child: Row(
                          children: [
                            AppAssetIcon(
                              assetPath: AppAssets.assistant,
                              size: 20,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Text(context.tr.nav.aiAssistantTitle),
                          ],
                        ),
                      ),
                    if (showShopQr)
                      PopupMenuItem(
                        value: 'qr',
                        child: Row(
                          children: [
                            AppAssetIcon(
                              assetPath: AppAssets.qrPayment,
                              size: 20,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              context.isEnglish
                                  ? 'Open store QR'
                                  : 'Mở QR của cửa hàng',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
            if (!compact) ...[
              if (showPeriodFilter) ...[
                _HeaderPeriodSelector(currentPath: currentPath),
                const SizedBox(width: AppSpacing.sm),
              ],
              IconButton(
                tooltip: context.tr.nav.searchPlaceholder,
                onPressed: onSearch,
                style: IconButton.styleFrom(
                  foregroundColor: colors.textMuted,
                  backgroundColor: Colors.transparent,
                ),
                icon: AppAssetIcon(
                  assetPath: AppAssets.search,
                  size: 17,
                  semanticLabel: context.tr.common.search,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (showAiRestore) ...[
                _HeaderAssetButton(
                  assetPath: AppAssets.assistant,
                  semanticLabel: context.tr.nav.aiAssistantTitle,
                  label: MediaQuery.sizeOf(context).width >= 1100
                      ? (context.isEnglish ? 'Assistant' : 'Trợ lý')
                      : null,
                  onPressed: onRestoreAi,
                  preserveAssetColor: false,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              if (showShopQr) ...[
                _HeaderAssetButton(
                  assetPath: AppAssets.qrPayment,
                  label: MediaQuery.sizeOf(context).width >= 1100 ? 'QR' : null,
                  semanticLabel: context.isEnglish
                      ? 'Open store QR'
                      : 'Mở QR của cửa hàng',
                  onPressed: onShopQr,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              _HeaderAssetButton(
                assetPath: AppAssets.notification,
                label: MediaQuery.sizeOf(context).width >= 1100
                    ? (context.isEnglish ? 'Notifications' : 'Thông báo')
                    : null,
                semanticLabel: notificationHint,
                badgeCount: notificationCount,
                onPressed: onNotifications,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderPeriodSelector extends ConsumerWidget {
  final String currentPath;

  const _HeaderPeriodSelector({required this.currentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final tr = context.tr;
    final tabKey = resolveTabKeyFromLocation(currentPath);
    final tabName = resolveTabName(tabKey, tr);
    final selection = ref.watch(tabSelectionProvider(tabKey));
    final resolved = ref.watch(tabResolvedPeriodProvider(tabKey));

    final periodLabel = reportingCompactRangeLabel(
      resolved.currentFrom,
      resolved.currentTo,
    );
    final periodName = reportingPeriodSelectionLabel(
      selection,
      DateTime.now(),
      tr,
    );

    return Material(
      color: colors.cardAlt,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () async {
          final updated = await showReportingPeriodEditor(
            context,
            initialSelection: selection,
            today: DateTime.now(),
          );
          if (updated != null) {
            ref
                .read(reportingPeriodNotifierProvider.notifier)
                .setPeriodForTab(tabKey, updated);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAssetIcon(
                assetPath: AppAssets.calendar,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tabName,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$periodName · $periodLabel',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              AppAssetIcon(
                assetPath: AppAssets.expand,
                size: 14,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderPeriodButtonCompact extends ConsumerWidget {
  final String currentPath;

  const _HeaderPeriodButtonCompact({required this.currentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final tabKey = resolveTabKeyFromLocation(currentPath);
    final selection = ref.watch(tabSelectionProvider(tabKey));

    return IconButton(
      tooltip: context.isEnglish ? 'Reporting period' : 'Chọn kỳ báo cáo',
      onPressed: () async {
        final updated = await showReportingPeriodEditor(
          context,
          initialSelection: selection,
          today: DateTime.now(),
        );
        if (updated != null) {
          ref
              .read(reportingPeriodNotifierProvider.notifier)
              .setPeriodForTab(tabKey, updated);
        }
      },
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: AppAssetIcon(
        assetPath: AppAssets.calendar,
        size: 20,
        color: colors.textSecondary,
      ),
    );
  }
}

class _ShopMenuItem extends StatelessWidget {
  final String name;
  final bool selected;

  const _ShopMenuItem({required this.name, required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        if (selected) ...[
          const SizedBox(width: AppSpacing.md),
          AppAssetIcon(
            assetPath: AppAssets.check,
            size: 16,
            color: colors.primary,
            semanticLabel: 'Đã chọn',
          ),
        ],
      ],
    );
  }
}

class _HeaderAssetButton extends StatelessWidget {
  final String assetPath;
  final String semanticLabel;
  final VoidCallback onPressed;
  final bool preserveAssetColor;
  final String? label;
  final int badgeCount;

  const _HeaderAssetButton({
    required this.assetPath,
    required this.semanticLabel,
    required this.onPressed,
    this.preserveAssetColor = false,
    this.label,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    final icon = Badge(
      isLabelVisible: badgeCount > 0,
      label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
      child: AppAssetIcon(
        assetPath: assetPath,
        size: 20,
        color: preserveAssetColor ? null : colors.textSecondary,
      ),
    );
    if (label != null) {
      return Tooltip(
        message: semanticLabel,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: icon,
          label: Text(label!),
          style: TextButton.styleFrom(
            foregroundColor: colors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 40),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: semanticLabel,
      child: IconButton(
        tooltip: semanticLabel,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: icon,
      ),
    );
  }
}

class _NavigationSurface extends StatelessWidget {
  const _NavigationSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: colors.divider)),
      ),
      child: child,
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final List<_NavDef> tabs;
  final int currentIndex;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  const _DesktopSidebar({
    required this.tabs,
    required this.currentIndex,
    required this.collapsed,
    required this.onToggleCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        right: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: desktopSidebarWidth(collapsed),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 68,
                padding: EdgeInsets.symmetric(horizontal: collapsed ? 15 : 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: colors.divider, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    const _SidebarLogo(),
                    if (!collapsed) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'SmartStock',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.35,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!collapsed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                  child: Text(
                    context.tr.nav.mainNavigation,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    collapsed ? 8 : 10,
                    collapsed ? 14 : 0,
                    collapsed ? 8 : 10,
                    12,
                  ),
                  itemCount: tabs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) => _SidebarNavItem(
                    definition: tabs[index],
                    selected: index == currentIndex,
                    collapsed: collapsed,
                  ),
                ),
              ),
              Divider(height: 1, color: colors.divider),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  collapsed ? 8 : 10,
                  8,
                  collapsed ? 8 : 10,
                  12,
                ),
                child: Column(
                  children: [
                    _SidebarUtilityItem(
                      label: context.tr.nav.helpCenter,
                      assetPath: AppAssets.help,
                      collapsed: collapsed,
                      onPressed: () => context.push('/help-center'),
                    ),
                    const SizedBox(height: 4),
                    _SidebarUtilityItem(
                      label: collapsed
                          ? context.tr.nav.expand
                          : context.tr.nav.collapse,
                      tooltip: collapsed
                          ? context.tr.nav.expandTooltip
                          : context.tr.nav.collapseTooltip,
                      assetPath: collapsed
                          ? AppAssets.panelExpand
                          : AppAssets.panelCollapse,
                      collapsed: collapsed,
                      onPressed: onToggleCollapsed,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarLogo extends StatelessWidget {
  const _SidebarLogo();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = colors.primary;
    return Container(
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.divider),
      ),
      child: const AppAssetIcon(
        assetPath: AppAssets.appIcon,
        size: 26,
        semanticLabel: 'SmartStock',
      ),
    );
  }
}

class _SidebarUtilityItem extends StatelessWidget {
  final String label;
  final String? tooltip;
  final String assetPath;
  final bool collapsed;
  final VoidCallback onPressed;

  const _SidebarUtilityItem({
    required this.label,
    this.tooltip,
    required this.assetPath,
    required this.collapsed,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    final item = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 14 : 12),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                AppAssetIcon(
                  assetPath: assetPath,
                  size: 19,
                  color: colors.textMuted,
                  semanticLabel: label,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return collapsed ? Tooltip(message: tooltip ?? label, child: item) : item;
  }
}

class _SidebarNavItem extends StatelessWidget {
  final _NavDef definition;
  final bool selected;
  final bool collapsed;

  const _SidebarNavItem({
    required this.definition,
    required this.selected,
    required this.collapsed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = colors.primary;

    final item = Semantics(
      button: true,
      selected: selected,
      label: 'Điều hướng đến ${definition.label}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(definition.route),
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 14 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: selected ? colors.primarySubtle : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(
                color: selected
                    ? primary.withValues(alpha: 0.25)
                    : Colors.transparent,
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                AppAssetIcon(
                  assetPath: definition.assetPath,
                  size: 20,
                  color: selected ? primary : colors.textMuted,
                  semanticLabel: definition.label,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      definition.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? primary : colors.textPrimary,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return collapsed ? Tooltip(message: definition.label, child: item) : item;
  }
}

class _TabletNavigationRail extends StatelessWidget {
  final List<_NavDef> tabs;
  final int currentIndex;

  const _TabletNavigationRail({required this.tabs, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 92,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.cardAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.divider),
                  ),
                  child: const AppAssetIcon(
                    assetPath: AppAssets.appIcon,
                    size: 30,
                    semanticLabel: 'SmartStock',
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: tabs.length,
                  itemBuilder: (context, index) => _RailNavItem(
                    definition: tabs[index],
                    selected: index == currentIndex,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/help-center'),
                style: TextButton.styleFrom(foregroundColor: primary),
                child: const Text('Trợ giúp', textAlign: TextAlign.center),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailNavItem extends StatelessWidget {
  final _NavDef definition;
  final bool selected;

  const _RailNavItem({required this.definition, required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Semantics(
      button: true,
      selected: selected,
      label: definition.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: () => context.go(definition.route),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAssetIcon(
                assetPath: definition.assetPath,
                size: 20,
                color: selected ? primary : colors.textMuted,
                semanticLabel: definition.label,
              ),
              const SizedBox(height: 5),
              Text(
                definition.label,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? primary : colors.textMuted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavigationBar extends StatelessWidget {
  final List<_NavDef> tabs;
  final int currentIndex;

  const _MobileNavigationBar({required this.tabs, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final labelHeight = MediaQuery.textScalerOf(context).scale(10) * 2.4;
    final navigationHeight = labelHeight + 40 < 68 ? 68.0 : labelHeight + 40;

    Widget buildItem(int index) => Semantics(
      button: true,
      selected: index == currentIndex,
      label: tabs[index].label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: () => context.go(tabs[index].route),
        child: Container(
          decoration: BoxDecoration(
            color: index == currentIndex
                ? primary.withValues(alpha: 0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAssetIcon(
                assetPath: tabs[index].assetPath,
                size: 19,
                color: index == currentIndex ? primary : colors.textMuted,
                semanticLabel: tabs[index].label,
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: labelHeight,
                child: Text(
                  tabs[index].label,
                  maxLines: 2,
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    height: 1.2,
                    color: index == currentIndex ? primary : colors.textMuted,
                    fontWeight: index == currentIndex
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Container(
          height: navigationHeight,
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.divider)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1417324D),
                blurRadius: 14,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (tabs.length <= 2) {
                final itemWidth = mobileNavigationItemWidth(
                  constraints.maxWidth + 16,
                  tabs.length,
                );
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 0; index < tabs.length; index++)
                      SizedBox(width: itemWidth, child: buildItem(index)),
                  ],
                );
              }

              return Row(
                children: [
                  for (var index = 0; index < tabs.length; index++)
                    Expanded(child: buildItem(index)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavDef {
  final String assetPath;
  final String label;
  final String route;
  final List<String> prefixes;

  const _NavDef({
    required this.assetPath,
    required this.label,
    required this.route,
    required this.prefixes,
  });

  bool matchesRoute(String location) {
    if (route == '/') return location == '/';
    return prefixes.any(location.startsWith);
  }
}
