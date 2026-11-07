import '../models/invoice_purchase_source.dart';
import '../../settings/providers/shop_provider.dart';
import '../../../core/widgets/business_date_field.dart';
import '../../finance/providers/invoice_scan_provider.dart';
import '../../../core/assets/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_provider.dart';
import '../../suppliers/providers/supplier_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../../../core/offline/offline_providers.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_form_draft.dart';
import '../../../core/network/api_client.dart';
import 'dart:async';
import '../models/purchase_order_suggestion.dart';
import '../../../core/widgets/product_thumbnail.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class _PoItem {
  int? productId;
  String? productName;
  String? productSku;
  String? sourceLabel;
  int quantity = 1;
  TextEditingController qtyCtrl = TextEditingController(text: '1');
  TextEditingController priceCtrl = TextEditingController();

  _PoItem();

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }

  double get unitPrice => parseCurrency(priceCtrl.text);
  double get subtotal => quantity * unitPrice;
}

class PurchaseOrderFormScreen extends ConsumerStatefulWidget {
  final PurchaseOrderSuggestion? suggestion;
  final InvoicePurchaseSource? sourceInvoice;
  const PurchaseOrderFormScreen({
    super.key,
    this.suggestion,
    this.sourceInvoice,
  });
  @override
  ConsumerState<PurchaseOrderFormScreen> createState() =>
      _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState
    extends ConsumerState<PurchaseOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();

  int? _supplierId;
  String _supplierName = '';
  int? _warehouseId;
  String _warehouseName = '';
  final List<_PoItem> _items = [];
  bool _saving = false;
  bool _suggestionApplying = false;
  PurchaseOrderSuggestion? _pendingSuggestion;
  OfflineFormDraft? _draft;
  bool _draftLoading = true;
  bool _completed = false;
  int _draftEditRevision = 0;
  String? _draftNotice;
  ProviderSubscription<OfflineScope?>? _scopeSubscription;
  bool _notPreviouslyReceived = false;
  DateTime _sourceDate = DateTime.now();
  int _currentStep = 0; // 0 = Info, 1 = Items, 2 = Confirm

  @override
  void initState() {
    super.initState();
    _pendingSuggestion = widget.suggestion;
    _sourceDate =
        DateTime.tryParse(widget.sourceInvoice?.invoiceDate ?? '') ??
        DateTime.now();
    _notesCtrl.addListener(_persistDraft);
    _scopeSubscription = ref.listenManual(offlineScopeProvider, (_, next) {
      if (_draft == null || _draft?.scope.key != next?.key) {
        unawaited(_restoreDraft(next));
      }
    }, fireImmediately: true);
  }

  Map<String, dynamic> _draftData() => {
    'sourceDate': DateFormat('yyyy-MM-dd').format(_sourceDate),
    'supplierId': _supplierId,
    'supplierName': _supplierName,
    'warehouseId': _warehouseId,
    'warehouseName': _warehouseName,
    'notes': _notesCtrl.text,
    'items': _items
        .map(
          (item) => {
            'productId': item.productId,
            'productName': item.productName,
            'productSku': item.productSku,
            'sourceLabel': item.sourceLabel,
            'quantityText': item.qtyCtrl.text,
            'priceText': item.priceCtrl.text,
          },
        )
        .toList(),
  };

  _PoItem _makeItem([Map<String, dynamic>? data]) {
    final item = _PoItem();
    if (data != null) {
      item.productId = int.tryParse('${data['productId']}');
      item.productName = data['productName'] as String?;
      item.productSku = data['productSku'] as String?;
      item.sourceLabel = data['sourceLabel'] as String?;
      item.qtyCtrl.text = data['quantityText']?.toString() ?? '1';
      item.quantity = int.tryParse(item.qtyCtrl.text) ?? 0;
      item.priceCtrl.text = data['priceText']?.toString() ?? '';
    }
    item.qtyCtrl.addListener(_persistDraft);
    item.priceCtrl.addListener(_persistDraft);
    return item;
  }

