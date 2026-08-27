import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/custom_date_range_picker.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../providers/inventory_provider.dart';

final _xntQuantityFormat = NumberFormat.decimalPattern('vi_VN');

bool xntUsesCardLayout(double width) => width < 720;

String formatXntQuantity(dynamic value) {
  final number = value is num ? value : num.tryParse(value?.toString() ?? '');
  return _xntQuantityFormat.format(number ?? 0);
}

class XntReportScreen extends ConsumerStatefulWidget {
  const XntReportScreen({super.key});
  @override
  ConsumerState<XntReportScreen> createState() => _XntReportScreenState();
}

class _XntReportScreenState extends ConsumerState<XntReportScreen> {
  late String _from;
  late String _to;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1).toIso8601String().split('T').first;
    _to = now.toIso8601String().split('T').first;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final reportAsync = ref.watch(
      xntReportProvider((from: _from, to: _to, warehouseId: null)),
    );
    final slowAsync = ref.watch(slowMovingProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'Báo cáo XNT Kho',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          featureGuideButton(context, 'xnt_report'),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () async {
              final picked = await showCustomDateRangePicker(
                context,
                initialRange: DateTimeRange(
                  start: DateTime.parse(_from),
                  end: DateTime.parse(_to),
                ),
              );
              if (picked != null) {
                setState(() {
                  _from = picked.start.toIso8601String().split('T').first;
                  _to = picked.end.toIso8601String().split('T').first;
                  _page = 1;
                });
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 48, color: c.textMuted),
                const SizedBox(height: 12),
                Text(
                  'Không tải được dữ liệu báo cáo\n$e',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(xntReportProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Thử lại'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final summary = data['summary'] as Map<String, dynamic>? ?? {};
          final items = (data['items'] as List?) ?? [];
          const pageSize = 20;
          final totalPages = items.isEmpty
              ? 1
              : (items.length / pageSize).ceil();
          final currentPage = _page.clamp(1, totalPages);
          final pageItems = items
              .skip((currentPage - 1) * pageSize)
              .take(pageSize)
              .toList();
          final openingSkuCount = summary['openingSkuCount'] ?? 0;
          final importedSkuCount = summary['importedSkuCount'] ?? 0;
          final exportedSkuCount = summary['exportedSkuCount'] ?? 0;
          final closingSkuCount = summary['closingSkuCount'] ?? 0;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period label styled like a premium badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.date_range_rounded,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Kỳ báo cáo: $_from → $_to',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Các thẻ đếm SKU, không cộng lẫn số lượng khác đơn vị tính.
                LayoutBuilder(
                  builder: (context, constraints) => GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: constraints.maxWidth < 680 ? 2 : 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: constraints.maxWidth < 680 ? 2.35 : 1.9,
                    children: [
                      _MiniCard(
                        'SKU có tồn đầu',
                        '$openingSkuCount',
                        AppColors.info,
                      ),
                      _MiniCard(
                        'SKU có nhập',
                        '$importedSkuCount',
                        AppColors.success,
                      ),
                      _MiniCard(
                        'SKU có xuất',
                        '$exportedSkuCount',
                        AppColors.warning,
                      ),
                      _MiniCard(
                        'SKU còn tồn',
                        '$closingSkuCount',
                        AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'Chi tiết sản phẩm',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                if (items.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Không có dữ liệu phát sinh trong kỳ',
                        style: GoogleFonts.inter(
                          color: c.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) =>
                        xntUsesCardLayout(constraints.maxWidth)
                        ? _XntProductCards(items: pageItems)
                        : _XntProductTable(items: pageItems),
                  ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AppPaginationBar(
                    currentPage: currentPage,
                    totalPages: totalPages,
                    totalItems: items.length,
                    itemLabel: 'sản phẩm',
                    onPageChanged: (page) => setState(() => _page = page),
                  ),
                ],
                const SizedBox(height: 24),

                // Slow-moving warnings
                Text(
                  'Cảnh báo hàng chậm luân chuyển',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 12),
                slowAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(
                    'Lỗi: $e',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  data: (slowItems) {
                    if (slowItems.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Không có sản phẩm chậm luân chuyển nào được phát hiện.',
                          style: GoogleFonts.inter(
                            color: c.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: slowItems.take(5).map<Widget>((item) {
                        final name =
                            item['productName'] ?? item['name'] ?? 'SP';
                        final qty =
                            item['quantity'] ?? item['currentStock'] ?? 0;
                        final unit = item['unit']?.toString() ?? 'đơn vị';
                        final days =
                            item['daysUnsold'] ??
                            item['daysSinceLastSale'] ??
                            0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: c.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tồn vướng kho: ${formatXntQuantity(qty)} $unit',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$days ngày đọng',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _XntProductCards extends StatelessWidget {
  final List<dynamic> items;

  const _XntProductCards({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          _XntProductCard(item: Map<String, dynamic>.from(items[index] as Map)),
        ],
      ],
    );
  }
}

class _XntProductCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _XntProductCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final sku = item['sku'] ?? item['productCode'] ?? '';
    final name = item['productName'] ?? item['name'] ?? 'Sản phẩm chưa có tên';
    final unit = item['unit']?.toString() ?? 'Đơn vị';
    final opening = item['openingStock'] ?? 0;
    final imported = item['imported'] ?? item['totalImport'] ?? 0;
    final exported = item['exported'] ?? item['totalExport'] ?? 0;
    final closing = item['closingStock'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
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
                      name.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sku.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.divider),
                ),
                child: Text(
                  unit,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _XntMetric(
                  label: 'Tồn đầu',
                  value: opening,
                  unit: unit,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _XntMetric(
                  label: 'Nhập',
                  value: imported,
                  unit: unit,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _XntMetric(
                  label: 'Xuất',
                  value: exported,
                  unit: unit,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _XntMetric(
                  label: 'Tồn cuối',
                  value: closing,
                  unit: unit,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _XntMetric extends StatelessWidget {
  final String label;
  final dynamic value;
  final String unit;
  final Color color;

  const _XntMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: colors.textSecondary),
          ),
          const SizedBox(height: 3),
          Text(
            '${formatXntQuantity(value)} $unit',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _XntProductTable extends StatelessWidget {
  final List<dynamic> items;

  const _XntProductTable({required this.items});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    Text header(String value) => Text(
      value,
      style: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: colors.textSecondary,
      ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.divider.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(colors.surface),
          columnSpacing: 24,
          columns: [
            DataColumn(label: header('Mã SP')),
            DataColumn(label: header('Tên sản phẩm')),
            DataColumn(label: header('Đơn vị')),
            DataColumn(label: header('Tồn đầu')),
            DataColumn(label: header('Nhập')),
            DataColumn(label: header('Xuất')),
            DataColumn(label: header('Tồn cuối')),
          ],
          rows: items.map<DataRow>((rawItem) {
            final item = Map<String, dynamic>.from(rawItem as Map);
            final sku = item['sku'] ?? item['productCode'] ?? '';
            final name = item['productName'] ?? item['name'] ?? '';
            final unit = item['unit']?.toString() ?? 'Đơn vị';
            Text quantity(dynamic value, {Color? color, bool bold = false}) =>
                Text(
                  formatXntQuantity(value),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: color ?? colors.textSecondary,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  ),
                );
            return DataRow(
              cells: [
                DataCell(Text(sku.toString())),
                DataCell(
                  SizedBox(
                    width: 180,
                    child: Text(
                      name.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(unit)),
                DataCell(quantity(item['openingStock'])),
                DataCell(
                  quantity(
                    item['imported'] ?? item['totalImport'],
                    color: AppColors.success,
                    bold: true,
                  ),
                ),
                DataCell(
                  quantity(
                    item['exported'] ?? item['totalExport'],
                    color: AppColors.warning,
                    bold: true,
                  ),
                ),
                DataCell(
                  quantity(
                    item['closingStock'],
                    color: colors.textPrimary,
                    bold: true,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
