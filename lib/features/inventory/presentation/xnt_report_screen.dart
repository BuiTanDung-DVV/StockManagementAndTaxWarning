import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_date_range_picker.dart';
import '../providers/inventory_provider.dart';

class XntReportScreen extends ConsumerStatefulWidget {
  const XntReportScreen({super.key});
  @override
  ConsumerState<XntReportScreen> createState() => _XntReportScreenState();
}

class _XntReportScreenState extends ConsumerState<XntReportScreen> {
  late String _from;
  late String _to;

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
    final reportAsync = ref.watch(xntReportProvider((from: _from, to: _to, warehouseId: null)));
    final slowAsync = ref.watch(slowMovingProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Báo cáo XNT Kho',
          style: GoogleFonts.outfit(
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final summary = data['summary'] as Map<String, dynamic>? ?? {};
          final items = (data['items'] as List?) ?? [];
          final openingTotal = summary['openingStock'] ?? 0;
          final importTotal = summary['totalImport'] ?? 0;
          final exportTotal = summary['totalExport'] ?? 0;
          final closingTotal = summary['closingStock'] ?? 0;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period label styled like a premium badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.date_range_rounded, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Kỳ báo cáo: $_from → $_to',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Summary cards grid
                Row(
                  children: [
                    Expanded(child: _MiniCard('Tồn đầu', '$openingTotal', AppColors.info)),
                    const SizedBox(width: 8),
                    Expanded(child: _MiniCard('Tổng nhập', '$importTotal', AppColors.success)),
                    const SizedBox(width: 8),
                    Expanded(child: _MiniCard('Tổng xuất', '$exportTotal', AppColors.warning)),
                    const SizedBox(width: 8),
                    Expanded(child: _MiniCard('Tồn cuối', '$closingTotal', AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'Chi tiết sản phẩm',
                  style: GoogleFonts.outfit(
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
                        style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.divider.withValues(alpha: 0.5)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(c.surface),
                        columnSpacing: 24,
                        columns: [
                          DataColumn(label: Text('Mã SP', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: c.textSecondary))),
                          DataColumn(label: Text('Tên sản phẩm', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: c.textSecondary))),
                          DataColumn(label: Text('Tồn đầu', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: c.textSecondary))),
                          DataColumn(label: Text('Nhập', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: c.textSecondary))),
                          DataColumn(label: Text('Xuất', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: c.textSecondary))),
                          DataColumn(label: Text('Tồn cuối', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: c.textSecondary))),
                        ],
                        rows: items.map<DataRow>((item) {
                          final sku = item['sku'] ?? item['productCode'] ?? '';
                          final name = item['productName'] ?? item['name'] ?? '';
                          final opening = item['openingStock'] ?? 0;
                          final imported = item['imported'] ?? item['totalImport'] ?? 0;
                          final exported = item['exported'] ?? item['totalExport'] ?? 0;
                          final closing = item['closingStock'] ?? 0;
                          return DataRow(
                            cells: [
                              DataCell(Text('$sku', style: GoogleFonts.inter(fontSize: 11, color: c.textPrimary))),
                              DataCell(
                                Container(
                                  constraints: const BoxConstraints(maxWidth: 150),
                                  child: Text(
                                    '$name',
                                    style: GoogleFonts.inter(fontSize: 11, color: c.textPrimary, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Text('$opening', style: GoogleFonts.inter(fontSize: 11, color: c.textSecondary))),
                              DataCell(Text('$imported', style: GoogleFonts.inter(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold))),
                              DataCell(Text('$exported', style: GoogleFonts.inter(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.bold))),
                              DataCell(Text('$closing', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: c.textPrimary))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Slow-moving warnings
                Text(
                  'Cảnh báo hàng chậm luân chuyển',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 12),
                slowAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Lỗi: $e', style: const TextStyle(color: AppColors.danger)),
                  data: (slowItems) {
                    if (slowItems.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Không có sản phẩm chậm luân chuyển nào được phát hiện.',
                          style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13),
                        ),
                      );
                    }
                    return Column(
                      children: slowItems.take(5).map<Widget>((item) {
                        final name = item['productName'] ?? item['name'] ?? 'SP';
                        final qty = item['quantity'] ?? item['currentStock'] ?? 0;
                        final days = item['daysUnsold'] ?? item['daysSinceLastSale'] ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
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
                                      'Tồn vướng kho: $qty sản phẩm',
                                      style: GoogleFonts.inter(fontSize: 11, color: c.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$days ngày đọng',
                                  style: GoogleFonts.outfit(
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
              style: GoogleFonts.outfit(
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
