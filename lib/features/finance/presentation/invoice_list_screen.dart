import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/widgets/app_animations.dart';
import '../providers/finance_provider.dart';

class InvoiceListScreen extends ConsumerWidget {
  const InvoiceListScreen({super.key});

  String _fmt(num v) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invAsync = ref.watch(invoiceListProvider((page: 1, type: null)));
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1).toIso8601String().split('T').first;
    final to = now.toIso8601String().split('T').first;
    final summaryAsync = ref.watch(invoiceSummaryProvider((from: from, to: to)));
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Hóa đơn'),
        actions: [featureGuideButton(context, 'invoices')],
      ),
      body: invAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) {
          final items = (data['items'] as List?) ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Legal Disclaimer
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tính năng lưu trữ số hóa Hóa đơn điện tử nội bộ. Ứng dụng không tự phát hành hóa đơn GTGT.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: c.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Summary Metrics - Taste-Skill: Left-aligned, no heavy cards
                Text(
                  'Thuế VAT tháng này',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                
                summaryAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox(),
                  data: (summary) {
                    final vatIn = asNum(summary['vatIn']);
                    final vatOut = asNum(summary['vatOut']);
                    final vatOwed = asNum(summary['vatOwed']);
                    
                    return Row(
                      children: [
                        Expanded(
                          child: _buildMetricItem(
                            'VAT đầu vào', 
                            _fmt(vatIn), 
                            AppColors.success, 
                            c, theme
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricItem(
                            'VAT đầu ra', 
                            _fmt(vatOut), 
                            AppColors.danger, 
                            c, theme
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricItem(
                            'Phải nộp', 
                            _fmt(vatOwed), 
                            vatOwed > 0 ? AppColors.danger : AppColors.success, 
                            c, theme
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),

                // List header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Danh sách hóa đơn',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      '${items.length} bản ghi',
                      style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (items.isEmpty)
                  AppEmpty(
                    message: 'Chưa có hóa đơn nào',
                    action: ElevatedButton.icon(
                      icon: const Icon(Icons.receipt), 
                      label: const Text('Thêm hóa đơn'), 
                      onPressed: () => _showAddDialog(context, ref)
                    ),
                  )
                else
                  // Taste-Skill: ListView instead of GridView, with simple separators, no card backgrounds
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: c.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: c.divider),
                      itemBuilder: (_, i) {
                        final inv = items[i];
                        final isOut = inv['invoiceType'] == 'OUT';
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isOut ? AppColors.danger : AppColors.success).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isOut ? Icons.arrow_upward : Icons.arrow_downward, 
                                  color: isOut ? AppColors.danger : AppColors.success, 
                                  size: 16
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      inv['invoiceNumber'] ?? 'Chưa cấp số', 
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: c.textPrimary,
                                      )
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      inv['partnerName'] ?? '', 
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: c.textSecondary,
                                      )
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _fmt(asNum(inv['totalAmount'])), 
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: c.textPrimary,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    )
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'VAT: ${_fmt(asNum(inv['taxAmount']))}', 
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: c.textMuted,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    )
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Text(
                                inv['invoiceDate']?.toString().split('T').first ?? '', 
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: c.textMuted,
                                )
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Thêm Hóa Đơn', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
  
  Widget _buildMetricItem(String label, String value, Color valueColor, AppThemeColors c, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final numC = TextEditingController();
    final partnerC = TextEditingController();
    final amountC = TextEditingController();
    final vatC = TextEditingController();
    String type = 'IN';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Thêm hóa đơn'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: type, items: const [
          DropdownMenuItem(value: 'IN', child: Text('Đầu vào')),
          DropdownMenuItem(value: 'OUT', child: Text('Đầu ra')),
        ], onChanged: (v) => type = v ?? 'IN', decoration: const InputDecoration(labelText: 'Loại')),
        const SizedBox(height: 16),
        TextField(controller: numC, decoration: const InputDecoration(labelText: 'Số hóa đơn')),
        const SizedBox(height: 16),
        TextField(controller: partnerC, decoration: const InputDecoration(labelText: 'Đối tác')),
        const SizedBox(height: 16),
        TextField(controller: amountC, decoration: const InputDecoration(labelText: 'Số tiền trước thuế'), keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        TextField(controller: vatC, decoration: const InputDecoration(labelText: 'Tiền VAT'), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        ElevatedButton(onPressed: () async {
          final partnerName = partnerC.text.trim();
          final subtotal = double.tryParse(amountC.text) ?? 0;
          final taxAmount = double.tryParse(vatC.text) ?? 0;
          if (partnerName.isEmpty || subtotal <= 0 || taxAmount < 0) {
            ToastService.showError('Vui lòng nhập đối tác, số tiền > 0 và VAT hợp lệ');
            return;
          }
          await ref.read(financeRepoProvider).createInvoice({
            'invoiceType': type, 'invoiceNumber': numC.text.trim().isEmpty ? null : numC.text.trim(), 'partnerName': partnerName,
            'subtotal': subtotal, 'taxAmount': taxAmount,
            'totalAmount': subtotal + taxAmount,
            'invoiceDate': DateTime.now().toIso8601String().split('T').first,
          });
          ref.invalidate(invoiceListProvider);
          ref.invalidate(invoiceSummaryProvider);
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Lưu')),
      ],
    ));
  }
}
