import 'package:flutter/material.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_provider.dart';
import '../../suppliers/providers/supplier_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../../core/widgets/app_animations.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class _PoItem {
  int? productId;
  String? productName;
  String? productSku;
  int quantity = 1;
  TextEditingController qtyCtrl = TextEditingController(text: '1');
  TextEditingController priceCtrl = TextEditingController();

  _PoItem();

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }

  double get unitPrice => double.tryParse(priceCtrl.text) ?? 0;
  double get subtotal => quantity * unitPrice;
}

class PurchaseOrderFormScreen extends ConsumerStatefulWidget {
  const PurchaseOrderFormScreen({super.key});
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
  int _currentStep = 0; // 0 = Info, 1 = Items, 2 = Confirm

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (var i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_PoItem()));
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  double get _totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  void _nextStep() {
    if (_currentStep == 0) {
      final suppliersAsync = ref.read(supplierListProvider((page: 1, search: null)));
      final hasSuppliers = ((suppliersAsync.value?['items'] as List?)?.isNotEmpty ?? false);
      if (_supplierId == null && hasSuppliers) {
        ToastService.showSuccess('Vui lòng chọn Nhà cung cấp!');
        return;
      }
      if (!hasSuppliers) {
         ToastService.showSuccess('Chưa có Nhà cung cấp nào. Vui lòng tạo Nhà cung cấp trước!');
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_items.isEmpty) {
        ToastService.showSuccess('Vui lòng thêm ít nhất 1 sản phẩm để nhập hàng!');
        return;
      }
      for (var i in _items) {
        if (i.productId == null) {
          ToastService.showSuccess('Vui lòng chọn sản phẩm cho tất cả các dòng!');
          return;
        }
        if (i.quantity <= 0) {
          ToastService.showSuccess('Số lượng sản phẩm nhập phải lớn hơn 0!');
          return;
        }
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
    setState(() => _saving = true);
    try {
      final payload = {
        'supplierId': _supplierId,
        'warehouseId': _warehouseId,
        'orderDate': DateTime.now().toIso8601String(),
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

      await ref.read(inventoryRepoProvider).createPurchaseOrder(payload);
      ref.invalidate(purchaseOrdersProvider);
      ref.invalidate(stockProvider(null));
      ref.invalidate(productListProvider((page: 1, search: null, tag: null)));
      ref.invalidate(lowStockProvider);

      if (mounted) {
        ToastService.showSuccess('Tạo đơn nhập hàng thành công!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError('Lỗi: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final suppliersAsync = ref.watch(
      supplierListProvider((page: 1, search: null)),
    );
    final productsAsync = ref.watch(
      productListProvider((page: 1, search: null, tag: null)),
    );
    final warehousesAsync = ref.watch(warehousesProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Đơn Mua Nhập Hàng',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Elegant Steps Indicator
            _buildStepsHeader(c, theme),
            
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildCurrentStepView(
                    c,
                    theme,
                    suppliersAsync,
                    productsAsync,
                    warehousesAsync,
                  ),
                ),
              ),
            ),
            
            // Bottom Buttons Bar
            _buildBottomActionBar(c, theme),
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

  Widget _buildStepIndicatorNode(int index, String label, AppThemeColors c, ThemeData theme) {
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
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: GoogleFonts.outfit(
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
          style: GoogleFonts.outfit(
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
        color: isCompleted ? AppColors.success : c.divider.withValues(alpha: 0.5),
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
        return _buildConfirmStep(c, theme);
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
                    child: Icon(
                      Icons.business_center_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Thông tin đối tác & Kho nhập',
                    style: GoogleFonts.outfit(
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
                    initialValue: _supplierId,
                    dropdownColor: c.card,
                    style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14),
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
                        borderSide: BorderSide(color: theme.colorScheme.primary),
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
                        final matched = items.firstWhere((e) => e['id'] == v, orElse: () => null);
                        if (matched != null) {
                          _supplierName = matched['name'] ?? '';
                        }
                      });
                    },
                    validator: (v) => v == null ? 'Vui lòng chọn NCC' : null,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(
                  'Lỗi tải NCC: $e',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              const SizedBox(height: 14),

              // Chọn Kho
              warehousesAsync.when(
                data: (data) {
                  if (data.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Chưa có kho hàng nào được tạo. (Sẽ dùng kho mặc định)',
                        style: TextStyle(color: c.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    );
                  }
                  
                  // Auto-select first warehouse if none selected
                  if (_warehouseId == null && data.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        _warehouseId = data[0]['id'];
                        _warehouseName = data[0]['name'] ?? '';
                      });
                    });
                  }

                  return DropdownButtonFormField<int>(
                    initialValue: _warehouseId,
                    dropdownColor: c.card,
                    style: GoogleFonts.inter(color: c.textPrimary, fontSize: 14),
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
                        borderSide: BorderSide(color: theme.colorScheme.primary),
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
                        final matched = data.firstWhere((e) => e['id'] == v, orElse: () => null);
                        if (matched != null) {
                          _warehouseName = matched['name'] ?? '';
                        }
                      });
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
    return Column(
      key: const ValueKey('step_items'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Danh sách sản phẩm nhập (${_items.length})',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: Text(
                'Thêm dòng',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: AppEmpty(message: 'Chưa có sản phẩm nào được chọn.'),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      child: Text(
                        '${idx + 1}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: productsAsync.when(
                        data: (data) {
                          final prods = (data['items'] as List?) ?? [];
                          return DropdownButtonFormField<int>(
                            initialValue: item.productId,
                            isExpanded: true,
                            dropdownColor: c.card,
                            style: GoogleFonts.inter(color: c.textPrimary, fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Chọn sản phẩm *',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(),
                            ),
                            items: prods.map((e) {
                              return DropdownMenuItem<int>(
                                value: e['id'],
                                child: Text(
                                  '${e['sku'] ?? 'N/A'} - ${e['name'] ?? 'Không tên'}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              setState(() {
                                item.productId = v;
                                final matched = prods.firstWhere((e) => e['id'] == v, orElse: () => null);
                                if (matched != null) {
                                  item.productName = matched['name'];
                                  item.productSku = matched['sku'];
                                  if (item.priceCtrl.text.isEmpty) {
                                    item.priceCtrl.text = (matched['costPrice'] ?? 0).toString();
                                  }
                                }
                              });
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
                      icon: const Icon(
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
                    style: GoogleFonts.outfit(
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

  Widget _buildConfirmStep(AppThemeColors c, ThemeData theme) {
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
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailTextRow('Nhà cung cấp:', _supplierName, c),
              const SizedBox(height: 6),
              _buildDetailTextRow('Kho nhập:', _warehouseName.isNotEmpty ? _warehouseName : 'Chưa thiết lập', c),
              const SizedBox(height: 6),
              _buildDetailTextRow('Ngày đặt:', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), c),
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
                style: GoogleFonts.outfit(
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
                        style: GoogleFonts.outfit(
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
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                _currFmt.format(_totalAmount),
                style: GoogleFonts.outfit(
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
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : (_currentStep == 2 ? _save : _nextStep),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
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
                  style: GoogleFonts.outfit(
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
