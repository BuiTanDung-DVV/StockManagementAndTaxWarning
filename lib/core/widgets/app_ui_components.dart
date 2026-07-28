import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../assets/app_assets.dart';
import '../theme/app_theme.dart';
import 'chart_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. AppCardContainer — Unified Card Container for All Screens
// ─────────────────────────────────────────────────────────────────────────────
class AppCardContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final Color? backgroundColor;
  final double borderRadius;

  const AppCardContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.borderColor,
    this.backgroundColor,
    this.borderRadius = AppRadius.card,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? c.card,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? c.divider, width: 1),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. AppKpiCard — Unified Metric Card for Dashboard, Finance, Inventory & Debt
// ─────────────────────────────────────────────────────────────────────────────
class AppKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final String? assetPath;
  final dynamic icon;
  final String? badgeText;
  final List<double>? sparklineData;
  final bool isHero;

  const AppKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    this.assetPath,
    this.icon,
    this.badgeText,
    this.sparklineData,
    this.isHero = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);

    final iconWidget = assetPath == null
        ? null
        : AppAssetIcon(
            assetPath: assetPath!,
            size: 19,
            color: color,
            semanticLabel: title,
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (iconWidget != null) ...[
                      iconWidget,
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: c.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    badgeText!,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
                letterSpacing: -0.5,
                height: 1.1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
            ),
          ),
          if (sparklineData != null && sparklineData!.isNotEmpty) ...[
            const SizedBox(height: 8),
            CompactSparkline(values: sparklineData!, color: color, height: 28),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. AppStatusBadge — Unified Badge for All Modules
// ─────────────────────────────────────────────────────────────────────────────
class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  factory AppStatusBadge.success(String label, {IconData? icon}) =>
      AppStatusBadge(label: label, color: AppColors.success, icon: icon);

  factory AppStatusBadge.danger(String label, {IconData? icon}) =>
      AppStatusBadge(label: label, color: AppColors.danger, icon: icon);

  factory AppStatusBadge.warning(String label, {IconData? icon}) =>
      AppStatusBadge(label: label, color: Colors.orange, icon: icon);

  factory AppStatusBadge.info(String label, {IconData? icon}) =>
      AppStatusBadge(label: label, color: AppColors.info, icon: icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.24), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. AppSectionHeader — Unified Header Row with Icon, Title & Action
// ─────────────────────────────────────────────────────────────────────────────
class AppSectionHeader extends StatelessWidget {
  final String title;
  final dynamic icon;
  final String? assetPath;
  final Color iconColor;
  final Widget? trailing;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.assetPath,
    this.iconColor = const Color(0xFF2563EB),
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              if (assetPath != null) ...[
                AppAssetIcon(
                  assetPath: assetPath!,
                  size: 20,
                  color: iconColor,
                  semanticLabel: title,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: trailing!),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. AppDataTableColumn — Definition for Columns in AppDataTable
// ─────────────────────────────────────────────────────────────────────────────
class AppDataTableColumn {
  final String title;
  final int flex;
  final bool alignRight;

  const AppDataTableColumn({
    required this.title,
    this.flex = 1,
    this.alignRight = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. AppDataTable — Unified Reusable Table for All Modules
// ─────────────────────────────────────────────────────────────────────────────
class AppDataTable<T> extends StatelessWidget {
  final String title;
  final dynamic icon;
  final String? assetPath;
  final Color iconColor;
  final Widget? headerAction;
  final List<AppDataTableColumn> columns;
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) rowBuilder;
  final String emptyMessage;

  const AppDataTable({
    super.key,
    required this.title,
    this.icon,
    this.assetPath,
    this.iconColor = const Color(0xFF2563EB),
    this.headerAction,
    required this.columns,
    required this.items,
    required this.rowBuilder,
    this.emptyMessage = 'Chưa có dữ liệu',
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);

    return AppCardContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title Header
          Padding(
            padding: const EdgeInsets.all(18),
            child: AppSectionHeader(
              title: title,
              icon: icon,
              assetPath: assetPath,
              iconColor: iconColor,
              trailing: headerAction,
            ),
          ),
          Divider(height: 1, color: c.divider.withValues(alpha: 0.6)),

          // Table Body with Smooth Horizontal Scroll on Mobile
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              final tableContent = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Table Columns Fill Header
                  Container(
                    color: c.cardAlt.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Row(
                      children: columns.map((col) {
                        return Expanded(
                          flex: col.flex,
                          child: Text(
                            col.title,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: c.textSecondary,
                              letterSpacing: 0.5,
                            ),
                            textAlign: col.alignRight
                                ? TextAlign.right
                                : TextAlign.left,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Divider(height: 1, color: c.divider.withValues(alpha: 0.6)),

                  // Items or Empty State
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          emptyMessage,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: c.textMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: c.divider.withValues(alpha: 0.3),
                      ),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Container(
                          color: index % 2 == 1
                              ? c.cardAlt.withValues(alpha: 0.2)
                              : Colors.transparent,
                          child: rowBuilder(context, item, index),
                        );
                      },
                    ),
                ],
              );

              if (isMobile) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: 650, child: tableContent),
                );
              }

              return tableContent;
            },
          ),
        ],
      ),
    );
  }
}
