import '../../../core/assets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/search_text.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_navigation_back_button.dart';

class _StkItem {
  int? productId;
  String sku = '';
  String name = '';
  String unit = '';
  int systemQty = 0;
  int actualQty = 0;
  TextEditingController actualQtyCtrl = TextEditingController(text: '0');

  _StkItem();

  void dispose() {
    actualQtyCtrl.dispose();
  }

  int get diff => actualQty - systemQty;

  void setActual(int val) {
    actualQty = val < 0 ? 0 : val;
    actualQtyCtrl.text = actualQty.toString();
  }

  void increment() => setActual(actualQty + 1);

  void decrement() {
    if (actualQty > 0) {
      setActual(actualQty - 1);
    }
  }

  void matchSystem() => setActual(systemQty);
}

class StockTakeFormScreen extends ConsumerStatefulWidget {
  const StockTakeFormScreen({super.key});

  @override
  ConsumerState<StockTakeFormScreen> createState() =>
      _StockTakeFormScreenState();
}

class _StockTakeFormScreenState extends ConsumerState<StockTakeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  final _searchFilterCtrl = TextEditingController();

  int? _warehouseId;
  String _warehouseName = '';
  final List<_StkItem> _items = [];
  bool _saving = false;
  int _currentStep = 0; // 0 = Info, 1 = Items, 2 = Confirm
  String _filterDiff = 'ALL'; // 'ALL', 'DIFF', 'OVER', 'SHORT', 'MATCH'
  String _searchFilterText = '';

  @override
  void dispose() {
    _notesCtrl.dispose();
    _searchFilterCtrl.dispose();
    for (var i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  void _addItem([_StkItem? item]) {
    setState(() => _items.add(item ?? _StkItem()));
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  void _matchAll() {
    if (_items.isEmpty) return;
    setState(() {
      for (var item in _items) {
        item.matchSystem();
      }
    });
    ToastService.showSuccess(
      'Đã đặt số lượng thực tế bằng hệ thống cho tất cả sản phẩm!',
    );
  }

  Future<void> _clearAll() async {
    if (_items.isEmpty) return;
    final confirm = await AppConfirmModal.show(
      context,
      title: 'Xóa toàn bộ dòng',
      message:
          'Bạn có chắc chắn muốn xóa tất cả sản phẩm trong phiếu kiểm kê hiện tại?',
      confirmText: 'Xóa tất cả',
      cancelText: 'Giữ lại',
      isDestructive: true,
    );
    if (confirm == true) {
      setState(() {
        for (var i in _items) {
          i.dispose();
        }
        _items.clear();
      });
      ToastService.showInfo('Đã xóa tất cả sản phẩm');
    }
  }

  void _loadAllWarehouseProducts(
    List<dynamic> allProducts,
    Map<int, int> stockMap,
  ) {
    final existingIds = _items.map((i) => i.productId).toSet();
    int added = 0;
    for (var p in allProducts) {
      final pid = p['id'] as int?;
      if (pid != null && !existingIds.contains(pid)) {
        final sysQty = stockMap[pid] ?? 0;
        final item = _StkItem()
          ..productId = pid
          ..sku = p['sku'] ?? 'N/A'
          ..name = p['name'] ?? 'SP'
          ..unit = p['unit'] ?? ''
          ..systemQty = sysQty
          ..actualQty = sysQty
          ..actualQtyCtrl.text = sysQty.toString();
        _items.add(item);
        added++;
      }
    }
    if (added > 0) {
      setState(() {});
      ToastService.showSuccess('Đã nạp $added sản phẩm vào phiếu kiểm kê');
    } else {
      ToastService.showInfo('Tất cả sản phẩm đã có trong phiếu kiểm kê');
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      final warehousesAsync = ref.read(warehousesProvider);
      final whList = warehousesAsync.value;
      if (_warehouseId == null && whList != null && whList.isNotEmpty) {
        _warehouseId = whList.first['id'] as int?;
        _warehouseName = whList.first['name']?.toString() ?? '';
      }
      final hasWarehouses = (whList?.isNotEmpty ?? false);
      if (_warehouseId == null && hasWarehouses) {
        ToastService.showError('Vui lòng chọn kho kiểm kê trước khi tiếp tục!');
        return;
      }
      if (!hasWarehouses) {
        _warehouseId = null; // Proceed with null if no warehouses
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_items.isEmpty) {
        ToastService.showError('Vui lòng thêm ít nhất 1 sản phẩm để kiểm kê!');
        return;
      }
      for (var i in _items) {
        if (i.productId == null) {
          ToastService.showError('Vui lòng chọn sản phẩm cho tất cả các dòng!');
          return;
        }
        if (i.actualQty < 0) {
          ToastService.showError(
            'Số lượng kiểm kê thực tế không thể là số âm!',
          );
          return;
        }
      }
      final selectedProductIds = _items.map((item) => item.productId).toList();
      if (selectedProductIds.toSet().length != selectedProductIds.length) {
        ToastService.showError(
          'Mỗi sản phẩm chỉ được xuất hiện một lần trong phiếu kiểm kê.',
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
    final bool? confirm = await AppConfirmModal.show(
      context,
      title: 'Xác nhận lưu',
      message:
          'Bạn có chắc chắn muốn lưu phiếu kiểm kê nháp? Tồn kho chỉ thay đổi sau khi phiếu được hoàn tất.',
      confirmText: 'Lưu',
      cancelText: 'Hủy',
    );

    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      final payload = {
        'warehouseId': _warehouseId,
        'stockTakeDate': DateTime.now().toIso8601String(),
        'notes': _notesCtrl.text.trim(),
        'items': _items
            .map((i) => {'productId': i.productId, 'actualQty': i.actualQty})
            .toList(),
      };

      await ref.read(inventoryRepoProvider).createStockTake(payload);
      ref.invalidate(stockTakesProvider);
      ref.invalidate(stockProvider);
      ref.invalidate(stockPageProvider);
      ref.invalidate(lowStockProvider);
      ref.invalidate(inventoryMovementsProvider);

      if (mounted) {
        ToastService.showSuccess('Lưu phiếu kiểm kê thành công!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError(
          'Không thể lưu phiếu kiểm kê. Vui lòng thử lại sau.',
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
    final productsAsync = ref.watch(productOptionsProvider);
    // Auto select first warehouse if not set
    warehousesAsync.whenData((data) {
      if (_warehouseId == null && data.isNotEmpty) {
        _warehouseId = data.first['id'] as int?;
        _warehouseName = data.first['name']?.toString() ?? '';
      }
    });

    final stockAsync = ref.watch(stockProvider(_warehouseId));

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
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'Phiếu Kiểm Kê Kho',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Form(
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
                      child: _buildCurrentStepView(
                        c,
                        theme,
                        warehousesAsync,
                        productsAsync,
                        stockMap,
                      ),
                    ),
                  ),
                ),

                // Bottom Action Navigation Bar
                _buildBottomActionBar(c, theme),
              ],
            ),
          ),
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
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: c.divider.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chọn Kho dropdown
                warehousesAsync.when(
                  data: (data) {
                    if (data.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Chưa có kho hàng nào được tạo.\n(Hệ thống sẽ lưu vào kho mặc định)',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      );
                    }
                    return DropdownButtonFormField<int>(
                      initialValue:
                          _warehouseId ??
                          (data.isNotEmpty ? data.first['id'] as int? : null),
                      isExpanded: true,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Kho kiểm kê *',
                        prefixIcon: AppIcon(
                          Icons.warehouse_rounded,
                          color: theme.colorScheme.primary,
                        ),
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
                          final wh = data
                              .where((e) => e['id'] == v)
                              .firstOrNull;
                          if (wh != null) _warehouseName = wh['name'] ?? '';
                        });
                      },
                      validator: (v) => v == null && data.isNotEmpty
                          ? 'Vui lòng chọn kho'
                          : null,
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
          _buildProTip(
            c,
            theme,
            'Mẹo: Việc chọn đúng kho giúp hệ thống hiển thị chính xác lượng tồn kho lý thuyết để so sánh với thực tế.',
          ),
        ],
      );
    } else if (_currentStep == 1) {
      // Step 2: Items (Quantity counting list & visual audit grid)
      return _buildItemsStep(c, theme, productsAsync, stockMap);
    } else {
      // Step 3: Review & Summary (Confirm audit ledger)
      return _buildConfirmStep(c, theme);
    }
  }

  Widget _buildItemsStep(
    AppThemeColors c,
    ThemeData theme,
    AsyncValue<Map<String, dynamic>> productsAsync,
    Map<int, int> stockMap,
  ) {
    final prods = (productsAsync.value?['items'] as List?) ?? [];
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;

    // Filter items based on _filterDiff and _searchFilterText
    final filteredEntries = _items.asMap().entries.where((entry) {
      final item = entry.value;

      // Filter by diff status
      if (_filterDiff == 'DIFF' && item.diff == 0) return false;
      if (_filterDiff == 'OVER' && item.diff <= 0) return false;
      if (_filterDiff == 'SHORT' && item.diff >= 0) return false;
      if (_filterDiff == 'MATCH' && item.diff != 0) return false;

      // Filter by search query
      if (_searchFilterText.isNotEmpty) {
        final q = foldSearchText(_searchFilterText);
        final nameF = foldSearchText(item.name);
        final skuF = foldSearchText(item.sku);
        if (!nameF.contains(q) && !skuF.contains(q)) return false;
      }

      return true;
    }).toList();

    return Column(
      key: const ValueKey('step_items'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. KPI Summary Bar (Thanh thống kê tổng quan trực quan)
        _buildSummaryKpiBar(c, theme),
        const SizedBox(height: 16),

        // 2. Toolbar & Action Bar (Thêm dòng, Nạp toàn bộ kho, Khớp tất cả, Lọc)
        _buildItemsToolbar(c, theme, prods, stockMap),
        const SizedBox(height: 14),

        // 3. Main Content: Table on Desktop or Cards on Mobile
        if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.divider.withValues(alpha: 0.6)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: AppIcon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chưa có sản phẩm nào trong phiếu kiểm kê',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bấm "+ Thêm dòng" để chọn từng sản phẩm hoặc bấm "Nạp toàn bộ SP kho" để kiểm nhanh cả kho.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _openProductPickerModal(
                        context: context,
                        allProducts: prods,
                        stockMap: stockMap,
                      ),
                      icon: const AppIcon(Icons.search_rounded, size: 18),
                      label: const Text('Tìm & chọn sản phẩm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    if (prods.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () =>
                            _loadAllWarehouseProducts(prods, stockMap),
                        icon: const AppIcon(
                          Icons.playlist_add_rounded,
                          size: 18,
                        ),
                        label: const Text('Nạp toàn bộ SP có trong kho'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          )
        else if (filteredEntries.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.divider),
            ),
            child: Center(
              child: Column(
                children: [
                  AppIcon(
                    Icons.filter_alt_off_outlined,
                    size: 36,
                    color: c.textSecondary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Không có sản phẩm nào phù hợp bộ lọc hiện tại',
                    style: TextStyle(
                      fontSize: 14,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterDiff = 'ALL';
                        _searchFilterCtrl.clear();
                        _searchFilterText = '';
                      });
                    },
                    child: const Text('Xóa bộ lọc'),
                  ),
                ],
              ),
            ),
          )
        else if (isDesktop)
          _buildDesktopItemsTable(c, theme, filteredEntries, prods, stockMap)
        else
          _buildMobileItemsCards(c, theme, filteredEntries, prods, stockMap),
      ],
    );
  }

  Widget _buildSummaryKpiBar(AppThemeColors c, ThemeData theme) {
    final validItems = _items.where((i) => i.productId != null).toList();
    final totalCount = _items.length;
    final matchCount = validItems.where((i) => i.diff == 0).length;
    final overItems = validItems.where((i) => i.diff > 0).toList();
    final shortItems = validItems.where((i) => i.diff < 0).toList();
    final overCount = overItems.length;
    final shortCount = shortItems.length;
    final totalOverQty = overItems.fold<int>(0, (s, i) => s + i.diff);
    final totalShortQty = shortItems.fold<int>(0, (s, i) => s + i.diff.abs());

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 640;
        final kpiChildren = [
          _buildKpiCard(
            c: c,
            icon: Icons.inventory_2_outlined,
            iconColor: theme.colorScheme.primary,
            title: 'Tổng mã kiểm',
            value: '$totalCount',
            subText: 'Mặt hàng trong phiếu',
            isActive: _filterDiff == 'ALL',
            onTap: () => setState(() => _filterDiff = 'ALL'),
          ),
          _buildKpiCard(
            c: c,
            icon: Icons.check_circle_outline_rounded,
            iconColor: c.textPrimary,
            title: 'Khớp số lượng',
            value: '$matchCount',
            subText: 'Không lệch tồn',
            badgeText: matchCount > 0 ? 'Khớp' : null,
            badgeColor: c.divider,
            isActive: _filterDiff == 'MATCH',
            onTap: () => setState(() => _filterDiff = 'MATCH'),
          ),
          _buildKpiCard(
            c: c,
            icon: Icons.arrow_upward_rounded,
            iconColor: AppColors.success,
            title: 'Lệch thừa (+)',
            value: '$overCount',
            subText: overCount > 0 ? 'Thực tế thừa $totalOverQty' : 'Không có',
            badgeText: totalOverQty > 0 ? '+$totalOverQty' : null,
            badgeColor: AppColors.success,
            isActive: _filterDiff == 'OVER',
            onTap: () => setState(() => _filterDiff = 'OVER'),
          ),
          _buildKpiCard(
            c: c,
            icon: Icons.arrow_downward_rounded,
            iconColor: AppColors.danger,
            title: 'Lệch thiếu (-)',
            value: '$shortCount',
            subText: shortCount > 0
                ? 'Thực tế thiếu $totalShortQty'
                : 'Không có',
            badgeText: totalShortQty > 0 ? '-$totalShortQty' : null,
            badgeColor: AppColors.danger,
            isActive: _filterDiff == 'SHORT',
            onTap: () => setState(() => _filterDiff = 'SHORT'),
          ),
        ];

        if (isWide) {
          return Row(
            children: [
              for (int i = 0; i < kpiChildren.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: kpiChildren[i]),
              ],
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: kpiChildren[0]),
                const SizedBox(width: 10),
                Expanded(child: kpiChildren[1]),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: kpiChildren[2]),
                const SizedBox(width: 10),
                Expanded(child: kpiChildren[3]),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required AppThemeColors c,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subText,
    String? badgeText,
    Color? badgeColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive ? iconColor : c.divider.withValues(alpha: 0.6),
              width: isActive ? 1.8 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AppIcon(icon, size: 16, color: iconColor),
                  ),
                  if (badgeText != null && badgeColor != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsToolbar(
    AppThemeColors c,
    ThemeData theme,
    List<dynamic> prods,
    Map<int, int> stockMap,
  ) {
    final validItems = _items.where((i) => i.productId != null).toList();
    final diffCount = validItems.where((i) => i.diff != 0).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Danh sách kiểm đếm (${_items.length})',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              // Quick action: Tìm SP để thêm
              ElevatedButton.icon(
                onPressed: () => _openProductPickerModal(
                  context: context,
                  allProducts: prods,
                  stockMap: stockMap,
                ),
                icon: const AppIcon(Icons.add_rounded, size: 16),
                label: const Text('Thêm SP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 8),

              // More quick options dropdown menu
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.divider.withValues(alpha: 0.8)),
                  ),
                  child: AppIcon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: c.textPrimary,
                  ),
                ),
                tooltip: 'Thao tác nâng cao',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'add_row',
                    child: const Row(
                      children: [
                        AppIcon(Icons.add_box_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Thêm 1 dòng trống'),
                      ],
                    ),
                  ),
                  if (prods.isNotEmpty)
                    PopupMenuItem(
                      value: 'load_all',
                      child: const Row(
                        children: [
                          AppIcon(Icons.playlist_add_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Nạp tất cả SP có trong kho'),
                        ],
                      ),
                    ),
                  if (_items.isNotEmpty) ...[
                    PopupMenuItem(
                      value: 'match_all',
                      child: const Row(
                        children: [
                          AppIcon(
                            Icons.done_all_rounded,
                            size: 18,
                            color: AppColors.success,
                          ),
                          SizedBox(width: 10),
                          Text('Khớp tất cả theo hệ thống'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'clear_all',
                      child: const Row(
                        children: [
                          AppIcon(
                            Icons.delete_sweep_outlined,
                            size: 18,
                            color: AppColors.danger,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Xóa toàn bộ dòng',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                onSelected: (val) {
                  if (val == 'add_row') _addItem();
                  if (val == 'load_all') {
                    _loadAllWarehouseProducts(prods, stockMap);
                  }
                  if (val == 'match_all') _matchAll();
                  if (val == 'clear_all') _clearAll();
                },
              ),
            ],
          ),

          if (_items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: c.divider.withValues(alpha: 0.5)),
            const SizedBox(height: 10),

            // Search in items field + Filter chips
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchFilterCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Tìm nhanh tên hoặc SKU trong phiếu...',
                        hintStyle: TextStyle(fontSize: 12, color: c.textMuted),
                        prefixIcon: const AppIcon(Icons.search, size: 16),
                        suffixIcon: _searchFilterText.isNotEmpty
                            ? IconButton(
                                icon: const AppIcon(Icons.clear, size: 14),
                                onPressed: () {
                                  setState(() {
                                    _searchFilterCtrl.clear();
                                    _searchFilterText = '';
                                  });
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0,
                        ),
                        filled: true,
                        fillColor: c.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => setState(() => _searchFilterText = v),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filter chip dropdown or fast toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _filterDiff != 'ALL'
                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                        : c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _filterDiff != 'ALL'
                          ? theme.colorScheme.primary
                          : c.divider,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterDiff,
                      icon: const AppIcon(Icons.filter_list_rounded, size: 16),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _filterDiff != 'ALL'
                            ? theme.colorScheme.primary
                            : c.textPrimary,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'ALL',
                          child: Text('Tất cả (${_items.length})'),
                        ),
                        DropdownMenuItem(
                          value: 'DIFF',
                          child: Text('Có chênh lệch ($diffCount)'),
                        ),
                        const DropdownMenuItem(
                          value: 'OVER',
                          child: Text('Lệch thừa (+)'),
                        ),
                        const DropdownMenuItem(
                          value: 'SHORT',
                          child: Text('Lệch thiếu (-)'),
                        ),
                        const DropdownMenuItem(
                          value: 'MATCH',
                          child: Text('Khớp (0)'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _filterDiff = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopItemsTable(
    AppThemeColors c,
    ThemeData theme,
    List<MapEntry<int, _StkItem>> entries,
    List<dynamic> prods,
    Map<int, int> stockMap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.divider.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(
                bottom: BorderSide(
                  color: c.divider.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    'STT',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: c.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    'SẢN PHẨM & MÃ SKU',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    'ĐVT',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: c.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'TỒN SỔ SÁCH',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: c.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 220,
                  child: Text(
                    'THỰC TẾ KIỂM ĐẾM',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: c.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: Text(
                    'CHÊNH LỆCH',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: c.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    'XÓA',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: c.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: c.divider.withValues(alpha: 0.5)),
            itemBuilder: (context, i) {
              final idx = entries[i].key;
              final item = entries[i].value;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // STT
                    SizedBox(
                      width: 44,
                      child: Text(
                        '#${idx + 1}',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: c.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Product Name & SKU
                    Expanded(
                      flex: 5,
                      child: item.productId == null
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () => _openProductPickerModal(
                                  context: context,
                                  allProducts: prods,
                                  stockMap: stockMap,
                                  targetItem: item,
                                ),
                                icon: const AppIcon(
                                  Icons.search_rounded,
                                  size: 16,
                                ),
                                label: const Text('Bấm để chọn sản phẩm *'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: GoogleFonts.manrope(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: c.textPrimary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _openProductPickerModal(
                                        context: context,
                                        allProducts: prods,
                                        stockMap: stockMap,
                                        targetItem: item,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Tooltip(
                                          message: 'Đổi sản phẩm',
                                          child: AppIcon(
                                            Icons.swap_horiz_rounded,
                                            size: 16,
                                            color: c.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.surface,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: c.divider.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    item.sku,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: c.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),

                    // Unit
                    SizedBox(
                      width: 70,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.unit.isNotEmpty ? item.unit : 'SP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // System Quantity
                    SizedBox(
                      width: 100,
                      child: Text(
                        NumberFormat.decimalPattern(
                          'vi_VN',
                        ).format(item.systemQty),
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Actual Quantity Stepper
                    SizedBox(
                      width: 220,
                      child: _buildActualStepper(c, theme, item),
                    ),

                    // Discrepancy Badge
                    SizedBox(
                      width: 130,
                      child: Center(child: _buildDiffBadge(c, item)),
                    ),

                    // Remove Button
                    SizedBox(
                      width: 44,
                      child: Center(
                        child: IconButton(
                          icon: const AppIcon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.danger,
                          ),
                          onPressed: () => _removeItem(idx),
                          tooltip: 'Xóa dòng này',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileItemsCards(
    AppThemeColors c,
    ThemeData theme,
    List<MapEntry<int, _StkItem>> entries,
    List<dynamic> prods,
    Map<int, int> stockMap,
  ) {
    return Column(
      children: entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: item.diff == 0
                  ? c.divider.withValues(alpha: 0.6)
                  : (item.diff > 0
                        ? AppColors.success.withValues(alpha: 0.3)
                        : AppColors.danger.withValues(alpha: 0.3)),
              width: item.diff != 0 ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Top: Product Info & Delete
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${idx + 1}',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: item.productId == null
                        ? OutlinedButton.icon(
                            onPressed: () => _openProductPickerModal(
                              context: context,
                              allProducts: prods,
                              stockMap: stockMap,
                              targetItem: item,
                            ),
                            icon: const AppIcon(Icons.search_rounded, size: 16),
                            label: const Text('Bấm chọn sản phẩm *'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.sku} • ĐVT: ${item.unit.isNotEmpty ? item.unit : 'SP'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),
                  IconButton(
                    icon: const AppIcon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.danger,
                    ),
                    onPressed: () => _removeItem(idx),
                    tooltip: 'Xóa',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: c.divider.withValues(alpha: 0.5)),
              const SizedBox(height: 10),

              // Card Middle: Side-by-side System vs Discrepancy
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tồn sổ sách',
                            style: TextStyle(
                              fontSize: 10,
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${NumberFormat.decimalPattern('vi_VN').format(item.systemQty)} ${item.unit}',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: item.diff == 0
                            ? c.surface
                            : (item.diff > 0
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.danger.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chênh lệch',
                            style: TextStyle(
                              fontSize: 10,
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.diff == 0
                                ? 'Khớp tồn (0)'
                                : (item.diff > 0
                                      ? '+${item.diff} (Thừa)'
                                      : '${item.diff} (Thiếu)'),
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: item.diff == 0
                                  ? c.textPrimary
                                  : (item.diff > 0
                                        ? AppColors.success
                                        : AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Card Bottom: Stepper Actual
              Row(
                children: [
                  Text(
                    'Thực tế:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _buildActualStepper(c, theme, item)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActualStepper(AppThemeColors c, ThemeData theme, _StkItem item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Button Minus
        IconButton(
          onPressed: () => setState(() => item.decrement()),
          icon: const AppIcon(Icons.remove_rounded, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: c.surface,
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
            maximumSize: const Size(32, 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: c.divider.withValues(alpha: 0.8)),
            ),
          ),
          tooltip: 'Giảm 1',
        ),
        const SizedBox(width: 4),

        // Text input field
        SizedBox(
          width: 56,
          height: 32,
          child: TextFormField(
            controller: item.actualQtyCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 2,
                vertical: 6,
              ),
              filled: true,
              fillColor: c.surface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: c.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (v) {
              setState(() {
                item.actualQty = int.tryParse(v) ?? 0;
              });
            },
          ),
        ),
        const SizedBox(width: 4),

        // Button Plus
        IconButton(
          onPressed: () => setState(() => item.increment()),
          icon: const AppIcon(Icons.add_rounded, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: c.surface,
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
            maximumSize: const Size(32, 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: c.divider.withValues(alpha: 0.8)),
            ),
          ),
          tooltip: 'Tăng 1',
        ),
        const SizedBox(width: 4),

        // Match System Button
        IconButton(
          onPressed: () => setState(() => item.matchSystem()),
          icon: const AppIcon(Icons.done_all_rounded, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: item.diff == 0
                ? c.surface
                : theme.colorScheme.primary.withValues(alpha: 0.1),
            foregroundColor: item.diff == 0
                ? c.textSecondary
                : theme.colorScheme.primary,
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
            maximumSize: const Size(32, 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: item.diff == 0
                    ? c.divider
                    : theme.colorScheme.primary.withValues(alpha: 0.4),
              ),
            ),
          ),
          tooltip: 'Khớp số sổ sách (${item.systemQty})',
        ),
      ],
    );
  }

  Widget _buildDiffBadge(AppThemeColors c, _StkItem item) {
    if (item.diff == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.divider.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              Icons.check_circle_outline_rounded,
              size: 13,
              color: c.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              '0 Khớp',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final isOver = item.diff > 0;
    final color = isOver ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            isOver ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${isOver ? '+' : ''}${item.diff} ${isOver ? 'Thừa' : 'Thiếu'}',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep(AppThemeColors c, ThemeData theme) {
    final validItems = _items.where((i) => i.productId != null).toList();
    final totalActual = validItems.fold<int>(0, (s, i) => s + i.actualQty);
    final totalSystem = validItems.fold<int>(0, (s, i) => s + i.systemQty);
    final overItems = validItems.where((i) => i.diff > 0).toList();
    final shortItems = validItems.where((i) => i.diff < 0).toList();
    final matchItems = validItems.where((i) => i.diff == 0).toList();
    final totalOverQty = overItems.fold<int>(0, (s, i) => s + i.diff);
    final totalShortQty = shortItems.fold<int>(0, (s, i) => s + i.diff.abs());

    return Column(
      key: const ValueKey('step_confirm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Biên bản đối soát kiểm kê kho',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // 1. General Info & Summary
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: c.divider.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _confirmRecapRow('Kho kiểm kê', _warehouseName, c, isBold: true),
              Divider(color: c.divider.withValues(alpha: 0.5), height: 16),
              _confirmRecapRow(
                'Ghi chú',
                _notesCtrl.text.isEmpty ? '(Không có)' : _notesCtrl.text,
                c,
              ),
              Divider(color: c.divider.withValues(alpha: 0.5), height: 16),
              _confirmRecapRow(
                'Tổng dòng sản phẩm kiểm kê',
                '${validItems.length} mặt hàng',
                c,
              ),
              Divider(color: c.divider.withValues(alpha: 0.5), height: 16),
              _confirmRecapRow(
                'Tổng lượng tồn sổ sách',
                NumberFormat.decimalPattern('vi_VN').format(totalSystem),
                c,
              ),
              Divider(color: c.divider.withValues(alpha: 0.5), height: 16),
              _confirmRecapRow(
                'Tổng lượng tồn thực tế',
                NumberFormat.decimalPattern('vi_VN').format(totalActual),
                c,
                isBold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Three Discrepancy KPI Cards
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.divider),
                ),
                child: Column(
                  children: [
                    Text(
                      'Khớp số lượng',
                      style: TextStyle(fontSize: 11, color: c.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${matchItems.length}',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      'mặt hàng',
                      style: TextStyle(fontSize: 10, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Lệch thừa (+)',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+$totalOverQty',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                    Text(
                      '${overItems.length} mặt hàng',
                      style: TextStyle(fontSize: 10, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Lệch thiếu (-)',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '-$totalShortQty',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                      ),
                    ),
                    Text(
                      '${shortItems.length} mặt hàng',
                      style: TextStyle(fontSize: 10, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        Text(
          'Danh sách chi tiết đối chiếu',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        // 3. Item List Review
        ...validItems.map((item) {
          final isDiff = item.diff != 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDiff
                    ? (item.diff > 0
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.danger.withValues(alpha: 0.3))
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SKU: ${item.sku} • ĐVT: ${item.unit.isNotEmpty ? item.unit : 'SP'}',
                        style: TextStyle(fontSize: 11, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Sổ sách: ${item.systemQty} → Thực tế: ${item.actualQty}',
                      style: TextStyle(
                        fontSize: 11,
                        color: c.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.diff == 0
                          ? 'Khớp (0)'
                          : (item.diff > 0
                                ? '+${item.diff} (Thừa)'
                                : '${item.diff} (Thiếu)'),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: item.diff == 0
                            ? c.textPrimary
                            : (item.diff > 0
                                  ? AppColors.success
                                  : AppColors.danger),
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

  void _openProductPickerModal({
    required BuildContext context,
    required List<dynamic> allProducts,
    required Map<int, int> stockMap,
    _StkItem? targetItem,
  }) {
    final c = AppThemeColors.of(context);
    final existingIds = _items.map((i) => i.productId).toSet();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _ProductPickerSheet(
          allProducts: allProducts,
          stockMap: stockMap,
          existingIds: existingIds,
          onSelect: (selectedProduct) {
            Navigator.of(ctx).pop();
            final pid = selectedProduct['id'] as int;
            setState(() {
              final item = targetItem ?? _StkItem();
              item.productId = pid;
              item.sku = selectedProduct['sku'] ?? 'N/A';
              item.name = selectedProduct['name'] ?? 'SP';
              item.unit = selectedProduct['unit'] ?? '';
              item.systemQty = stockMap[pid] ?? 0;
              item.actualQty = item.systemQty;
              item.actualQtyCtrl.text = item.actualQty.toString();
              if (targetItem == null) {
                _items.add(item);
              }
            });
          },
        );
      },
    );
  }

  Widget _confirmRecapRow(
    String label,
    String value,
    AppThemeColors c, {
    bool isBold = false,
  }) {
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
              color: c.textPrimary,
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
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          AppIcon(
            Icons.lightbulb_outline_rounded,
            color: theme.colorScheme.primary,
            size: 18,
          ),
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
                icon: const AppIcon(Icons.arrow_back_ios_new_rounded, size: 14),
                label: Text(
                  'Quay lại',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.colorScheme.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : AppIcon(
                        isLastStep
                            ? Icons.check_circle_rounded
                            : Icons.arrow_forward_ios_rounded,
                        size: 16,
                      ),
                label: Text(
                  _saving
                      ? 'ĐANG LƯU PHIẾU...'
                      : (isLastStep ? 'HOÀN THÀNH & LƯU' : 'TIẾP TỤC'),
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLastStep
                      ? AppColors.success
                      : theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shadowColor:
                      (isLastStep
                              ? AppColors.success
                              : theme.colorScheme.primary)
                          .withValues(alpha: 0.25),
                  elevation: 2,
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

class _ProductPickerSheet extends StatefulWidget {
  final List<dynamic> allProducts;
  final Map<int, int> stockMap;
  final Set<int?> existingIds;
  final ValueChanged<dynamic> onSelect;

  const _ProductPickerSheet({
    required this.allProducts,
    required this.stockMap,
    required this.existingIds,
    required this.onSelect,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    final filtered = widget.allProducts.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = foldSearchText(_searchQuery);
      final name = foldSearchText(p['name']);
      final sku = foldSearchText(p['sku']);
      return name.contains(q) || sku.contains(q);
    }).toList();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: AppIcon(
                    Icons.inventory_2_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Chọn sản phẩm kiểm kê (${widget.allProducts.length})',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const AppIcon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên hoặc mã SKU...',
                prefixIcon: const AppIcon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const AppIcon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: c.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.divider),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: c.divider.withValues(alpha: 0.5)),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Không tìm thấy sản phẩm nào phù hợp',
                        style: TextStyle(color: c.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, idx) {
                      final p = filtered[idx];
                      final pid = p['id'] as int?;
                      final isSelected = widget.existingIds.contains(pid);
                      final stock = widget.stockMap[pid] ?? 0;
                      final unit = p['unit']?.toString() ?? '';

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isSelected ? null : () => widget.onSelect(p),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? c.surface.withValues(alpha: 0.5)
                                  : c.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? c.divider.withValues(alpha: 0.3)
                                    : c.divider.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? c.divider.withValues(alpha: 0.2)
                                        : theme.colorScheme.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: AppIcon(
                                    Icons.inventory_2_outlined,
                                    size: 18,
                                    color: isSelected
                                        ? c.textMuted
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['name']?.toString() ?? '',
                                        style: GoogleFonts.manrope(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? c.textMuted
                                              : c.textPrimary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'SKU: ${p['sku'] ?? 'N/A'}${unit.isNotEmpty ? ' • ĐVT: $unit' : ''}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: c.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Tồn: $stock ${unit.isNotEmpty ? unit : ''}',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? c.textMuted
                                            : c.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: c.surface,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Đã thêm',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: c.textMuted,
                                          ),
                                        ),
                                      )
                                    else
                                      Text(
                                        'Chọn',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
