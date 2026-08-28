import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/providers/tax_config_provider.dart';
import '../../tax/services/tax_service.dart';
import '../providers/finance_provider.dart';
import '../providers/tax_reference_provider.dart';
import '../../../core/widgets/app_navigation_back_button.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

IconData _taxFormIcon(String iconKey) => switch (iconKey) {
  'list' => Icons.list_alt,
  'article' => Icons.article_outlined,
  _ => Icons.description_outlined,
};

class TaxDeclarationScreen extends ConsumerWidget {
  const TaxDeclarationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final config = ref.watch(taxConfigProvider);
    if (!config.isLoaded) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: Navigator.of(context).canPop() ? 60 : null,
          leading: Navigator.of(context).canPop()
              ? AppNavigationBackLeading(
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: const Text('Kê khai thuế'),
        ),
        body: Center(
          child: config.isLoading
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: c.divider),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.receipt_long_outlined,
                              color: AppColors.warning,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Cần hoàn tất cấu hình thuế',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Thông tin chính sách thuế của cửa hàng chưa đầy đủ nên chưa thể lập tờ khai. Bạn có thể mở phần cấu hình để bổ sung hoặc thử tải lại.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: c.textSecondary),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => ref
                                    .read(taxConfigProvider.notifier)
                                    .refresh(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Thử tải lại'),
                              ),
                              FilledButton.icon(
                                onPressed: () => context.push('/tax-config'),
                                icon: const Icon(Icons.settings_outlined),
                                label: const Text('Mở cấu hình thuế'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      );
    }

    final referenceAsync = ref.watch(taxReferenceDataProvider);
    if (referenceAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (referenceAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kê khai thuế')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Không thể tải danh mục biểu mẫu từ DB: ${referenceAsync.error}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final forms = referenceAsync.requireValue.forms;

    // Fetch real revenue from profit-loss API instead of hardcoded 450M
    final now = DateTime.now();
    final from = DateTime(
      now.year,
      now.month,
      1,
    ).toIso8601String().split('T').first;
    final to = now.toIso8601String().split('T').first;
    final plAsync = ref.watch(profitLossProvider((from: from, to: to)));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('Kê khai thuế'),
        actions: [featureGuideButton(context, 'tax_declaration')],
      ),
      body: plAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (plData) {
          final revenue = ((plData['revenue'] as num?) ?? 0).toDouble();
          final vat = config.calculateVat(revenue);
          final pit = config.calculatePit(revenue);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tóm tắt kỳ kê khai',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Doanh thu',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  _currFmt.format(revenue),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'GTGT phải nộp',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  _currFmt.format(vat),
                                  style: const TextStyle(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TNCN phải nộp',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  _currFmt.format(pit),
                                  style: const TextStyle(
                                    color: AppColors.info,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tổng thuế',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  _currFmt.format(vat + pit),
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (revenue == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Chưa có doanh thu trong kỳ',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Mẫu kê khai',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ...forms.map((f) {
                  final isReady = f.isReady;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _taxFormIcon(f.iconKey),
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        f.code,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (isReady
                                                      ? AppColors.success
                                                      : AppColors.warning)
                                                  .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          isReady ? 'Sẵn sàng' : 'Bản nháp',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: isReady
                                                ? AppColors.success
                                                : AppColors.warning,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    f.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          f.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showExportDialog(
                                  context,
                                  ref,
                                  f.code,
                                  f.name,
                                ),
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text(
                                  'Kết xuất XML',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(color: AppColors.primary),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _showSubmitDialog(context, f.name),
                                icon: const Icon(Icons.cloud_upload, size: 16),
                                label: const Text(
                                  'Nộp tờ khai',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lưu ý: Dữ liệu được tự động điền từ app. Vui lòng kiểm tra kỹ trước khi nộp cho cơ quan thuế.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showExportDialog(
    BuildContext context,
    WidgetRef ref,
    String formCode,
    String formName,
  ) async {
    if (formCode != '01/CNKD') {
      ToastService.showWarning(
        'Mẫu $formCode chưa được hỗ trợ xuất XML. Hiện hệ thống chỉ hỗ trợ mẫu 01/CNKD.',
      );
      return;
    }

    final c = AppThemeColors.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        content: const Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Đang kết xuất XML...'),
          ],
        ),
      ),
    );

    try {
      final now = DateTime.now();
      await ref
          .read(taxServiceProvider)
          .exportHTKK(now.month.toString().padLeft(2, '0'), '${now.year}');
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ToastService.showSuccess('Đã kết xuất XML mẫu $formName thành công!');
      }
    } catch (error) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ToastService.showError('Không thể kết xuất XML: $error');
      }
    }
  }

  void _showSubmitDialog(BuildContext context, String formName) {
    final c = AppThemeColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.cloud_upload, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Nộp $formName',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ứng dụng chưa tích hợp ký điện tử và nộp tờ khai trực tuyến. '
              'Hãy xuất XML đã kiểm tra, sau đó nộp bằng kênh chính thức của cơ quan thuế.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Hủy',
                      style: TextStyle(color: c.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Đã hiểu'),
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
