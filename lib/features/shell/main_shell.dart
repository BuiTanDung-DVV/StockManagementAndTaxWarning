import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/assets/app_assets.dart';
import '../../core/constants/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ai_assistant_widget.dart';
import '../../core/widgets/global_search_delegate.dart';
import '../settings/presentation/shop_payment_qr_dialog.dart';
import '../settings/providers/shop_provider.dart';

enum MainShellNavigationMode { bottomBar, rail, sidebar }

abstract final class _ShellPalette {
  static const navy = Color(0xFF102A43);
  static const cyan = Color(0xFF38BDF8);
  static const text = Color(0xFFF4F8FC);
  static const muted = Color(0xFFAAC0D4);
}

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

String shellShopContextLabel(ShopState state) =>
    shellCanSwitchShops(state) || state.isAllShops
    ? 'PHẠM VI ĐANG XEM'
    : 'CỬA HÀNG';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _sidebarCollapsedKey = 'main_sidebar_collapsed_v1';
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _restoreSidebarState();
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
    final shop = ref.watch(shopProvider);
    final tabs = <_NavDef>[
      _NavDef(
        assetPath: AppAssets.home,
        label: AppStrings.navHome,
        route: '/',
        prefixes: const ['/'],
      ),
      if (!shop.isAllShops && shop.hasPermission('sales'))
        _NavDef(
          assetPath: AppAssets.orders,
          label: AppStrings.navSales,
          route: '/sales',
          prefixes: const ['/sales', '/pos'],
        ),
      if (!shop.isAllShops && shop.hasPermission('inventory'))
        _NavDef(
          assetPath: AppAssets.inventory,
          label: AppStrings.navInventory,
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
          label: AppStrings.navFinance,
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
        label: AppStrings.navSettings,
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

        final page = ColoredBox(
          color: colors.bg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  if (showUtilityHeader)
                    _ShellUtilityHeader(
                      compact: mode == MainShellNavigationMode.bottomBar,
                      shop: shop,
                      showAiRestore: showAiHeaderAction,
                      showShopQr: shouldShowShopPaymentQr(
                        isAllShops: shop.isAllShops,
                      ),
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
                  Expanded(child: widget.child),
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
          ),
        );

        late final Widget navigationShell;
        if (mode == MainShellNavigationMode.sidebar) {
          navigationShell = Scaffold(
            backgroundColor: colors.bg,
            body: Row(
              children: [
                _DesktopSidebar(
                  tabs: tabs,
                  currentIndex: currentIndex,
                  collapsed: _sidebarCollapsed,
                  onToggleCollapsed: _toggleSidebar,
                ),
                VerticalDivider(width: 1, color: colors.divider),
                Expanded(child: page),
              ],
            ),
          );
        } else if (mode == MainShellNavigationMode.rail) {
          navigationShell = Scaffold(
            backgroundColor: colors.bg,
            body: Row(
              children: [
                _TabletNavigationRail(tabs: tabs, currentIndex: currentIndex),
                VerticalDivider(width: 1, color: colors.divider),
                Expanded(child: page),
              ],
            ),
          );
        } else {
          navigationShell = Scaffold(
            backgroundColor: colors.bg,
            body: page,
            bottomNavigationBar: _MobileNavigationBar(
              tabs: tabs,
              currentIndex: currentIndex,
            ),
          );
        }

        return navigationShell;
      },
    );
  }
}

class _ShellUtilityHeader extends StatelessWidget {
  final bool compact;
  final ShopState shop;
  final bool showAiRestore;
  final bool showShopQr;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final ValueChanged<int> onShopSelected;
  final VoidCallback onShopQr;
  final VoidCallback onRestoreAi;

