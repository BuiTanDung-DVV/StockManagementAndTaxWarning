import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_animations.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/chart_widgets.dart';

final _currencyFormatter = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

final _integerFormatter = NumberFormat.decimalPattern('vi_VN');

String formatVietnameseMoney(num value) => _currencyFormatter.format(value);

String formatSignedVietnameseMoney(num value) {
  final formatted = _currencyFormatter.format(value.abs());
  if (value > 0) return '+$formatted';
  if (value < 0) return '-$formatted';
  return formatted;
}

String formatVietnameseInteger(num value) => _integerFormatter.format(value);

String formatSignedVietnameseInteger(num value) {
  final formatted = _integerFormatter.format(value.abs());
  if (value > 0) return '+$formatted';
  if (value < 0) return '-$formatted';
  return formatted;
}

String formatQuantity(double qty) {
  if (qty == qty.roundToDouble()) {
    return _integerFormatter.format(qty.toInt());
  }
  return NumberFormat('#,##0.##', 'vi_VN').format(qty);
}

// ─────────────────────────────────────────────────────────────
// Pure Data Models & Aggregation Helpers
// ─────────────────────────────────────────────────────────────

class CashFlowBucket {
  final String label;
  final double income;
  final double expense;
  final String? tooltipDate;

  const CashFlowBucket({
    required this.label,
    required this.income,
    required this.expense,
    this.tooltipDate,
  });
}

class DailyFlowEntry {
  final String date;
  final double income;
  final double expense;

  const DailyFlowEntry({
    required this.date,
    required this.income,
    required this.expense,
  });
}

/// Validates raw cash summary data from backend.
/// Checks that income, expense, and netCashFlow are finite numbers,
/// and that dailyFlow is a valid List of objects containing valid date, income, and expense.
bool isValidCashSummaryData(Map<String, dynamic> data) {
  const requiredKeys = ['income', 'expense', 'netCashFlow'];
  for (final key in requiredKeys) {
    final parsed = num.tryParse(data[key]?.toString() ?? '');
    if (parsed == null || !parsed.isFinite) return false;
  }
  if (data['dailyFlow'] is! List) return false;
  final list = data['dailyFlow'] as List;
  for (final item in list) {
    if (item is! Map || item['date'] == null) return false;
    final inc = num.tryParse(item['income']?.toString() ?? '');
    final exp = num.tryParse(item['expense']?.toString() ?? '');
    if (inc == null || !inc.isFinite || exp == null || !exp.isFinite) {
      return false;
    }
  }
  return true;
}

/// Sequentially partitions dailyFlow entries into at most [maxBuckets]
/// consecutive date ranges, preserving exact totals of income and expense
/// with no points discarded.
List<CashFlowBucket> aggregateDailyFlow(
  List<DailyFlowEntry> items, {
  int maxBuckets = 7,
}) {
  if (items.isEmpty) return const [];

  if (items.length <= maxBuckets) {
    return items.map((item) {
      final label = _formatSingleDateLabel(item.date);
      final tooltip = _formatSingleDateTooltip(item.date);
      return CashFlowBucket(
        label: label,
        income: item.income,
        expense: item.expense,
        tooltipDate: tooltip,
      );
    }).toList();
  }

  // When points exceed maxBuckets, partition sequentially into consecutive date chunks
  final chunkSize = (items.length / maxBuckets).ceil();
  final buckets = <CashFlowBucket>[];

  for (var i = 0; i < items.length; i += chunkSize) {
    final end = math.min(i + chunkSize, items.length);
    final chunk = items.sublist(i, end);

    var sumIncome = 0.0;
    var sumExpense = 0.0;
    for (final it in chunk) {
      sumIncome += it.income;
      sumExpense += it.expense;
    }

    final startStr = chunk.first.date;
    final endStr = chunk.last.date;
    final isSingleDay = chunk.length == 1 || startStr == endStr;
    final label = isSingleDay
        ? _formatSingleDateLabel(startStr)
        : _formatDateRangeLabel(startStr, endStr);
    final tooltip = isSingleDay
        ? _formatSingleDateTooltip(startStr)
        : _formatDateRangeTooltip(startStr, endStr);

    buckets.add(
      CashFlowBucket(
        label: label,
        income: sumIncome,
        expense: sumExpense,
        tooltipDate: tooltip,
      ),
    );
  }

  return buckets;
}

