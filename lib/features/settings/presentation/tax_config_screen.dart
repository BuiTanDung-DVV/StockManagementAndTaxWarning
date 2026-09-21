import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../providers/tax_config_provider.dart';

String _moneyThreshold(double value) {
  if (value >= 1000000000 && value % 1000000000 == 0) {
    return '${(value / 1000000000).toStringAsFixed(0)} tỷ';
  }
  if (value >= 1000000 && value % 1000000 == 0) {
    return '${(value / 1000000).toStringAsFixed(0)} triệu';
  }
  return '${value.toStringAsFixed(0)} ₫';
}

class TaxConfigScreen extends ConsumerStatefulWidget {
  const TaxConfigScreen({super.key});

  @override
  ConsumerState<TaxConfigScreen> createState() => _TaxConfigScreenState();
}

class _TaxConfigScreenState extends ConsumerState<TaxConfigScreen> {
  bool _isSaving = false;
  bool _customRatesEnabled = false;
  late final TextEditingController _customVatController;
  late final TextEditingController _customPitController;

  @override
  void initState() {
    super.initState();
    _customVatController = TextEditingController();
    _customPitController = TextEditingController();
  }

  @override
  void dispose() {
    _customVatController.dispose();
    _customPitController.dispose();
    super.dispose();
  }

  void _syncControllers(TaxConfig config) {
    if (_customVatController.text.isEmpty && config.customVatRate != null) {
      _customVatController.text = config.customVatRate!.toStringAsFixed(2);
      _customRatesEnabled = true;
    }
    if (_customPitController.text.isEmpty && config.customPitRate != null) {
      _customPitController.text = config.customPitRate!.toStringAsFixed(2);
      _customRatesEnabled = true;
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      double? customVat;
      double? customPit;
      if (_customRatesEnabled) {
        customVat = double.tryParse(_customVatController.text.trim());
        customPit = double.tryParse(_customPitController.text.trim());
      }
      await ref
          .read(taxConfigProvider.notifier)
          .saveConfig(customVatRate: customVat, customPitRate: customPit);
      if (!mounted) return;
      ToastService.showSuccess('Đã lưu cấu hình thuế thành công!');
    } catch (e) {
      if (!mounted) return;
      ToastService.showError(
        'Không thể lưu cấu hình thuế lên máy chủ. Đã lưu tạm bộ nhớ máy.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetToOfficialBenchmark() {
    ref.read(taxConfigProvider.notifier).resetToDefaultPolicy();
    setState(() {
      _customRatesEnabled = false;
      _customVatController.clear();
      _customPitController.clear();
    });
    ToastService.showSuccess(
      'Đã áp dụng biểu thuế chuẩn 2026 (Nghị định 141/2026/NĐ-CP)!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final config = ref.watch(taxConfigProvider);
    final compactLayout = MediaQuery.sizeOf(context).width < 720;

    _syncControllers(config);

    final double displayedVatRate;
    final double displayedPitRate;
    if (_customRatesEnabled) {
      final parsedVat = double.tryParse(_customVatController.text.trim());
      final parsedPit = double.tryParse(_customPitController.text.trim());
      displayedVatRate = (parsedVat != null
          ? parsedVat / 100
          : config.effectiveVatRate);
      displayedPitRate = (parsedPit != null
          ? parsedPit / 100
          : config.effectivePitRate);
    } else {
      displayedVatRate = config.effectiveVatRate;
      displayedPitRate = config.effectivePitRate;
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'Cấu hình Thuế 2026',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (compactLayout)
            Tooltip(
              message: !config.isLoaded
                  ? 'Chưa có cấu hình hợp lệ để lưu'
                  : 'Lưu cấu hình thuế',
              child: AppPrimaryHeaderAction(
                label: 'Lưu cấu hình',
                assetPath: AppAssets.settings,
                heroTag: 'tax-config-save-compact',
                onPressed: _isSaving || !config.isLoaded ? null : _save,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: compactLayout
          ? null
          : Tooltip(
              message: !config.isLoaded
                  ? 'Chưa có cấu hình hợp lệ để lưu'
                  : 'Lưu cấu hình thuế',
              child: FloatingActionButton.extended(
                onPressed: _isSaving || !config.isLoaded ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isSaving ? 'Đang lưu…' : 'Lưu cấu hình',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                ),
                backgroundColor: !config.isLoaded
                    ? c.divider
                    : Theme.of(context).colorScheme.primary,
                foregroundColor: !config.isLoaded ? c.textMuted : Colors.white,
                elevation: 2,
              ),
            ),
      body: !config.isLoaded
          ? Center(
              child: config.isLoading
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: c.textMuted,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            config.errorMessage ??
                                'Không thể kết nối máy chủ cấu hình thuế.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Kiểm tra lại kết nối mạng hoặc thử tải lại cấu hình.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: c.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () =>
                                ref.read(taxConfigProvider.notifier).refresh(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => ref
                                .read(taxConfigProvider.notifier)
                                .resetToDefaultPolicy(),
                            icon: const Icon(Icons.shield_outlined),
                            label: const Text(
                              'Sử dụng cấu hình chuẩn 2026 ngay',
                            ),
                          ),
                        ],
                      ),
                    ),
            )
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.read(taxConfigProvider.notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 80),
                child: AppResponsiveContent(
                  maxWidth: 920,
                  verticalPadding: AppSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Banner
                      if (config.isUsingFallback)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.info.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.verified_user_rounded,
                                color: AppColors.info,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Chính sách thuế 2026 đã xác minh',
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Hệ thống đang áp dụng biểu thuế chuẩn theo ${config.policySourceCode ?? "NĐ 141/2026/NĐ-CP"}. Đảm bảo tính toán chính xác và liên tục.',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Thử đồng bộ lại máy chủ',
                                icon: const Icon(Icons.sync_rounded, size: 20),
                                onPressed: () => ref
                                    .read(taxConfigProvider.notifier)
                                    .refresh(),
                              ),
                            ],
                          ),
                        ),