  Future<void> _restoreDraft(OfflineScope? scope) async {
    if (!mounted) return;
    setState(() => _draftLoading = true);
    _completed = false;
    final draft = scope == null
        ? null
        : OfflineFormDraft(
            store: ref.read(offlineStoreProvider.future),
            scope: scope,
            slot: widget.sourceInvoice == null
                ? 'purchase-form'
                : 'purchase-from-invoice-${widget.sourceInvoice!.invoiceId}',
            kind: 'PURCHASE_ORDER_CREATE',
          );
    _draft = draft;
    try {
      final saved = await draft?.restore();
      if (!mounted || !identical(_draft, draft)) return;
      for (final item in _items) {
        item.dispose();
      }
      _items.clear();
      final data = saved?.data ?? <String, dynamic>{};
      _sourceDate =
          DateTime.tryParse('${data['sourceDate'] ?? ''}') ?? _sourceDate;
      _supplierId = int.tryParse('${data['supplierId']}');
      _supplierName = data['supplierName']?.toString() ?? '';
      _warehouseId = int.tryParse('${data['warehouseId']}');
      _warehouseName = data['warehouseName']?.toString() ?? '';
      _notesCtrl.text = data['notes']?.toString() ?? '';
      for (final item in data['items'] as List? ?? []) {
        _items.add(_makeItem(Map<String, dynamic>.from(item as Map)));
      }
      final source = widget.sourceInvoice;
      if (saved == null &&
          source != null &&
          '${scope?.shopId}' == '${source.shopId}') {
        _items.addAll(source.suggestedRows().map(_makeItem));
        _notesCtrl.text =
            'Nhập hàng theo hóa đơn ${source.number}; đã đối chiếu ảnh và quy đổi đơn vị.';
      }
      _currentStep = 0;
      _draftNotice = saved?.alreadyQueued == true
          ? 'Phiếu trước đã được gửi xử lý. Kiểm tra danh sách đơn nhập trước khi tạo phiếu khác.'
          : saved == null
          ? null
          : 'Đã khôi phục bản nháp trên thiết bị. Kiểm tra thông tin trước khi ghi.';
      if (saved?.alreadyQueued == true) await draft!.clear();
    } catch (_) {
      if (mounted && identical(_draft, draft)) {
        _draftNotice =
            'Chưa đọc được bản nháp. Nội dung mới chưa được xác nhận đã giữ trên thiết bị.';
      }
    } finally {
      if (mounted && identical(_draft, draft)) {
        setState(() => _draftLoading = false);
      }
    }
    if (mounted &&
        identical(_draft, draft) &&
        _pendingSuggestion != null &&
        _items.isEmpty) {
      await _applySuggestion();
    }
  }

