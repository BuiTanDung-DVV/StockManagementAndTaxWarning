import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../sales/services/receipt_pdf_service.dart';
import '../providers/operations_provider.dart';

class ReceiptTemplateScreen extends ConsumerStatefulWidget {
  const ReceiptTemplateScreen({super.key});
  @override
  ConsumerState<ReceiptTemplateScreen> createState() =>
      _ReceiptTemplateScreenState();
}

class _ReceiptTemplateScreenState extends ConsumerState<ReceiptTemplateScreen> {
  Map<String, dynamic>? _profile;
  String? _error;
  bool _saving = false;
  final _title = TextEditingController(text: 'PHIẾU BÁN HÀNG');
  final _footer = TextEditingController();
  String _paperSize = '80mm';
  final Map<String, bool> _flags = {
    'showLogo': true,
    'showShopInfo': true,
    'showCustomer': true,
    'showSku': true,
    'showDiscount': true,
    'showPayment': true,
    'showQr': true,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ref
          .read(settingsOperationsRepositoryProvider)
          .shopProfile();
      final config = Map<String, dynamic>.from(
        profile['receiptTemplateConfig'] as Map? ?? const {},
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _paperSize = config['paperSize']?.toString() ?? '80mm';
        _title.text = config['title']?.toString() ?? 'PHIẾU BÁN HÀNG';
        _footer.text =
            config['footer']?.toString() ??
            profile['receiptFooter']?.toString() ??
            '';
        for (final key in _flags.keys) {
          _flags[key] = config[key] != false;
        }
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _footer.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _config => {
    'paperSize': _paperSize,
    'title': _title.text.trim(),
    'footer': _footer.text.trim(),
    ..._flags,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppThemeColors.of(context).bg,
    body: AppResponsiveContent(
      maxWidth: 1050,
      child: _profile == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: _load,
                      child: const Text('Thử tải lại'),
                    ),
            )
          : ListView(
              children: [
                AppPageHeader(
                  title: 'Mẫu phiếu in',
                  subtitle:
                      'Thiết lập nội dung cho phiếu bán hàng 80mm hoặc A4.',
                  showBackButton: true,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCardContainer(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: '80mm',
                              label: Text('Khổ 80mm'),
                            ),
                            ButtonSegment(value: 'A4', label: Text('Khổ A4')),
                          ],
                          selected: {_paperSize},
                          onSelectionChanged: (value) =>
                              setState(() => _paperSize = value.first),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _title,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Tiêu đề',
                          ),
                        ),
                        TextField(
                          controller: _footer,
                          maxLength: 500,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Chân trang',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: _flags.entries
                              .map(
                                (entry) => FilterChip(
                                  selected: entry.value,
                                  label: Text(_labels[entry.key]!),
                                  onSelected: (value) =>
                                      setState(() => _flags[entry.key] = value),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Lưu cấu hình'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _preview,
                              icon: const Icon(Icons.preview_outlined),
                              label: const Text('Xem trước PDF'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'Lưu ý: Phiếu bán hàng không thay thế hóa đơn điện tử hợp pháp.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    ),
  );

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final profile = await ref
          .read(settingsOperationsRepositoryProvider)
          .saveReceiptConfig(_config);
      if (mounted) setState(() => _profile = profile);
      ToastService.showSuccess('Đã lưu mẫu phiếu in');
    } catch (error) {
      ToastService.showError(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _preview() async {
    final bytes = await ReceiptPdfService.build(
      profile: _profile!,
      config: _config,
      order: {
        'orderCode': 'SO-DEMO',
        'orderDate': DateTime.now().toIso8601String(),
        'subtotal': 1250000,
        'discountAmount': 50000,
        'taxAmount': 100000,
        'totalAmount': 1300000,
        'paidAmount': 1300000,
        'customer': {'name': 'Khách hàng mẫu'},
        'items': [
          {
            'quantity': 2,
            'unitPrice': 625000,
            'subtotal': 1250000,
            'product': {'name': 'Sản phẩm mẫu', 'sku': 'SP-001'},
          },
        ],
      },
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'phieu-ban-hang-xem-truoc.pdf',
    );
  }

  static const _labels = {
    'showLogo': 'Logo',
    'showShopInfo': 'Thông tin cửa hàng',
    'showCustomer': 'Khách hàng',
    'showSku': 'SKU',
    'showDiscount': 'Chiết khấu',
    'showPayment': 'Thanh toán',
    'showQr': 'QR',
  };
}
