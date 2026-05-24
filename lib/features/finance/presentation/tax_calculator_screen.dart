import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/guides/feature_guide_sheet.dart';
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
    final theme = Theme.of(context);
    final config = ref.watch(taxConfigProvider);
    final vat = config.calculateVat(_revenue);
    final pit = config.calculatePit(_revenue);
    final total = vat + pit;
    final afterTax = _revenue - total;

    // Parameters for custom milestones progress
    const double maxScale = 1200000000.0; // 1.2 billion max scale
    final double progressRatio = (_revenue / maxScale).clamp(0.0, 1.0);
    const double milestone1Ratio = 500000000.0 / maxScale; // 500M mark
    const double milestone2Ratio = 1000000000.0 / maxScale; // 1B mark

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Công cụ Tính Thuế HKD 2026',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        actions: [featureGuideButton(context, 'tax_calculator')],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current config display (Glassmorphic Banner)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.business_center_rounded, size: 18, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.businessType.label,
                          style: GoogleFonts.outfit(
                            fontSize: 13, 
                            fontWeight: FontWeight.bold, 
                            color: theme.colorScheme.primary
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tỷ suất: GTGT ${(config.effectiveVatRate * 100).toStringAsFixed(1)}% • TNCN ${(config.businessType.pitRate * 100).toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Method selector
            Text(
              'Phương pháp tính', 
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MethodTab(
                    'Trực tiếp DT', 
                    _method == 0, 
                    () => setState(() => _method = 0)
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MethodTab(
                    'Thu nhập CT', 
                    _method == 1, 
                    () => setState(() => _method = 1)
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Revenue input
            Text(
              'Doanh thu nhập vào', 
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: c.card,
                hintText: 'Nhập số tiền doanh thu (VNĐ)',
                prefixIcon: Icon(Icons.payments_rounded, color: theme.colorScheme.primary),
                suffixText: 'VNĐ',
                suffixStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: c.divider.withValues(alpha: 0.6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
              ),
              onChanged: (v) => setState(() => _revenue = double.tryParse(v) ?? 0),
            ),
            const SizedBox(height: 24),

            // Dynamic Milestone Warning Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: c.divider.withValues(alpha: 0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: RevenueThreshold.getColor(_revenue).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.radar_rounded,
                          size: 16,
                          color: RevenueThreshold.getColor(_revenue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Cảnh Báo Ngưỡng Doanh Thu 2026',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Interactive double progress track
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final trackWidth = constraints.maxWidth;
                      return Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Base Track
                              Container(
                                height: 10,
                                width: trackWidth,
                                decoration: BoxDecoration(
                                  color: c.surface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              // Glowing Progress fill
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: 10,
                                width: trackWidth * progressRatio,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: LinearGradient(
                                    colors: [
                                      theme.colorScheme.primary,
                                      RevenueThreshold.getColor(_revenue),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: RevenueThreshold.getColor(_revenue).withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              // Milestone 1 Node (500M)
                              Positioned(
                                left: trackWidth * milestone1Ratio - 6,
                                top: -3,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: _revenue >= 500000000.0 
                                        ? AppColors.warning 
                                        : c.textMuted.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      if (_revenue >= 500000000.0)
                                        BoxShadow(
                                          color: AppColors.warning.withValues(alpha: 0.5),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              // Milestone 2 Node (1B)
                              Positioned(
                                left: trackWidth * milestone2Ratio - 6,
                                top: -3,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: _revenue >= 1000000000.0 
                                        ? AppColors.danger 
                                        : c.textMuted.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      if (_revenue >= 1000000000.0)
                                        BoxShadow(
                                          color: AppColors.danger.withValues(alpha: 0.5),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Milestone Labels
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '0',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: c.textMuted),
                              ),
                              Expanded(
                                child: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: EdgeInsets.only(left: trackWidth * milestone1Ratio - 35),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '500M',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11, 
                                          fontWeight: FontWeight.bold, 
                                          color: _revenue >= 500000000.0 ? AppColors.warning : c.textSecondary
                                        ),
                                      ),
                                      Text('Khai thuế', style: TextStyle(fontSize: 8, color: c.textMuted, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.only(right: trackWidth * (1.0 - milestone2Ratio) - 22),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '1 Tỷ',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11, 
                                        fontWeight: FontWeight.bold, 
                                        color: _revenue >= 1000000000.0 ? AppColors.danger : c.textSecondary
                                      ),
                                    ),
                                    Text('Bắt buộc HĐĐT', style: TextStyle(fontSize: 8, color: c.textMuted, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Text warning advisory
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: RevenueThreshold.getColor(_revenue).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: RevenueThreshold.getColor(_revenue).withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Ngưỡng hiện tại: ${RevenueThreshold.getTierLabel(_revenue)}',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: RevenueThreshold.getColor(_revenue),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          RevenueThreshold.getObligation(_revenue),
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Doanh thu tiếp theo cần lưu ý: ${_currFmt.format(RevenueThreshold.getNextThreshold(_revenue))}',
                    style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tax breakdown list (Sleek Ledger style)
            Text(
              'Chi tiết thuế phải nộp', 
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)
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
                children: [
                  _TaxRow('Doanh thu kê khai', _currFmt.format(_revenue), c.textPrimary, isBold: true),
                  Divider(color: c.divider.withValues(alpha: 0.4), height: 24),
                  _TaxRow(
                    'Thuế GTGT (${(config.effectiveVatRate * 100).toStringAsFixed(1)}%)',
                    _currFmt.format(vat), 
                    AppColors.warning
                  ),
                  if (config.vatReduction20) ...[
                    const SizedBox(height: 4),
                    _TaxRow(
                      '  └ Miễn giảm 20% (NQ 204)', 
                      '−${_currFmt.format(config.businessType.vatRate * _revenue * 0.2)}',
                      AppColors.success,
                      isItalic: true,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _TaxRow(
                    'Thuế TNCN (${(config.businessType.pitRate * 100).toStringAsFixed(1)}%)',
                    _currFmt.format(pit), 
                    AppColors.info
                  ),
                  Divider(color: c.divider.withValues(alpha: 0.4), height: 24),
                  _TaxRow('TỔNG THUẾ PHẢI NỘP', _currFmt.format(total), AppColors.danger, isBold: true),
                  const SizedBox(height: 12),
                  _TaxRow('Thu nhập còn lại sau thuế', _currFmt.format(afterTax), AppColors.success, isBold: true),
                ],
              ),
            ),

            // E-Invoice Advisory Tag
            if (_revenue > 0) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (RevenueThreshold.canUseInvoice(_revenue) ? AppColors.success : AppColors.warning).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (RevenueThreshold.canUseInvoice(_revenue) ? AppColors.success : AppColors.warning).withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      RevenueThreshold.canUseInvoice(_revenue) ? Icons.verified_user_rounded : Icons.info_outline_rounded,
                      size: 20,
                      color: RevenueThreshold.canUseInvoice(_revenue) ? AppColors.success : AppColors.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        RevenueThreshold.mustUseEInvoice(_revenue)
                            ? 'BẮT BUỘC sử dụng Hóa đơn điện tử (HĐĐT) cho mọi giao dịch bán lẻ theo đúng quy định.'
                            : RevenueThreshold.canUseInvoice(_revenue)
                                ? 'Đủ điều kiện xuất hóa đơn. Khuyến khích đăng ký sử dụng HĐĐT để tối ưu quy trình.'
                                : 'Chưa đủ ngưỡng sử dụng hóa đơn bán hàng lẻ (< 500 triệu VNĐ).',
                        style: TextStyle(
                          fontSize: 12,
                          color: RevenueThreshold.canUseInvoice(_revenue) ? AppColors.success : AppColors.warning,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
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
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? theme.colorScheme.primary : c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? theme.colorScheme.primary : c.divider.withValues(alpha: 0.6),
            width: 1,
          ),
          boxShadow: [
            if (active)
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: active ? Colors.white : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TaxRow extends StatelessWidget {
  final String label, amount;
  final Color color;
  final bool isBold;
  final bool isItalic;
  const _TaxRow(this.label, this.amount, this.color, {this.isBold = false, this.isItalic = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label, 
            style: TextStyle(
              fontSize: 13, 
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            amount, 
            style: GoogleFonts.outfit(
              fontSize: isBold ? 17 : 14, 
              fontWeight: isBold ? FontWeight.w800 : FontWeight.bold, 
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
