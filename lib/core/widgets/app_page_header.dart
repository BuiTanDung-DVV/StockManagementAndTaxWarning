import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget>? breadcrumbs;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.breadcrumbs,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    final heading = Column(
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
          style: textTheme.headlineSmall?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.35,
            height: 1.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600 && action != null) {
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
              if (action != null) ...[
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
