import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_provider.dart';
import '../../products/providers/product_provider.dart';

class _StkItem {
  int? productId;
  int systemQty = 0;
  int actualQty = 0;
  TextEditingController actualQtyCtrl = TextEditingController(text: '0');

  _StkItem();
  
  void dispose() {
    actualQtyCtrl.dispose();
  }

  int get diff => actualQty - systemQty;
}

class StockTakeFormScreen extends ConsumerStatefulWidget {
  const StockTakeFormScreen({super.key});
  @override
  ConsumerState<StockTakeFormScreen> createState() => _StockTakeFormScreenState();
}

class _StockTakeFormScreenState extends ConsumerState<StockTakeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  
  int? _warehouseId;
  final List<_StkItem> _items = [];
  bool _saving = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (var i in _items) { i.dispose(); }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_StkItem()));
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng thêm ít nhất 1 sản phẩm để kiểm kê'), backgroundColor: AppColors.danger));
      return;
    }
    for (var i in _items) {
      if (i.productId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn sản phẩm cho tất cả các dòng'), backgroundColor: AppColors.danger));
        return;
      }
      if (i.actualQty < 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số lượng thực tế không được âm'), backgroundColor: AppColors.danger));
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'warehouseId': _warehouseId,
        'stockTakeDate': DateTime.now().toIso8601String(),
        'notes': _notesCtrl.text.trim(),
        'items': _items.map((i) => {
          'productId': i.productId,
          'systemQty': i.systemQty,
          'actualQty': i.actualQty,
        }).toList(),
      };

      await ref.read(inventoryRepoProvider).createStockTake(payload);
      ref.invalidate(stockProvider(null)); // Refresh stock list
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lưu phiếu kiểm kê thành công!'), backgroundColor: AppColors.success));
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
    final warehousesAsync = ref.watch(warehousesProvider);
    final productsAsync = ref.watch(productListProvider((page: 1, search: null)));
    final stockAsync = ref.watch(stockProvider(null));

    // Lấy map tồn kho để tự điền systemQty
    final stockMap = <int, int>{};
    stockAsync.whenData((items) {
      for (var s in items) {
        final pid = s['product'] != null ? s['product']['id'] : s['productId'];
        if (pid != null) {
          stockMap[pid] = s['quantity'] ?? 0;
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo phiếu kiểm kê'),
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
                    const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text('Thông tin chung', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 16),
                  
                  // Chọn Kho
                  warehousesAsync.when(
                    data: (data) {
                      if (data.isEmpty) return const SizedBox.shrink();
                      return DropdownButtonFormField<int>(
                        initialValue: _warehouseId,
                        decoration: InputDecoration(
                          labelText: 'Kho kiểm kê *',
                          filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: data.map((e) => DropdownMenuItem<int>(value: e['id'], child: Text(e['name']))).toList(),
                        onChanged: (v) => setState(() => _warehouseId = v),
                        validator: (v) => v == null ? 'Vui lòng chọn kho' : null,
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
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
                      const Text('Sản phẩm kiểm kê', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                                          item.systemQty = stockMap[v] ?? 0;
                                          item.actualQty = item.systemQty;
                                          item.actualQtyCtrl.text = item.actualQty.toString();
                                        });
                                      },
                                      validator: (v) => v == null ? 'Bắt buộc' : null,
                                    );
                                  },
                                  loading: () => const LinearProgressIndicator(),
                                  error: (e, stack) => const Text('Lỗi tải SPM', style: TextStyle(color: AppColors.danger)),
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
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: c.card,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Theme.of(context).dividerColor)
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Tồn hệ thống', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                                      Text('${item.systemQty}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: item.actualQtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Thực tế', isDense: true, border: OutlineInputBorder()),
                                  onChanged: (v) => setState(() { item.actualQty = int.tryParse(v) ?? 0; }),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: item.diff == 0 ? c.card : (item.diff > 0 ? AppColors.success.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Theme.of(context).dividerColor)
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Chênh lệch', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                                      Text('${item.diff > 0 ? '+' : ''}${item.diff}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: item.diff == 0 ? c.textPrimary : (item.diff > 0 ? AppColors.success : AppColors.danger))),
                                    ],
                                  ),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