  Future<void> _applySuggestion() async {
    final suggestion = _pendingSuggestion;
    final scope = ref.read(offlineScopeProvider);
    if (suggestion == null || _suggestionApplying || _saving) return;
    if (scope == null || !suggestion.matches(scope.userId, scope.shopId)) {
      setState(() {
        _pendingSuggestion = null;
        _draftNotice =
            'Đề xuất thuộc tài khoản hoặc cửa hàng khác. Chưa thêm sản phẩm.';
      });
      return;
    }
    setState(() => _suggestionApplying = true);
    try {
      final products = await ref.read(productOptionsProvider.future);
      if (!mounted || ref.read(offlineScopeProvider)?.key != scope.key) return;
      final merged = suggestion.merge(
        _draftData()['items'] as List,
        products['items'] as List? ?? [],
      );
      setState(() {
        _draftLoading = true;
        for (final item in _items) {
          item.dispose();
        }
        _items.clear();
        _items.addAll(merged.map(_makeItem));
        if (_notesCtrl.text.trim().isEmpty) {
          _notesCtrl.text =
              'Đề xuất bổ sung hàng dưới định mức. Kiểm tra số lượng và đơn giá trước khi nhập.';
        }
        _pendingSuggestion = null;
        _draftLoading = false;
      });
      _persistDraft();
    } catch (_) {
      if (mounted) {
        setState(
          () => _draftNotice =
              'Chưa thêm được đề xuất. Bản nháp hiện tại được giữ nguyên; kiểm tra danh mục rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _suggestionApplying = false);
    }
  }

  void _persistDraft() {
    final draft = _draft;
    if (_draftLoading || _completed || draft == null) return;
    final revision = ++_draftEditRevision;
    final data = _draftData();
    setState(() => _draftNotice = 'Đang giữ bản nháp…');
    unawaited(
      draft
          .save(data)
          .then(
            (_) {
              if (mounted &&
                  identical(_draft, draft) &&
                  revision == _draftEditRevision &&
                  !_completed) {
                setState(() => _draftNotice = 'Bản nháp đã lưu trên thiết bị.');
              }
            },
            onError: (Object _) {
              if (mounted &&
                  identical(_draft, draft) &&
                  revision == _draftEditRevision &&
                  !_completed) {
                setState(
                  () => _draftNotice =
                      'Chưa giữ được bản nháp. Đừng rời trang khi còn nội dung chưa lưu.',
                );
              }
            },
          ),
    );
  }

  @override
  void dispose() {
    _scopeSubscription?.close();
    _notesCtrl.dispose();
    for (var i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_makeItem()));
    _persistDraft();
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
    _persistDraft();
  }

  double get _totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  void _nextStep() {
    if (_currentStep == 0) {
      final suppliersAsync = ref.read(supplierOptionsProvider);
      final warehousesAsync = ref.read(warehousesProvider);
      if (suppliersAsync.isLoading ||
          warehousesAsync.isLoading ||
          suppliersAsync.hasError ||
          warehousesAsync.hasError) {
        ToastService.showError(
          'Chờ tải đúng nhà cung cấp và kho của cửa hàng, hoặc thử lại khi có lỗi.',
        );
        return;
      }
      final warehouses = warehousesAsync.asData?.value ?? [];
      if (warehouses.isNotEmpty &&
          !warehouses.any((item) => item['id'] == _warehouseId)) {
        ToastService.showError(
          'Vui lòng chọn kho lưu trữ thuộc cửa hàng hiện tại.',
        );
        return;
      }
      final hasSuppliers =
          ((suppliersAsync.value?['items'] as List?)?.isNotEmpty ?? false);
      final selectedExists = (suppliersAsync.value?['items'] as List? ?? [])
          .any((item) => item['id'] == _supplierId);
      if (!selectedExists && hasSuppliers) {
        ToastService.showError('Vui lòng chọn Nhà cung cấp!');
        return;
      }
      if (!hasSuppliers) {
        ToastService.showError(
          'Chưa có Nhà cung cấp nào. Vui lòng tạo Nhà cung cấp trước!',
        );
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_items.isEmpty) {
        ToastService.showError(
          'Vui lòng thêm ít nhất 1 sản phẩm để nhập hàng!',
        );
        return;
      }
      for (var i in _items) {
        final loadedProducts =
            ref.read(productOptionsProvider).value?['items'] as List? ?? [];
        if (i.productId == null ||
            !loadedProducts.any((product) => product['id'] == i.productId)) {
          ToastService.showError('Vui lòng chọn sản phẩm cho tất cả các dòng!');
          return;
        }
        if (i.quantity <= 0) {
          ToastService.showError('Số lượng sản phẩm nhập phải lớn hơn 0!');
          return;
        }
        if (!i.unitPrice.isFinite || i.unitPrice <= 0) {
          ToastService.showError('Đơn giá nhập hàng phải lớn hơn 0!');
          return;
        }
      }
      final selectedProductIds = _items.map((item) => item.productId).toList();
      if (selectedProductIds.toSet().length != selectedProductIds.length) {
        ToastService.showError(
          'Mỗi sản phẩm chỉ được xuất hiện một lần trong đơn nhập hàng.',
        );
        return;
      }
      setState(() => _currentStep = 2);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _save() async {
    if (_saving || _suggestionApplying) return;
    final source = widget.sourceInvoice;
    if (source != null &&
        (!_notPreviouslyReceived ||
            ref.read(shopProvider).currentShopId != source.shopId)) {
      ToastService.showError(
        'Chọn đúng cửa hàng và xác nhận hàng chưa được ghi tăng kho.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = {
        'supplierId': _supplierId,
        'warehouseId': _warehouseId,
        'orderDate': DateFormat(
          'yyyy-MM-dd',
        ).format(source == null ? DateTime.now() : _sourceDate),
        'notes': _notesCtrl.text.trim(),
        'items': _items
            .map(
              (i) => {
                'productId': i.productId,
                'quantity': i.quantity,
                'unitPrice': i.unitPrice,
              },
            )
            .toList(),
      };

      final scope = ref.read(offlineScopeProvider);
      if (scope == null) {
        throw ApiException(
          'Chọn một cửa hàng và chờ tải tài khoản trước khi ghi phiếu nhập.',
        );
      }
      final draft = _draft;
      if (draft != null && draft.scope.key != scope.key) {
        throw ApiException('Phạm vi bản nháp đã thay đổi.');
      }
      if (source == null) {
        await ref.read(inventoryRepoProvider).createPurchaseOrder(payload);
      } else {
        await ref
            .read(inventoryRepoProvider)
            .createPurchaseFromScan(source.scanId, {
              ...payload,
              'invoiceRevision': source.revision,
              'confirmNotPreviouslyReceived': _notPreviouslyReceived,
            });
        ref.invalidate(invoiceScanDetailProvider(source.scanId));
        ref.invalidate(filteredInvoiceScanListProvider);
      }
      if (!mounted || ref.read(offlineScopeProvider)?.key != scope.key) return;
      _completed = true;
      try {
        await draft?.clear();
      } catch (_) {
        /* The server already confirmed the purchase. */
      }
      ref.invalidate(purchaseOrdersProvider);
      ref.invalidate(purchaseOrderQueryProvider);
      ref.invalidate(stockProvider);
      ref.invalidate(stockPageProvider);
      ref.invalidate(productListProvider);
      ref.invalidate(inventoryMovementsProvider);
      ref.invalidate(lowStockProvider);

      if (mounted) {
        ToastService.showSuccess('Tạo đơn nhập hàng thành công!');
        final router = GoRouter.maybeOf(context);
        if (router != null) {
          if (router.canPop()) {
            router.pop(true);
          } else {
            router.go('/purchase-orders');
          }
        } else if (Navigator.of(context).canPop()) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError(
          e is ApiException
              ? e.message
              : 'Chưa lưu được phiếu nhập. Nội dung vẫn được giữ để thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final suppliersAsync = ref.watch(supplierOptionsProvider);
    final productsAsync = ref.watch(productOptionsProvider);
    final warehousesAsync = ref.watch(warehousesProvider);

    if (_draftLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () async {
                  if (_saving) return;
                  try {
                    await _draft?.flush();
                  } catch (_) {
                    ToastService.showError(
                      'Chưa giữ được bản nháp. Hãy thử lại trước khi rời trang.',
                    );
                    return;
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
              )
            : null,
        title: Text(
          'Đơn Mua Nhập Hàng',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: AbsorbPointer(
        absorbing: _saving || _suggestionApplying,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Elegant Steps Indicator
                  _buildStepsHeader(c, theme),
                  if (_pendingSuggestion != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Có đề xuất ${_pendingSuggestion!.items.length} sản phẩm. Nháp hiện tại vẫn được giữ; dòng trùng giữ số lượng lớn hơn và đơn giá đang nhập.',
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _suggestionApplying
                                  ? null
                                  : _applySuggestion,
                              child: Text(
                                _suggestionApplying
                                    ? 'Đang thêm đề xuất…'
                                    : 'Thêm đề xuất vào nháp',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_draftNotice != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        _draftNotice!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.sourceInvoice != null) _sourceInfo(),
                            _buildCurrentStepView(
                              c,
                              theme,
                              suppliersAsync,
                              productsAsync,
                              warehousesAsync,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Buttons Bar
                  _buildBottomActionBar(c, theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sourceInfo() {
    final source = widget.sourceInvoice!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Từ hóa đơn ${source.number}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Đối tác trên ảnh: ${source.partnerName} · Tổng: ${_currFmt.format(source.total)}',
            ),
            const SizedBox(height: 8),
            const Text(
              'Chọn đúng nhà cung cấp, kho và ghép từng dòng với mã hàng. Đơn giá gợi ý phân bổ theo tổng tiền hóa đơn (gồm thuế/phí); kiểm tra lại giá vốn và số lượng theo đơn vị trong kho. Không tự ghép sản phẩm theo tên.',
            ),
            if (_currentStep == 0) ...[
              const SizedBox(height: 12),
              BusinessDateField(
                label: 'Ngày nhận hàng',
                selectedDate: _sourceDate,
                onChanged: (value) {
                  setState(() => _sourceDate = value);
                  _persistDraft();
                },
              ),
            ],
            if (_currentStep == 1 &&
                ref.watch(shopProvider).hasPermission('products', 'edit'))
              TextButton.icon(
                onPressed: () async {
                  await context.push('/products/form');
                  ref.invalidate(productOptionsProvider);
                },
                icon: const AppIcon(Icons.add),
                label: const Text('Chưa có mã hàng? Tạo sản phẩm trước'),
              ),
            if (_currentStep == 2) ...[
              Text(
                'Tổng giá vốn nhập: ${_currFmt.format(_items.fold<double>(0, (sum, item) => sum + item.subtotal))}. Sai số cho phép với hóa đơn: tối đa 1 đồng.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _notPreviouslyReceived,
                onChanged: (value) =>
                    setState(() => _notPreviouslyReceived = value ?? false),
                title: const Text(
                  'Các hàng này chưa được ghi tăng kho trong ứng dụng.',
                ),
              ),
              const Text(
                'Tạo phiếu chờ chưa tăng tồn, chưa ghi công nợ hoặc chi tiền. Hoàn tất phiếu nhập khi đã kiểm nhận hàng.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepsHeader(AppThemeColors c, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(
          bottom: BorderSide(color: c.divider.withValues(alpha: 0.5), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepIndicatorNode(0, 'Thông tin', c, theme),
          _buildStepConnectorLine(0, c, theme),
          _buildStepIndicatorNode(1, 'Sản phẩm', c, theme),
          _buildStepConnectorLine(1, c, theme),
          _buildStepIndicatorNode(2, 'Xác nhận', c, theme),
        ],
      ),
    );
  }

  Widget _buildStepIndicatorNode(
    int index,
    String label,
    AppThemeColors c,
    ThemeData theme,
  ) {
    final isActive = _currentStep == index;
    final isCompleted = _currentStep > index;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? theme.colorScheme.primary
                : (isCompleted ? AppColors.success : c.surface),
            border: Border.all(
              color: isActive
                  ? theme.colorScheme.primary
                  : (isCompleted ? AppColors.success : c.divider),
              width: 1.5,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const AppIcon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  )
                : Text(
                    '${index + 1}',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : c.textSecondary,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? theme.colorScheme.primary : c.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnectorLine(int index, AppThemeColors c, ThemeData theme) {
    final isCompleted = _currentStep > index;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        height: 2,
        color: isCompleted
            ? AppColors.success
            : c.divider.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildCurrentStepView(
    AppThemeColors c,
    ThemeData theme,
    AsyncValue<Map<String, dynamic>> suppliersAsync,
    AsyncValue<Map<String, dynamic>> productsAsync,
    AsyncValue<List<dynamic>> warehousesAsync,
  ) {
    switch (_currentStep) {
      case 0:
        return _buildInfoStep(c, theme, suppliersAsync, warehousesAsync);
      case 1:
        return _buildItemsStep(c, theme, productsAsync);
      case 2:
        return _buildConfirmStep(c, theme, productsAsync);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInfoStep(
    AppThemeColors c,
    ThemeData theme,
    AsyncValue<Map<String, dynamic>> suppliersAsync,
    AsyncValue<List<dynamic>> warehousesAsync,
  ) {
    return Column(
      key: const ValueKey('step_info'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.divider.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AppIcon(
                      Icons.business_center_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Thông tin đối tác & Kho nhập',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Chọn NCC
              suppliersAsync.when(
                skipLoadingOnRefresh: false,
                data: (data) {
                  final items = (data['items'] as List?) ?? [];
                  if (items.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Chưa có Nhà cung cấp. Vui lòng vào phân hệ Đối Tác để thêm Nhà cung cấp trước khi nhập hàng.',
                        style: TextStyle(color: AppColors.danger, fontSize: 13),
                      ),
                    );
                  }
                  return DropdownButtonFormField<int>(
                    initialValue: items.any((item) => item['id'] == _supplierId)
                        ? _supplierId
                        : null,
                    dropdownColor: c.card,
                    style: GoogleFonts.inter(
                      color: c.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Nhà cung cấp *',
                      labelStyle: TextStyle(color: c.textSecondary),
                      filled: true,
                      fillColor: c.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    items: items.map((e) {
                      return DropdownMenuItem<int>(
                        value: e['id'],
                        child: Text(e['name'] ?? 'Không tên'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() {
                        _supplierId = v;
                        final matched = items
                            .where((e) => e['id'] == v)
                            .firstOrNull;
                        if (matched != null) {
                          _supplierName = matched['name'] ?? '';
                        }
                      });
                      _persistDraft();
                    },
                    validator: (v) => v == null ? 'Vui lòng chọn NCC' : null,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => const Text(
                  'Không thể tải nhà cung cấp. Vui lòng thử lại.',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
              const SizedBox(height: 14),

              // Chọn Kho
              warehousesAsync.when(
                skipLoadingOnRefresh: false,
                data: (data) {
                  if (data.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Chưa có kho hàng nào được tạo. (Sẽ dùng kho mặc định)',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    );
                  }

                  // Auto-select first warehouse if none selected
                  if (!warehousesAsync.isLoading &&
                      data.isNotEmpty &&
                      !data.any((item) => item['id'] == _warehouseId)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      final latest = ref.read(warehousesProvider);
                      if (_draftLoading ||
                          latest.isLoading ||
                          !identical(latest.asData?.value, data) ||
                          data.any((item) => item['id'] == _warehouseId)) {
                        return;
                      }
                      setState(() {
                        _warehouseId = data[0]['id'];
                        _warehouseName = data[0]['name'] ?? '';
                      });
                      _persistDraft();
                    });
                  }

                  return DropdownButtonFormField<int>(
                    key: ValueKey('warehouse-$_warehouseId'),
                    initialValue: data.any((item) => item['id'] == _warehouseId)
                        ? _warehouseId
                        : null,
                    dropdownColor: c.card,
                    style: GoogleFonts.inter(
                      color: c.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Kho lưu trữ sản phẩm',
                      labelStyle: TextStyle(color: c.textSecondary),
                      filled: true,
                      fillColor: c.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    items: data.map((e) {
                      return DropdownMenuItem<int>(
                        value: e['id'],
                        child: Text(e['name'] ?? 'Không tên'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() {
                        _warehouseId = v;
                        final matched = data
                            .where((e) => e['id'] == v)
                            .firstOrNull;
                        if (matched != null) {
                          _warehouseName = matched['name'] ?? '';
                        }
                      });
                      _persistDraft();
                    },
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, stack) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 14),

              // Ghi chú
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Ghi chú / Mô tả chi tiết đơn mua',
                  labelStyle: TextStyle(color: c.textSecondary),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: c.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemsStep(
    AppThemeColors c,
    ThemeData theme,
    AsyncValue<Map<String, dynamic>> productsAsync,
  ) {
    final productsById = _productsById(productsAsync);
    return Column(
      key: const ValueKey('step_items'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Danh sách sản phẩm nhập (${_items.length})',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: _addItem,
              icon: const AppIcon(Icons.add_circle_outline_rounded, size: 18),
              label: Text(
                'Thêm dòng',
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: AppEmpty(
              visual: AppEmptyVisual.inventory,
              message: 'Chưa có sản phẩm nào được chọn.',
            ),
          ),

        ..._items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.divider.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.sourceLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Trên hóa đơn: ${item.sourceLabel}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (item.productId != null)
                      _itemThumbnail(item, productsById)
                    else
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: Text(
                          '${idx + 1}',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: productsAsync.when(
                        skipLoadingOnRefresh: false,
                        data: (data) {
                          final prods = (data['items'] as List?) ?? [];
                          return DropdownButtonFormField<int>(
                            initialValue:
                                prods.any(
                                  (product) => product['id'] == item.productId,
                                )
                                ? item.productId
                                : null,
                            isExpanded: true,
                            dropdownColor: c.card,
                            style: GoogleFonts.inter(
                              color: c.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Chọn sản phẩm *',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            items: prods.map((e) {
                              return DropdownMenuItem<int>(
                                value: e['id'],
                                child: Text(
                                  widget.sourceInvoice == null
                                      ? '${e['sku'] ?? 'N/A'} - ${e['name'] ?? 'Không tên'}'
                                      : '${e['sku'] ?? 'N/A'} - ${e['name'] ?? 'Không tên'} · Tồn ${e['currentStock'] ?? 0} ${e['unit'] ?? ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              setState(() {
                                item.productId = v;
                                final matched = prods
                                    .where((e) => e['id'] == v)
                                    .firstOrNull;
                                if (matched != null) {
                                  item.productName = matched['name'];
                                  item.productSku = matched['sku'];
                                  if (item.priceCtrl.text.isEmpty) {
                                    item.priceCtrl.text =
                                        (matched['costPrice'] ?? 0).toString();
                                  }
                                }
                              });
                              _persistDraft();
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, stack) => const Text(
                          'Lỗi tải sản phẩm',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const AppIcon(
                        Icons.delete_outline_rounded,
                        color: AppColors.danger,
                        size: 20,
                      ),
                      onPressed: () => _removeItem(idx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: item.qtyCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Số lượng',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() {
                          item.quantity = int.tryParse(v) ?? 0;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: item.priceCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Đơn giá nhập',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Thành tiền: ${_currFmt.format(item.subtotal)}',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Map<String, Map> _productsById(AsyncValue<Map<String, dynamic>> data) => {
    for (final product
        in (data.value?['items'] as List? ?? []).whereType<Map>())
      '${product['id']}': product,
  };

  Widget _itemThumbnail(_PoItem item, Map<String, Map> productsById) =>
      ProductThumbnail(
        imageUrl: productsById['${item.productId}']?['imageUrl']?.toString(),
        name: item.productName,
        size: 44,
      );

  Widget _buildConfirmStep(
    AppThemeColors c,
    ThemeData theme,
    AsyncValue<Map<String, dynamic>> productsAsync,
  ) {
    final productsById = _productsById(productsAsync);
    return Column(
      key: const ValueKey('step_confirm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.divider.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TỔNG QUAN PHIẾU NHẬP HÀNG',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailTextRow('Nhà cung cấp:', _supplierName, c),
              const SizedBox(height: 6),
              _buildDetailTextRow(
                'Kho nhập:',
                _warehouseName.isNotEmpty ? _warehouseName : 'Chưa thiết lập',
                c,
              ),
              const SizedBox(height: 6),
              _buildDetailTextRow(
                widget.sourceInvoice == null ? 'Ngày đặt:' : 'Ngày nhận hàng:',
                DateFormat('dd/MM/yyyy').format(
                  widget.sourceInvoice == null ? DateTime.now() : _sourceDate,
                ),
                c,
              ),
              if (_notesCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildDetailTextRow('Ghi chú:', _notesCtrl.text, c),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Items listing card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.divider.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHI TIẾT SẢN PHẨM (${_items.length})',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: c.textSecondary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(),
              ..._items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      _itemThumbnail(item, productsById),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName ?? 'Sản phẩm',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'SKU: ${item.productSku ?? 'N/A'} • SL: ${item.quantity}',
                              style: TextStyle(
                                fontSize: 11,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _currFmt.format(item.subtotal),
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Glassy aggregate amount card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.85),
                theme.colorScheme.primary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng thanh toán',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                _currFmt.format(_totalAmount),
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDetailTextRow(String label, String val, AppThemeColors c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            val,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(AppThemeColors c, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(
          top: BorderSide(color: c.divider.withValues(alpha: 0.4)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Quay lại',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: _saving
                    ? null
                    : (_currentStep == 2 ? _save : _nextStep),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : AppIcon(
                        _currentStep == 2
                            ? Icons.check_circle_outline_rounded
                            : Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                label: Text(
                  _saving
                      ? 'Đang tạo...'
                      : (_currentStep == 2 ? 'Lưu Đơn Nhập' : 'Tiếp tục'),
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