String _formatSingleDateLabel(String date) {
  final dt = DateTime.tryParse(date.length == 7 ? '$date-01' : date);
  if (dt != null) {
    if (date.length == 7) {
      return '${dt.month.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)}';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
  return date;
}

String _formatSingleDateTooltip(String date) {
  final dt = DateTime.tryParse(date.length == 7 ? '$date-01' : date);
  if (dt != null) {
    if (date.length == 7) {
      return 'Tháng ${dt.month}/${dt.year}';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
  return date;
}

String _formatDateRangeLabel(String start, String end) {
  if (start == end) {
    return _formatSingleDateLabel(start);
  }
  final sDt = DateTime.tryParse(start);
  final eDt = DateTime.tryParse(end);
  if (sDt != null && eDt != null) {
    if (sDt.year == eDt.year && sDt.month == eDt.month && sDt.day == eDt.day) {
      return _formatSingleDateLabel(start);
    }
    if (sDt.month == eDt.month && sDt.year == eDt.year) {
      return '${sDt.day.toString().padLeft(2, '0')}–${eDt.day.toString().padLeft(2, '0')}\nThg ${sDt.month.toString().padLeft(2, '0')}';
    }
    return '${sDt.day.toString().padLeft(2, '0')}/${sDt.month.toString().padLeft(2, '0')}\n– ${eDt.day.toString().padLeft(2, '0')}/${eDt.month.toString().padLeft(2, '0')}';
  }
  return '$start\n..$end';
}

String _formatDateRangeTooltip(String start, String end) {
  if (start == end) {
    return _formatSingleDateTooltip(start);
  }
  final sDt = DateTime.tryParse(start);
  final eDt = DateTime.tryParse(end);
  if (sDt != null && eDt != null) {
    if (sDt.year == eDt.year && sDt.month == eDt.month && sDt.day == eDt.day) {
      return _formatSingleDateTooltip(start);
    }
    return '${sDt.day.toString().padLeft(2, '0')}/${sDt.month.toString().padLeft(2, '0')}/${sDt.year} – ${eDt.day.toString().padLeft(2, '0')}/${eDt.month.toString().padLeft(2, '0')}/${eDt.year}';
  }
  return '$start – $end';
}

class InventoryCategoryItem {
  final String name;
  final int skuCount;
  final double value;

  const InventoryCategoryItem({
    required this.name,
    required this.skuCount,
    required this.value,
  });
}

class InventoryCategoriesParseResult {
  final List<InventoryCategoryItem>? items;
  final bool isValid;

  const InventoryCategoriesParseResult.valid(this.items) : isValid = true;
  const InventoryCategoriesParseResult.invalid()
    : items = null,
      isValid = false;
}

/// Validates and parses inventory category summary data.
/// Retains zero-valued groups (positive physical stock with zero valuation).
/// Verifies skuCount >= 0 and value >= 0 are finite.
InventoryCategoriesParseResult parseInventoryCategories(dynamic raw) {
  if (raw is! List) return const InventoryCategoriesParseResult.invalid();
  final items = <InventoryCategoryItem>[];
  for (final entry in raw) {
    if (entry is! Map) return const InventoryCategoriesParseResult.invalid();
    final name = (entry['name'] ?? 'Chưa phân loại').toString().trim();
    if (name.isEmpty) return const InventoryCategoriesParseResult.invalid();

    final rawCount = entry['skuCount'];
    if (rawCount == null) return const InventoryCategoriesParseResult.invalid();
    final skuCount = int.tryParse(rawCount.toString());
    if (skuCount == null || skuCount < 0) {
      return const InventoryCategoriesParseResult.invalid();
    }

    final rawVal = entry['value'];
    if (rawVal == null) return const InventoryCategoriesParseResult.invalid();
    final val = num.tryParse(rawVal.toString());
    if (val == null || !val.isFinite || val < 0) {
      return const InventoryCategoriesParseResult.invalid();
    }

    // Retain all groups including value == 0
    items.add(
      InventoryCategoryItem(
        name: name,
        skuCount: skuCount,
        value: val.toDouble(),
      ),
    );
  }
  return InventoryCategoriesParseResult.valid(items);
}

class LowStockItem {
  final int? shopId;
  final int productId;
  final String name;
  final String sku;
  final String unit;
  final double currentQuantity;
  final double minStock;
  final double deficit;

  const LowStockItem({
    this.shopId,
    required this.productId,
    required this.name,
    required this.sku,
    required this.unit,
    required this.currentQuantity,
    required this.minStock,
    required this.deficit,
  });
}

class LowStockParseResult {
  final List<LowStockItem>? items;
  final bool isValid;

  const LowStockParseResult.valid(this.items) : isValid = true;
  const LowStockParseResult.invalid() : items = null, isValid = false;
}

/// Strictly parses and validates low-stock records.
/// Never skips malformed records, never defaults missing quantity/minStock to 0.
/// Preserves negative stock and individual units.
LowStockParseResult parseLowStockList(dynamic raw) {
  if (raw is! List) return const LowStockParseResult.invalid();
  final items = <LowStockItem>[];
  for (final entry in raw) {
    if (entry is! Map) return const LowStockParseResult.invalid();
    final product = entry['product'] is Map ? entry['product'] as Map : entry;

    final rawProductId = entry['productId'] ?? product['id'];
    if (rawProductId == null) return const LowStockParseResult.invalid();
    final productId = int.tryParse(rawProductId.toString());
    if (productId == null) return const LowStockParseResult.invalid();

    final name = (product['name'] ?? entry['name'])?.toString().trim();
    if (name == null || name.isEmpty) {
      return const LowStockParseResult.invalid();
    }

    final sku = (product['sku'] ?? entry['sku'] ?? '—').toString();
    final unit = (product['unit'] ?? entry['unit'] ?? '').toString();

    final rawQty = entry['currentQuantity'] ?? entry['quantity'];
    if (rawQty == null) return const LowStockParseResult.invalid();
    final currentQty = num.tryParse(rawQty.toString());
    if (currentQty == null || !currentQty.isFinite) {
      return const LowStockParseResult.invalid();
    }

    final rawMin = entry['minStock'] ?? product['minStock'];
    if (rawMin == null) return const LowStockParseResult.invalid();
    final minStock = num.tryParse(rawMin.toString());
    if (minStock == null || !minStock.isFinite) {
      return const LowStockParseResult.invalid();
    }

    // Deficit is max(minStock - currentQuantity, 0).
    // If currentQuantity is negative (-5) and minStock is 10, deficit is 10 - (-5) = 15.
    final deficit = math.max(minStock.toDouble() - currentQty.toDouble(), 0.0);
    final rawShopId = entry['shopId'];
    final shopId = rawShopId != null
        ? int.tryParse(rawShopId.toString())
        : null;

    items.add(
      LowStockItem(
        shopId: shopId,
        productId: productId,
        name: name,
        sku: sku,
        unit: unit,
        currentQuantity: currentQty.toDouble(),
        minStock: minStock.toDouble(),
        deficit: deficit,
      ),
    );
  }
  return LowStockParseResult.valid(items);
}

// ─────────────────────────────────────────────────────────────
// Unified Insight Card Shell (V4 Design Tokens)
// ─────────────────────────────────────────────────────────────

class DashboardInsightCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const DashboardInsightCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.divider),
        boxShadow: const [AppTheme.diffusionShadow],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;
          final textScale = MediaQuery.textScalerOf(context).scale(1.0);
          final shouldStackHeader =
              trailing != null && (isNarrow || textScale > 1.2);

          Widget header;
          if (trailing == null) {
            header = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.35,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            );
          } else if (shouldStackHeader) {
            header = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.35,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Align(alignment: Alignment.centerLeft, child: trailing!),
              ],
            );
          } else {
            header = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle!,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            height: 1.35,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            );
          }

          final headerSlotHeight = textScale > 1.2
              ? 56.0
              : (shouldStackHeader ? 52.0 : 44.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: headerSlotHeight),
                child: header,
              ),
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          );
        },
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  final double height;
  const _CardSkeleton({this.height = 240});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ShimmerBox(
        width: double.infinity,
        height: height,
        radius: AppRadius.card,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PANEL 1: Thu – chi trong kỳ (DashboardCashFlowCard)
// ─────────────────────────────────────────────────────────────

class DashboardCashFlowCard extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>>? cashAsync;
  final String currentLabel;
  final VoidCallback? onRetry;

  const DashboardCashFlowCard({
    super.key,
    required this.cashAsync,
    required this.currentLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final warning = AppColors.warning;

    if (cashAsync == null) {
      return DashboardInsightCard(
        title: 'Thu – chi trong kỳ',
        subtitle: 'Dòng tiền phát sinh trong kỳ báo cáo ($currentLabel)',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Text(
            'Bạn không có quyền xem số liệu dòng tiền thu – chi.',
            style: GoogleFonts.inter(color: colors.textMuted),
          ),
        ),
      );
    }

    return cashAsync!.when(
      loading: () => const _CardSkeleton(height: 320),
      error: (_, _) => DashboardInsightCard(
        title: 'Thu – chi trong kỳ',
        subtitle: 'Dòng tiền phát sinh trong kỳ báo cáo ($currentLabel)',
        child: AppInlineError(
          message: 'Không thể tải dữ liệu dòng tiền thu – chi.',
          onRetry: onRetry,
        ),
      ),
      data: (data) {
        if (!isValidCashSummaryData(data)) {
          return DashboardInsightCard(
            title: 'Thu – chi trong kỳ',
            subtitle: 'Dòng tiền phát sinh trong kỳ báo cáo ($currentLabel)',
            child: AppInlineError(
              message: 'Dữ liệu dòng tiền chưa đầy đủ hoặc không khả dụng.',
              onRetry: onRetry,
            ),
          );
        }

        final income =
            num.tryParse(data['income']?.toString() ?? '0')?.toDouble() ?? 0.0;
        final expense =
            num.tryParse(data['expense']?.toString() ?? '0')?.toDouble() ?? 0.0;
        final netCashFlow =
            num.tryParse(data['netCashFlow']?.toString() ?? '0')?.toDouble() ??
            0.0;

        final rawList = data['dailyFlow'] as List;
        final dailyEntries = <DailyFlowEntry>[];
        for (final item in rawList) {
          dailyEntries.add(
            DailyFlowEntry(
              date: item['date'].toString(),
              income:
                  num.tryParse(item['income']?.toString() ?? '0')?.toDouble() ??
                  0.0,
              expense:
                  num.tryParse(
                    item['expense']?.toString() ?? '0',
                  )?.toDouble() ??
                  0.0,
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1.0);
            final maxBuckets = (constraints.maxWidth < 420 || textScale > 1.2)
                ? 4
                : 7;
            final buckets = aggregateDailyFlow(
              dailyEntries,
              maxBuckets: maxBuckets,
            );
            final hasMovement =
                income > 0 ||
                expense > 0 ||
                buckets.any((b) => b.income > 0 || b.expense > 0);

            return DashboardInsightCard(
              title: 'Thu – chi trong kỳ',
              subtitle: 'Dòng tiền phát sinh trong kỳ báo cáo ($currentLabel)',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.cardAlt,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: colors.divider),
                ),
                child: Text(
                  currentLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CashFlowTotalsSummary(
                    income: income,
                    expense: expense,
                    netCashFlow: netCashFlow,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (!hasMovement || buckets.isEmpty)
                    const SizedBox(
                      height: 180,
                      child: EmptyChartPlaceholder(
                        message: 'Chưa có phát sinh thu – chi trong kỳ.',
                        assetPath: AppAssets.analyticsMotif,
                      ),
                    )
                  else
                    _CashFlowBarChart(
                      buckets: buckets,
                      primaryColor: primary,
                      warningColor: warning,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CashFlowTotalsSummary extends StatelessWidget {
  final double income;
  final double expense;
  final double netCashFlow;

  const _CashFlowTotalsSummary({
    required this.income,
    required this.expense,
    required this.netCashFlow,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final compact = constraints.maxWidth < 460 || textScale > 1.2;

        final items = [
          (
            label: 'Tổng thu',
            value: formatVietnameseMoney(income),
            color: primary,
            dot: primary,
          ),
          (
            label: 'Tổng chi',
            value: formatVietnameseMoney(expense),
            color: AppColors.warning,
            dot: AppColors.warning,
          ),
          (
            label: 'Dòng tiền thuần',
            value: formatSignedVietnameseMoney(netCashFlow),
            color: netCashFlow >= 0 ? AppColors.success : AppColors.danger,
            dot: null,
          ),
        ];

        if (compact) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.cardAlt,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: colors.divider),
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 12),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (items[i].dot != null) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: items[i].dot,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            items[i].label,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        items[i].value,
                        style: AppTheme.tabularStyle(
                          context,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: items[i].color,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.cardAlt,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: colors.divider),
          ),
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) ...[
                  Container(
                    height: 24,
                    width: 1,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    color: colors.divider,
                  ),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (items[i].dot != null) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: items[i].dot,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            items[i].label,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          items[i].value,
                          style: AppTheme.tabularStyle(
                            context,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: items[i].color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CashFlowBarChart extends StatelessWidget {
  final List<CashFlowBucket> buckets;
  final Color primaryColor;
  final Color warningColor;

  const _CashFlowBarChart({
    required this.buckets,
    required this.primaryColor,
    required this.warningColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final count = buckets.length;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final bottomReservedSize = (34.0 * textScale).clamp(34.0, 56.0);
    final chartHeight = (194.0 + bottomReservedSize).clamp(220.0, 260.0);

    var maxVal = 0.0;
    for (final b in buckets) {
      if (b.income > maxVal) maxVal = b.income;
      if (b.expense > maxVal) maxVal = b.expense;
    }
    final maxY = maxVal > 0 ? maxVal * 1.2 : 1.0;
    final rodWidth = count <= 4 ? 16.0 : (count <= 7 ? 12.0 : 8.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _ChartLegendDot(color: primaryColor, label: 'Thu'),
            const SizedBox(width: AppSpacing.md),
            _ChartLegendDot(color: warningColor, label: 'Chi'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: chartHeight,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: colors.divider.withValues(alpha: 0.4),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 72,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.max || value == meta.min) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        space: 4,
                        child: Text(
                          compactVietnameseCurrency(value),
                          textAlign: TextAlign.right,
                          style: AppTheme.tabularStyle(
                            context,
                            fontSize: 9.5,
                            color: colors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: bottomReservedSize,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= buckets.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        space: 6,
                        child: Text(
                          buckets[idx].label,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colors.textMuted,
                            height: 1.2,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => const Color(0xFF1E293B),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (groupIndex < 0 || groupIndex >= buckets.length) {
                      return null;
                    }
                    final bucket = buckets[groupIndex];
                    final isIncome = rodIndex == 0;
                    final val = isIncome ? bucket.income : bucket.expense;
                    final name = isIncome ? 'Thu' : 'Chi';
                    final dateHeader =
                        bucket.tooltipDate ??
                        bucket.label.replaceAll('\n', ' ');
                    return BarTooltipItem(
                      '$dateHeader\n$name: ${formatVietnameseMoney(val)}',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
              barGroups: List.generate(count, (index) {
                final b = buckets[index];
                return BarChartGroupData(
                  x: index,
                  barsSpace: 4,
                  barRods: [
                    BarChartRodData(
                      toY: b.income,
                      color: primaryColor,
                      width: rodWidth,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                    BarChartRodData(
                      toY: b.expense,
                      color: warningColor,
                      width: rodWidth,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PANEL 2: Kết quả bán hàng (DashboardSalesPerformanceCard)
// ─────────────────────────────────────────────────────────────

class DashboardSalesPerformanceCard extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>>? currentSales;
  final AsyncValue<Map<String, dynamic>>? comparisonSales;
  final String currentLabel;
  final String previousLabel;
  final VoidCallback? onRetry;
  final VoidCallback? onRetryComparison;

  const DashboardSalesPerformanceCard({
    super.key,
    required this.currentSales,
    required this.comparisonSales,
    required this.currentLabel,
    required this.previousLabel,
    this.onRetry,
    this.onRetryComparison,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    if (currentSales == null) {
      return DashboardInsightCard(
        title: 'Kết quả bán hàng',
        subtitle: 'So sánh kỳ này ($currentLabel) và kỳ trước ($previousLabel)',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Text(
            'Bạn không có quyền xem báo cáo kết quả bán hàng.',
            style: GoogleFonts.inter(color: colors.textMuted),
          ),
        ),
      );
    }

    return currentSales!.when(
      loading: () => const _CardSkeleton(height: 280),
      error: (_, _) => DashboardInsightCard(
        title: 'Kết quả bán hàng',
        subtitle: 'So sánh kỳ này ($currentLabel) và kỳ trước ($previousLabel)',
        child: AppInlineError(
          message: 'Không thể tải kết quả bán hàng.',
          onRetry: onRetry,
        ),
      ),
      data: (curData) {
        final curRev = num.tryParse(
          (curData['netSalesRevenue'] ?? curData['totalRevenue'])?.toString() ??
              '',
        );
        final curCogs = num.tryParse(curData['totalCogs']?.toString() ?? '');
        final curProfit = num.tryParse(
          curData['grossProfit']?.toString() ?? '',
        );
        final curOrders = num.tryParse(
          (curData['totalOrders'] ?? curData['orderCount'])?.toString() ?? '',
        );

        if (curRev == null ||
            curCogs == null ||
            curProfit == null ||
            curOrders == null) {
          return DashboardInsightCard(
            title: 'Kết quả bán hàng',
            subtitle:
                'So sánh kỳ này ($currentLabel) và kỳ trước ($previousLabel)',
            child: AppInlineError(
              message: 'Dữ liệu kết quả bán hàng chưa đầy đủ.',
              onRetry: onRetry,
            ),
          );
        }

        final comparisonFailed =
            comparisonSales != null && comparisonSales!.hasError;
        final prevData = comparisonSales?.value;

        final prevRev = prevData != null
            ? num.tryParse(
                (prevData['netSalesRevenue'] ?? prevData['totalRevenue'])
                        ?.toString() ??
                    '',
              )
            : null;
        final prevCogs = prevData != null
            ? num.tryParse(prevData['totalCogs']?.toString() ?? '')
            : null;
        final prevProfit = prevData != null
            ? num.tryParse(prevData['grossProfit']?.toString() ?? '')
            : null;
        final prevOrders = prevData != null
            ? num.tryParse(
                (prevData['totalOrders'] ?? prevData['orderCount'])
                        ?.toString() ??
                    '',
              )
            : null;

        String resolvePrevDisplay(num? prev) {
          if (comparisonFailed) return 'Lỗi tải';
          if (prev == null) return '—';
          return formatVietnameseMoney(prev);
        }

        String resolveDiffDisplay(num cur, num? prev) {
          if (comparisonFailed) return 'Lỗi tải';
          if (prev == null) return '—';
          return formatSignedVietnameseMoney(cur - prev);
        }

        Color resolveDiffColor(
          num cur,
          num? prev, {
          bool lowerIsBetter = false,
        }) {
          if (comparisonFailed) return AppColors.danger;
          if (prev == null) return colors.textMuted;
          if (cur == prev) return colors.textSecondary;
          if (lowerIsBetter) {
            return cur < prev ? AppColors.success : colors.textPrimary;
          }
          return cur > prev ? AppColors.success : AppColors.danger;
        }

        final rows = [
          _SalesMetricRow(
            title: 'Doanh thu thuần',
            subtitle: null,
            currentValue: formatVietnameseMoney(curRev),
            previousValue: resolvePrevDisplay(prevRev),
            diffValue: resolveDiffDisplay(curRev, prevRev),
            diffColor: resolveDiffColor(curRev, prevRev),
          ),
          _SalesMetricRow(
            title: 'Giá vốn (COGS)',
            subtitle: null,
            currentValue: formatVietnameseMoney(curCogs),
            previousValue: resolvePrevDisplay(prevCogs),
            diffValue: resolveDiffDisplay(curCogs, prevCogs),
            diffColor: resolveDiffColor(curCogs, prevCogs, lowerIsBetter: true),
          ),
          _SalesMetricRow(
            title: 'Lợi nhuận gộp',
            subtitle: 'Doanh thu thuần – Giá vốn (chưa trừ chi phí vận hành)',
            currentValue: formatSignedVietnameseMoney(curProfit),
            previousValue: comparisonFailed
                ? 'Lỗi tải'
                : (prevProfit != null
                      ? formatSignedVietnameseMoney(prevProfit)
                      : '—'),
            diffValue: resolveDiffDisplay(curProfit, prevProfit),
            diffColor: resolveDiffColor(curProfit, prevProfit),
          ),
          _SalesMetricRow(
            title: 'Số đơn hàng',
            subtitle: null,
            currentValue: formatVietnameseInteger(curOrders),
            previousValue: comparisonFailed
                ? 'Lỗi tải'
                : (prevOrders != null
                      ? formatVietnameseInteger(prevOrders)
                      : '—'),
            diffValue: comparisonFailed
                ? 'Lỗi tải'
                : (prevOrders != null
                      ? formatSignedVietnameseInteger(curOrders - prevOrders)
                      : '—'),
            diffColor: resolveDiffColor(curOrders, prevOrders),
          ),
        ];

        return DashboardInsightCard(
          title: 'Kết quả bán hàng',
          subtitle: 'Kỳ này ($currentLabel) so với kỳ trước ($previousLabel)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (comparisonFailed) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppInlineError(
                    message:
                        'Không thể tải số liệu kỳ đối chiếu ($previousLabel).',
                    onRetry: onRetryComparison ?? onRetry,
                  ),
                ),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                  final isCompact =
                      constraints.maxWidth < 520 || textScale > 1.2;
                  if (isCompact) {
                    return _CompactSalesMetricsList(rows: rows);
                  }
                  return _FullSalesMetricsTable(
                    rows: rows,
                    currentLabel: currentLabel,
                    previousLabel: previousLabel,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SalesMetricRow {
  final String title;
  final String? subtitle;
  final String currentValue;
  final String previousValue;
  final String diffValue;
  final Color diffColor;

  const _SalesMetricRow({
    required this.title,
    this.subtitle,
    required this.currentValue,
    required this.previousValue,
    required this.diffValue,
    required this.diffColor,
  });
}

class _FullSalesMetricsTable extends StatelessWidget {
  final List<_SalesMetricRow> rows;
  final String currentLabel;
  final String previousLabel;

  const _FullSalesMetricsTable({
    required this.rows,
    required this.currentLabel,
    required this.previousLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colors.cardAlt,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'Chỉ số',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Kỳ này ($currentLabel)',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Kỳ trước ($previousLabel)',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Chênh lệch',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (int i = 0; i < rows.length; i++) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rows[i].title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (rows[i].subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          rows[i].subtitle!,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      rows[i].currentValue,
                      style: AppTheme.tabularStyle(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      rows[i].previousValue,
                      style: AppTheme.tabularStyle(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      rows[i].diffValue,
                      style: AppTheme.tabularStyle(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: rows[i].diffColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactSalesMetricsList extends StatelessWidget {
  final List<_SalesMetricRow> rows;

  const _CompactSalesMetricsList({required this.rows});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        // For narrow width or large text, show metric then separate labelled rows
        // for current, previous, difference at readable font size without squashing.
        final stackLabelledRows =
            constraints.maxWidth < 460 || textScale > 1.15;

        return Column(
          children: [
            for (int i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rows[i].title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (rows[i].subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      rows[i].subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (stackLabelledRows) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.cardAlt,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        border: Border.all(color: colors.divider),
                      ),
                      child: Column(
                        children: [
                          _MetricDetailRow(
                            label: 'Kỳ này',
                            value: rows[i].currentValue,
                            valueColor: colors.textPrimary,
                            isBold: true,
                          ),
                          const SizedBox(height: 5),
                          _MetricDetailRow(
                            label: 'Kỳ trước',
                            value: rows[i].previousValue,
                            valueColor: colors.textSecondary,
                            isBold: false,
                          ),
                          const SizedBox(height: 5),
                          _MetricDetailRow(
                            label: 'Chênh lệch',
                            value: rows[i].diffValue,
                            valueColor: rows[i].diffColor,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kỳ này',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: colors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  rows[i].currentValue,
                                  style: AppTheme.tabularStyle(
                                    context,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kỳ trước',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: colors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  rows[i].previousValue,
                                  style: AppTheme.tabularStyle(
                                    context,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Chênh lệch',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: colors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  rows[i].diffValue,
                                  style: AppTheme.tabularStyle(
                                    context,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: rows[i].diffColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MetricDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool isBold;

  const _MetricDetailRow({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.isBold,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: 2,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
          ),
          Text(
            value,
            style: AppTheme.tabularStyle(
              context,
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PANEL 3: Giá trị tồn kho theo nhóm (DashboardInventoryCategoryCard)
// ─────────────────────────────────────────────────────────────

const _categoryPalette = <Color>[
  Color(0xFF0F766E), // Teal
  Color(0xFF0284C7), // Sky/Cyan
  Color(0xFF10B981), // Emerald
  Color(0xFF6366F1), // Indigo
  Color(0xFFF59E0B), // Amber
  Color(0xFF94A3B8), // Slate
];

class _InventoryCategoryDonutChart extends StatefulWidget {
  final List<InventoryCategoryItem> items;
  final double totalValue;
  final int totalSkus;

  const _InventoryCategoryDonutChart({
    required this.items,
    required this.totalValue,
    required this.totalSkus,
  });

  @override
  State<_InventoryCategoryDonutChart> createState() =>
      _InventoryCategoryDonutChartState();
}

class _InventoryCategoryDonutChartState
    extends State<_InventoryCategoryDonutChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final positiveItems = widget.items.where((it) => it.value > 0).toList();
    final hasPositiveVal = widget.totalValue > 0 && positiveItems.isNotEmpty;

    if (!hasPositiveVal) {
      // Neutral non-data ring for zero valuation: no fabricated PieChartSectionData(value: 1)
      return Semantics(
        label: 'Chưa có giá trị vốn tồn kho để tạo lát cắt biểu đồ',
        child: Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.divider.withValues(alpha: 0.5),
              width: 14,
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAssetIcon(
                assetPath: AppAssets.warehouseMotif,
                size: 22,
                color: colors.textMuted,
              ),
              const SizedBox(height: 2),
              Text(
                '0 ₫',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.textMuted,
                ),
              ),
              Text(
                'Không có giá trị',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    for (int p = 0; p < positiveItems.length; p++) {
      final it = positiveItems[p];
      final originalIndex = widget.items.indexOf(it);
      final color =
          _categoryPalette[(originalIndex >= 0 ? originalIndex : p) %
              _categoryPalette.length];
      final isTouched = p == _touchedIndex;

      sections.add(
        PieChartSectionData(
          value: it.value,
          color: color,
          radius: isTouched ? 18.0 : 14.0,
          showTitle: false,
        ),
      );
    }

    final touchedItem =
        (_touchedIndex != null &&
            _touchedIndex! >= 0 &&
            _touchedIndex! < positiveItems.length)
        ? positiveItems[_touchedIndex!]
        : null;

    final touchedOriginalIndex = touchedItem != null
        ? widget.items.indexOf(touchedItem)
        : -1;
    final touchedColor = touchedOriginalIndex >= 0
        ? _categoryPalette[touchedOriginalIndex % _categoryPalette.length]
        : colors.textPrimary;
    final touchedRatio = (touchedItem != null && widget.totalValue > 0)
        ? (touchedItem.value / widget.totalValue)
        : 0.0;
    final touchedPct = (touchedRatio * 100).toStringAsFixed(1);

    final semanticLabel = touchedItem != null
        ? '${touchedItem.name}: ${formatVietnameseMoney(touchedItem.value)} ($touchedPct% cơ cấu giá trị)'
        : 'Biểu đồ cơ cấu giá trị tồn kho theo nhóm hàng';

    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 42,
                sectionsSpace: 2.5,
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedIndex = null;
                        return;
                      }
                      _touchedIndex =
                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
              ),
            ),
            // Center label clearly referring to value share (not SKU counts)
            if (touchedItem != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$touchedPct%',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: touchedColor,
                      ),
                    ),
                    Text(
                      'Tỷ trọng giá vốn',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppAssetIcon(
                    assetPath: AppAssets.warehouseMotif,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cơ cấu',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'giá vốn',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class DashboardInventoryCategoryCard extends StatelessWidget {
  final AsyncValue<List<dynamic>>? categoriesAsync;
  final VoidCallback? onRetry;

  const DashboardInventoryCategoryCard({
    super.key,
    required this.categoriesAsync,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    if (categoriesAsync == null) {
      return const SizedBox.shrink();
    }

    return categoriesAsync!.when(
      loading: () => const _CardSkeleton(height: 280),
      error: (_, _) => DashboardInsightCard(
        title: 'Giá trị tồn kho theo nhóm',
        subtitle: 'Tồn kho hiện tại · theo giá vốn; không theo kỳ báo cáo',
        child: AppInlineError(
          message: 'Không thể tải giá trị tồn kho theo nhóm.',
          onRetry: onRetry,
        ),
      ),
      data: (rawList) {
        final parseResult = parseInventoryCategories(rawList);
        if (!parseResult.isValid) {
          return DashboardInsightCard(
            title: 'Giá trị tồn kho theo nhóm',
            subtitle: 'Tồn kho hiện tại · theo giá vốn; không theo kỳ báo cáo',
            child: AppInlineError(
              message: 'Dữ liệu giá trị tồn kho không hợp lệ.',
              onRetry: onRetry,
            ),
          );
        }

        final parsed = parseResult.items!;
        if (parsed.isEmpty) {
          return const DashboardInsightCard(
            title: 'Giá trị tồn kho theo nhóm',
            subtitle: 'Tồn kho hiện tại · theo giá vốn; không theo kỳ báo cáo',
            child: SizedBox(
              height: 180,
              child: EmptyChartPlaceholder(
                message: 'Chưa có dữ liệu tồn kho dương theo nhóm.',
                assetPath: AppAssets.warehouseMotif,
              ),
            ),
          );
        }

        // Sort descending by value, then by skuCount descending
        parsed.sort((a, b) {
          final valCmp = b.value.compareTo(a.value);
          if (valCmp != 0) return valCmp;
          return b.skuCount.compareTo(a.skuCount);
        });

        final totalValue = parsed.fold<double>(0.0, (s, it) => s + it.value);
        final totalSkus = parsed.fold<int>(0, (s, it) => s + it.skuCount);

        final displayItems = <InventoryCategoryItem>[];
        if (parsed.length <= 5) {
          displayItems.addAll(parsed);
        } else {
          displayItems.addAll(parsed.take(5));
          final remainder = parsed.skip(5);
          final remVal = remainder.fold<double>(0.0, (s, it) => s + it.value);
          final remSkus = remainder.fold<int>(0, (s, it) => s + it.skuCount);
          displayItems.add(
            InventoryCategoryItem(
              name: 'Nhóm khác',
              skuCount: remSkus,
              value: remVal,
            ),
          );
        }

        return DashboardInsightCard(
          title: 'Giá trị tồn kho theo nhóm',
          subtitle: 'Tồn kho hiện tại · theo giá vốn; không theo kỳ báo cáo',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.cardAlt,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: colors.divider),
            ),
            child: Text(
              'Tổng: ${formatVietnameseMoney(totalValue)}',
              style: AppTheme.tabularStyle(
                context,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1.0);
              final stackOnMobile =
                  constraints.maxWidth < 480 || textScale > 1.2;

              final donut = _InventoryCategoryDonutChart(
                items: displayItems,
                totalValue: totalValue,
                totalSkus: totalSkus,
              );

              final itemsColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < displayItems.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    _CategoryBarItem(
                      item: displayItems[i],
                      totalValue: totalValue,
                      primaryColor: primary,
                      itemColor: _categoryPalette[i % _categoryPalette.length],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '* Chỉ tính các nhóm có số lượng tồn dương (> 0) theo giá vốn hiện tại ($totalSkus SKU).',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              );

              if (stackOnMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        child: donut,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    itemsColumn,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xs,
                      right: AppSpacing.lg,
                    ),
                    child: donut,
                  ),
                  Expanded(child: itemsColumn),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _CategoryBarItem extends StatelessWidget {
  final InventoryCategoryItem item;
  final double totalValue;
  final Color primaryColor;
  final Color itemColor;

  const _CategoryBarItem({
    required this.item,
    required this.totalValue,
    required this.primaryColor,
    required this.itemColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final ratio = totalValue > 0 ? (item.value / totalValue) : 0.0;
    final percentage = (ratio * 100).toStringAsFixed(1);
    final barWidthFactor = (item.value <= 0 || ratio <= 0)
        ? 0.0
        : ratio.clamp(0.0, 1.0);

    return Tooltip(
      message:
          '${item.name}: ${formatVietnameseMoney(item.value)} ($percentage% · ${item.skuCount} SKU)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: itemColor,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  item.name,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: colors.cardAlt,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Text(
                  '${item.skuCount} SKU',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: colors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatVietnameseMoney(item.value),
                    style: AppTheme.tabularStyle(
                      context,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$percentage%',
                    style: AppTheme.tabularStyle(
                      context,
                      fontSize: 11,
                      color: colors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 7,
              color: colors.divider.withValues(alpha: 0.45),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: barWidthFactor,
                  child: Container(
                    decoration: BoxDecoration(
                      color: itemColor.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PANEL 4: Hàng chạm mức tồn tối thiểu (DashboardLowStockCard)
// ─────────────────────────────────────────────────────────────

class DashboardLowStockCard extends StatelessWidget {
  final AsyncValue<List<dynamic>>? lowStockAsync;
  final bool isAllShops;
  final VoidCallback? onRetry;

  const DashboardLowStockCard({
    super.key,
    required this.lowStockAsync,
    this.isAllShops = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    if (lowStockAsync == null) {
      return const SizedBox.shrink();
    }

    return lowStockAsync!.when(
      loading: () => const _CardSkeleton(height: 280),
      error: (_, _) => DashboardInsightCard(
        title: 'Hàng chạm mức tồn tối thiểu',
        subtitle: 'Ảnh chụp tức thời · các mặt hàng cần nhập thêm',
        child: AppInlineError(
          message: 'Không thể tải danh sách tồn kho tối thiểu.',
          onRetry: onRetry,
        ),
      ),
      data: (rawList) {
        final parseResult = parseLowStockList(rawList);
        if (!parseResult.isValid) {
          return DashboardInsightCard(
            title: 'Hàng chạm mức tồn tối thiểu',
            subtitle: 'Ảnh chụp tức thời · các mặt hàng cần nhập thêm',
            child: AppInlineError(
              message: 'Dữ liệu tồn kho tối thiểu không hợp lệ.',
              onRetry: onRetry,
            ),
          );
        }

        final items = parseResult.items!;
        final totalCount = items.length;
        final top5 = items.take(5).toList();

        final viewAllButton = TextButton.icon(
          onPressed: () => context.push('/inventory?issue=low-stock'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
          label: Text('Xem tất cả ($totalCount)'),
        );

        if (items.isEmpty) {
          return DashboardInsightCard(
            title: 'Hàng chạm mức tồn tối thiểu',
            subtitle: 'Ảnh chụp tức thời tại thời điểm hiện tại',
            trailing: viewAllButton,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mức tồn ổn định',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Không có mặt hàng chạm mức tồn tối thiểu trong phạm vi đang xem.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return DashboardInsightCard(
          title: 'Hàng chạm mức tồn tối thiểu',
          subtitle:
              'Ảnh chụp tức thời · $totalCount mặt hàng cần lưu ý nhập thêm',
          trailing: viewAllButton,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1.0);
              final isCompact = constraints.maxWidth < 560 || textScale > 1.2;
              if (isCompact) {
                return _CompactLowStockList(
                  items: top5,
                  isAllShops: isAllShops,
                );
              }
              return _FullLowStockTable(items: top5, isAllShops: isAllShops);
            },
          ),
        );
      },
    );
  }
}

class _FullLowStockTable extends StatelessWidget {
  final List<LowStockItem> items;
  final bool isAllShops;

  const _FullLowStockTable({required this.items, required this.isAllShops});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colors.cardAlt,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'Sản phẩm / SKU',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Tồn hiện tại',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Tối thiểu',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Thiếu hụt',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (int i = 0; i < items.length; i++) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          if (isAllShops && items[i].shopId != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: colors.cardAlt,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'CH #${items[i].shopId}',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              items[i].sku,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${formatQuantity(items[i].currentQuantity)} ${items[i].unit}',
                      style: AppTheme.tabularStyle(
                        context,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${formatQuantity(items[i].minStock)} ${items[i].unit}',
                      style: AppTheme.tabularStyle(
                        context,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '-${formatQuantity(items[i].deficit)} ${items[i].unit}',
                      style: AppTheme.tabularStyle(
                        context,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactLowStockList extends StatelessWidget {
  final List<LowStockItem> items;
  final bool isAllShops;

  const _CompactLowStockList({required this.items, required this.isAllShops});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final useVerticalLayout =
            constraints.maxWidth < 460 || textScale > 1.15;

        return Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 16),
              _buildItem(
                context,
                item: items[i],
                colors: colors,
                useVerticalLayout: useVerticalLayout,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required LowStockItem item,
    required AppThemeColors colors,
    required bool useVerticalLayout,
  }) {
    final shopBadge = (isAllShops && item.shopId != null)
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: colors.cardAlt,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              'CH #${item.shopId}',
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          )
        : null;

    final deficitBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(
        'Thiếu ${formatQuantity(item.deficit)} ${item.unit}',
        style: AppTheme.tabularStyle(
          context,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.danger,
        ),
      ),
    );

    final stockDetailRow = Wrap(
      spacing: AppSpacing.md,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tồn: ',
              style: GoogleFonts.inter(fontSize: 11.5, color: colors.textMuted),
            ),
            Text(
              '${formatQuantity(item.currentQuantity)} ${item.unit}',
              style: AppTheme.tabularStyle(
                context,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mức tối thiểu: ',
              style: GoogleFonts.inter(fontSize: 11.5, color: colors.textMuted),
            ),
            Text(
              '${formatQuantity(item.minStock)} ${item.unit}',
              style: AppTheme.tabularStyle(
                context,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );

    if (useVerticalLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full-width product name with wrapping and no maxLines cap
          Text(
            item.name,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 5),
          // Deficit badge and shop/SKU on separate wrapping row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (shopBadge != null) ...[
                    shopBadge,
                    const SizedBox(width: 4),
                  ],
                  Text(
                    item.sku,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
              deficitBadge,
            ],
          ),
          const SizedBox(height: 6),
          stockDetailRow,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (shopBadge != null) ...[
                        shopBadge,
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          item.sku,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            deficitBadge,
          ],
        ),
        const SizedBox(height: 6),
        stockDetailRow,
      ],
    );
  }
}