  const _ShellUtilityHeader({
    required this.compact,
    required this.shop,
    required this.showAiRestore,
    required this.showShopQr,
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

    Widget shopSummary() => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact)
          Text(
            shellShopContextLabel(shop),
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
                compact ? 'SmartStock · $resolvedShop' : resolvedShop,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (canSwitchShop) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
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
            label: 'Chuyển cửa hàng. Đang xem $resolvedShop',
            child: PopupMenuButton<int>(
              tooltip: 'Chuyển cửa hàng',
              onSelected: onShopSelected,
              position: PopupMenuPosition.under,
              itemBuilder: (context) => [
                for (final item in selectableShops)
                  PopupMenuItem<int>(
                    value: parseShopRecordId(item['shopId']),
                    child: _ShopMenuItem(
                      name: item['shopName']?.toString() ?? 'Cửa hàng',
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
                    name: 'Tất cả cửa hàng',
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
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D17324D),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (compact) ...[
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: colors.cardAlt,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: colors.divider),
                ),
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
                child: shopIdentity,
              ),
            ),
            if (compact) ...[
              const SizedBox(width: AppSpacing.xs),
              if (showAiRestore) ...[
                _HeaderAssetButton(
                  assetPath: AppAssets.aiMascot,
                  semanticLabel: 'Hiển thị nút AI',
                  onPressed: onRestoreAi,
                  preserveAssetColor: true,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              if (showShopQr) ...[
                _HeaderAssetButton(
                  assetPath: AppAssets.qrPayment,
                  semanticLabel: 'Mở QR của cửa hàng',
                  onPressed: onShopQr,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              _HeaderAssetButton(
                assetPath: AppAssets.notification,
                semanticLabel: 'Mở thông báo',
                onPressed: onNotifications,
              ),
            ],
            if (!compact) ...[
              OutlinedButton(
                onPressed: onSearch,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(220, 40),
                  alignment: Alignment.centerLeft,
                  foregroundColor: colors.textMuted,
                  backgroundColor: colors.cardAlt,
                  side: BorderSide(color: colors.divider),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppAssetIcon(
                      assetPath: AppAssets.search,
                      size: 17,
                      semanticLabel: 'Tìm kiếm',
                    ),
                    SizedBox(width: 9),
                    Text('Tìm sản phẩm, đơn hàng...'),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (showAiRestore) ...[
                _HeaderAssetButton(
                  assetPath: AppAssets.aiMascot,
                  semanticLabel: 'Hiển thị nút AI',
                  onPressed: onRestoreAi,
                  preserveAssetColor: true,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              if (showShopQr) ...[
                _HeaderAssetButton(
                  assetPath: AppAssets.qrPayment,
                  semanticLabel: 'Mở QR của cửa hàng',
                  onPressed: onShopQr,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              _HeaderAssetButton(
                assetPath: AppAssets.notification,
                semanticLabel: 'Mở thông báo',
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
          Icon(
            Icons.check_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
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

  const _HeaderAssetButton({
    required this.assetPath,
    required this.semanticLabel,
    required this.onPressed,
    this.preserveAssetColor = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: Material(
          color: colors.cardAlt,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: colors.divider),
              ),
              child: AppAssetIcon(
                assetPath: assetPath,
                size: 19,
                color: preserveAssetColor ? null : primary,
                semanticLabel: semanticLabel,
              ),
            ),
          ),
        ),
      ),
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
    return ColoredBox(
      color: _ShellPalette.navy,
      child: SafeArea(
        right: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: desktopSidebarWidth(collapsed),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 72,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: collapsed ? 15 : 16,
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
                                  color: _ShellPalette.text,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.35,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              if (!collapsed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                  child: Text(
                    'CHỨC NĂNG CHÍNH',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _ShellPalette.muted,
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
              const Divider(height: 1, color: Colors.white12),
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
                      label: 'Trung tâm trợ giúp',
                      assetPath: AppAssets.help,
                      collapsed: collapsed,
                      onPressed: () => context.push('/settings/ai-knowledge'),
                    ),
                    const SizedBox(height: 4),
                    _SidebarUtilityItem(
                      label: collapsed ? 'Mở rộng' : 'Thu gọn',
                      tooltip: collapsed
                          ? 'Mở rộng thanh điều hướng'
                          : 'Thu gọn thanh điều hướng',
                      assetPath: collapsed
                          ? AppAssets.expand
                          : AppAssets.collapse,
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
    return Container(
      width: 38,
      height: 38,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const AppAssetIcon(
        assetPath: AppAssets.appIcon,
        size: 28,
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
                  color: _ShellPalette.muted,
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
                        color: _ShellPalette.muted,
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
    final item = Semantics(
      button: true,
      selected: selected,
      label: 'Điều hướng đến ${definition.label}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(definition.route),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 14 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(
                  color: selected ? _ShellPalette.cyan : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                AppAssetIcon(
                  assetPath: definition.assetPath,
                  size: 20,
                  color: selected ? _ShellPalette.cyan : _ShellPalette.muted,
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
                        color: selected
                            ? _ShellPalette.text
                            : _ShellPalette.muted,
                        fontWeight: selected
                            ? FontWeight.w700
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
    return ColoredBox(
      color: _ShellPalette.navy,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
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
                onPressed: () => context.push('/settings/ai-knowledge'),
                style: TextButton.styleFrom(
                  foregroundColor: _ShellPalette.cyan,
                ),
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
                ? Colors.white.withValues(alpha: 0.12)
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
                color: selected ? _ShellPalette.cyan : _ShellPalette.muted,
                semanticLabel: definition.label,
              ),
              const SizedBox(height: 5),
              Text(
                definition.label,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? _ShellPalette.text : _ShellPalette.muted,
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
              Text(
                tabs[index].label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: index == currentIndex ? primary : colors.textMuted,
                  fontWeight: index == currentIndex
                      ? FontWeight.w700
                      : FontWeight.w500,
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
          height: 68,
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
