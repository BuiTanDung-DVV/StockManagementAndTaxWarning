import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/reporting_period.dart';
import '../../../core/utils/finance_display.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/chart_widgets.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../providers/finance_provider.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

const _financeTools = <({String title, String description, String route})>[
  (
    title: 'Giao dịch thu chi',
    description: 'Ghi nhận và tra cứu các khoản tiền vào, tiền ra.',
    route: '/transactions',
  ),
  (
    title: 'Chốt sổ cuối ngày',
    description: 'Đối soát tiền mặt và xác nhận số dư thực tế.',
    route: '/daily-closing',
  ),
  (
    title: 'Sổ chi phí SXKD',
    description: 'Theo dõi chi phí theo nhóm và chứng từ liên quan.',
    route: '/expense-ledger',
  ),
  (
    title: 'Quản lý chứng từ',
    description: 'Kiểm tra hóa đơn đầu vào, đầu ra và trạng thái xử lý.',
    route: '/invoices',
  ),
  (
    title: 'Báo cáo kết quả kinh doanh',
    description: 'Đối chiếu doanh thu, chi phí và lợi nhuận trong kỳ.',
    route: '/profit-loss',
  ),
  (
    title: 'Phân tích tuổi nợ',
    description: 'Phân nhóm công nợ theo thời gian và mức độ ưu tiên.',
    route: '/debt-aging',
  ),
  (
    title: 'Dự báo dòng tiền',
    description: 'Xem các khoản dự kiến thu, chi trong thời gian tới.',
    route: '/cashflow-forecast',
  ),
  (
    title: 'Bảng kê mua không hóa đơn',
    description: 'Quản lý giao dịch mua chưa có chứng từ hợp lệ.',
    route: '/purchases-no-invoice',
  ),
  (
    title: 'Tính thuế hộ kinh doanh',
    description: 'Ước tính nghĩa vụ theo dữ liệu và cấu hình hiện có.',
    route: '/tax-calculator',
  ),
  (
    title: 'Theo dõi nghĩa vụ thuế',
    description: 'Theo dõi kỳ, hạn nộp và trạng thái hoàn thành.',
    route: '/tax-obligations',
  ),
  (
    title: 'Kê khai thuế',
    description: 'Chuẩn bị dữ liệu phục vụ quy trình kê khai.',
    route: '/tax-declaration',
  ),
  (
    title: 'Sổ lương nhân viên',
    description: 'Theo dõi lương, phụ cấp và khoản chi theo nhân viên.',
    route: '/salary-ledger',
  ),
];

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final period = currentMonthReportingPeriod(DateTime.now());
    final from = period.from;
    final to = period.to;
    final periodLabel = reportingCompactRangeLabel(
      DateTime.parse(from),
      DateTime.parse(to),
    );
    final summaryAsync = ref.watch(cashSummaryProvider((from: from, to: to)));
    final transactionsAsync = ref.watch(
      transactionsProvider((
        page: 1,
        limit: 20,
        type: null,
        category: null,
        from: from,
        to: to,
      )),
    );
    final categoriesAsync = ref.watch(
      expensesByCategoryForPeriodProvider((from: from, to: to)),
    );
    final compactLayout = MediaQuery.sizeOf(context).width < 720;

    Future<void> refresh() async {
      ref.invalidate(cashSummaryProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(expensesByCategoryForPeriodProvider);
    }

    return Scaffold(
      backgroundColor: colors.bg,
      floatingActionButton: compactLayout
          ? null
          : AppPrimaryFloatingAction(
              label: 'Lịch sử giao dịch',
              assetPath: AppAssets.cash,
              heroTag: 'finance-transaction-action',
              onPressed: () => context.push('/transactions'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: RefreshIndicator(
        onRefresh: refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: AppResponsiveContent(
            maxWidth: 1320,
            verticalPadding: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppPageHeader(
                  title: 'Tài chính & sổ cái',
                  subtitle:
                      'Theo dõi dòng tiền, đối soát giao dịch và xử lý công việc tài chính trong tháng.',
                  dense: true,
                  action: featureGuideButton(context, 'finance'),
                  compactAction: Wrap(
                    spacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      featureGuideButton(context, 'finance'),
                      AppPrimaryHeaderAction(
                        label: 'Lịch sử giao dịch',
                        assetPath: AppAssets.cash,
                        heroTag: 'finance-transaction-action-compact',
                        onPressed: () => context.push('/transactions'),
                      ),
                    ],
                  ),
                ),
                summaryAsync.when(
                  data: (data) =>
                      _FinanceMetricStrip(data: data, periodLabel: periodLabel),
                  loading: () => const _FinanceMetricLoading(),
                  error: (_, _) => AppInlineError(
                    message: 'Không thể tải số liệu tài chính tháng này.',
                    onRetry: () => ref.invalidate(cashSummaryProvider),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final chart = summaryAsync.when(
                      data: (data) =>
                          _CashFlowPanel(data: data, periodLabel: periodLabel),
                      loading: () => const _PanelLoading(height: 406),
                      error: (_, _) => AppInlineError(
                        message: 'Không thể tải biểu đồ dòng tiền.',
                        onRetry: () => ref.invalidate(cashSummaryProvider),
                      ),
                    );
                    final categories = categoriesAsync.when(
                      data: (data) => _ExpenseCategoryPanel(
                        data: data,
                        periodLabel: periodLabel,
                      ),
                      loading: () => const _PanelLoading(height: 406),
                      error: (_, _) => AppInlineError(
                        message: 'Không thể tải phân loại chi phí.',
                        onRetry: () =>
                            ref.invalidate(expensesByCategoryForPeriodProvider),
                      ),
                    );

                    if (constraints.maxWidth < 980) {
                      return Column(
                        children: [
                          chart,
                          const SizedBox(height: AppSpacing.md),
                          categories,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: chart),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: categories),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionLead(
                  title: 'Công việc tài chính',
                  subtitle:
                      'Các sổ và báo cáo được nhóm theo nhiệm vụ để dễ tìm trên cả desktop và điện thoại.',
                ),
                const SizedBox(height: AppSpacing.md),
                AppFillGrid(
                  minItemWidth: 240,
                  maxColumns: 4,
                  itemHeight: 84,
                  children: [
                    for (var index = 0; index < _financeTools.length; index++)
                      _FinanceToolTile(
                        index: index + 1,
                        title: _financeTools[index].title,
                        description: _financeTools[index].description,
                        onTap: () => context.push(_financeTools[index].route),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionLead(
                  title: 'Giao dịch gần đây',
                  trailing: TextButton(
                    onPressed: () => context.push('/transactions'),
                    child: const Text('Xem tất cả'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                transactionsAsync.when(
                  data: (data) => _RecentTransactionPanel(
                    items: (data['items'] as List?) ?? const [],
                  ),
                  loading: () => const ShimmerList(count: 3),
                  error: (_, _) => AppInlineError(
                    message: 'Không thể tải giao dịch gần đây.',
                    onRetry: () => ref.invalidate(transactionsProvider),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinanceMetricStrip extends StatelessWidget {
  final Map<String, dynamic> data;
  final String periodLabel;

  const _FinanceMetricStrip({required this.data, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final balance = asDouble(
      data['cashBalance'] ?? data['currentBalance'] ?? data['balance'],
    );
    final income = asDouble(data['totalIncome'] ?? data['income']);
    final expense = asDouble(data['totalExpense'] ?? data['expense']);
    final net = income - expense;

    return AppFillGrid(
      minItemWidth: 190,
      maxColumns: 4,
      itemHeight: 88,
      children: [
        AppKpiCard(
          title: 'Quỹ tiền mặt',
          value: _currencyFormat.format(balance),
          color: AppColors.primary,
          assetPath: AppAssets.cash,
          badgeText: 'Hiện tại',
        ),
        AppKpiCard(
          title: 'Tổng thu',
          value: _currencyFormat.format(income),
          color: AppColors.success,
          assetPath: AppAssets.revenue,
          badgeText: periodLabel,
        ),
        AppKpiCard(
          title: 'Tổng chi',
          value: _currencyFormat.format(expense),
          color: AppColors.danger,
          assetPath: AppAssets.orders,
          badgeText: periodLabel,
        ),
        AppKpiCard(
          title: 'Dòng tiền thuần',
          value: _currencyFormat.format(net),
          color: net >= 0 ? AppColors.success : AppColors.danger,
          assetPath: AppAssets.profit,
          badgeText: periodLabel,
        ),
      ],
    );
  }
}

class _FinanceMetricLoading extends StatelessWidget {
  const _FinanceMetricLoading();

  @override
  Widget build(BuildContext context) {
    return AppFillGrid(
      minItemWidth: 190,
      maxColumns: 4,
      itemHeight: 88,
      children: List.generate(
        4,
        (_) => AppShimmer(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
          ),
        ),
      ),
    );
  }
}

class _CashFlowPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  final String periodLabel;

  const _CashFlowPanel({required this.data, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final chartHeight = MediaQuery.sizeOf(context).width < 600 ? 250.0 : 300.0;
    final dailyFlow = ((data['dailyFlow'] as List?) ?? const [])
        .whereType<Map>()
        .toList();
    final incomeData = dailyFlow
        .map((item) => asDouble(item['income']))
        .toList();
    final expenseData = dailyFlow
        .map((item) => asDouble(item['expense']))
        .toList();
    final labels = dailyFlow.map((item) {
      final rawDate = item['date']?.toString() ?? '';
      if (rawDate.length >= 10) {
        return '${rawDate.substring(8, 10)}/${rawDate.substring(5, 7)}';
      }
      return rawDate;
    }).toList();
    final hasMovement =
        incomeData.any((value) => value != 0) ||
        expenseData.any((value) => value != 0);

    return AppCardContainer(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLead(
            title: 'Dòng tiền · $periodLabel',
            subtitle: 'Đơn vị: đồng · So sánh tiền thu và tiền chi theo ngày.',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (dailyFlow.isEmpty || !hasMovement)
            SizedBox(
              height: chartHeight,
              child: const AppEmpty(
                visual: AppEmptyVisual.finance,
                message: 'Chưa có giao dịch thu–chi trong kỳ',
                subtitle: 'Biểu đồ sẽ xuất hiện khi có giao dịch thực tế.',
              ),
            )
          else
            SizedBox(
              height: chartHeight,
              child: MiniAreaChart(
                data1: incomeData,
                data2: expenseData,
                label1: 'Thu',
                label2: 'Chi',
                color1: AppColors.success,
                color2: AppColors.danger,
                xLabels: labels,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpenseCategoryPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  final String periodLabel;

  const _ExpenseCategoryPanel({required this.data, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final chartHeight = MediaQuery.sizeOf(context).width < 600 ? 250.0 : 300.0;
    final categories =
        ((data['categories'] as List?) ?? (data['items'] as List?) ?? const [])
            .whereType<Map>()
            .take(5)
            .toList();
    final maximum = categories.fold<double>(0, (current, item) {
      final value = asDouble(item['total'] ?? item['amount'] ?? item['value']);
      return value > current ? value : current;
    });

    return AppCardContainer(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLead(
            title: 'Nhóm chi phí lớn',
            subtitle: '$periodLabel · Năm nhóm có tổng chi cao nhất.',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (categories.isEmpty)
            SizedBox(
              height: chartHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Chưa có chi phí để phân loại.',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => context.push('/expense-ledger'),
                    child: const Text('Thêm khoản chi'),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: chartHeight,
              child: Column(
                children: [
                  for (var index = 0; index < categories.length; index++) ...[
                    _ExpenseCategoryRow(
                      name: financeCategoryLabel(
                        categories[index]['category']?.toString() ??
                            categories[index]['name']?.toString(),
                      ),
                      value: asDouble(
                        categories[index]['total'] ??
                            categories[index]['amount'] ??
                            categories[index]['value'],
                      ),
                      maximum: maximum,
                    ),
                    if (index < categories.length - 1)
                      const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpenseCategoryRow extends StatelessWidget {
  final String name;
  final double value;
  final double maximum;

  const _ExpenseCategoryRow({
    required this.name,
    required this.value,
    required this.maximum,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final progress = maximum <= 0 ? 0.0 : (value / maximum).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _currencyFormat.format(value),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        LinearProgressIndicator(
          value: progress,
          minHeight: 5,
          borderRadius: BorderRadius.circular(3),
          backgroundColor: colors.divider,
          valueColor: const AlwaysStoppedAnimation(AppColors.danger),
        ),
      ],
    );
  }
}

class _FinanceToolTile extends StatelessWidget {
  final int index;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _FinanceToolTile({
    required this.index,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Material(
      color: colors.card,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.divider),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Xem',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTransactionPanel extends StatelessWidget {
  final List<dynamic> items;

  const _RecentTransactionPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final transactions = items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .take(5)
        .toList();

    return AppCardContainer(
      padding: EdgeInsets.zero,
      child: transactions.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Text(
                  'Chưa phát sinh giao dịch trong tháng này.',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 720) {
                  return Column(
                    children: [
                      for (var index = 0; index < transactions.length; index++)
                        _MobileTransactionRow(
                          transaction: transactions[index],
                          showDivider: index < transactions.length - 1,
                        ),
                    ],
                  );
                }

                return Column(
                  children: [
                    const _TransactionTableHeader(),
                    for (var index = 0; index < transactions.length; index++)
                      _DesktopTransactionRow(
                        transaction: transactions[index],
                        showDivider: index < transactions.length - 1,
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _TransactionTableHeader extends StatelessWidget {
  const _TransactionTableHeader();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final style = TextStyle(
      color: colors.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );

    return Container(
      color: colors.cardAlt,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('NỘI DUNG', style: style)),
          Expanded(flex: 2, child: Text('PHƯƠNG THỨC', style: style)),
          Expanded(
            flex: 2,
            child: Text('LOẠI', textAlign: TextAlign.center, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text('SỐ TIỀN', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _DesktopTransactionRow extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final bool showDivider;

  const _DesktopTransactionRow({
    required this.transaction,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final isIncome =
        transaction['type'] == 'INCOME' || transaction['type'] == 'income';
    final amount = asDouble(transaction['amount']);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colors.divider))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              transaction['description']?.toString() ??
                  transaction['note']?.toString() ??
                  (isIncome ? 'Giao dịch thu' : 'Giao dịch chi'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              transaction['paymentMethod']?.toString() ?? 'Tiền mặt',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: AppStatusBadge(
                label: isIncome ? 'Thu' : 'Chi',
                color: isIncome ? AppColors.success : AppColors.danger,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${isIncome ? '+' : '-'}${_currencyFormat.format(amount)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isIncome ? AppColors.success : AppColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileTransactionRow extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final bool showDivider;

  const _MobileTransactionRow({
    required this.transaction,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final isIncome =
        transaction['type'] == 'INCOME' || transaction['type'] == 'income';
    final amount = asDouble(transaction['amount']);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colors.divider))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['description']?.toString() ??
                      transaction['note']?.toString() ??
                      (isIncome ? 'Giao dịch thu' : 'Giao dịch chi'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  transaction['paymentMethod']?.toString() ?? 'Tiền mặt',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppStatusBadge(
                label: isIncome ? 'Thu' : 'Chi',
                color: isIncome ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${isIncome ? '+' : '-'}${_currencyFormat.format(amount)}',
                style: TextStyle(
                  color: isIncome ? AppColors.success : AppColors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLead extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SectionLead({required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

class _PanelLoading extends StatelessWidget {
  final double height;

  const _PanelLoading({required this.height});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
    );
  }
}
