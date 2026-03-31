import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/product_provider.dart';

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
  final _minStockCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

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
      _sellPriceCtrl.text = '${p['sellPrice'] ?? p['sell_price'] ?? ''}';
      _wholesalePriceCtrl.text = '${p['wholesalePrice'] ?? p['wholesale_price'] ?? ''}';
      _minStockCtrl.text = '${p['minStock'] ?? p['min_stock'] ?? ''}';
      _descCtrl.text = p['description'] ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(productRepoProvider);
      final data = {
        'name': _nameCtrl.text.trim(),
        'sku': _skuCtrl.text.trim(),
        'barcode': _barcodeCtrl.text.trim(),
        'unit': _unitCtrl.text.trim(),
        'costPrice': double.tryParse(_costPriceCtrl.text.trim()) ?? 0,
        'sellPrice': double.tryParse(_sellPriceCtrl.text.trim()) ?? 0,
        'wholesalePrice': double.tryParse(_wholesalePriceCtrl.text.trim()) ?? 0,
        'minStock': int.tryParse(_minStockCtrl.text.trim()) ?? 0,
        'description': _descCtrl.text.trim(),
      };
      if (_isEdit) {
        await repo.update(widget.product!['id'], data);
      } else {
        await repo.create(data);
      }
      ref.invalidate(productListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Cập nhật thành công!' : 'Thêm sản phẩm thành công!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _skuCtrl.dispose(); _barcodeCtrl.dispose();
    _unitCtrl.dispose(); _costPriceCtrl.dispose(); _sellPriceCtrl.dispose();
    _wholesalePriceCtrl.dispose(); _minStockCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: AppColors.primary, size: 18),
            label: Text(_saving ? 'Đang lưu...' : 'Lưu', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionHeader('Thông tin cơ bản'),
            const SizedBox(height: 12),
            _field('Tên sản phẩm *', _nameCtrl, HugeIcons.strokeRoundedPackage, c,
                validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên' : null),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field('SKU', _skuCtrl, HugeIcons.strokeRoundedTag01, c)),
              const SizedBox(width: 12),
              Expanded(child: _field('Mã vạch', _barcodeCtrl, HugeIcons.strokeRoundedBarCode01, c)),
            ]),
            const SizedBox(height: 12),
            _field('Đơn vị tính', _unitCtrl, HugeIcons.strokeRoundedRuler, c, hint: 'VD: Cái, Kg, Hộp'),

            const SizedBox(height: 24),
            _sectionHeader('Giá'),
            const SizedBox(height: 12),
            _field('Giá vốn', _costPriceCtrl, HugeIcons.strokeRoundedCoinsDollar, c, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field('Giá bán lẻ *', _sellPriceCtrl, HugeIcons.strokeRoundedMoney01, c,
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Bắt buộc' : null)),
              const SizedBox(width: 12),
              Expanded(child: _field('Giá sỉ', _wholesalePriceCtrl, HugeIcons.strokeRoundedMoney01, c, keyboardType: TextInputType.number)),
            ]),

            const SizedBox(height: 24),
            _sectionHeader('Kho'),
            const SizedBox(height: 12),
            _field('Tồn tối thiểu', _minStockCtrl, HugeIcons.strokeRoundedWarehouse, c, keyboardType: TextInputType.number, hint: 'Cảnh báo khi dưới mức này'),

            const SizedBox(height: 24),
            _sectionHeader('Mô tả'),
            const SizedBox(height: 12),
            _field('Mô tả sản phẩm', _descCtrl, HugeIcons.strokeRoundedTextAlignLeft, c, maxLines: 3),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: Colors.white, size: 18),
                label: Text(_saving ? 'Đang lưu...' : (_isEdit ? 'Cập nhật' : 'Thêm sản phẩm')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Row(children: [
    HugeIcon(icon: HugeIcons.strokeRoundedFolder01, size: 18, color: AppColors.primary),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
  ]);

  Widget _field(String label, TextEditingController ctrl, dynamic icon, AppThemeColors c, {
    TextInputType? keyboardType, int maxLines = 1, String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl, keyboardType: keyboardType, maxLines: maxLines, validator: validator,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: Padding(padding: const EdgeInsets.all(12), child: HugeIcon(icon: icon, size: 20, color: AppColors.primary)),
        filled: true, fillColor: c.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
