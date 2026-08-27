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
}) => canPop && !_primaryShellRoutes.contains(location);

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
    final location = GoRouterState.of(context).uri.path;
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
          style:
              titleStyle ??
              textTheme.headlineMedium?.copyWith(
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
          AppNavigationBackButton(onPressed: context.pop),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(child: headingContent),
      ],
    );

    return Container(
      padding: EdgeInsets.only(
        top: dense ? 0 : AppSpacing.xs,
        bottom: dense ? AppSpacing.md : AppSpacing.lg,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;
          if (isCompact && action != null && compactAction == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: AppSpacing.md),
                Align(alignment: Alignment.centerLeft, child: action),
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
