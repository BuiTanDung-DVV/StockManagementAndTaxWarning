import '../../../core/assets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/finance_display.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/widgets/chart_widgets.dart';
import '../../../core/widgets/panel_scroll_body.dart';

class ExpenseLedgerContent extends StatelessWidget {
  const ExpenseLedgerContent({
    super.key,
    required this.total,
    required this.categories,
    required this.recentItems,
  });

  final num total;
  final List categories;
  final List recentItems;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final overviewHeight = (220 * MediaQuery.textScalerOf(context).scale(1))
        .clamp(220, 360)
        .toDouble();
    final palette = [
      AppColors.primary,
      AppColors.warning,
      AppColors.success,
      AppColors.danger,
      Color(0xFF8B5CF6),
      Color(0xFF64748B),
    ];
    final transactionCount = categories.fold<int>(
      0,
      (sum, item) => sum + asNum(item['count']).toInt(),
    );
    final summary = Container(
      key: const Key('expense-summary-card'),
      width: double.infinity,
      height: overviewHeight,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Tổng chi phí tháng này',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatVietnameseCurrency(total),
              style: AppTheme.tabularStyle(
                context,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$transactionCount giao dịch · ${categories.length} nhóm chi phí',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
    final chart = ChartCard(
      key: const Key('expense-distribution-card'),
      title: 'Tỷ trọng chi phí',
      height: overviewHeight,
      child: MiniDonutChart(
        segments: categories
            .asMap()
            .entries
            .map(
              (e) => DonutSegment(
                financeCategoryLabel(e.value['category']?.toString()),
                asNum(e.value['amount']).toDouble(),
                palette[e.key % palette.length],
              ),
            )
            .toList(),
      ),
    );
    final categoryPanel = ChartCard(
      key: const Key('expense-category-panel'),
      title: 'Theo danh mục',
      height: 420,
      child: PanelScrollBody(
        child: Column(
          children: categories.asMap().entries.map((entry) {
            final item = entry.value;
            final category = item['category']?.toString() ?? 'OTHER';
            final amount = asNum(item['amount']);
            final percent = total > 0
                ? (amount / total * 100).toStringAsFixed(1)
                : '0';
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              leading: Container(
                width: 4,
                height: 38,
                color: palette[entry.key % palette.length],
              ),
              title: Text(financeCategoryLabel(category)),
              subtitle: Text(
                '${asNum(item['count']).toInt()} giao dịch · $percent%',
              ),
              trailing: Text(
                formatVietnameseCurrency(amount),
                style: AppTheme.tabularStyle(
                  context,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => context.push(
                Uri(
                  path: '/transactions',
                  queryParameters: {'type': 'EXPENSE', 'category': category},
                ).toString(),
              ),
            );
          }).toList(),
        ),
      ),
    );
    final recentPanel = ChartCard(
      key: const Key('expense-recent-panel'),
      title: 'Giao dịch gần đây',
      height: 420,
      trailing: TextButton(
        onPressed: () => context.push('/transactions?type=EXPENSE'),
        child: const Text('Xem tất cả'),
      ),
      child: recentItems.isEmpty
          ? const Center(child: Text('Chưa có giao dịch'))
          : PanelScrollBody(
              child: Column(
                children: recentItems.map<Widget>((item) {
                  final id = int.tryParse(item['id']?.toString() ?? '');
                  final date = DateTime.tryParse(
                    item['transactionDate']?.toString() ?? '',
                  );
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    title: Text(
                      item['counterparty']?.toString() ??
                          financeCategoryLabel(item['category']?.toString()),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      date == null
                          ? '—'
                          : DateFormat('dd/MM/yyyy').format(date),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatVietnameseCurrency(asNum(item['amount'])),
                          style: AppTheme.tabularStyle(
                            context,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (id != null) ...[
                          const SizedBox(width: 6),
                          const AppIcon(Icons.chevron_right, size: 16),
                        ],
                      ],
                    ),
                    onTap: id == null
                        ? null
                        : () => context.push('/transactions/$id'),
                  );
                }).toList(),
              ),
            ),
    );
    Widget pair(Widget left, Widget right, double width) => width < 760
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 16), right],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              Expanded(child: right),
            ],
          );
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                pair(summary, chart, constraints.maxWidth),
                const SizedBox(height: 16),
                pair(categoryPanel, recentPanel, constraints.maxWidth),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
