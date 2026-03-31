import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_provider.dart';
import '../../suppliers/providers/supplier_provider.dart';
import '../../products/providers/product_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class _PoItem {
  int? productId;
  String? productName;
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
  ConsumerState<PurchaseOrderFormScreen> createState() => _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState extends ConsumerState<PurchaseOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  
  int? _supplierId;
  int? _warehouseId;
  final List<_PoItem> _items = [];
  bool _saving = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (var i in _items) { i.dispose(); }
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn Nhà cung cấp'), backgroundColor: AppColors.danger));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng thêm ít nhất 1 sản phẩm'), backgroundColor: AppColors.danger));
      return;
    }
    for (var i in _items) {
      if (i.productId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn sản phẩm cho tất cả các dòng'), backgroundColor: AppColors.danger));
        return;
      }
      if (i.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số lượng phải lớn hơn 0'), backgroundColor: AppColors.danger));
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'supplierId': _supplierId,
        'warehouseId': _warehouseId,
        'orderDate': DateTime.now().toIso8601String(),
        'notes': _notesCtrl.text.trim(),
        'items': _items.map((i) => {
          'productId': i.productId,
          'quantity': i.quantity,
          'unitPrice': i.unitPrice,
        }).toList(),
      };

      await ref.read(inventoryRepoProvider).createPurchaseOrder(payload);
      ref.invalidate(purchaseOrdersProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo đơn nhập hàng thành công!'), backgroundColor: AppColors.success));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final suppliersAsync = ref.watch(supplierListProvider((page: 1, search: null)));
    final productsAsync = ref.watch(productListProvider((page: 1, search: null)));
    final warehousesAsync = ref.watch(warehousesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo đơn nhập hàng'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: AppColors.primary, size: 18),
            label: Text(_saving ? 'Đang lưu...' : 'Lưu', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Thông tin chung
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const HugeIcon(icon: HugeIcons.strokeRoundedBuilding03, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text('Thông tin chung', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 16),
                  
                  // Chọn NCC
                  suppliersAsync.when(
                    data: (data) {
                      final items = (data['items'] as List?) ?? [];
                      return DropdownButtonFormField<int>(
                        initialValue: _supplierId,
                        decoration: InputDecoration(
                          labelText: 'Nhà cung cấp *',
                          filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: items.map((e) => DropdownMenuItem<int>(value: e['id'], child: Text(e['name']))).toList(),
                        onChanged: (v) => setState(() => _supplierId = v),
                        validator: (v) => v == null ? 'Vui lòng chọn NCC' : null,
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Lỗi tải NCC: $e', style: const TextStyle(color: AppColors.danger)),
                  ),
                  const SizedBox(height: 12),

                  // Chọn Kho
                  warehousesAsync.when(
                    data: (data) {
                      if (data.isEmpty) return const SizedBox.shrink();
                      return DropdownButtonFormField<int>(
                        initialValue: _warehouseId,
                        decoration: InputDecoration(
                          labelText: 'Kho nhập',
                          filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: data.map((e) => DropdownMenuItem<int>(value: e['id'], child: Text(e['name']))).toList(),
                        onChanged: (v) => setState(() => _warehouseId = v),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (e, stack) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),

                  // Ghi chú
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Ghi chú',
                      filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Danh sách sản phẩm
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      const HugeIcon(icon: HugeIcons.strokeRoundedPackage, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text('Sản phẩm nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    TextButton.icon(
                      onPressed: _addItem, 
                      icon: const Icon(Icons.add, size: 18), 
                      label: const Text('Thêm dòng'),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  if (_items.isEmpty)
                    Center(child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text('Chưa có sản phẩm nào', style: TextStyle(color: c.textMuted)),
                    )),

                  ..._items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Theme.of(context).scaffoldBackgroundColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).dividerColor)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(children: [
                              Expanded(
                                child: productsAsync.when(
                                  data: (data) {
                                    final prods = (data['items'] as List?) ?? [];
                                    return DropdownButtonFormField<int>(
                                      initialValue: item.productId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Chọn sản phẩm *',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      items: prods.map((e) => DropdownMenuItem<int>(
                                        value: e['id'], 
                                        child: Text('${e['sku'] ?? 'N/A'} - ${e['name']}'),
                                      )).toList(),
                                      onChanged: (v) {
                                        setState(() {
                                          item.productId = v;
                                          final p = prods.firstWhere((e) => e['id'] == v, orElse: () => null);
                                          if (p != null) item.productName = p['name'];
                                        });
                                      },
                                    );
                                  },
                                  loading: () => const LinearProgressIndicator(),
                                  error: (e, stack) => const Text('Lỗi tải sản phẩm', style: TextStyle(color: AppColors.danger)),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                onPressed: () => _removeItem(idx),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: item.qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Số lượng', isDense: true, border: OutlineInputBorder()),
                                  onChanged: (v) => setState(() { item.quantity = int.tryParse(v) ?? 0; }),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: item.priceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Đơn giá nhập', isDense: true, border: OutlineInputBorder()),
                                  onChanged: (v) => setState(() {}),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text('Thành tiền: ${_currFmt.format(item.subtotal)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng cộng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(_currFmt.format(_totalAmount), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
