import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

final _compactFmt = NumberFormat.compact(locale: 'vi_VN');

// ─────────────────────────────────────────────
// ChartCard — Unified container for all charts
// ─────────────────────────────────────────────
class ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double? height;
  final Widget? trailing;

  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    this.height,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.divider.withValues(alpha: 0.4)),
        boxShadow: const [AppTheme.diffusionShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// EmptyChartPlaceholder — When there's no data yet
// ─────────────────────────────────────────────────
class EmptyChartPlaceholder extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyChartPlaceholder({
    super.key,
    required this.message,
    this.icon = Icons.bar_chart_rounded,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.divider.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 28,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: c.textMuted,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────
// MiniAreaChart — Compact line + area
// ─────────────────────────────────────
class MiniAreaChart extends StatelessWidget {
  final List<double> data1;
  final List<double> data2;
  final String label1;
  final String label2;
  final Color color1;
  final Color color2;
  final List<String>? xLabels;

  const MiniAreaChart({
    super.key,
    required this.data1,
    required this.data2,
    this.label1 = 'Thu',
    this.label2 = 'Chi',
    this.color1 = AppColors.success,
    this.color2 = AppColors.danger,
    this.xLabels,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);

    if (data1.isEmpty && data2.isEmpty) {
      return const EmptyChartPlaceholder(message: 'Chưa có dữ liệu');
    }

    final spots1 = data1
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final spots2 = data2
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final maxLen = data1.length > data2.length ? data1.length : data2.length;
    double maxY = 0;
    for (final v in data1) {
      if (v > maxY) maxY = v;
    }
    for (final v in data2) {
      if (v > maxY) maxY = v;
    }
    if (maxY == 0) maxY = 1000000;

    return Column(
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _legendDot(color1, label1, c),
            const SizedBox(width: 12),
            _legendDot(color2, label2, c),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: c.divider.withValues(alpha: 0.2),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: xLabels != null,
                    reservedSize: 22,
                    getTitlesWidget: (v, m) {
                      final idx = v.toInt();
                      if (xLabels == null || idx < 0 || idx >= xLabels!.length)
                        return const SizedBox.shrink();
                      if (maxLen > 7 &&
                          idx % (maxLen / 5).ceil() != 0 &&
                          idx != maxLen - 1)
                        return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          xLabels![idx],
                          style: TextStyle(
                            color: c.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, m) {
                      if (v == m.max || v == m.min)
                        return const SizedBox.shrink();
                      return Text(
                        _compactFmt.format(v),
                        style: AppTheme.tabularStyle(
                          context,
                          fontSize: 9,
                          color: c.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (maxLen - 1).toDouble(),
              minY: 0,
              maxY: maxY * 1.15,
              lineBarsData: [
                LineChartBarData(
                  spots: spots1,
                  isCurved: true,
                  color: color1,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color1.withValues(alpha: 0.08),
                  ),
                ),
                LineChartBarData(
                  spots: spots2,
                  isCurved: true,
                  color: color2,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color2.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label, AppThemeColors c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: c.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────
// MiniDonutChart — Compact pie with legend
// ──────────────────────────────────────────
class MiniDonutChart extends StatefulWidget {
  final List<DonutSegment> segments;
  final double centerRadius;

  const MiniDonutChart({
    super.key,
    required this.segments,
    this.centerRadius = 36,
  });

  @override
  State<MiniDonutChart> createState() => _MiniDonutChartState();
}

class _MiniDonutChartState extends State<MiniDonutChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);

    if (widget.segments.isEmpty) {
      return const EmptyChartPlaceholder(message: 'Chưa có dữ liệu');
    }

    final total = widget.segments.fold<double>(0, (s, e) => s + e.value);

    return Row(
      children: [
        // Chart
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sectionsSpace: 2,
              centerSpaceRadius: widget.centerRadius,
              sections: widget.segments.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final isTouched = i == touchedIndex;
                final pct = total > 0 ? (e.value / total * 100) : 0.0;
                
                String displayTitle = '';
                if (isTouched) {
                    displayTitle = '${e.label}\n${pct.toStringAsFixed(1)}%';
                } else if (pct >= 5) {
                    displayTitle = '${pct.toStringAsFixed(0)}%';
                }

                return PieChartSectionData(
                  color: e.color,
                  value: e.value,
                  title: displayTitle,
                  radius: isTouched ? 28 : 22,
                  titleStyle: TextStyle(
                    fontSize: isTouched ? 8 : 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Legend
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.segments.take(7).map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: e.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        e.label,
                        style: TextStyle(fontSize: 10, color: c.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class DonutSegment {
  final String label;
  final double value;
  final Color color;
  const DonutSegment(this.label, this.value, this.color);
}

// ──────────────────────────────────────
// MiniBarChart — Compact vertical bars
// ──────────────────────────────────────
class MiniBarChart extends StatelessWidget {
  final List<double> values;
  final List<String>? labels;
  final Color? barColor;
  final List<Color>? barColors;

  const MiniBarChart({
    super.key,
    required this.values,
    this.labels,
    this.barColor,
    this.barColors,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    if (values.isEmpty) {
      return const EmptyChartPlaceholder(message: 'Chưa có dữ liệu');
    }

    double maxY = 0;
    for (final v in values) {
      if (v > maxY) maxY = v;
    }
    if (maxY == 0) maxY = 1;

    final defaultColor = barColor ?? theme.colorScheme.primary;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.15,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => c.surface,
            getTooltipItem: (group, gIdx, rod, rIdx) {
              return BarTooltipItem(
                _compactFmt.format(rod.toY),
                AppTheme.tabularStyle(
                  context,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: labels != null,
              reservedSize: 22,
              getTitlesWidget: (v, m) {
                final idx = v.toInt();
                if (labels == null || idx < 0 || idx >= labels!.length)
                  return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels![idx],
                    style: TextStyle(
                      color: c.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: c.divider.withValues(alpha: 0.15), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: values.asMap().entries.map((e) {
          final color = barColors != null && e.key < barColors!.length
              ? barColors![e.key]
              : defaultColor;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value,
                color: color,
                width: values.length > 10 ? 8 : 14,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────
// HorizontalBarList — Simple horizontal %
// ─────────────────────────────────────────
class HorizontalBarList extends StatelessWidget {
  final List<HBarItem> items;

  const HorizontalBarList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    if (items.isEmpty) return const SizedBox.shrink();

    final maxVal = items.fold<double>(0, (s, e) => e.value > s ? e.value : s);

    return Column(
      children: items.take(6).map((item) {
        final pct = maxVal > 0 ? (item.value / maxVal) : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _compactFmt.format(item.value),
                    style: AppTheme.tabularStyle(
                      context,
                      fontSize: 11,
                      color: c.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct.clamp(0, 1).toDouble(),
                  backgroundColor: c.divider.withValues(alpha: 0.2),
                  color: item.color,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class HBarItem {
  final String label;
  final double value;
  final Color color;
  const HBarItem(this.label, this.value, this.color);
}
