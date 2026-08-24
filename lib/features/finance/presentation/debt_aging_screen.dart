import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/excel_export_service.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/chart_widgets.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../customers/providers/customer_provider.dart';

bool debtAgingUsesMobileCards(double width) => width < 720;

final _debtCurrency = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

List<Map<String, dynamic>> debtAgingCustomers(Map<String, dynamic> data) {
  return ((data['customers'] as List?) ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

class DebtAgingScreen extends ConsumerWidget {
  const DebtAgingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final asOf = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final reportAsync = ref.watch(debtAgingProvider(asOf));

    Future<void> exportReport() async {
      try {
        final report = await ref.read(debtAgingProvider(asOf).future);
        final launched = await ExcelExportService.exportDebtAgingToExcel(
          report,
        );
        if (launched) {
          ToastService.showSuccess('Đã tạo file Excel tuổi nợ');
        } else {
          ToastService.showError('Trình duyệt đã chặn tải file');
        }
      } catch (_) {
        ToastService.showError('Không thể xuất báo cáo tuổi nợ');
      }
    }

    Widget headerActions() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        featureGuideButton(context, 'debt_aging'),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: 'Xuất Excel',
          onPressed: exportReport,
          icon: const Icon(Icons.file_download_outlined),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: colors.bg,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(debtAgingProvider(asOf)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: AppResponsiveContent(
            maxWidth: 1320,
            verticalPadding: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppPageHeader(
                  title: 'Tuổi nợ phải thu',
                  subtitle:
                      'Theo dõi khoản khách hàng còn phải thanh toán và ưu tiên nợ đã quá hạn.',
                  dense: true,
                  breadcrumbs: [
                    TextButton(
                      onPressed: () => context.go('/finance'),
                      child: const Text('Tài chính'),
                    ),
                    const Text('Công nợ khách hàng'),
                  ],
                  action: headerActions(),
                  compactAction: headerActions(),
                ),
                reportAsync.when(
                  loading: () => const _DebtAgingLoading(),
                  error: (_, _) => AppInlineError(
                    message: 'Không thể tải báo cáo tuổi nợ phải thu.',
                    onRetry: () => ref.invalidate(debtAgingProvider(asOf)),
                  ),
                  data: (data) => _DebtAgingReport(data: data, asOf: asOf),
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

class _DebtAgingReport extends StatelessWidget {
  final Map<String, dynamic> data;
  final String asOf;

  const _DebtAgingReport({required this.data, required this.asOf});

  @override
  Widget build(BuildContext context) {
    final summary = data['summary'] as Map<String, dynamic>? ?? const {};
    final buckets = data['buckets'] as Map<String, dynamic>? ?? const {};
    final customers = debtAgingCustomers(data);
    final total = asDouble(summary['totalDebt'] ?? data['totalDebt']);
    final overdue = asDouble(summary['overdueDebt']);
    final overdueRatio = asDouble(summary['overdueRatio']);
    final receivableCount = asInt(
      summary['receivableCount'] ?? data['receivableCount'],
    );
    final customerCount = asInt(
      summary['customerCount'] ?? data['customerCount'] ?? customers.length,
    );
    final current = asDouble(buckets['current']);
    final past30 = asDouble(buckets['past30'] ?? buckets['days30']);
    final past60 = asDouble(buckets['past60'] ?? buckets['days60']);
    final past90 = asDouble(
      buckets['past90'] ?? buckets['days90'] ?? buckets['over90'],
    );
    final overdueCustomers = customers
        .where((item) => asDouble(item['overdue']) > 0)
        .toList();

    if (total <= 0) {
      return const AppEmpty(
        visual: AppEmptyVisual.finance,
        message: 'Không có khoản phải thu đang mở',
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
              title: 'Tổng phải thu',
              value: _debtCurrency.format(total),
              color: AppColors.primary,
              assetPath: AppAssets.cash,
              badgeText: 'Tại ${_displayDate(asOf)}',
            ),
            AppKpiCard(
              title: 'Đã quá hạn',
              value: _debtCurrency.format(overdue),
              color: AppColors.danger,
              assetPath: AppAssets.orders,
              badgeText:
                  '${NumberFormat('0.0', 'vi_VN').format(overdueRatio * 100)}%',
            ),
            AppKpiCard(
              title: 'Khoản đang mở',
              value: NumberFormat.decimalPattern(
                'vi_VN',
              ).format(receivableCount),
              color: AppColors.warning,
              assetPath: AppAssets.book,
              badgeText: 'Loại trừ đã trả/hủy',
            ),
            AppKpiCard(
              title: 'Khách hàng còn nợ',
              value: NumberFormat.decimalPattern('vi_VN').format(customerCount),
              color: AppColors.info,
              assetPath: AppAssets.inventory,
              badgeText: 'Khách duy nhất',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final chart = ChartCard(
              title: 'Phân nhóm tuổi nợ phải thu',
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
            final priority = _CustomerPriorityPanel(customers: customers);

            if (constraints.maxWidth < 980) {
              return Column(
                children: [
                  chart,
                  const SizedBox(height: AppSpacing.md),
                  priority,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: chart),
                const SizedBox(width: AppSpacing.md),
                Expanded(flex: 2, child: priority),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        _OverdueCustomersSection(
          customers: overdueCustomers,
          totalCount: overdueCustomers.length,
        ),
      ],
    );
  }
}

class _CustomerPriorityPanel extends StatelessWidget {
  final List<Map<String, dynamic>> customers;

  const _CustomerPriorityPanel({required this.customers});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final visible = customers.take(5).toList();
    final maximum = visible.fold<double>(
      0,
      (value, item) =>
          asDouble(item['total']) > value ? asDouble(item['total']) : value,
    );

    return AppCardContainer(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        height: 294,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Khách hàng cần ưu tiên',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Xếp theo nợ quá hạn, sau đó đến tổng dư nợ.',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        'Chưa có khách hàng cần ưu tiên.',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final customer = visible[index];
                        final total = asDouble(customer['total']);
                        final overdue = asDouble(customer['overdue']);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${index + 1}. ${customer['customerName'] ?? 'Chưa xác định'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  _debtCurrency.format(total),
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
                                  : (total / maximum).clamp(0, 1),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(4),
                              backgroundColor: colors.divider,
                              valueColor: AlwaysStoppedAnimation(
                                overdue > 0
                                    ? AppColors.danger
                                    : AppColors.success,
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

class _OverdueCustomersSection extends StatelessWidget {
  final List<Map<String, dynamic>> customers;
  final int totalCount;

  const _OverdueCustomersSection({
    required this.customers,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (debtAgingUsesMobileCards(constraints.maxWidth)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Khách hàng cần thu hồi sớm',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (customers.isEmpty)
                const AppEmpty(
                  visual: AppEmptyVisual.finance,
                  message: 'Không có khách hàng nợ quá hạn',
                )
              else
                for (final customer in customers.take(10))
                  _OverdueCustomerMobileCard(customer: customer),
            ],
          );
        }

        return AppDataTable<Map<String, dynamic>>(
          title: 'Khách hàng cần thu hồi sớm',
          assetPath: AppAssets.cash,
          iconColor: AppColors.danger,
          headerAction: Text(
            'Hiển thị ${customers.take(10).length}/$totalCount khách',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          columns: const [
            AppDataTableColumn(title: 'KHÁCH HÀNG', flex: 4),
            AppDataTableColumn(title: 'QUÁ HẠN LÂU NHẤT', flex: 2),
            AppDataTableColumn(title: 'NỢ QUÁ HẠN', flex: 2, alignRight: true),
            AppDataTableColumn(title: 'TỔNG DƯ NỢ', flex: 2, alignRight: true),
            AppDataTableColumn(title: 'THAO TÁC', flex: 2, alignRight: true),
          ],
          items: customers.take(10).toList(),
          rowBuilder: (context, customer, _) =>
              _OverdueCustomerDesktopRow(customer: customer),
          emptyMessage: 'Không có khách hàng nợ quá hạn.',
        );
      },
    );
  }
}

class _OverdueCustomerDesktopRow extends StatelessWidget {
  final Map<String, dynamic> customer;

  const _OverdueCustomerDesktopRow({required this.customer});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final days = asInt(customer['overdueDays']);
    final name = customer['customerName']?.toString() ?? 'Chưa xác định';
    final overdue = asDouble(customer['overdue']);
    final total = asDouble(customer['total']);

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
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppStatusBadge(
                label: '$days ngày',
                color: AppColors.danger,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _debtCurrency.format(overdue),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _debtCurrency.format(total),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _showReminderDialog(
                  context,
                  customerName: name,
                  debtAmount: _debtCurrency.format(total),
                ),
                child: const Text('Soạn nhắc nợ'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverdueCustomerMobileCard extends StatelessWidget {
  final Map<String, dynamic> customer;

  const _OverdueCustomerMobileCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    final name = customer['customerName']?.toString() ?? 'Chưa xác định';
    final days = asInt(customer['overdueDays']);
    final overdue = asDouble(customer['overdue']);
    final total = asDouble(customer['total']);
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
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              AppStatusBadge(
                label: '$days ngày quá hạn',
                color: AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Quá hạn ${_debtCurrency.format(overdue)}',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _debtCurrency.format(total),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showReminderDialog(
                context,
                customerName: name,
                debtAmount: _debtCurrency.format(total),
              ),
              child: const Text('Soạn nhắc nợ'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtAgingLoading extends StatelessWidget {
  const _DebtAgingLoading();

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

void _showReminderDialog(
  BuildContext context, {
  required String customerName,
  required String debtAmount,
}) {
  final colors = AppThemeColors.of(context);
  final reminderText =
      'Kính gửi $customerName, cửa hàng xin thông báo khoản công nợ hiện tại của quý khách là $debtAmount. Vui lòng liên hệ cửa hàng để đối chiếu và thanh toán. Xin cảm ơn.';

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: colors.card,
      title: const Text('Nội dung nhắc nợ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Khách hàng: $customerName'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tổng dư nợ: $debtAmount',
            style: const TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.cardAlt,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: colors.divider),
            ),
            child: SelectableText(reminderText),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Đóng'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: reminderText));
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            ToastService.showSuccess('Đã sao chép nội dung nhắc nợ');
          },
          icon: const AppAssetIcon(
            assetPath: AppAssets.copy,
            size: 16,
            color: Colors.white,
          ),
          label: const Text('Sao chép'),
        ),
      ],
    ),
  );
}

String _displayDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null ? '—' : DateFormat('dd/MM/yyyy').format(date);
}
