import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ai_assistant_widget.dart';
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
  final isMobile = viewportWidth < AppBreakpoints.compactNavigation;
  final isPos = location == '/pos' || location.startsWith('/pos/');
  return !(isMobile && isPos);
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
        icon: HugeIcons.strokeRoundedHome01,
        label: AppStrings.navHome,
        route: '/',
        prefixes: const ['/'],
      ),
      if (!shop.isAllShops && shop.hasPermission('sales'))
        _NavDef(
          icon: HugeIcons.strokeRoundedShoppingCart01,
          label: AppStrings.navSales,
          route: '/sales',
          prefixes: const ['/sales', '/pos'],
        ),
      if (!shop.isAllShops && shop.hasPermission('inventory'))
        _NavDef(
          icon: HugeIcons.strokeRoundedPackage,
          label: AppStrings.navInventory,
          route: '/inventory',
          prefixes: const ['/inventory', '/purchase-orders', '/stock', '/xnt'],
        ),
      if (!shop.isAllShops && shop.hasPermission('finance'))
        _NavDef(
          icon: HugeIcons.strokeRoundedCoinsDollar,
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
        icon: HugeIcons.strokeRoundedSettings02,
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
        final content = ColoredBox(color: colors.bg, child: child);
        final location = GoRouterState.of(context).uri.path;
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
                Expanded(child: content),
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
                Expanded(child: content),
              ],
            ),
          );
        } else {
          navigationShell = Scaffold(
            backgroundColor: colors.bg,
            body: content,
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
            if (shouldShowAiAssistant(
              location: location,
              viewportWidth: constraints.maxWidth,
            ))
              const Positioned.fill(child: AiAssistantWidget()),
          ],
        );
      },
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
    final primary = Theme.of(context).colorScheme.primary;

    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 248,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                      alignment: Alignment.center,
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedStore01,
                        color: Colors.white,
                        size: 24,
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
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            shopName?.trim().isNotEmpty == true
                                ? shopName!
                                : 'Quản lý cửa hàng',
                            maxLines: 1,
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
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: tabs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) => _SidebarNavItem(
                    definition: tabs[index],
                    selected: index == currentIndex,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: _SidebarSupportLink(
                  onTap: () => context.push('/settings/ai-knowledge'),
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
    final foreground = selected ? primary : colors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Điều hướng đến ${definition.label}',
      child: Material(
        color: selected ? primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.control),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(definition.route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                HugeIcon(icon: definition.icon, color: foreground, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    definition.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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

class _SidebarSupportLink extends StatelessWidget {
  final VoidCallback onTap;

  const _SidebarSupportLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedBookOpen01,
                color: colors.textMuted,
                size: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nguồn hướng dẫn',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: colors.textMuted),
                ),
              ),
            ],
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
    final primary = Theme.of(context).colorScheme.primary;

    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 88,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  alignment: Alignment.center,
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedStore01,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              Expanded(
                child: NavigationRail(
                  backgroundColor: colors.surface,
                  selectedIndex: currentIndex,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.75,
                  onDestinationSelected: (index) =>
                      context.go(tabs[index].route),
                  destinations: [
                    for (final tab in tabs)
                      NavigationRailDestination(
                        icon: HugeIcon(
                          icon: tab.icon,
                          color: colors.textMuted,
                          size: 22,
                        ),
                        selectedIcon: HugeIcon(
                          icon: tab.icon,
                          color: primary,
                          size: 22,
                        ),
                        label: Text(tab.label),
                      ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Nguồn hướng dẫn',
                child: IconButton(
                  onPressed: () => context.push('/settings/ai-knowledge'),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedBookOpen01,
                    color: colors.textMuted,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 12),
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

    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: NavigationBar(
          height: 72,
          backgroundColor: colors.surface,
          selectedIndex: currentIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) => context.go(tabs[index].route),
          destinations: [
            for (final tab in tabs)
              NavigationDestination(
                tooltip: tab.label,
                icon: HugeIcon(
                  icon: tab.icon,
                  color: colors.textMuted,
                  size: 22,
                ),
                selectedIcon: HugeIcon(
                  icon: tab.icon,
                  color: primary,
                  size: 22,
                ),
                label: tab.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _NavDef {
  final dynamic icon;
  final String label;
  final String route;
  final List<String> prefixes;

  const _NavDef({
    required this.icon,
    required this.label,
    required this.route,
    required this.prefixes,
  });

  bool matchesRoute(String location) {
    if (route == '/') return location == '/';
    return prefixes.any(location.startsWith);
  }
}
