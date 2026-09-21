import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_ui_components.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../providers/invoice_scan_provider.dart';

class InvoiceScanDetailScreen extends ConsumerStatefulWidget {
  const InvoiceScanDetailScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<InvoiceScanDetailScreen> createState() =>
      _InvoiceScanDetailScreenState();
}

class _InvoiceScanDetailScreenState
    extends ConsumerState<InvoiceScanDetailScreen> {
  final number = TextEditingController(),
      date = TextEditingController(),
      partner = TextEditingController(),
      taxCode = TextEditingController(),
      subtotal = TextEditingController(),
      tax = TextEditingController(),
      total = TextEditingController();
  final items = <Map<String, TextEditingController>>[];
  bool hydrated = false, saving = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(invoiceScanDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: AppThemeColors.of(context).bg,
      body: AppResponsiveContent(
        maxWidth: 1100,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppInlineError(
                message:
                    'Không tải được chi tiết phiếu quét. Vui lòng thử lại sau.',
                onRetry: () =>
                    ref.invalidate(invoiceScanDetailProvider(widget.id)),
              ),
            ),
          ),
          data: (scan) {
            if (!hydrated) {
              hydrated = true;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _hydrate(scan),
              );
            }
            final confirmed = scan['status'] == 'CONFIRMED';
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(invoiceScanDetailProvider(widget.id)),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  AppPageHeader(
                    title: 'Kiểm tra hóa đơn quét',
                    subtitle: confirmed
                        ? 'Đã tạo hóa đơn đầu vào.'
                        : 'Mọi kết quả OCR đều cần được đối chiếu với ảnh.',
                    showBackButton: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (scan['errorMessage'] != null)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(scan['errorMessage'].toString()),
                          ),
                          if (!confirmed)
                            TextButton(
                              onPressed: saving ? null : _retry,
                              child: const Text('Thử OCR lại'),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final rawUrl = scan['imageUrl']?.toString() ?? '';
                      final hasValidUrl = rawUrl.isNotEmpty && rawUrl != 'null';
                      final image = AppCardContainer(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: hasValidUrl
                              ? Image.network(
                                  rawUrl,
                                  height: constraints.maxWidth >= 760
                                      ? 520
                                      : 280,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const SizedBox(
                                    height: 220,
                                    child: Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox(
                                  height: 220,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.image_not_supported_outlined,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 8),
                                        Text('Không có ảnh hóa đơn quét'),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      );
                      final form = _form(confirmed);
                      return constraints.maxWidth >= 760
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: image),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(child: form),
                              ],
                            )
                          : Column(
                              children: [
                                image,
                                const SizedBox(height: AppSpacing.md),
                                form,
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _form(bool confirmed) => AppCardContainer(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          TextField(
            controller: number,
            enabled: !confirmed,
            decoration: const InputDecoration(labelText: 'Số hóa đơn *'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: date,
            enabled: !confirmed,
            decoration: InputDecoration(
              labelText: 'Ngày YYYY-MM-DD *',
              suffixIcon: confirmed
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.calendar_today_outlined),
                      tooltip: 'Chọn ngày hóa đơn',
                      onPressed: () async {
                        final now = DateTime.now();
                        final initial =
                            DateTime.tryParse(date.text.trim()) ?? now;
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          date.text = picked.toIso8601String().split('T').first;
                        }
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: partner,
            enabled: !confirmed,
            decoration: const InputDecoration(labelText: 'Đối tác *'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: taxCode,
            enabled: !confirmed,
            decoration: const InputDecoration(labelText: 'Mã số thuế'),
          ),
          const Divider(height: 28),
          ...items.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: entry.value['name'],
                      enabled: !confirmed,
                      decoration: InputDecoration(
                        labelText: 'Dòng ${entry.key + 1}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: entry.value['qty'],
                      enabled: !confirmed,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'SL'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: entry.value['price'],
                      enabled: !confirmed,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Đơn giá'),
                    ),
                  ),
                  if (!confirmed && items.length > 1)
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.danger,
                        size: 20,
                      ),
                      tooltip: 'Xóa dòng',
                      onPressed: () => _removeItem(entry.key),
                    ),
                ],
              ),
            ),
          ),
          if (!confirmed)
            TextButton.icon(
              onPressed: () => _addItem(null),
              icon: const Icon(Icons.add),
              label: const Text('Thêm dòng hàng'),
            ),
          const Divider(height: 28),
          TextField(
            controller: subtotal,
            enabled: !confirmed,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Tiền trước thuế'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: tax,
            enabled: !confirmed,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Tiền thuế'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: total,
            enabled: !confirmed,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Tổng tiền'),
          ),
          if (!confirmed) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : _confirm,
                icon: const Icon(Icons.check),
                label: Text(saving ? 'Đang tạo…' : 'Xác nhận và tạo hóa đơn'),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  void _hydrate(Map<String, dynamic> scan) {
    Map<String, dynamic> parsed = {};
    try {
      parsed = Map<String, dynamic>.from(
        jsonDecode(scan['confirmedData'] ?? scan['ocrParsedData'] ?? '{}'),
      );
    } catch (_) {}
    number.text = parsed['invoiceNumber']?.toString() ?? '';
    date.text = parsed['invoiceDate']?.toString() ?? '';
    partner.text = parsed['partnerName']?.toString() ?? '';
    taxCode.text = parsed['partnerTaxCode']?.toString() ?? '';
    subtotal.text = parsed['subtotal']?.toString() ?? '';
    tax.text = parsed['taxAmount']?.toString() ?? '';
    total.text = parsed['totalAmount']?.toString() ?? '';
    for (final row in parsed['items'] as List? ?? const []) {
      _addItem(Map<String, dynamic>.from(row), notify: false);
    }
    if (items.isEmpty) _addItem(null, notify: false);
    if (mounted) setState(() {});
  }

  void _addItem(Map<String, dynamic>? value, {bool notify = true}) {
    items.add({
      'name': TextEditingController(text: value?['itemName']?.toString()),
      'qty': TextEditingController(text: value?['quantity']?.toString() ?? '1'),
      'price': TextEditingController(
        text: value?['unitPrice']?.toString() ?? '0',
      ),
    });
    if (notify && mounted) setState(() {});
  }

  void _removeItem(int index) {
    if (items.length <= 1) return;
    final removed = items.removeAt(index);
    for (final c in removed.values) {
      c.dispose();
    }
    if (mounted) setState(() {});
  }

  Future<void> _confirm() async {
    final invoiceNumber = number.text.trim();
    if (invoiceNumber.isEmpty) {
      ToastService.showError('Vui lòng nhập số hóa đơn');
      return;
    }

    final invoiceDate = date.text.trim();
    if (invoiceDate.isEmpty) {
      ToastService.showError('Vui lòng nhập ngày hóa đơn');
      return;
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(invoiceDate)) {
      ToastService.showError('Ngày hóa đơn phải đúng định dạng YYYY-MM-DD');
      return;
    }

    final partnerName = partner.text.trim();
    if (partnerName.isEmpty) {
      ToastService.showError('Vui lòng nhập tên đối tác');
      return;
    }

    if (items.isEmpty) {
      ToastService.showError('Hóa đơn phải có ít nhất một dòng hàng');
      return;
    }

    for (var i = 0; i < items.length; i++) {
      final itemName = items[i]['name']!.text.trim();
      if (itemName.isEmpty) {
        ToastService.showError('Dòng ${i + 1} chưa có tên sản phẩm');
        return;
      }
      final qty = asDouble(items[i]['qty']!.text);
      if (qty <= 0) {
        ToastService.showError('Số lượng dòng ${i + 1} phải lớn hơn 0');
        return;
      }
    }

    final rows = items.map((item) {
      final qty = asDouble(item['qty']!.text, fallback: 1);
      final price = parseCurrency(item['price']!.text);
      return {
        'itemName': item['name']!.text.trim(),
        'unit': 'Cái',
        'quantity': qty,
        'unitPrice': price,
        'subtotal': qty * price,
        'taxRate': 0,
        'taxAmount': 0,
      };
    }).toList();

    final subtotalVal = parseCurrency(subtotal.text);
    final taxVal = parseCurrency(tax.text);
    var totalVal = parseCurrency(total.text);
    final calculatedTotal = rows.fold<double>(
      0,
      (s, r) => s + (r['subtotal'] as num).toDouble(),
    );

    if (totalVal <= 0) {
      totalVal = subtotalVal > 0 ? subtotalVal + taxVal : calculatedTotal;
    }

    if (totalVal <= 0) {
      ToastService.showError('Tổng tiền hóa đơn phải lớn hơn 0');
      return;
    }

    setState(() => saving = true);
    try {
      await ref.read(invoiceScanRepositoryProvider).confirm(widget.id, {
        'invoiceNumber': invoiceNumber,
        'invoiceDate': invoiceDate,
        'partnerName': partnerName,
        'partnerTaxCode': taxCode.text.trim(),
        'items': rows,
        'subtotal': subtotalVal > 0 ? subtotalVal : calculatedTotal,
        'taxAmount': taxVal,
        'totalAmount': totalVal,
        'confidence': 1,
      });
      ref.invalidate(invoiceScanDetailProvider(widget.id));
      ToastService.showSuccess('Đã tạo hóa đơn đầu vào');
    } catch (error) {
      ToastService.showError(
        error is ApiException
            ? error.message
            : 'Không thể lưu hóa đơn đầu vào. Vui lòng thử lại sau.',
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [number, date, partner, taxCode, subtotal, tax, total]) {
      c.dispose();
    }
    for (final row in items) {
      for (final c in row.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _retry() async {
    setState(() => saving = true);
    try {
      await ref.read(invoiceScanRepositoryProvider).retry(widget.id);
      hydrated = false;
      ref.invalidate(invoiceScanDetailProvider(widget.id));
      ref.invalidate(invoiceScanListProvider);
      ToastService.showSuccess('Đã đọc lại ảnh; vui lòng kiểm tra kết quả');
    } catch (error) {
      ToastService.showError(
        error is ApiException
            ? error.message
            : 'Không thể đọc lại ảnh hóa đơn. Vui lòng thử lại sau.',
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
