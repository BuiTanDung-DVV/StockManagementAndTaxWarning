import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../settings/providers/shop_provider.dart';

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
    final shop = ref.watch(shopProvider);

    // Build visible tabs based on permissions
    final allTabs = <_NavDef>[
      _NavDef(icon: HugeIcons.strokeRoundedHome01, label: 'Trang chủ', route: '/', prefixes: ['/']),
      if (shop.hasPermission('pos') || shop.hasPermission('sales_view'))
        _NavDef(icon: HugeIcons.strokeRoundedShoppingCart01, label: 'Bán hàng', route: '/sales', prefixes: ['/sales', '/pos']),
      if (shop.hasPermission('inventory'))
        _NavDef(icon: HugeIcons.strokeRoundedPackage, label: 'Kho', route: '/inventory', prefixes: ['/inventory', '/purchase', '/stock', '/xnt']),
      if (shop.hasPermission('finance'))
        _NavDef(icon: HugeIcons.strokeRoundedCoinsDollar, label: 'Tài chính', route: '/finance', prefixes: ['/finance', '/daily', '/profit', '/cashflow', '/debt', '/invoices', '/tax-calculator', '/expense-ledger', '/tax-obligations', '/salary-ledger', '/tax-declaration', '/transactions']),
      _NavDef(icon: HugeIcons.strokeRoundedSettings02, label: 'Cài đặt', route: '/settings', prefixes: ['/settings', '/activity', '/tax-config', '/tax-support', '/payment-config']),
    ];

    final idx = _currentIndex(context, allTabs);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: c.bg,
            body: Row(
              children: [
                Container(
                  width: 260,
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(right: BorderSide(color: c.divider)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const HugeIcon(icon: HugeIcons.strokeRoundedStore01, color: AppColors.primary, size: 26),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'SmartStock',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: allTabs.length,
                          itemBuilder: (context, i) {
                            final isActive = i == idx;
                            final color = isActive ? AppColors.primary : c.textSecondary;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: ListTile(
                                leading: HugeIcon(icon: allTabs[i].icon, color: color, size: 24),
                                title: Text(
                                  allTabs[i].label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                    color: color,
                                  ),
                                ),
                                selected: isActive,
                                selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                Expanded(child: child),
              ],
            ),
          );
        }

        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: child,
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: c.surface,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, -2)),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (int i = 0; i < allTabs.length; i++)
                      _NavItem(icon: allTabs[i].icon, label: allTabs[i].label, isActive: i == idx, onTap: () => context.go(allTabs[i].route)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Nav tab definition ──
class _NavDef {
  final dynamic icon; // HugeIcons path data
  final String label;
  final String route;
  final List<String> prefixes;
  const _NavDef({required this.icon, required this.label, required this.route, required this.prefixes});

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
  const _NavItem({required this.icon, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final color = isActive ? AppColors.primary : c.textMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: color)),
          ],
        ),
      ),
    );
  }
}
