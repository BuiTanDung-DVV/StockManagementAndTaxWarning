import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../../core/widgets/app_animations.dart';

class _StkItem {
  int? productId;
  String sku = '';
  String name = '';
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
  String _warehouseName = '';
  final List<_StkItem> _items = [];
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
    setState(() => _items.add(_StkItem()));
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_warehouseId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn kho kiểm kê trước khi tiếp tục!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng thêm ít nhất 1 sản phẩm để kiểm kê!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      for (var i in _items) {
        if (i.productId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng chọn sản phẩm cho tất cả các dòng!'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.danger,
            ),
          );
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
        'warehouseId': _warehouseId,
        'stockTakeDate': DateTime.now().toIso8601String(),
        'notes': _notesCtrl.text.trim(),
        'items': _items
            .map(
              (i) => {
                'productId': i.productId,
                'systemQty': i.systemQty,
                'actualQty': i.actualQty,
              },
            )
            .toList(),
      };

      await ref.read(inventoryRepoProvider).createStockTake(payload);
      ref.invalidate(stockProvider(null)); // Refresh stock list
      ref.invalidate(lowStockProvider); // Refresh low-stock warning

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lưu phiếu kiểm kê thành công!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'), 
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.danger,
          ),
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
    final warehousesAsync = ref.watch(warehousesProvider);
    final productsAsync = ref.watch(
      productListProvider((page: 1, search: null)),
    );
    final stockAsync = ref.watch(stockProvider(null));

    // Map stock for dynamic filling
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
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Phiếu Kiểm Kê Kho',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Elegant Steps Progress Header
            _buildStepsHeader(c, theme),
            
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(18),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildCurrentStepView(c, theme, warehousesAsync, productsAsync, stockMap),
                ),
              ),
            ),
            
            // Bottom Action Navigation Bar
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
          _buildStepIndicatorNode(1, 'Kiểm đếm', c, theme),
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
    AsyncValue<List<dynamic>> warehousesAsync,
    AsyncValue<Map<String, dynamic>> productsAsync,
    Map<int, int> stockMap,
  ) {
    if (_currentStep == 0) {
      // Step 1: Info (Warehouse selection & notes)
      return Column(
        key: const ValueKey('step_info'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chọn Kho & Ghi chú',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.divider.withValues(alpha: 0.5), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chọn Kho dropdown
                warehousesAsync.when(
                  data: (data) {
                    if (data.isEmpty) return const SizedBox.shrink();
                    return DropdownButtonFormField<int>(
                      initialValue: _warehouseId,
                      isExpanded: true,
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Kho kiểm kê *',
                        prefixIcon: Icon(Icons.warehouse_rounded, color: theme.colorScheme.primary),
                        filled: true,
                        fillColor: c.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: data
                          .map(
                            (e) => DropdownMenuItem<int>(
                              value: e['id'],
                              child: Text(e['name']),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _warehouseId = v;
                          final wh = data.firstWhere((e) => e['id'] == v, orElse: () => null);
                          if (wh != null) _warehouseName = wh['name'] ?? '';
                        });
                      },
                      validator: (v) => v == null ? 'Vui lòng chọn kho' : null,
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, stack) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // Notes text field
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Ghi chú kiểm kê',
                    hintText: 'Nhập lý do kiểm kê hoặc chi tiết...',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: c.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildProTip(c, theme, 'Mẹo: Việc chọn đúng kho giúp hệ thống hiển thị chính xác lượng tồn kho lý thuyết để so sánh với thực tế.'),
        ],
      );
    } else if (_currentStep == 1) {
      // Step 2: Items (Quantity counting list)
      return Column(
        key: const ValueKey('step_items'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sản phẩm kiểm đếm (${_items.length})',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Thêm dòng', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_items.isEmpty)
            const AppEmpty(message: 'Chưa có sản phẩm nào được chọn. Nhấp "Thêm dòng" ở trên để bắt đầu!'),

          ..._items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: c.divider.withValues(alpha: 0.5), width: 1),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: productsAsync.when(
                          data: (data) {
                            final prods = (data['items'] as List?) ?? [];
                            return DropdownButtonFormField<int>(
                              initialValue: item.productId,
                              isExpanded: true,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                              decoration: const InputDecoration(
                                labelText: 'Chọn sản phẩm *',
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: prods
                                  .map(
                                    (e) => DropdownMenuItem<int>(
                                      value: e['id'],
                                      child: Text(
                                        '${e['sku'] ?? 'N/A'} - ${e['name']}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                final selected = prods.firstWhere((e) => e['id'] == v, orElse: () => null);
                                setState(() {
                                  item.productId = v;
                                  item.sku = selected?['sku'] ?? 'N/A';
                                  item.name = selected?['name'] ?? 'SP';
                                  item.systemQty = stockMap[v] ?? 0;
                                  item.actualQty = item.systemQty;
                                  item.actualQtyCtrl.text = item.actualQty.toString();
                                });
                              },
                              validator: (v) => v == null ? 'Bắt buộc' : null,
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (e, stack) => const Text(
                            'Lỗi tải sản phẩm',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                        onPressed: () => _removeItem(idx),
                        tooltip: 'Xóa dòng này',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  
                  // Triple visual balance counters
                  Row(
                    children: [
                      // System Qty
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hệ thống', style: TextStyle(fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text('${item.systemQty}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Actual Qty input
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: TextFormField(
                            controller: item.actualQtyCtrl,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: 'Thực tế',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: c.divider),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                              ),
                            ),
                            onChanged: (v) => setState(() {
                              item.actualQty = int.tryParse(v) ?? 0;
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Discrepancy (Diff)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: item.diff == 0
                                ? c.surface
                                : (item.diff > 0
                                    ? AppColors.success.withValues(alpha: 0.1)
                                    : AppColors.danger.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Chênh lệch', style: TextStyle(fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text(
                                '${item.diff > 0 ? '+' : ''}${item.diff}', 
                                style: GoogleFonts.outfit(
                                  fontSize: 15, 
                                  fontWeight: FontWeight.bold, 
                                  color: item.diff == 0
                                      ? c.textPrimary
                                      : (item.diff > 0 ? AppColors.success : AppColors.danger)
                                )
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      );
    } else {
      // Step 3: Review & Summary (Confirm audit ledger)
      final totalDiff = _items.fold<int>(0, (sum, item) => sum + item.diff.abs());
      final totalActual = _items.fold<int>(0, (sum, item) => sum + item.actualQty);
      final totalSystem = _items.fold<int>(0, (sum, item) => sum + item.systemQty);

      return Column(
        key: const ValueKey('step_confirm'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xác nhận bảng kiểm kê',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
          const SizedBox(height: 12),
          
          // General info recap card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.divider.withValues(alpha: 0.5), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _confirmRecapRow('Kho kiểm kê', _warehouseName, c, isBold: true),
                Divider(color: c.divider.withValues(alpha: 0.5), height: 16),
                _confirmRecapRow('Ghi chú', _notesCtrl.text.isEmpty ? '(Không có)' : _notesCtrl.text, c),
                Divider(color: c.divider.withValues(alpha: 0.5), height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tổng dòng sản phẩm', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    Text('${_items.length}', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                Divider(color: c.divider.withValues(alpha: 0.5), height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tổng tồn trên hệ thống', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    Text('$totalSystem', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                Divider(color: c.divider.withValues(alpha: 0.5), height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tổng tồn thực tế kiểm', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    Text('$totalActual', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                Divider(color: c.divider.withValues(alpha: 0.5), height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tổng chênh lệch lệch kiểm', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: totalDiff == 0 
                            ? AppColors.success.withValues(alpha: 0.1) 
                            : AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$totalDiff sản phẩm', 
                        style: GoogleFonts.outfit(
                          fontSize: 12, 
                          fontWeight: FontWeight.bold,
                          color: totalDiff == 0 ? AppColors.success : AppColors.danger,
                        )
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          Text(
            'Danh sách kiểm kê đối chiếu',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
          const SizedBox(height: 10),
          
          ..._items.map((item) {
            final isDiff = item.diff != 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDiff 
                      ? (item.diff > 0 ? AppColors.success.withValues(alpha: 0.3) : AppColors.danger.withValues(alpha: 0.3))
                      : c.divider.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name, 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SKU: ${item.sku}', 
                          style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w500)
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Hệ thống: ${item.systemQty} → Thực tế: ${item.actualQty}', 
                        style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w500)
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Chênh lệch: ${item.diff > 0 ? '+' : ''}${item.diff}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: item.diff == 0 
                              ? c.textPrimary 
                              : (item.diff > 0 ? AppColors.success : AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      );
    }
  }

  Widget _confirmRecapRow(String label, String value, AppThemeColors c, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13, 
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: c.textPrimary
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildProTip(AppThemeColors c, ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: theme.colorScheme.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(AppThemeColors c, ThemeData theme) {
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == 2;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(
          top: BorderSide(color: c.divider.withValues(alpha: 0.5), width: 1),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (!isFirstStep) ...[
              OutlinedButton.icon(
                onPressed: _prevStep,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                label: Text('Quay lại', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.colorScheme.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saving ? null : (isLastStep ? _save : _nextStep),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Icon(
                        isLastStep ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded, 
                        size: 16
                      ),
                label: Text(
                  _saving 
                      ? 'ĐANG LƯU PHIẾU...' 
                      : (isLastStep ? 'HOÀN THÀNH & LƯU' : 'TIẾP TỤC'),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLastStep ? AppColors.success : theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shadowColor: (isLastStep ? AppColors.success : theme.colorScheme.primary).withValues(alpha: 0.25),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
