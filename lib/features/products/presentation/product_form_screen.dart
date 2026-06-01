import 'package:flutter/material.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/inline_tag_picker.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/tag_provider.dart';
import '../../../core/network/api_client.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? product; // null = create, non-null = edit
  const ProductFormScreen({super.key, this.product});
  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _sellPriceCtrl = TextEditingController();
  final _wholesalePriceCtrl = TextEditingController();
  final _currentStockCtrl = TextEditingController();
  final _minStockCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagInputCtrl = TextEditingController();

  List<String> _tags = [];
  bool _saving = false;
  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.product!;
      _nameCtrl.text = p['name'] ?? '';
      _skuCtrl.text = p['sku'] ?? '';
      _barcodeCtrl.text = p['barcode'] ?? '';
      _unitCtrl.text = p['unit'] ?? '';
      _costPriceCtrl.text = '${p['costPrice'] ?? p['cost_price'] ?? ''}';
      _sellPriceCtrl.text = '${p['sellingPrice'] ?? p['sellPrice'] ?? p['selling_price'] ?? p['sell_price'] ?? ''}';
      _wholesalePriceCtrl.text = '${p['wholesalePrice'] ?? p['wholesale_price'] ?? ''}';
      _currentStockCtrl.text = '${p['currentStock'] ?? p['stock'] ?? ''}';
      _minStockCtrl.text = '${p['minStock'] ?? p['min_stock'] ?? ''}';
      _descCtrl.text = p['description'] ?? '';
      
      final tagsRaw = p['tags'];
      if (tagsRaw is List) {
        _tags = tagsRaw.map((e) => e.toString()).toList();
      } else if (tagsRaw is String && tagsRaw.isNotEmpty) {
        _tags = tagsRaw.split(',').where((e) => e.trim().isNotEmpty).toList();
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(productRepoProvider);
      final name = _nameCtrl.text.trim();
      final sellingPrice = double.tryParse(_sellPriceCtrl.text.trim()) ?? 0;

      if (name.isEmpty) {
        ToastService.showSuccess('Vui lòng nhập tên sản phẩm');
        setState(() => _saving = false);
        return;
      }
      if (sellingPrice <= 0) {
        ToastService.showSuccess('Giá bán phải lớn hơn 0');
        setState(() => _saving = false);
        return;
      }

      final data = {
        'name': name,
        'sku': _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
        'barcode': _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        'unit': _unitCtrl.text.trim().isEmpty ? 'Cái' : _unitCtrl.text.trim(),
        'costPrice': double.tryParse(_costPriceCtrl.text.trim()) ?? 0,
        'sellingPrice': sellingPrice,
        'wholesalePrice': double.tryParse(_wholesalePriceCtrl.text.trim()) ?? 0,
        'currentStock': int.tryParse(_currentStockCtrl.text.trim()) ?? 0,
        'minStock': int.tryParse(_minStockCtrl.text.trim()) ?? 0,
        'description': _descCtrl.text.trim(),
        'tags': _tags,
      };
      if (_isEdit) {
        await repo.update(widget.product!['id'], data);
      } else {
        await repo.create(data);
      }
      if (!mounted) return;
      ref.invalidate(productListProvider((page: 1, search: null, tag: null)));
      ToastService.showSuccess(_isEdit ? 'Cập nhật sản phẩm thành công!' : 'Thêm sản phẩm thành công!');
      Navigator.of(context).pop(true);
      return;
    } catch (e) {
      if (context.mounted) {
        if (e is ApiException) {
          ToastService.showError(e.message);
        } else {
          ToastService.showError('Lỗi: $e');
        }
      }
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _unitCtrl.dispose();
    _costPriceCtrl.dispose();
    _sellPriceCtrl.dispose();
    _wholesalePriceCtrl.dispose();
    _currentStockCtrl.dispose();
    _minStockCtrl.dispose();
    _descCtrl.dispose();
    _tagInputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEdit ? 'Cập Nhật Sản Phẩm' : 'Thêm Sản Phẩm Mới',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image upload frame with dotted/dashed visual
              Center(
                child: Container(
                  width: double.infinity,
                  height: 125,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        ToastService.showSuccess('Tính năng tải ảnh sản phẩm sẽ khả dụng ở bản cập nhật tiếp theo!');
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_rounded,
                            size: 32,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tải ảnh sản phẩm lên (Dưới 5MB)',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hỗ trợ định dạng JPG, PNG, WEBP',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              _sectionHeader('Thông tin cơ bản', theme, c),
              const SizedBox(height: 12),
              _field(
                'Tên sản phẩm *',
                _nameCtrl,
                HugeIcons.strokeRoundedPackage,
                c,
                theme,
                validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên sản phẩm' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      'Mã SKU',
                      _skuCtrl,
                      HugeIcons.strokeRoundedTag01,
                      c,
                      theme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      'Mã vạch',
                      _barcodeCtrl,
                      HugeIcons.strokeRoundedBarCode01,
                      c,
                      theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(
                'Đơn vị tính',
                _unitCtrl,
                HugeIcons.strokeRoundedRuler,
                c,
                theme,
                hint: 'VD: Cái, Kg, Hộp, Lon',
              ),

              const SizedBox(height: 24),
              _sectionHeader('Thiết lập giá bán', theme, c),
              const SizedBox(height: 12),
              _field(
                'Giá vốn nhập hàng',
                _costPriceCtrl,
                HugeIcons.strokeRoundedCoinsDollar,
                c,
                theme,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      'Giá bán lẻ *',
                      _sellPriceCtrl,
                      HugeIcons.strokeRoundedMoney01,
                      c,
                      theme,
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Bắt buộc' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      'Giá bán sỉ',
                      _wholesalePriceCtrl,
                      HugeIcons.strokeRoundedMoney01,
                      c,
                      theme,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _sectionHeader('Cấu hình kho hàng', theme, c),
              const SizedBox(height: 12),
              _field(
                'Tồn kho hiện có',
                _currentStockCtrl,
                HugeIcons.strokeRoundedPackageSearch,
                c,
                theme,
                keyboardType: TextInputType.number,
                hint: 'Số lượng tồn kho ban đầu',
              ),
              const SizedBox(height: 12),
              _field(
                'Ngưỡng báo động tối thiểu',
                _minStockCtrl,
                HugeIcons.strokeRoundedWarehouse,
                c,
                theme,
                keyboardType: TextInputType.number,
                hint: 'Cảnh báo khi dưới mức này',
              ),

              const SizedBox(height: 24),
              _sectionHeader('Mô tả bổ sung', theme, c),
              const SizedBox(height: 12),
              _field(
                'Mô tả chi tiết sản phẩm',
                _descCtrl,
                HugeIcons.strokeRoundedTextAlignLeft,
                c,
                theme,
                maxLines: 3,
              ),

              const SizedBox(height: 24),
              _sectionHeader('Gắn nhãn (Tags)', theme, c),
              const SizedBox(height: 12),
              _buildTagEditor(c, theme),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                          color: Colors.white,
                          size: 18,
                        ),
                  label: Text(
                    _saving 
                        ? 'Đang lưu lại...' 
                        : (_isEdit ? 'Cập Nhật Sản Phẩm' : 'Thêm Sản Phẩm Mới'),
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, ThemeData theme, AppThemeColors c) {
    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedFolder01,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: c.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    dynamic icon,
    AppThemeColors c,
    ThemeData theme, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 13, color: c.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.textSecondary, fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(color: c.textMuted, fontSize: 12),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: HugeIcon(icon: icon, size: 18, color: theme.colorScheme.primary),
        ),
        filled: true,
        fillColor: c.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildTagEditor(AppThemeColors c, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Nhãn (Tags)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: c.textSecondary)),
            TextButton.icon(
              onPressed: () => _showTagPicker(c, theme),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Chọn / Thêm nhãn'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_tags.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.divider, style: BorderStyle.solid),
            ),
            child: Text('Chưa có nhãn nào được chọn', style: GoogleFonts.inter(color: c.textMuted, fontSize: 13, fontStyle: FontStyle.italic)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              return Chip(
                label: Text(tag, style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.8),
                deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white),
                onDeleted: () => setState(() => _tags.remove(tag)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                side: BorderSide.none,
              );
            }).toList(),
          ),
      ],
    );
  }

  void _showTagPicker(AppThemeColors c, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return InlineTagPicker(
          type: 'product',
          selectedTags: _tags,
          onTagsChanged: (newTags) => setState(() => _tags = newTags),
        );
      },
    );
  }
}

