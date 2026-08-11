import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/reporting_period.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/chart_widgets.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../providers/sales_provider.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

bool salesListUsesCompactLayout(double width) =>
    width < AppBreakpoints.compactNavigation;

int salesListCurrentPage(Map<String, dynamic> data) {
  final value = int.tryParse(data['page']?.toString() ?? '');
  return value != null && value > 0 ? value : 1;
}

int salesListTotalPages(Map<String, dynamic> data) {
  final value = int.tryParse(data['totalPages']?.toString() ?? '');
  return value != null && value > 0 ? value : 1;
}

int salesListTotalItems(Map<String, dynamic> data) {
  final value = int.tryParse(data['total']?.toString() ?? '');
  return value != null && value >= 0
      ? value
      : ((data['items'] as List?)?.length ?? 0);
}

class SalesListScreen extends ConsumerStatefulWidget {
  const SalesListScreen({super.key});

  @override
  ConsumerState<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends ConsumerState<SalesListScreen> {
  int _page = 1;
  String? _status;
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _searchQuery = value;
          _page = 1;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final compactLayout = salesListUsesCompactLayout(
      MediaQuery.sizeOf(context).width,
    );
    final listAsync = ref.watch(
      salesListProvider((
        page: _page,
        status: _status,
        customerId: null,
        search: _searchQuery,
      )),
    );
    Widget headerActions({required bool compact}) => Wrap(
      spacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        featureGuideButton(context, 'sales_list'),
        if (compact)
          Tooltip(
            message: 'Mở POS',
            child: FloatingActionButton.small(
              heroTag: 'sales-open-pos-action-compact',
              elevation: 0,
              onPressed: () => context.push('/pos'),
              child: const AppAssetIcon(
                assetPath: AppAssets.orders,
                size: 18,
                color: Colors.white,
                semanticLabel: 'Mở POS',
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: colors.bg,
      floatingActionButton: compactLayout
          ? null
          : AppPrimaryFloatingAction(
              label: 'Mở POS',
              assetPath: AppAssets.orders,
              heroTag: 'sales-open-pos-action',
              onPressed: () => context.push('/pos'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(salesListProvider);
            ref.invalidate(salesSummaryProvider);
            ref.invalidate(paymentSummaryProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: AppResponsiveContent(
              maxWidth: 1440,
              verticalPadding: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppPageHeader(
                    title: 'Lịch sử đơn hàng',
                    subtitle:
                        'Theo dõi trạng thái thanh toán và xử lý đơn bán hàng.',
                    dense: true,
                    action: headerActions(compact: compactLayout),
                    compactAction: headerActions(compact: true),
                  ),
                  _SalesSummarySection(
                    onRetry: () => ref.invalidate(salesSummaryProvider),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SalesListControls(
                    status: _status,
                    onSearchChanged: _onSearchChanged,
                    onStatusChanged: (value) => setState(() {
                      _status = value;
                      _page = 1;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  listAsync.when(
                    data: (data) {
                      final items = (data['items'] as List?) ?? const [];
                      if (items.isEmpty) {
                        return const AppEmpty(
                          visual: AppEmptyVisual.sales,
                          message: 'Không tìm thấy đơn hàng',
                          subtitle:
                              'Thử thay đổi bộ lọc hoặc tạo đơn mới từ màn hình POS.',
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final desktop = constraints.maxWidth >= 780;
                          final currentPage = salesListCurrentPage(data);
                          final totalPages = salesListTotalPages(data);
                          final totalItems = salesListTotalItems(data);
                          return Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              border: Border.all(color: colors.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListView.separated(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: items.length + (desktop ? 1 : 0),
                                  separatorBuilder: (_, index) =>
                                      index == 0 && desktop
                                      ? const SizedBox.shrink()
                                      : Divider(
                                          height: 1,
                                          color: colors.divider,
                                        ),
                                  itemBuilder: (context, index) {
                                    if (desktop && index == 0) {
                                      return const _SalesTableHeader();
                                    }
                                    final itemIndex = desktop
                                        ? index - 1
                                        : index;
                                    return _OrderRow(
                                      order: items[itemIndex],
                                      desktop: desktop,
                                      onTap: () => context.push(
                                        '/sales/${items[itemIndex]['id']}',
                                      ),
                                    );
                                  },
                                ),
                                Divider(height: 1, color: colors.divider),
                                _SalesPagination(
                                  currentPage: currentPage,
                                  totalPages: totalPages,
                                  totalItems: totalItems,
                                  onPrevious: currentPage > 1
                                      ? () => setState(
                                          () => _page = currentPage - 1,
                                        )
                                      : null,
                                  onNext: currentPage < totalPages
                                      ? () => setState(
                                          () => _page = currentPage + 1,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const ShimmerList(),
                    error: (_, _) => AppError(
                      message: 'Không thể tải danh sách đơn hàng.',
                      onRetry: () => ref.invalidate(salesListProvider),
                    ),
                  ),
                  const SizedBox(height: 112),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SalesPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _SalesPagination({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          Text(
            '$totalItems đơn hàng · Trang $currentPage/$totalPages',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: onPrevious, child: const Text('Trước')),
              const SizedBox(width: AppSpacing.xs),
              FilledButton.tonal(onPressed: onNext, child: const Text('Sau')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesListControls extends StatelessWidget {
  final String? status;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;

  const _SalesListControls({
    required this.status,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Danh sách đơn hàng',
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Tìm kiếm và trạng thái chỉ áp dụng cho danh sách bên dưới.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          FilterBar(
            searchHint: 'Tìm theo mã đơn hoặc khách hàng',
            onSearchChanged: onSearchChanged,
            dense: true,
            showSearchIcon: true,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: _SalesStatusFilter(
              value: status,
              onChanged: onStatusChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesStatusFilter extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _SalesStatusFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final options = <(String?, String)>[
      (null, 'Tất cả'),
      ('PENDING', 'Chờ xử lý'),
      ('CONFIRMED', 'Đã xác nhận'),
      ('COMPLETED', 'Hoàn thành'),
      ('CANCELLED', 'Đã hủy'),
    ];

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final option in options)
          TextButton(
            onPressed: () => onChanged(option.$1),
            style: TextButton.styleFrom(
              foregroundColor: value == option.$1
                  ? primary
                  : colors.textSecondary,
              backgroundColor: value == option.$1
                  ? primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              side: BorderSide(
                color: value == option.$1 ? primary : colors.divider,
              ),
            ),
            child: Text(option.$2),
          ),
      ],
    );
  }
}

class _SalesSummarySection extends ConsumerWidget {
  final VoidCallback onRetry;

  const _SalesSummarySection({required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final period = currentMonthReportingPeriod(DateTime.now());
    final summaryAsync = ref.watch(
      salesSummaryProvider((from: period.from, to: period.to)),
    );
    final paymentAsync = ref.watch(
      paymentSummaryProvider((from: period.from, to: period.to)),
    );
    final periodLabel = reportingCompactRangeLabel(
      DateTime.parse(period.from),
      DateTime.parse(period.to),
    );

    return summaryAsync.when(
      loading: () => const AppShimmer(
        child: ShimmerBox(
          width: double.infinity,
          height: 104,
          radius: AppRadius.card,
        ),
      ),
      error: (_, _) => AppInlineError(
        message: 'Không thể tải tổng quan bán hàng tháng này.',
        onRetry: onRetry,
      ),
      data: (data) {
        final orderCount =
            data['orderCount'] ?? data['totalOrders'] ?? data['count'] ?? 0;
        final revenue =
            double.tryParse(
              data['totalRevenue']?.toString() ??
                  data['revenue']?.toString() ??
                  '0',
            ) ??
            0;
        final grossProfit =
            double.tryParse(
              data['grossProfit']?.toString() ??
                  data['profit']?.toString() ??
                  '0',
            ) ??
            0;
        final daily = (data['daily'] as List?) ?? const [];
        final lastSeven = daily.length > 7
            ? daily.sublist(daily.length - 7)
            : daily;
        final barValues = lastSeven
            .map<double>(
              (item) =>
                  double.tryParse(
                    item['revenue']?.toString() ??
                        item['totalRevenue']?.toString() ??
                        '0',
                  ) ??
                  0,
            )
            .toList();
        final barLabels = lastSeven.map<String>((item) {
          final date = item['date']?.toString() ?? '';
          final parts = date.split('-');
          return parts.length >= 3 ? '${parts[2]}/${parts[1]}' : date;
        }).toList();

        final metrics = [
          _SalesMetric(
            label: 'Đơn hàng',
            value: '$orderCount',
            assetPath: AppAssets.orders,
            color: Theme.of(context).colorScheme.primary,
          ),
          _SalesMetric(
            label: 'Doanh thu',
            value: _currencyFormat.format(revenue),
            assetPath: AppAssets.revenue,
            color: AppColors.success,
          ),
          _SalesMetric(
            label: 'Lợi nhuận gộp',
            value: _currencyFormat.format(grossProfit),
            assetPath: AppAssets.profit,
            color: grossProfit < 0 ? AppColors.danger : AppColors.success,
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (barValues.length >= 3 && barValues.any((value) => value > 0))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final revenueChart = ChartCard(
                      title: 'Doanh thu 7 ngày gần nhất',
                      height: 230,
                      trailing: Text(
                        'Đơn vị: đồng',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: MiniBarChart(
                        values: barValues,
                        labels: barLabels,
                        tooltipLabels: barLabels,
                        barColor: Theme.of(context).colorScheme.primary,
                        showLeftTitles: true,
                        valueSuffix: ' đồng',
                      ),
                    );
                    final paymentPanel = paymentAsync.when(
                      data: (items) => _PaymentMethodBreakdown(
                        items: items,
                        periodLabel: periodLabel,
                      ),
                      loading: () => const AppShimmer(
                        child: ShimmerBox(
                          width: double.infinity,
                          height: 230,
                          radius: AppRadius.card,
                        ),
                      ),
                      error: (_, _) => const AppInlineError(
                        message: 'Không thể tải cơ cấu thanh toán.',
                      ),
                    );

                    if (constraints.maxWidth < 860) {
                      return Column(
                        children: [
                          revenueChart,
                          const SizedBox(height: AppSpacing.md),
                          paymentPanel,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: revenueChart),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: paymentPanel),
                      ],
                    );
                  },
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.divider),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 620) {
                    return Column(
                      children: [
                        for (
                          var index = 0;
                          index < metrics.length;
                          index++
                        ) ...[
                          if (index > 0)
                            Divider(height: 1, color: colors.divider),
                          _SalesMetricRow(metric: metrics[index]),
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (var index = 0; index < metrics.length; index++) ...[
                        if (index > 0)
                          VerticalDivider(width: 1, color: colors.divider),
                        Expanded(
                          child: _SalesMetricCell(metric: metrics[index]),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PaymentMethodBreakdown extends StatelessWidget {
  final List<dynamic> items;
  final String periodLabel;

  const _PaymentMethodBreakdown({
    required this.items,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final rows =
        items
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => _paymentAmount(item) > 0)
            .toList()
          ..sort((a, b) => _paymentAmount(b).compareTo(_paymentAmount(a)));
    final visibleRows = rows.take(4).toList();
    final total = rows.fold<double>(
      0,
      (sum, item) => sum + _paymentAmount(item),
    );

    return ChartCard(
      title: 'Tiền đã thu theo phương thức',
      height: 230,
      trailing: Text(
        periodLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: visibleRows.isEmpty
          ? const EmptyChartPlaceholder(
              message: 'Chưa có thanh toán trong tháng.',
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < visibleRows.length; index++) ...[
                  _PaymentMethodRow(
                    item: visibleRows[index],
                    total: total,
                    color: _paymentColor(context, index),
                  ),
                  if (index < visibleRows.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
    );
  }
}

class _PaymentMethodRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final double total;
  final Color color;

  const _PaymentMethodRow({
    required this.item,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final amount = _paymentAmount(item);
    final share = total <= 0 ? 0.0 : amount / total;
    final count = int.tryParse(item['count']?.toString() ?? '') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _paymentMethodLabel(item['method']?.toString()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${compactVietnameseAmount(amount)} ₫ · $count lượt',
              style: AppTheme.tabularStyle(
                context,
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: share.clamp(0, 1),
            minHeight: 8,
            backgroundColor: colors.cardAlt,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

double _paymentAmount(Map<String, dynamic> item) =>
    double.tryParse(item['total']?.toString() ?? '') ?? 0;

String _paymentMethodLabel(String? method) {
  switch (method?.toUpperCase()) {
    case 'CASH':
      return 'Tiền mặt';
    case 'BANK_TRANSFER':
    case 'TRANSFER':
      return 'Chuyển khoản';
    case 'CREDIT_CARD':
    case 'CARD':
      return 'Thẻ';
    case 'DEBT':
      return 'Ghi nợ';
    default:
      return 'Khác';
  }
}

Color _paymentColor(BuildContext context, int index) {
  final palette = <Color>[
    Theme.of(context).colorScheme.primary,
    AppColors.success,
    AppColors.warning,
    AppColors.info,
  ];
  return palette[index % palette.length];
}

class _SalesMetricCell extends StatelessWidget {
  final _SalesMetric metric;

  const _SalesMetricCell({required this.metric});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAssetIcon(
                assetPath: metric.assetPath,
                size: 18,
                color: metric.color,
                semanticLabel: metric.label,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                metric.label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric.value,
              style: AppTheme.tabularStyle(
                context,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tháng này',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SalesMetricRow extends StatelessWidget {
  final _SalesMetric metric;

  const _SalesMetricRow({required this.metric});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AppAssetIcon(
            assetPath: metric.assetPath,
            size: 20,
            color: metric.color,
            semanticLabel: metric.label,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${metric.label} • Tháng này',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ),
          Flexible(
            child: Text(
              metric.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.tabularStyle(
                context,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesTableHeader extends StatelessWidget {
  const _SalesTableHeader();

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Container(
      color: colors.cardAlt,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('Mã đơn')),
          Expanded(flex: 3, child: Text('Khách hàng')),
          Expanded(flex: 2, child: Text('Thanh toán')),
          Expanded(flex: 2, child: Text('Trạng thái')),
          Expanded(
            flex: 2,
            child: Text('Tổng tiền', textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool desktop;
  final VoidCallback onTap;

  const _OrderRow({
    required this.order,
    required this.desktop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final status = _OrderStatus.from(order['status']?.toString());
    final total = double.tryParse(order['totalAmount']?.toString() ?? '0') ?? 0;
    final paid =
        double.tryParse(
          order['amountPaid']?.toString() ??
              order['paidAmount']?.toString() ??
              '0',
        ) ??
        0;
    final customer = order['customer']?['name']?.toString() ?? 'Khách mua lẻ';
    final code = order['orderCode']?.toString() ?? 'DH-${order['id']}';
    final payment = paid >= total && paid > 0
        ? 'Đã thanh toán'
        : paid > 0
        ? 'Thanh toán một phần'
        : 'Chưa thanh toán';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        child: desktop
            ? Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      code,
                      style: AppTheme.tabularStyle(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      payment,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppStatusBadge(
                        label: status.label,
                        color: status.color,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _currencyFormat.format(total),
                      textAlign: TextAlign.right,
                      style: AppTheme.tabularStyle(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              code,
                              style: AppTheme.tabularStyle(
                                context,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              customer,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _currencyFormat.format(total),
                        style: AppTheme.tabularStyle(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppStatusBadge(label: status.label, color: status.color),
                      Text(
                        payment,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
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

class _SalesMetric {
  final String label;
  final String value;
  final String assetPath;
  final Color color;

  const _SalesMetric({
    required this.label,
    required this.value,
    required this.assetPath,
    required this.color,
  });
}

class _OrderStatus {
  final String label;
  final Color color;

  const _OrderStatus(this.label, this.color);

  factory _OrderStatus.from(String? value) {
    switch (value) {
      case 'COMPLETED':
      case 'DELIVERED':
        return const _OrderStatus('Hoàn thành', AppColors.success);
      case 'PENDING':
        return const _OrderStatus('Chờ xử lý', AppColors.warning);
      default:
        return const _OrderStatus('Đã hủy', AppColors.danger);
    }
  }
}
