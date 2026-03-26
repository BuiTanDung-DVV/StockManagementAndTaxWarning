import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/tax_config_provider.dart';

class TaxConfigScreen extends ConsumerWidget {
  const TaxConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final config = ref.watch(taxConfigProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Cấu hình Thuế')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chọn ngành nghề kinh doanh để tự động xác định thuế suất GTGT và TNCN theo Sổ tay HKD.',
                  style: TextStyle(fontSize: 12, color: AppColors.info),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Business type selector
          Text('Ngành nghề kinh doanh',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...BusinessType.values.map((type) => _BusinessTypeCard(
                type: type,
                isSelected: config.businessType == type,
                onTap: () =>
                    ref.read(taxConfigProvider.notifier).setBusinessType(type),
              )),

          const SizedBox(height: 20),

          // Current rates display
          Text('Thuế suất áp dụng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _RateCard(
                'Thuế GTGT',
                '${(config.effectiveVatRate * 100).toStringAsFixed(1)}%',
                AppColors.primary,
                config.vatReduction20 ? '(đã giảm 20%)' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RateCard(
                'Thuế TNCN',
                '${(config.businessType.pitRate * 100).toStringAsFixed(1)}%',
                AppColors.success,
                null,
              ),
            ),
          ]),

          const SizedBox(height: 20),

          // VAT reduction toggle
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.discount, color: AppColors.warning, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Giảm 20% thuế GTGT',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('Theo NQ 204/2025/QH15',
                      style: TextStyle(fontSize: 11, color: c.textSecondary)),
                ]),
              ),
              Switch(
                value: config.vatReduction20,
                onChanged: (v) =>
                    ref.read(taxConfigProvider.notifier).setVatReduction20(v),
                activeThumbColor: AppColors.primary,
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // Revenue thresholds info
          Text('Ngưỡng doanh thu & Nghĩa vụ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _ThresholdRow('≤ 100 triệu', 'Không nộp thuế', AppColors.success),
          _ThresholdRow('100 - 300 triệu', 'Thuế khoán', AppColors.info),
          _ThresholdRow('300 - 500 triệu', 'Kê khai quý/năm', AppColors.warning),
          _ThresholdRow('500 triệu - 1 tỷ', 'Khuyến khích HĐĐT', AppColors.warning),
          _ThresholdRow('> 1 tỷ', 'Bắt buộc HĐĐT', AppColors.danger),
        ]),
      ),
    );
  }
}

class _BusinessTypeCard extends StatelessWidget {
  final BusinessType type;
  final bool isSelected;
  final VoidCallback onTap;
  const _BusinessTypeCard({required this.type, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppThemeColors.of(context).card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: isSelected ? 2 : 0,
        ),
      ),
      child: Row(children: [
        Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isSelected ? AppColors.primary : AppThemeColors.of(context).textMuted,
          size: 20,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(type.label, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            Text(
              'GTGT: ${(type.vatRate * 100).toStringAsFixed(0)}% • TNCN: ${(type.pitRate * 100).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 11, color: AppThemeColors.of(context).textSecondary),
            ),
          ]),
        ),
      ]),
    ),
  );
}

class _RateCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final String? subtitle;
  const _RateCard(this.label, this.value, this.color, this.subtitle);

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppThemeColors.of(context).card,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: [
      Text(label, style: TextStyle(fontSize: 11, color: AppThemeColors.of(context).textSecondary)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      if (subtitle != null)
        Text(subtitle!, style: TextStyle(fontSize: 10, color: color)),
    ]),
  );
}

class _ThresholdRow extends StatelessWidget {
  final String range, obligation;
  final Color color;
  const _ThresholdRow(this.range, this.obligation, this.color);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppThemeColors.of(context).card,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(child: Text(range, style: const TextStyle(fontSize: 13))),
      Text(obligation, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    ]),
  );
}
