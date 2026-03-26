import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/providers/tax_config_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class TaxCalculatorScreen extends ConsumerStatefulWidget {
  const TaxCalculatorScreen({super.key});
  @override
  ConsumerState<TaxCalculatorScreen> createState() => _TaxCalculatorScreenState();
}

class _TaxCalculatorScreenState extends ConsumerState<TaxCalculatorScreen> {
  final _controller = TextEditingController();
  double _revenue = 0;
  int _method = 0; // 0 = trực tiếp doanh thu, 1 = thu nhập chịu thuế

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final config = ref.watch(taxConfigProvider);
    final vat = config.calculateVat(_revenue);
    final pit = config.calculatePit(_revenue);
    final total = vat + pit;
    final afterTax = _revenue - total;

    return Scaffold(
      appBar: AppBar(title: Text('Tính thuế HKD')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Current config display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.business, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  config.businessType.label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary),
                ),
              ),
              Text(
                'GTGT ${(config.effectiveVatRate * 100).toStringAsFixed(1)}% • TNCN ${(config.businessType.pitRate * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 11, color: AppColors.primary),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Method selector
          Text('Phương pháp tính', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _MethodTab('Trực tiếp DT', _method == 0, () => setState(() => _method = 0))),
            const SizedBox(width: 8),
            Expanded(child: _MethodTab('Thu nhập CT', _method == 1, () => setState(() => _method = 1))),
          ]),
          const SizedBox(height: 16),

          // Revenue input
          Text('Doanh thu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'Nhập doanh thu (VNĐ)',
              prefixIcon: Icon(Icons.attach_money, color: AppColors.primary),
              suffixText: 'VNĐ',
            ),
            onChanged: (v) => setState(() => _revenue = double.tryParse(v) ?? 0),
          ),
          const SizedBox(height: 20),

          // Threshold status
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.flag, size: 16, color: RevenueThreshold.getColor(_revenue)),
                const SizedBox(width: 8),
                Text('Ngưỡng: ${RevenueThreshold.getTierLabel(_revenue)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: RevenueThreshold.getColor(_revenue))),
              ]),
              SizedBox(height: 6),
              Text(RevenueThreshold.getObligation(_revenue),
                  style: TextStyle(fontSize: 12, color: c.textSecondary)),
              SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: RevenueThreshold.getProgress(_revenue).clamp(0.0, 1.0),
                  backgroundColor: c.surface,
                  color: RevenueThreshold.getColor(_revenue),
                  minHeight: 6,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Tiến tới ngưỡng tiếp: ${_currFmt.format(RevenueThreshold.getNextThreshold(_revenue))}',
                style: TextStyle(fontSize: 10, color: c.textMuted),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Tax breakdown
          Text('Chi tiết thuế phải nộp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          _TaxRow('Doanh thu', _currFmt.format(_revenue), c.textPrimary, isBold: true),
          Divider(color: c.surface, height: 20),
          _TaxRow('Thuế GTGT (${(config.effectiveVatRate * 100).toStringAsFixed(1)}%)',
              _currFmt.format(vat), AppColors.warning),
          if (config.vatReduction20)
            _TaxRow('  └ Đã giảm 20% GTGT', '−${_currFmt.format(config.businessType.vatRate * _revenue * 0.2)}',
                AppColors.success),
          _TaxRow('Thuế TNCN (${(config.businessType.pitRate * 100).toStringAsFixed(1)}%)',
              _currFmt.format(pit), AppColors.info),
          Divider(color: c.surface, height: 20),
          _TaxRow('Tổng thuế phải nộp', _currFmt.format(total), AppColors.danger, isBold: true),
          _TaxRow('Còn lại sau thuế', _currFmt.format(afterTax), AppColors.success, isBold: true),

          // Invoice usage info
          if (_revenue > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (RevenueThreshold.canUseInvoice(_revenue) ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(
                  RevenueThreshold.canUseInvoice(_revenue) ? Icons.check_circle : Icons.info,
                  size: 18,
                  color: RevenueThreshold.canUseInvoice(_revenue) ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    RevenueThreshold.mustUseEInvoice(_revenue)
                        ? 'Bắt buộc sử dụng hóa đơn điện tử (HĐĐT)'
                        : RevenueThreshold.canUseInvoice(_revenue)
                            ? 'Được sử dụng hóa đơn, khuyến khích dùng HĐĐT'
                            : 'Chưa đủ ngưỡng sử dụng hóa đơn (< 500 triệu)',
                    style: TextStyle(
                      fontSize: 12,
                      color: RevenueThreshold.canUseInvoice(_revenue) ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _MethodTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _MethodTab(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppThemeColors.of(context).card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppThemeColors.of(context).textSecondary,
            )),
      ),
    ),
  );
}

class _TaxRow extends StatelessWidget {
  final String label, amount;
  final Color color;
  final bool isBold;
  const _TaxRow(this.label, this.amount, this.color, {this.isBold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal)),
      Text(amount, style: TextStyle(fontSize: isBold ? 16 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color)),
    ]),
  );
}
