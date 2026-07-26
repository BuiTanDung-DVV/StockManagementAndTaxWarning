import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

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
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? c.card,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color:
              borderColor ??
              (isDark ? c.divider : c.divider.withValues(alpha: 0.8)),
          width: 1.5,
        ),
        boxShadow: const [AppTheme.diffusionShadow],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget iconWidget;
    if (assetPath != null && assetPath!.endsWith('.svg')) {
      iconWidget = SvgPicture.asset(
        assetPath!,
        width: 18,
        height: 18,
        colorFilter: ColorFilter.mode(
          isHero ? Colors.white : color,
          BlendMode.srcIn,
        ),
      );
    } else if (icon is IconData) {
      iconWidget = Icon(
        icon as IconData,
        size: 18,
        color: isHero ? Colors.white : color,
      );
    } else if (icon != null) {
      iconWidget = HugeIcon(
        icon: icon,
        size: 18,
        color: isHero ? Colors.white : color,
      );
    } else {
      iconWidget = Icon(
        Icons.analytics_rounded,
        size: 18,
        color: isHero ? Colors.white : color,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isHero ? null : c.card,
        gradient: isHero
            ? LinearGradient(
                colors: [color, color.withAlpha(220)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHero
              ? Colors.white.withValues(alpha: 0.2)
              : color.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isHero ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isHero
                            ? Colors.white.withValues(alpha: 0.2)
                            : color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: iconWidget,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isHero
                              ? Colors.white.withValues(alpha: 0.9)
                              : c.textSecondary,
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
                    color: isHero
                        ? Colors.white.withValues(alpha: 0.25)
                        : color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isHero
                          ? Colors.white
                          : color.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    badgeText!,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isHero ? Colors.white : color,
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
                color: isHero ? Colors.white : c.textPrimary,
                letterSpacing: -0.5,
                height: 1.1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
            ),
          ),
          if (sparklineData != null && sparklineData!.isNotEmpty) ...[
            const SizedBox(height: 8),
            CompactSparkline(
              values: sparklineData!,
              color: isHero ? Colors.white : color,
              height: 28,
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
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
  final Color iconColor;
  final Widget? trailing;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.icon = HugeIcons.strokeRoundedGrid,
    this.iconColor = const Color(0xFF2563EB),
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);

    Widget iconWidget;
    if (icon is IconData) {
      iconWidget = Icon(icon as IconData, size: 18, color: iconColor);
    } else {
      iconWidget = HugeIcon(icon: icon, size: 18, color: iconColor);
    }

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: iconWidget,
              ),
              const SizedBox(width: 12),
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
  final Color iconColor;
  final Widget? headerAction;
  final List<AppDataTableColumn> columns;
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) rowBuilder;
  final String emptyMessage;

  const AppDataTable({
    super.key,
    required this.title,
    this.icon = HugeIcons.strokeRoundedTable,
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
