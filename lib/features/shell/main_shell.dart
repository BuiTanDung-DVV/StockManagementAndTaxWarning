import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/assets/app_assets.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ai_assistant_widget.dart';
import '../../core/widgets/global_search_delegate.dart';
import '../settings/providers/shop_provider.dart';

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
      _NavDef(label: AppStrings.navHome, route: '/', prefixes: const ['/']),
      if (!shop.isAllShops && shop.hasPermission('sales'))
        _NavDef(
          label: AppStrings.navSales,
          route: '/sales',
          prefixes: const ['/sales', '/pos'],
        ),
      if (!shop.isAllShops && shop.hasPermission('inventory'))
        _NavDef(
          label: AppStrings.navInventory,
          route: '/inventory',
          prefixes: const ['/inventory', '/purchase-orders', '/stock', '/xnt'],
        ),
      if (!shop.isAllShops && shop.hasPermission('finance'))
        _NavDef(
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
          child: Column(
            children: [
              if (showUtilityHeader)
                _ShellUtilityHeader(
                  compact: mode == MainShellNavigationMode.bottomBar,
                  shopName: shop.currentShopName,
                  canSell: canSell,
                  onSearch: () {
                    showSearch(
                      context: context,
                      delegate: GlobalSearchDelegate(),
                    );
                  },
                  onAi: () => ref.read(aiAssistantOpenProvider.notifier).open(),
                  onSale: () => context.push('/pos'),
                ),
              Expanded(child: child),
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

        return Stack(
          fit: StackFit.expand,
          children: [
            navigationShell,
            if (showAi)
              Positioned.fill(
                child: AiAssistantWidget(showLauncher: !showUtilityHeader),
              ),
          ],
        );
      },
    );
  }
}

class _ShellUtilityHeader extends StatelessWidget {
  final bool compact;
  final String? shopName;
  final bool canSell;
  final VoidCallback onSearch;
  final VoidCallback onAi;
  final VoidCallback onSale;

  const _ShellUtilityHeader({
    required this.compact,
    required this.shopName,
    required this.canSell,
    required this.onSearch,
    required this.onAi,
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
        height: compact ? 56 : 64,
        padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider)),
        ),
        child: Row(
          children: [
            if (compact) ...[
              const AppAssetIcon(
                assetPath: AppAssets.appIcon,
                size: 30,
                semanticLabel: 'SmartStock',
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                resolvedShop,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!compact) ...[
              TextButton(onPressed: onSearch, child: const Text('Tìm kiếm')),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Thông báo',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            OutlinedButton(
              onPressed: onAi,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 14,
                  vertical: 10,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppAssetIcon(
                    assetPath: AppAssets.appIcon,
                    size: 20,
                    semanticLabel: 'Hỏi AI',
                  ),
                  const SizedBox(width: 7),
                  const Text('Hỏi AI'),
                ],
              ),
            ),
            if (!compact && canSell) ...[
              const SizedBox(width: AppSpacing.sm),
              FilledButton(onPressed: onSale, child: const Text('Bán hàng')),
            ],
          ],
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
    final colors = AppThemeColors.of(context);

    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 216,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Row(
                  children: [
                    const AppAssetIcon(
                      assetPath: AppAssets.appIcon,
                      size: 38,
                      semanticLabel: 'SmartStock',
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SmartStock',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            shopName?.trim().isNotEmpty == true
                                ? shopName!
                                : 'Quản lý cửa hàng',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: tabs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 2),
                  itemBuilder: (context, index) => _SidebarNavItem(
                    definition: tabs[index],
                    selected: index == currentIndex,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                child: TextButton(
                  onPressed: () => context.push('/settings/ai-knowledge'),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: colors.textMuted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('Nguồn hướng dẫn'),
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
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Điều hướng đến ${definition.label}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(definition.route),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? primary.withValues(alpha: 0.07)
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: selected ? primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              definition.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? primary : colors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
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
    final colors = AppThemeColors.of(context);

    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 104,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: AppAssetIcon(
                  assetPath: AppAssets.appIcon,
                  size: 36,
                  semanticLabel: 'SmartStock',
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: tabs.length,
                  itemBuilder: (context, index) => _RailNavItem(
                    definition: tabs[index],
                    selected: index == currentIndex,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/settings/ai-knowledge'),
                child: const Text('Hướng dẫn', textAlign: TextAlign.center),
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
        onTap: () => context.go(definition.route),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.07)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected ? primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            definition.label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? primary : colors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
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
          height: 62,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.divider)),
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
                      onTap: () => context.go(tabs[index].route),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: index == currentIndex
                                  ? primary
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          tabs[index].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: index == currentIndex
                                    ? primary
                                    : colors.textMuted,
                                fontWeight: index == currentIndex
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
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
  final String label;
  final String route;
  final List<String> prefixes;

  const _NavDef({
    required this.label,
    required this.route,
    required this.prefixes,
  });

  bool matchesRoute(String location) {
    if (route == '/') return location == '/';
    return prefixes.any(location.startsWith);
  }
}