                      // Section 1: Business Sector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ngành nghề kinh doanh chính',
                            style: GoogleFonts.manrope(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _resetToOfficialBenchmark,
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 16,
                            ),
                            label: const Text('Mặc định chuẩn 2026'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...BusinessType.values.map(
                        (type) => _BusinessTypeCard(
                          type: type,
                          rates: config.ratesFor(type)!,
                          isSelected: config.businessType == type,
                          onTap: () {
                            ref
                                .read(taxConfigProvider.notifier)
                                .setBusinessType(type);
                            if (!_customRatesEnabled) {
                              final r = config.ratesFor(type)!;
                              _customVatController.text = (r.vat * 100)
                                  .toStringAsFixed(2);
                              _customPitController.text = (r.pit * 100)
                                  .toStringAsFixed(2);
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Current Rates Summary
                      Text(
                        'Thuế suất áp dụng trên doanh thu',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _RateCard(
                              title: 'Thuế GTGT',
                              percentage:
                                  '${(displayedVatRate * 100).toStringAsFixed(2)}%',
                              color: AppColors.primary,
                              subtitle: _customRatesEnabled
                                  ? 'Mức tùy chỉnh'
                                  : 'Giá trị gia tăng',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RateCard(
                              title: 'Thuế TNCN',
                              percentage:
                                  '${(displayedPitRate * 100).toStringAsFixed(2)}%',
                              color: AppColors.success,
                              subtitle: _customRatesEnabled
                                  ? 'Mức tùy chỉnh'
                                  : 'Thu nhập cá nhân',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RateCard(
                              title: 'Tổng thuế',
                              percentage:
                                  '${((displayedVatRate + displayedPitRate) * 100).toStringAsFixed(2)}%',
                              color: AppColors.warning,
                              subtitle: 'Trích trên doanh thu',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Section 2: Custom Rates Override
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: c.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.tune_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tùy chỉnh thuế suất riêng',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: c.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Bật khi hộ kinh doanh có mức thuế ấn định riêng từ Chi cục Thuế',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: c.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _customRatesEnabled,
                                  onChanged: (val) {
                                    setState(() {
                                      _customRatesEnabled = val;
                                      if (val) {
                                        _customVatController.text =
                                            (config.effectiveVatRate * 100)
                                                .toStringAsFixed(2);
                                        _customPitController.text =
                                            (config.effectivePitRate * 100)
                                                .toStringAsFixed(2);
                                      } else {
                                        _customVatController.clear();
                                        _customPitController.clear();
                                      }
                                    });
                                  },
                                  activeThumbColor: AppColors.primary,
                                ),
                              ],
                            ),
                            if (_customRatesEnabled) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _customVatController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        labelText: 'Tỷ lệ GTGT tùy chỉnh (%)',
                                        hintText: 'Ví dụ: 1.0',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        suffixText: '%',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: TextField(
                                      controller: _customPitController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        labelText: 'Tỷ lệ TNCN tùy chỉnh (%)',
                                        hintText: 'Ví dụ: 0.5',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        suffixText: '%',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Section 3: Revenue Thresholds & Safety Gauge
                      Text(
                        'Ngưỡng Doanh Thu & Quy Định Thuế 2026',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ThresholdCard(
                        title: 'Vùng 1: An toàn (Không chịu thuế)',
                        range:
                            'Doanh thu năm ≤ ${_moneyThreshold(config.thresholds!.tier3)}',
                        description:
                            'Dưới 900 triệu/năm: Hộ kinh doanh hoàn toàn không phải nộp thuế GTGT & TNCN.',
                        badgeText: 'An toàn',
                        color: AppColors.success,
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      const SizedBox(height: 10),
                      _ThresholdCard(
                        title: 'Vùng 2: Cảnh báo sớm',
                        range:
                            '${_moneyThreshold(config.thresholds!.tier3)} - ${_moneyThreshold(config.thresholds!.tier4)}',
                        description:
                            'Từ 900 triệu đến 1 tỷ/năm: Hệ thống kích hoạt cảnh báo sớm để chuẩn bị hồ sơ sổ sách.',
                        badgeText: 'Cần chú ý',
                        color: AppColors.warning,
                        icon: Icons.warning_amber_rounded,
                      ),
                      const SizedBox(height: 10),
                      _ThresholdCard(
                        title: 'Vùng 3: Chịu thuế & Bắt buộc HĐĐT',
                        range:
                            'Doanh thu năm > ${_moneyThreshold(config.thresholds!.tier4)}',
                        description:
                            'Trên 1 tỷ/năm: Bắt buộc nộp thuế GTGT + TNCN theo tỷ lệ và xuất Hóa đơn điện tử máy tính tiền.',
                        badgeText: 'Bắt buộc HĐĐT',
                        color: AppColors.danger,
                        icon: Icons.error_outline_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _BusinessTypeCard extends StatelessWidget {
  final BusinessType type;
  final TaxRates rates;
  final bool isSelected;
  final VoidCallback onTap;

  const _BusinessTypeCard({
    required this.type,
    required this.rates,
    required this.isSelected,
    required this.onTap,
  });

  IconData get _sectorIcon => switch (type) {
    BusinessType.distribution => Icons.storefront_rounded,
    BusinessType.manufacturing => Icons.factory_rounded,
    BusinessType.services => Icons.handyman_rounded,
    BusinessType.other => Icons.business_center_rounded,
  };

  String get _examples => switch (type) {
    BusinessType.distribution =>
      'Vật liệu xây dựng, phân bón, nông sản, bán lẻ tiêu dùng',
    BusinessType.manufacturing =>
      'Cơ khí, sản xuất mộc, vận tải, xây lắp bao thầu NVL',
    BusinessType.services =>
      'Sửa chữa, dịch vụ lưu trú, ăn uống, thi công không thầu NVL',
    BusinessType.other => 'Các ngành nghề hoạt động kinh doanh thương mại khác',
  };

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : c.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : c.divider.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _sectorIcon,
                color: isSelected ? AppColors.primary : c.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          type.label,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isSelected
                                ? AppColors.primary
                                : c.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Tổng ${((rates.vat + rates.pit) * 100).toStringAsFixed(1)}%',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _examples,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _RateBadge(label: 'GTGT', rate: rates.vat),
                      _RateBadge(label: 'TNCN', rate: rates.pit),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primary : c.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _RateBadge extends StatelessWidget {
  final String label;
  final double rate;
  const _RateBadge({required this.label, required this.rate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: ${(rate * 100).toStringAsFixed(1)}%',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  final String title;
  final String percentage;
  final Color color;
  final String subtitle;

  const _RateCard({
    required this.title,
    required this.percentage,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 12, color: c.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            percentage,
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 11, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ThresholdCard extends StatelessWidget {
  final String title;
  final String range;
  final String description;
  final String badgeText;
  final Color color;
  final IconData icon;

  const _ThresholdCard({
    required this.title,
    required this.range,
    required this.description,
    required this.badgeText,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  range,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
