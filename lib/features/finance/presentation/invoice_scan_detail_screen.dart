import '../../settings/providers/shop_provider.dart';
import 'package:go_router/go_router.dart';
import '../../inventory/models/invoice_purchase_source.dart';
import '../providers/finance_provider.dart';
import '../../../core/assets/app_icon.dart';
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
      partnerAddress = TextEditingController(),
      subtotal = TextEditingController(),
      tax = TextEditingController(),
      total = TextEditingController();
  final items = <Map<String, TextEditingController>>[];
  bool hydrated = false, saving = false;
  bool _editing = false;
  Map<String, dynamic> _loadedScan = {};
  final _retired = <TextEditingController>[];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(invoiceScanDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: AppThemeColors.of(context).bg,
      body: AppResponsiveContent(
        maxWidth: 1100,
        child: async.when(
          skipLoadingOnRefresh: false,
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
            final linkedPurchase = scan['linkedPurchaseOrder'];
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(invoiceScanDetailProvider(widget.id)),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  AppPageHeader(
                    title: 'Kiểm tra hóa đơn quét',
                    subtitle: confirmed
                        ? linkedPurchase is Map
                              ? linkedPurchase['status'] == 'COMPLETED'
                                    ? 'Phiếu nhập liên kết đã hoàn tất và ghi kho. Theo dõi công nợ và thanh toán tại phiếu nhập.'
                                    : 'Đã liên kết phiếu nhập. Xem trạng thái phiếu để theo dõi kho, công nợ và thanh toán.'
                              : 'Đã lưu hóa đơn đầu vào; chưa ghi tăng tồn kho hoặc thanh toán.'
                        : 'Mọi kết quả OCR đều cần được đối chiếu với ảnh.',
                    showBackButton: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (confirmed)
                    AppCardContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hóa đơn đã lưu: ${scan['invoice']?['invoiceNumber'] ?? number.text}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Danh sách Hóa đơn mặc định lọc kỳ hiện tại. Hóa đơn ngày cũ cần chọn Toàn bộ thời gian.',
                            ),
                            const SizedBox(height: 8),
                            if (!_editing &&
                                scan['canEditInvoice'] == true &&
                                ref
                                    .watch(shopProvider)
                                    .hasPermission('finance', 'edit'))
                              OutlinedButton.icon(
                                onPressed: saving
                                    ? null
                                    : () => setState(() => _editing = true),
                                icon: const AppIcon(Icons.edit_outlined),
                                label: const Text('Chỉnh sửa hóa đơn'),
                              ),
                            if (scan['invoice'] == null)
                              const Text(
                                'Chưa tìm thấy hóa đơn liên kết. Hãy tải lại phiếu trước khi xử lý.',
                              ),
                            if (!_editing &&
                                scan['canCreatePurchaseOrder'] == true &&
                                ref
                                    .watch(shopProvider)
                                    .hasPermission('inventory', 'edit') &&
                                ref
                                    .watch(shopProvider)
                                    .hasPermission('finance', 'edit'))
                              FilledButton.icon(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        final source =
                                            InvoicePurchaseSource.fromScan(
                                              scan,
                                            );
                                        await context.push(
                                          '/purchase-orders/form',
                                          extra: source,
                                        );
                                        if (mounted)
                                          ref.invalidate(
                                            invoiceScanDetailProvider(
                                              widget.id,
                                            ),
                                          );
                                      },
                                icon: const AppIcon(Icons.inventory_2_outlined),
                                label: const Text('Lập phiếu nhập'),
                              ),
                            if (scan['linkedPurchaseOrder'] is Map)
                              OutlinedButton.icon(
                                onPressed: () => context.push(
                                  '/purchase-orders/detail?id=${scan['linkedPurchaseOrder']['id']}',
                                ),
                                icon: const AppIcon(Icons.open_in_new),
                                label: Text(
                                  'Xem phiếu nhập ${scan['linkedPurchaseOrder']['orderCode']}',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
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
                                      child: AppIcon(
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
                                        AppIcon(
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
                      final form = _form(
                        (confirmed && !_editing) ||
                            !ref
                                .watch(shopProvider)
                                .hasPermission('finance', 'edit'),
                      );
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
            enabled: !saving,
            readOnly: confirmed,
            decoration: const InputDecoration(labelText: 'Số hóa đơn *'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: date,
            enabled: !saving,
            readOnly: confirmed,
            decoration: InputDecoration(
              labelText: 'Ngày YYYY-MM-DD *',
              suffixIcon: confirmed || saving
                  ? null
                  : IconButton(
                      icon: const AppIcon(Icons.calendar_today_outlined),
                      tooltip: 'Chọn ngày hóa đơn',
                      onPressed: () async {
                        final now = DateUtils.dateOnly(DateTime.now());
                        final initial =
                            DateTime.tryParse(date.text.trim()) ?? now;
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial.isAfter(now) ? now : initial,
                          firstDate: DateTime(1),
                          lastDate: now,
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
            enabled: !saving,
            readOnly: confirmed,
            decoration: const InputDecoration(labelText: 'Đối tác *'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: taxCode,
            enabled: !saving,
            readOnly: confirmed,
            decoration: const InputDecoration(labelText: 'Mã số thuế'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: partnerAddress,
            enabled: !saving,
            readOnly: confirmed,
            decoration: const InputDecoration(labelText: 'Địa chỉ đối tác'),
          ),
          const Divider(height: 28),
          ...items.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: entry.value['name'],
                    enabled: !saving,
                    readOnly: confirmed,
                    decoration: InputDecoration(
                      labelText: 'Dòng ${entry.key + 1}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: entry.value['unit'],
                          enabled: !saving,
                          readOnly: confirmed,
                          decoration: const InputDecoration(
                            labelText: 'Đơn vị',
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: entry.value['qty'],
                          enabled: !saving,
                          readOnly: confirmed,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'SL'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: entry.value['price'],
                          enabled: !saving,
                          readOnly: confirmed,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Đơn giá',
                          ),
                        ),
                      ),
                      if (!confirmed && !saving && items.length > 1)
                        IconButton(
                          icon: const AppIcon(
                            Icons.remove_circle_outline,
                            color: AppColors.danger,
                            size: 20,
                          ),
                          tooltip: 'Xóa dòng',
                          onPressed: () => _removeItem(entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: entry.value['taxRate'],
                    enabled: !saving,
                    readOnly: confirmed,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Thuế suất dòng hàng (%)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!confirmed)
            TextButton.icon(
              onPressed: saving ? null : () => _addItem(null),
              icon: const AppIcon(Icons.add),
              label: const Text('Thêm dòng hàng'),
            ),
          const Divider(height: 28),
          TextField(
            controller: subtotal,
            enabled: !saving,
            readOnly: confirmed,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Tiền trước thuế'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: tax,
            enabled: !saving,
            readOnly: confirmed,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Tiền thuế'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: total,
            enabled: !saving,
            readOnly: confirmed,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Tổng tiền'),
          ),
          if (!confirmed) ...[
            const SizedBox(height: 12),
            const Text(
              'Lưu tại đây chỉ lưu thông tin hóa đơn. Tồn kho, tiền và công nợ được ghi bằng nghiệp vụ riêng.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : _confirm,
                icon: const AppIcon(Icons.check),
                label: Text(
                  saving
                      ? 'Đang lưu…'
                      : _editing
                      ? 'Lưu thay đổi hóa đơn'
                      : 'Xác nhận và tạo hóa đơn',
                ),
              ),
            ),
            if (_editing)
              TextButton(
                onPressed: saving
                    ? null
                    : () {
                        setState(() => _editing = false);
                        _hydrate(_loadedScan);
                      },
                child: const Text('Hủy chỉnh sửa'),
              ),
          ],
        ],
      ),
    ),
  );

  void _hydrate(Map<String, dynamic> scan) {
    if (!mounted) return;
    _loadedScan = scan;
    for (final row in items) {
      _retired.addAll(row.values);
    }
    items.clear();
    Map<String, dynamic> parsed = {};
    try {
      parsed = scan['editableData'] is Map
          ? Map<String, dynamic>.from(scan['editableData'])
          : Map<String, dynamic>.from(
              jsonDecode(
                scan['confirmedData'] ?? scan['ocrParsedData'] ?? '{}',
              ),
            );
    } catch (_) {}
    number.text = parsed['invoiceNumber']?.toString() ?? '';
    date.text = parsed['invoiceDate']?.toString() ?? '';
    partner.text = parsed['partnerName']?.toString() ?? '';
    taxCode.text = parsed['partnerTaxCode']?.toString() ?? '';
    partnerAddress.text = parsed['partnerAddress']?.toString() ?? '';
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
      'unit': TextEditingController(text: value?['unit']?.toString() ?? 'Cái'),
      'taxRate': TextEditingController(
        text: value?['taxRate']?.toString() ?? '0',
      ),
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
    if (saving || !ref.read(shopProvider).hasPermission('finance', 'edit'))
      return;
    final isEditing = _editing;
    final scope = ref.read(shopProvider).currentShopId;
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
    final parsedDate = DateTime.tryParse(invoiceDate);
    if (parsedDate == null ||
        parsedDate.toIso8601String().split('T').first != invoiceDate ||
        parsedDate.isAfter(DateUtils.dateOnly(DateTime.now()))) {
      ToastService.showError(
        'Ngày hóa đơn phải hợp lệ và không được sau hôm nay',
      );
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
        'unit': item['unit']!.text.trim(),
        'quantity': qty,
        'unitPrice': price,
        'subtotal': qty * price,
        'taxRate': asDouble(item['taxRate']!.text),
        'taxAmount': qty * price * asDouble(item['taxRate']!.text) / 100,
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
      final payload = <String, dynamic>{
        'invoiceNumber': invoiceNumber,
        'invoiceDate': invoiceDate,
        'partnerName': partnerName,
        'partnerTaxCode': taxCode.text.trim(),
        'partnerAddress': partnerAddress.text.trim(),
        'items': rows,
        'subtotal': subtotalVal > 0 ? subtotalVal : calculatedTotal,
        'taxAmount': taxVal,
        'totalAmount': totalVal,
        'confidence': 1,
        if (isEditing) 'invoiceRevision': _loadedScan['invoiceRevision'],
      };
      final repository = ref.read(invoiceScanRepositoryProvider);
      final result = isEditing
          ? await repository.updateInvoice(widget.id, payload)
          : await repository.confirm(widget.id, payload);
      if (result['scan'] is! Map ||
          result['invoice'] is! Map ||
          result['scan']['status'] != 'CONFIRMED' ||
          result['scan']['referenceId'] != result['invoice']['id']) {
        throw ApiException(
          'Chưa xác định được kết quả lưu. Tải lại phiếu trước khi thử tiếp.',
          502,
        );
      }
      if (!mounted || ref.read(shopProvider).currentShopId != scope) return;
      setState(() {
        _editing = false;
        hydrated = false;
      });
      ref.invalidate(invoiceScanDetailProvider(widget.id));
      ref.invalidate(filteredInvoiceScanListProvider);
      ref.invalidate(invoiceScanListProvider);
      ref.invalidate(invoiceListProvider);
      ref.invalidate(invoiceSummaryProvider);
      ref.invalidate(invoiceReconciliationProvider);
      ToastService.showSuccess(
        isEditing
            ? 'Đã cập nhật hóa đơn'
            : 'Đã lưu hóa đơn đầu vào. Chưa ghi kho hoặc thanh toán.',
      );
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
    for (final c in [
      ..._retired,
      number,
      date,
      partner,
      taxCode,
      partnerAddress,
      subtotal,
      tax,
      total,
    ]) {
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
