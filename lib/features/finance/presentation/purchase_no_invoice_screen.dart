import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../products/providers/product_provider.dart';
import '../../settings/providers/shop_provider.dart';
import '../providers/finance_provider.dart';

class PurchaseNoInvoiceScreen extends ConsumerStatefulWidget {
  const PurchaseNoInvoiceScreen({super.key});

  @override
  ConsumerState<PurchaseNoInvoiceScreen> createState() => _PurchaseNoInvoiceScreenState();
}

class _PurchaseNoInvoiceScreenState extends ConsumerState<PurchaseNoInvoiceScreen> {
  int _page = 1;
  String _statusFilter = 'ALL';

  String _fmt(num v) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context) {
    final pnAsync = ref.watch(purchasesNoInvoiceProvider(_page));
    final shop = ref.watch(shopProvider);
    final isOwner = shop.isOwner;

    Widget listBody({required bool pendingTabOnly, required bool showQuickFilter}) {
      return pnAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) {
          final rawItems = (data['items'] as List?) ?? [];
          final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
          final items = rawItems.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          final filtered = _filterItems(items, pendingTabOnly: pendingTabOnly);
          final totalAmount = filtered.fold<num>(0, (s, i) => s + ((i['totalAmount'] as num?) ?? 0));

          if (filtered.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.receipt_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                rawItems.isEmpty ? 'Chưa có bảng kê nào' : 'Không có dữ liệu phù hợp bộ lọc',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(icon: const Icon(Icons.add), label: const Text('Thêm bảng kê'), onPressed: _openAddDialog),
            ]));
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(purchasesNoInvoiceProvider(_page)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length + (showQuickFilter ? 3 : 2),
              itemBuilder: (_, index) {
                if (index == 0) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Tổng giá trị', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(_fmt(totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                    ]),
                  );
                }

                final listStartIndex = showQuickFilter ? 2 : 1;

                if (showQuickFilter && index == 1) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('ALL', 'Tất cả'),
                          const SizedBox(width: 8),
                          _filterChip('PENDING', 'Chờ duyệt'),
                          const SizedBox(width: 8),
                          _filterChip('APPROVED', 'Đã duyệt'),
                          const SizedBox(width: 8),
                          _filterChip('REJECTED', 'Từ chối'),
                        ],
                      ),
                    ),
                  );
                }

                if (index == filtered.length + listStartIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      OutlinedButton.icon(
                        onPressed: _page > 1 ? () => setState(() => _page--) : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Trước'),
                      ),
                      const SizedBox(width: 12),
                      Text('Trang $_page/$totalPages', style: TextStyle(color: AppThemeColors.of(context).textSecondary)),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _page < totalPages ? () => setState(() => _page++) : null,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Sau'),
                      ),
                    ]),
                  );
                }

                final p = filtered[index - listStartIndex];
                final detailItems = (p['items'] as List?) ?? const [];
                final approvalStatus = (p['approvalStatus'] ?? 'PENDING').toString().toUpperCase();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(p['recordCode'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(_fmt((p['totalAmount'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                    ]),
                    const SizedBox(height: 6),
                    _buildApprovalChip(approvalStatus),
                    const SizedBox(height: 4),
                    Text('${p['sellerName'] ?? ''} ${p['sellerIdentityNumber'] != null ? '• CCCD: ${p['sellerIdentityNumber']}' : ''}', style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 12)),
                    Text(p['purchaseDate']?.toString().split('T').first ?? '', style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 11)),
                    if ((p['approvalNotes'] ?? '').toString().trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Ghi chú duyệt: ${p['approvalNotes']}', style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 11)),
                      ),
                    if (detailItems.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Mặt hàng: ${detailItems.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ...detailItems.take(3).map<Widget>((it) => Text(
                        '- ${it['productName'] ?? ''}: ${it['quantity'] ?? 0} x ${_fmt((it['unitPrice'] as num?) ?? 0)}',
                        style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 11),
                      )),
                    ],
                    if (isOwner && approvalStatus == 'PENDING') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _handleApprovalDecision(p['id'] as int, approve: false),
                              icon: const Icon(Icons.close, color: AppColors.danger, size: 16),
                              label: const Text('Từ chối', style: TextStyle(color: AppColors.danger)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _handleApprovalDecision(p['id'] as int, approve: true),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Duyệt'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ]),
                );
              },
            ),
          );
        },
      );
    }

    if (isOwner) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Mua hàng không hóa đơn'),
            actions: [featureGuideButton(context, 'purchase_no_invoice')],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Tất cả'),
                Tab(text: 'Chờ duyệt'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              listBody(pendingTabOnly: false, showQuickFilter: true),
              listBody(pendingTabOnly: true, showQuickFilter: false),
            ],
          ),
          floatingActionButton: FloatingActionButton(onPressed: _openAddDialog, child: const Icon(Icons.add)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mua hàng không hóa đơn'), actions: [featureGuideButton(context, 'purchase_no_invoice')]),
      body: listBody(pendingTabOnly: false, showQuickFilter: true),
      floatingActionButton: FloatingActionButton(onPressed: _openAddDialog, child: const Icon(Icons.add)),
    );
  }

  List<Map<String, dynamic>> _filterItems(List<Map<String, dynamic>> items, {required bool pendingTabOnly}) {
    final base = pendingTabOnly
        ? items.where((i) => (i['approvalStatus'] ?? 'PENDING').toString().toUpperCase() == 'PENDING')
        : items;
    if (_statusFilter == 'ALL' || pendingTabOnly) {
      return base.toList();
    }
    return base.where((i) => (i['approvalStatus'] ?? 'PENDING').toString().toUpperCase() == _statusFilter).toList();
  }

  Widget _filterChip(String value, String label) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _statusFilter = value;
      }),
    );
  }

  Future<void> _openAddDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AddPurchaseNoInvoiceDialog(formatCurrency: _fmt),
    );
    if (saved == true && mounted) {
      ref.invalidate(purchasesNoInvoiceProvider(_page));
    }
  }

  Widget _buildApprovalChip(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'APPROVED':
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.success;
        label = 'Da duyet';
        break;
      case 'REJECTED':
        bg = AppColors.danger.withValues(alpha: 0.15);
        fg = AppColors.danger;
        label = 'Tu choi';
        break;
      default:
        bg = AppColors.warning.withValues(alpha: 0.2);
        fg = AppColors.warning;
        label = 'Cho duyet';
        break;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }

  Future<void> _handleApprovalDecision(int purchaseId, {required bool approve}) async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Duyet bang ke' : 'Tu choi bang ke'),
        content: TextField(
          controller: notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Ghi chu (khong bat buoc)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(approve ? 'Duyet' : 'Tu choi')),
        ],
      ),
    );

    if (confirmed != true) {
      notesController.dispose();
      return;
    }

    try {
      if (approve) {
        await ref.read(financeRepoProvider).approvePurchaseNoInvoice(purchaseId, approvalNotes: notesController.text.trim());
      } else {
        await ref.read(financeRepoProvider).rejectPurchaseNoInvoice(purchaseId, approvalNotes: notesController.text.trim());
      }
      if (!mounted) return;
      ref.invalidate(purchasesNoInvoiceProvider(_page));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Da duyet bang ke' : 'Da tu choi bang ke')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Khong the cap nhat phe duyet: $e')));
    } finally {
      notesController.dispose();
    }
  }
}

