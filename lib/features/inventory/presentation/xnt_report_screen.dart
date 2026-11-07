import '../../../core/assets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/custom_date_range_picker.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../providers/inventory_provider.dart';
import '../../../core/providers/reporting_period_provider.dart';
import '../../../core/utils/excel_export_service.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/shop_provider.dart';

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
  DateTimeRange? _rangeOverride;
  int _page = 1;
  int _exportVersion = 0;
  bool _exporting = false;
  ({int? shopId, bool allShops, String from, String to})? _listScope;

  ({String from, String to}) _period() {
    final period = ref.read(tabResolvedPeriodProvider('inventory'));
    return (
      from: (_rangeOverride?.start ?? period.currentFrom)
          .toIso8601String()
          .split('T')
          .first,
      to: (_rangeOverride?.end ?? period.currentTo)
          .toIso8601String()
          .split('T')
          .first,
    );
  }

  Future<void> _pickPeriod() async {
    final period = _period(), version = _exportVersion;
    final picked = await showCustomDateRangePicker(
      context,
      initialRange: DateTimeRange(
        start: DateTime.parse(period.from),
        end: DateTime.parse(period.to),
      ),
    );
    if (!mounted || picked == null || version != _exportVersion) return;
    setState(() {
      _rangeOverride = picked;
      _page = 1;
      _exportVersion++;
    });
  }

  Future<void> _exportReport() async {
    if (_exporting) return;
    final shop = ref.read(shopProvider), period = _period();
    final shopId = shop.currentShopId,
        actor = ref.read(authProvider).user?['id']?.toString(),
        version = _exportVersion;
    bool current() {
      if (!mounted || version != _exportVersion) return false;
      final auth = ref.read(authProvider), active = ref.read(shopProvider);
      return auth.isLoggedIn &&
          !auth.isOfflineSession &&
          actor != null &&
          auth.user?['id']?.toString() == actor &&
          shopId != null &&
          !active.isAllShops &&
          active.currentShopId == shopId &&
          active.hasPermission('inventory') &&
          _period() == period;
    }

    if (!current()) return;
    setState(() => _exporting = true);
    try {
      final report = await ref
          .read(inventoryRepoProvider)
          .exportXntInShop(
            shopId!,
            from: period.from,
            to: period.to,
            isCurrentScope: current,
          );
      if (!current()) return;
      final downloaded = await ExcelExportService.exportXnt(
        report,
        shopName: shop.currentShopName ?? 'Cửa hàng $shopId',
      );
      if (!mounted || !current()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'Đã gửi tệp Excel gồm ${report.items.length} sản phẩm để tải xuống.'
                : 'Chưa tải được tệp Excel. Vui lòng thử lại.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted || !current()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : error is FormatException
                ? error.message
                : 'Chưa xuất được báo cáo. Vui lòng thử lại.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      authProvider.select(
        (value) => (
          value.isLoggedIn,
          value.user?['id']?.toString(),
          value.isOfflineSession,
        ),
      ),
      (previous, next) {
        if (previous != next) _exportVersion++;
      },
    );
    ref.listen(shopProvider, (previous, next) {
      if (previous?.currentShopId != next.currentShopId ||
          previous?.isAllShops != next.isAllShops ||
          previous?.hasPermission('inventory') !=
              next.hasPermission('inventory')) {
        _exportVersion++;
      }
    });
    ref.listen(tabResolvedPeriodProvider('inventory'), (previous, next) {
      if (previous?.currentFrom != next.currentFrom ||
          previous?.currentTo != next.currentTo) {
        setState(() {
          _rangeOverride = null;
          _page = 1;
          _exportVersion++;
        });
      }
    });
    ref.watch(tabResolvedPeriodProvider('inventory'));
    final period = _period(), shop = ref.watch(shopProvider);
    final listScope = (
      shopId: shop.currentShopId,
      allShops: shop.isAllShops,
      from: period.from,
      to: period.to,
    );
    if (_listScope != listScope) {
      _listScope = listScope;
      _page = 1;
      _exportVersion++;
    }
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final reportAsync = ref.watch(
      xntReportProvider((from: period.from, to: period.to, warehouseId: null)),
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
          if (MediaQuery.sizeOf(context).width < 720)
            PopupMenuButton<String>(
              tooltip: 'Tác vụ báo cáo',
              onSelected: (value) {
                if (value == 'period') _pickPeriod();
                if (value == 'export') _exportReport();
                if (value == 'guide') showFeatureGuide(context, 'xnt_report');
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'period', child: Text('Chọn kỳ')),
                PopupMenuItem(
                  value: 'export',
                  enabled:
                      !_exporting &&
                      !shop.isAllShops &&
                      shop.hasPermission('inventory'),
                  child: const Text('Xuất XNT Excel'),
                ),
                const PopupMenuItem(value: 'guide', child: Text('Hướng dẫn')),
              ],
            )
          else ...[
            featureGuideButton(context, 'xnt_report'),
            OutlinedButton.icon(
              onPressed:
                  _exporting ||
                      shop.isAllShops ||
                      !shop.hasPermission('inventory')
                  ? null
                  : _exportReport,
              icon: const AppIcon(Icons.download_outlined, size: 18),
              label: Text(_exporting ? 'Đang xuất…' : 'Xuất XNT Excel'),
            ),
            IconButton(
              tooltip: 'Chọn kỳ báo cáo',
              icon: const AppIcon(Icons.calendar_month_rounded),
              onPressed: _pickPeriod,
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppInlineError(
              message: 'Không tải được dữ liệu báo cáo. Vui lòng thử lại sau.',
              onRetry: () => ref.invalidate(xntReportProvider),
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

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(xntReportProvider);
              ref.invalidate(slowMovingProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                        AppIcon(
                          Icons.date_range_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Kỳ báo cáo: ${period.from} → ${period.to}',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Các thẻ đếm SKU, không cộng lẫn số lượng khác đơn vị tính.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 680;
                      final cards = [
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
                      ];

                      if (isCompact) {
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: cards[0]),
                                const SizedBox(width: 8),
                                Expanded(child: cards[1]),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: cards[2]),
                                const SizedBox(width: 8),
                                Expanded(child: cards[3]),
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 8),
                          Expanded(child: cards[1]),
                          const SizedBox(width: 8),
                          Expanded(child: cards[2]),
                          const SizedBox(width: 8),
                          Expanded(child: cards[3]),
                        ],
                      );
                    },
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
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: AppEmpty(
                          visual: AppEmptyVisual.document,
                          message: 'Không có dữ liệu phát sinh trong kỳ',
                          subtitle:
                              'Thử chọn khoảng thời gian khác hoặc kiểm tra lại các phát sinh nhập xuất kho.',
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
                    error: (e, _) => AppInlineError(
                      message:
                          'Không tải được cảnh báo hàng chậm luân chuyển. Vui lòng thử lại sau.',
                      onRetry: () => ref.invalidate(slowMovingProvider),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
        mainAxisAlignment: MainAxisAlignment.center,
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
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
