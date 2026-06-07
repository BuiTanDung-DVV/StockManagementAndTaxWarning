import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../settings/providers/shop_provider.dart';
import '../../core/constants/app_strings.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context, List<_NavDef> visibleTabs) {
    final location = GoRouterState.of(context).uri.toString();
    for (int i = 0; i < visibleTabs.length; i++) {
      if (visibleTabs[i].matchesRoute(location)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final shop = ref.watch(shopProvider);

    // Build visible tabs based on permissions
    final allTabs = <_NavDef>[
      _NavDef(
        icon: HugeIcons.strokeRoundedHome01,
        label: AppStrings.navHome,
        route: '/',
        prefixes: ['/'],
      ),
      if (shop.hasPermission('pos') || shop.hasPermission('sales_view'))
        _NavDef(
          icon: HugeIcons.strokeRoundedShoppingCart01,
          label: AppStrings.navSales,
          route: '/sales',
          prefixes: ['/sales', '/pos'],
        ),
      if (shop.hasPermission('inventory'))
        _NavDef(
          icon: HugeIcons.strokeRoundedPackage,
          label: AppStrings.navInventory,
          route: '/inventory',
          prefixes: ['/inventory', '/purchase-orders', '/stock', '/xnt'],
        ),
      if (shop.hasPermission('finance'))
        _NavDef(
          icon: HugeIcons.strokeRoundedCoinsDollar,
          label: AppStrings.navFinance,
          route: '/finance',
          prefixes: [
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
        prefixes: [
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

    final idx = _currentIndex(context, allTabs);

    return Scaffold(
      backgroundColor: c.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;

          if (isDesktop) {
            return Row(
              children: [
                Container(
                  width: 260,
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(
                      right: BorderSide(
                        color: c.divider.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          24,
                          32,
                          24,
                          24,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const HugeIcon(
                                icon: HugeIcons.strokeRoundedStore01,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'SmartStock',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          itemCount: allTabs.length,
                          itemBuilder: (context, i) {
                            final isActive = i == idx;
                            final color = isActive ? Colors.white : c.textSecondary;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: ListTile(
                                leading: HugeIcon(
                                  icon: allTabs[i].icon,
                                  color: color,
                                  size: 24,
                                ),
                                title: Text(
                                  allTabs[i].label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                    color: color,
                                  ),
                                ),
                                selected: isActive,
                                selectedTileColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                hoverColor: AppColors.primary.withValues(alpha: 0.05),
                                onTap: () => context.go(allTabs[i].route),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: c.bg,
                    child: child,
                  ),
                ),
              ],
            );
          }

                return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            color: c.bg.withValues(alpha: 0.4),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 480,
                                ),
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: c.card.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: c.divider.withValues(alpha: 0.5),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    for (int i = 0; i < allTabs.length; i++)
                                      _NavItem(
                                        icon: allTabs[i].icon,
                                        label: allTabs[i].label,
                                        isActive: i == idx,
                                        onTap: () =>
                                            context.go(allTabs[i].route),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// ── Nav tab definition ──
class _NavDef {
  final dynamic icon; // HugeIcons path data
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
    // Home is special: only exact match
    if (route == '/') return location == '/';
    return prefixes.any((p) => location.startsWith(p));
  }
}

class _NavItem extends StatelessWidget {
  final dynamic icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final color = isActive ? AppColors.primary : c.textMuted;

    return Semantics(
      label: label,
      selected: isActive,
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(icon: icon, color: color, size: 22),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: color,
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
