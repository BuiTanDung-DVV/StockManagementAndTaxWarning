import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/assets/app_assets.dart';
import '../../core/constants/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ai_assistant_widget.dart';
import '../../core/widgets/global_search_delegate.dart';
import '../settings/providers/shop_provider.dart';

enum MainShellNavigationMode { bottomBar, rail, sidebar }

abstract final class _ShellPalette {
  static const navy = Color(0xFF102A43);
  static const navyRaised = Color(0xFF173B5E);
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

bool shouldShowAiAssistant({
  required String location,
  required double viewportWidth,
}) {
  final isPos = location == '/pos' || location.startsWith('/pos/');
  final isQr = location == '/qr-payment' || location.startsWith('/qr-payment/');
  return !isPos && !isQr;
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

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context, List<_NavDef> visibleTabs) {
    final location = GoRouterState.of(context).uri.toString();
    for (var i = 0; i < visibleTabs.length; i++) {
      if (visibleTabs[i].matchesRoute(location)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          prefixes: const ['/inventory', '/purchase-orders', '/stock', '/xnt'],
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
            '/tax-estimate',
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
        final canSell =
            !shop.isAllShops && (shop.isOwner || shop.hasPermission('sales'));

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
                      shopName: shop.currentShopName,
                      canSell: canSell,
                      onSearch: () async {
                        final route = await showSearch<String>(
                          context: context,
                          delegate: GlobalSearchDelegate(
                            api: ref.read(apiClientProvider),
                          ),
                        );
                        if (route != null && route.isNotEmpty && context.mounted) {
                          context.push(route);
                        }
                      },
                      onNotifications: () => context.push('/notifications'),
                      onSale: () => context.push('/pos'),
                    ),
                  Expanded(child: child),
                ],
              ),
              if (showAi)
                Positioned.fill(
                  child: AiAssistantWidget(
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
                  shopName: shop.currentShopName,
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
  final String? shopName;
  final bool canSell;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onSale;

  const _ShellUtilityHeader({
    required this.compact,
    required this.shopName,
    required this.canSell,
    required this.onSearch,
    required this.onNotifications,
    required this.onSale,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final resolvedShop = shopName?.trim().isNotEmpty == true
        ? shopName!
        : 'Cửa hàng';

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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!compact)
                    Text(
                      'CỬA HÀNG ĐANG CHỌN',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  Text(
                    compact ? 'SmartStock · $resolvedShop' : resolvedShop,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (compact) ...[
              const SizedBox(width: AppSpacing.xs),
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
              _HeaderAssetButton(
                assetPath: AppAssets.notification,
                semanticLabel: 'Mở thông báo',
                onPressed: onNotifications,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            if (!compact && canSell)
              FilledButton(onPressed: onSale, child: const Text('Tạo đơn bán')),
          ],
        ),
      ),
    );
  }
}

class _HeaderAssetButton extends StatelessWidget {
  final String assetPath;
  final String semanticLabel;
  final VoidCallback onPressed;

  const _HeaderAssetButton({
    required this.assetPath,
    required this.semanticLabel,
    required this.onPressed,
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
                color: primary,
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
  final String? shopName;

  const _DesktopSidebar({
    required this.tabs,
    required this.currentIndex,
    required this.shopName,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _ShellPalette.navy,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 252,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 18, 18),
                child: Row(
                  children: [
                    Container(
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SmartStock',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: _ShellPalette.text,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.35,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            shopName?.trim().isNotEmpty == true
                                ? shopName!
                                : 'Quản lý cửa hàng',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: _ShellPalette.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: Text(
                  'ĐIỀU HƯỚNG',
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: tabs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) => _SidebarNavItem(
                    definition: tabs[index],
                    selected: index == currentIndex,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                decoration: BoxDecoration(
                  color: _ShellPalette.navyRaised,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Trung tâm trợ giúp',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _ShellPalette.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quy trình bán hàng, kho và thuế',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _ShellPalette.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => context.push('/settings/ai-knowledge'),
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        foregroundColor: _ShellPalette.cyan,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 36),
                      ),
                      child: const Text('Quản lý nguồn hướng dẫn'),
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

class _SidebarNavItem extends StatelessWidget {
  final _NavDef definition;
  final bool selected;

  const _SidebarNavItem({required this.definition, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Điều hướng đến ${definition.label}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(definition.route),
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(
                color: selected ? Colors.white12 : Colors.transparent,
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
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
          child: Row(
            children: [
              for (var index = 0; index < tabs.length; index++)
                Expanded(
                  child: Semantics(
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
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppAssetIcon(
                              assetPath: tabs[index].assetPath,
                              size: 19,
                              color: index == currentIndex
                                  ? primary
                                  : colors.textMuted,
                              semanticLabel: tabs[index].label,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tabs[index].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontSize: 10,
                                    color: index == currentIndex
                                        ? primary
                                        : colors.textMuted,
                                    fontWeight: index == currentIndex
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