class _AddPurchaseNoInvoiceDialog extends ConsumerStatefulWidget {
  final String Function(num) formatCurrency;
  const _AddPurchaseNoInvoiceDialog({required this.formatCurrency});

  @override
  ConsumerState<_AddPurchaseNoInvoiceDialog> createState() => _AddPurchaseNoInvoiceDialogState();
}

class _AddPurchaseNoInvoiceDialogState extends ConsumerState<_AddPurchaseNoInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController sellerC;
  late final TextEditingController idC;
  late final TextEditingController productC;
  late final TextEditingController qtyC;
  late final TextEditingController unitPriceC;

  final lineItems = <Map<String, dynamic>>[];
  bool _isSubmitting = false;
  int? _selectedProductId;

  @override
  void initState() {
    super.initState();
    sellerC = TextEditingController();
    idC = TextEditingController();
    productC = TextEditingController();
    qtyC = TextEditingController(text: '1');
    unitPriceC = TextEditingController();
  }

  @override
  void dispose() {
    sellerC.dispose();
    idC.dispose();
    productC.dispose();
    qtyC.dispose();
    unitPriceC.dispose();
    super.dispose();
  }

  double calcTotal() => lineItems.fold<double>(0, (s, i) => s + (i['subtotal'] as double? ?? 0));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm bảng kê'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: sellerC,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Tên người bán'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên người bán' : null,
          ),
          TextFormField(
            controller: idC,
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'CCCD người bán'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập CCCD người bán' : null,
          ),
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft, child: Text('Chi tiết hàng hóa', style: TextStyle(fontWeight: FontWeight.w600))),
          TextFormField(controller: productC, decoration: const InputDecoration(labelText: 'Tên hàng hóa')),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isSubmitting ? null : () => _showProductPicker(context, ref, onPick: (name, unitPrice) {
                setState(() {
                  productC.text = name;
                  unitPriceC.text = unitPrice > 0 ? unitPrice.toStringAsFixed(0) : '';
                });
              }, onPickProductId: (id) {
                _selectedProductId = id;
              }),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Chọn từ danh sách hàng hóa'),
            ),
          ),
          Row(children: [
            Expanded(child: TextFormField(controller: qtyC, decoration: const InputDecoration(labelText: 'Số lượng'), keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: unitPriceC, decoration: const InputDecoration(labelText: 'Đơn giá'), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isSubmitting ? null : () {
                final productName = productC.text.trim();
                final quantity = double.tryParse(qtyC.text) ?? 0;
                final unitPrice = double.tryParse(unitPriceC.text) ?? 0;
                if (productName.isEmpty || quantity <= 0 || unitPrice < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kiểm tra lại tên hàng, số lượng và đơn giá')));
                  return;
                }
                setState(() {
                  lineItems.add({
                    'productName': productName,
                    'productId': _selectedProductId,
                    'quantity': quantity,
                    'unitPrice': unitPrice,
                    'subtotal': quantity * unitPrice,
                  });
                  productC.clear();
                  qtyC.text = '1';
                  unitPriceC.clear();
                  _selectedProductId = null;
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Thêm dòng'),
            ),
          ),
          if (lineItems.isNotEmpty)
            ...lineItems.asMap().entries.map((entry) {
              final idx = entry.key;
              final line = entry.value;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(line['productName'] as String),
                subtitle: Text('${line['quantity']} x ${widget.formatCurrency(line['unitPrice'] as num)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.formatCurrency(line['subtotal'] as num), style: const TextStyle(fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _isSubmitting ? null : () => setState(() => lineItems.removeAt(idx)),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Tổng: ${widget.formatCurrency(calcTotal())}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ])),
      ),
      actions: [
        TextButton(onPressed: _isSubmitting ? null : () => Navigator.pop(context, false), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Lưu'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng thêm ít nhất 1 mặt hàng')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(financeRepoProvider).createPurchaseNoInvoice({
        'sellerName': sellerC.text.trim(),
        'sellerIdentityNumber': idC.text.trim(),
        'totalAmount': calcTotal(),
        'items': lineItems,
        'purchaseDate': DateTime.now().toIso8601String().split('T').first,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu bảng kê thành công')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lưu thất bại: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showProductPicker(
    BuildContext context,
    WidgetRef ref, {
    required void Function(String name, double unitPrice) onPick,
    required void Function(int productId) onPickProductId,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final productAsync = ref.watch(productListProvider((page: 1, search: null)));
        return productAsync.when(
          loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => SizedBox(height: 220, child: Center(child: Text('Lỗi tải sản phẩm: $e'))),
          data: (data) {
            final products = (data['items'] as List?) ?? const [];
            if (products.isEmpty) {
              return const SizedBox(height: 220, child: Center(child: Text('Chưa có sản phẩm để chọn')));
            }
            return ListView.builder(
              itemCount: products.length,
              itemBuilder: (_, i) {
                final p = products[i] as Map<String, dynamic>;
                final name = p['name']?.toString() ?? 'Sản phẩm';
                final unitPrice = (p['costPrice'] ?? p['cost_price'] ?? p['sellingPrice'] ?? p['selling_price'] ?? 0).toDouble();
                return ListTile(
                  title: Text(name),
                  subtitle: Text('Giá gợi ý: ${widget.formatCurrency(unitPrice)}'),
                  onTap: () {
                    onPick(name, unitPrice);
                    final id = (p['id'] as num?)?.toInt();
                    if (id != null && id > 0) onPickProductId(id);
                    Navigator.pop(ctx);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}


