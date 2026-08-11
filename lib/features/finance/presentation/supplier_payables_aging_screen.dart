import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/chart_widgets.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../suppliers/providers/supplier_provider.dart';

bool supplierPayablesUsesMobileCards(double width) => width < 720;

final _payableCurrency = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class SupplierPayablesAgingScreen extends ConsumerWidget {
  const SupplierPayablesAgingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final asOf = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final reportAsync = ref.watch(supplierPayablesAgingProvider(asOf));

    return Scaffold(
      backgroundColor: colors.bg,
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(supplierPayablesAgingProvider(asOf)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: AppResponsiveContent(
            maxWidth: 1320,
            verticalPadding: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppPageHeader(
                  title: 'Tuổi nợ phải trả',
                  subtitle:
                      'Theo dõi khoản còn phải thanh toán và ưu tiên nhà cung cấp đã quá hạn.',
                  dense: true,
                  breadcrumbs: [
                    TextButton(
                      onPressed: () => context.go('/finance'),
                      child: const Text('Tài chính'),
                    ),
                    const Text('Công nợ nhà cung cấp'),
                  ],
                  action: featureGuideButton(context, 'debt_aging'),
                  compactAction: featureGuideButton(context, 'debt_aging'),
                ),
                reportAsync.when(
                  loading: () => const _PayablesReportLoading(),
                  error: (_, _) => AppInlineError(
                    message: 'Không thể tải báo cáo công nợ nhà cung cấp.',
                    onRetry: () =>
                        ref.invalidate(supplierPayablesAgingProvider(asOf)),
                  ),
                  data: (data) => _PayablesReport(data: data, asOf: asOf),
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

class _PayablesReport extends StatelessWidget {
  final Map<String, dynamic> data;
  final String asOf;

  const _PayablesReport({required this.data, required this.asOf});

  @override
  Widget build(BuildContext context) {
    final summary = data['summary'] as Map<String, dynamic>? ?? const {};
    final buckets = data['buckets'] as Map<String, dynamic>? ?? const {};
    final suppliers = ((data['suppliers'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final items = ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final total = asDouble(summary['totalOutstanding']);
    final overdue = asDouble(summary['overdueOutstanding']);
    final overdueRatio = asDouble(summary['overdueRatio']);
    final payableCount = asInt(summary['payableCount']);
    final supplierCount = asInt(summary['supplierCount']);
    final current = asDouble(buckets['current']);
    final past30 = asDouble(buckets['past30']);
    final past60 = asDouble(buckets['past60']);
    final past90 = asDouble(buckets['past90']);

    if (total <= 0) {
      return const AppEmpty(
        visual: AppEmptyVisual.finance,
        message: 'Không có khoản phải trả đang mở',
        subtitle: 'Các khoản đã thanh toán hoặc đã hủy không được tính.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFillGrid(
          minItemWidth: 190,
          maxColumns: 4,
          itemHeight: 94,
          children: [
            AppKpiCard(
              title: 'Tổng phải trả',
              value: _payableCurrency.format(total),
              color: AppColors.primary,
              assetPath: AppAssets.cash,
              badgeText: 'Tại $asOf',
            ),
            AppKpiCard(
              title: 'Đã quá hạn',
              value: _payableCurrency.format(overdue),
              color: AppColors.danger,
              assetPath: AppAssets.orders,
              badgeText:
                  '${NumberFormat('0.0', 'vi_VN').format(overdueRatio * 100)}%',
            ),
            AppKpiCard(
              title: 'Khoản đang mở',
              value: NumberFormat.decimalPattern('vi_VN').format(payableCount),
              color: AppColors.warning,
              assetPath: AppAssets.book,
              badgeText: 'Loại trừ đã trả/hủy',
            ),
            AppKpiCard(
              title: 'Nhà cung cấp có dư nợ',
              value: NumberFormat.decimalPattern('vi_VN').format(supplierCount),
              color: AppColors.info,
              assetPath: AppAssets.inventory,
              badgeText: 'Cần theo dõi',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final chart = ChartCard(
              title: 'Phân nhóm tuổi nợ phải trả',
              height: 330,
              trailing: const Text('Đơn vị: đồng'),
              child: MiniBarChart(
                values: [current, past30, past60, past90],
                labels: const ['Chưa hạn', '1–30', '31–60', '>60'],
                tooltipLabels: const [
                  'Chưa đến hạn',
                  'Quá hạn 1–30 ngày',
                  'Quá hạn 31–60 ngày',
                  'Quá hạn trên 60 ngày',
                ],
                showLeftTitles: true,
                valueSuffix: ' ₫',
                barColors: const [
                  AppColors.success,
                  AppColors.info,
                  AppColors.warning,
                  AppColors.danger,
                ],
              ),
            );
            final priorities = _SupplierPriorityPanel(
              suppliers: suppliers,
              maximum: suppliers.fold<double>(
                0,
                (value, item) => asDouble(item['totalOutstanding']) > value
                    ? asDouble(item['totalOutstanding'])
                    : value,
              ),
            );

            if (constraints.maxWidth < 980) {
              return Column(
                children: [
                  chart,
                  const SizedBox(height: AppSpacing.md),
                  priorities,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: chart),
                const SizedBox(width: AppSpacing.md),
                Expanded(flex: 2, child: priorities),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        _OpenPayablesSection(items: items, totalCount: payableCount),
      ],
    );
  }
}

class _SupplierPriorityPanel extends StatelessWidget {
  final List<Map<String, dynamic>> suppliers;
  final double maximum;

  const _SupplierPriorityPanel({
    required this.suppliers,
    required this.maximum,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return AppCardContainer(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        height: 294,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nhà cung cấp cần ưu tiên',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Xếp theo số tiền quá hạn, sau đó đến tổng dư nợ.',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: suppliers.isEmpty
                  ? Center(
                      child: Text(
                        'Chưa có nhà cung cấp cần ưu tiên.',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: suppliers.take(5).length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final supplier = suppliers[index];
                        final outstanding = asDouble(
                          supplier['totalOutstanding'],
                        );
                        final overdue = asDouble(
                          supplier['overdueOutstanding'],
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${index + 1}. ${supplier['supplierName'] ?? 'Chưa xác định'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  _payableCurrency.format(outstanding),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            LinearProgressIndicator(
                              value: maximum <= 0
                                  ? 0
                                  : (outstanding / maximum).clamp(0, 1),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(4),
                              backgroundColor: colors.divider,
                              valueColor: AlwaysStoppedAnimation(
                                overdue > 0
                                    ? AppColors.danger
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenPayablesSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final int totalCount;

  const _OpenPayablesSection({required this.items, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (supplierPayablesUsesMobileCards(constraints.maxWidth)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Khoản cần xử lý sớm',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final item in items) _PayableMobileCard(item: item),
            ],
          );
        }

        return AppDataTable<Map<String, dynamic>>(
          title: 'Khoản cần xử lý sớm',
          assetPath: AppAssets.cash,
          iconColor: AppColors.danger,
          headerAction: Text(
            'Hiển thị ${items.length}/$totalCount khoản',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          columns: const [
            AppDataTableColumn(title: 'NHÀ CUNG CẤP', flex: 4),
            AppDataTableColumn(title: 'HẠN THANH TOÁN', flex: 2),
            AppDataTableColumn(title: 'TRẠNG THÁI', flex: 2),
            AppDataTableColumn(title: 'ĐÃ TRẢ', flex: 2, alignRight: true),
            AppDataTableColumn(title: 'CÒN LẠI', flex: 2, alignRight: true),
          ],
          items: items,
          rowBuilder: (context, item, _) => _PayableDesktopRow(item: item),
          emptyMessage: 'Không có khoản phải trả đang mở.',
        );
      },
    );
  }
}

class _PayableDesktopRow extends StatelessWidget {
  final Map<String, dynamic> item;

  const _PayableDesktopRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final days = asInt(item['daysOverdue']);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              item['supplierName']?.toString() ?? 'Chưa xác định',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _displayDate(item['dueDate']),
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppStatusBadge(
                label: days > 0 ? 'Quá hạn $days ngày' : 'Chưa đến hạn',
                color: days > 0 ? AppColors.danger : AppColors.success,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _payableCurrency.format(asDouble(item['paidAmount'])),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _payableCurrency.format(asDouble(item['remaining'])),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: days > 0 ? AppColors.danger : colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayableMobileCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _PayableMobileCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final days = asInt(item['daysOverdue']);
    return AppCardContainer(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item['supplierName']?.toString() ?? 'Chưa xác định',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              AppStatusBadge(
                label: days > 0 ? 'Quá hạn $days ngày' : 'Chưa hạn',
                color: days > 0 ? AppColors.danger : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hạn ${_displayDate(item['dueDate'])}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ),
              Text(
                _payableCurrency.format(asDouble(item['remaining'])),
                style: TextStyle(
                  color: days > 0 ? AppColors.danger : colors.textPrimary,
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

class _PayablesReportLoading extends StatelessWidget {
  const _PayablesReportLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ShimmerList(count: 2),
        SizedBox(height: AppSpacing.lg),
        AppShimmer(
          child: ShimmerBox(
            width: double.infinity,
            height: 330,
            radius: AppRadius.card,
          ),
        ),
      ],
    );
  }
}

String _displayDate(dynamic value) {
  final raw = value?.toString() ?? '';
  final date = DateTime.tryParse(raw);
  return date == null ? '—' : DateFormat('dd/MM/yyyy').format(date);
}
