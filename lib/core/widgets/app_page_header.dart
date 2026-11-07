import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'app_navigation_back_button.dart';

const _primaryShellRoutes = {
  '/',
  '/sales',
  '/inventory',
  '/finance',
  '/settings',
};

bool shouldShowPageBackButton({
  required String location,
  required bool canPop,
}) =>
    (canPop || location.isNotEmpty) && !_primaryShellRoutes.contains(location);

String _currentRouterPath(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.path;
  } catch (_) {}
  final router = GoRouter.maybeOf(context);
  return router?.routerDelegate.currentConfiguration.uri.path ?? '';
}

String pageBackFallbackRoute(String location) {
  if (const [
    '/debt-aging',
    '/supplier-payables-aging',
    '/salary-ledger',
    '/cashflow-forecast',
    '/expense-ledger',
    '/profit-loss',
    '/daily-closing',
    '/invoices',
    '/invoice-scans',
    '/purchases-no-invoice',
    '/transactions',
    '/opening-balances',
    '/tax-',
  ].any(location.startsWith))
    return '/finance';
  if (location.startsWith('/products/')) return '/products';
  if (location == '/products' ||
      location == '/stock-take' ||
      location == '/xnt-report' ||
      location == '/purchase-orders')
    return '/inventory';
  if (location.startsWith('/purchase-orders/')) return '/purchase-orders';
  if (location.startsWith('/customers/')) return '/customers';
  if (location.startsWith('/suppliers/')) return '/suppliers';
  if (location == '/customers' ||
      location == '/suppliers' ||
      location.startsWith('/sales/'))
    return '/sales';
  if (location.startsWith('/settings/') ||
      const [
        '/profile',
        '/change-password',
        '/shop-profile',
        '/activity-logs',
        '/staff',
        '/roles',
        '/help-center',
      ].contains(location))
    return '/settings';
  return '/';
}

void navigatePageBack(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else if (router != null && router.canPop()) {
    router.pop();
  } else if (router != null) {
    router.go(pageBackFallbackRoute(_currentRouterPath(context)));
  }
}

class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget? compactAction;
  final List<Widget>? breadcrumbs;
  final bool dense;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final bool? showBackButton;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.compactAction,
    this.breadcrumbs,
    this.dense = false,
    this.titleStyle,
    this.subtitleStyle,
    this.showBackButton,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final location = _currentRouterPath(context);
    final resolvedShowBack =
        showBackButton ??
        shouldShowPageBackButton(
          location: location,
          canPop: Navigator.of(context).canPop(),
        );

    final headingContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (breadcrumbs != null && breadcrumbs!.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var index = 0; index < breadcrumbs!.length; index++) ...[
                breadcrumbs![index],
                if (index < breadcrumbs!.length - 1)
                  Container(width: 1, height: 14, color: colors.divider),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(
          title,
          style: (titleStyle ?? textTheme.headlineMedium)?.copyWith(
            fontSize: compact ? 22 : null,
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.55,
            height: 1.15,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            maxLines: dense ? 2 : null,
            overflow: dense ? TextOverflow.ellipsis : null,
            style:
                subtitleStyle ??
                textTheme.bodyMedium?.copyWith(
                  fontSize: compact ? 13 : null,
                  color: colors.textSecondary,
                  height: 1.45,
                ),
          ),
        ],
      ],
    );
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (resolvedShowBack) ...[
          AppNavigationBackButton(onPressed: () => navigatePageBack(context)),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(child: headingContent),
      ],
    );

    return Container(
      padding: EdgeInsets.only(
        top: dense ? 0 : AppSpacing.xs,
        bottom: compact ? 12 : (dense ? AppSpacing.md : AppSpacing.lg),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;
          if (isCompact && action != null && compactAction == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: AppSpacing.sm),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              if (isCompact && compactAction != null) ...[
                const SizedBox(width: AppSpacing.sm),
                compactAction!,
              ] else if (action != null) ...[
                const SizedBox(width: AppSpacing.md),
                action!,
              ],
            ],
          );
        },
      ),
    );
  }
}
