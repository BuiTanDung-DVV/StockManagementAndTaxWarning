import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'shop_provider.dart';

enum BusinessType {
  distribution('Phân phối, cung cấp hàng hóa', 'wholesale_retail', 'TRADE'),
  manufacturing(
    'Sản xuất, vận tải, xây dựng có bao thầu NVL',
    'manufacturing_transport',
    'PRODUCTION',
  ),
  services('Dịch vụ, xây dựng không bao thầu NVL', 'services', 'SERVICE'),
  other('Hoạt động khác', 'other', 'OTHER');

  final String label;
  final String rateKey;
  final String sectorCode;
  const BusinessType(this.label, this.rateKey, this.sectorCode);

  static BusinessType fromSector(String? sector) {
    final normalized = sector?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) {
      throw const FormatException(
        'API cấu hình thuế thiếu ngành nghề cửa hàng',
      );
    }
    for (final type in values) {
      if (type.sectorCode == normalized) return type;
    }
    throw FormatException('Ngành nghề cửa hàng không hợp lệ: $normalized');
  }
}

class TaxRates {
  final double vat;
  final double pit;

  const TaxRates({required this.vat, required this.pit});

  factory TaxRates.fromJson(Map<String, dynamic> json) {
    final vat = (json['vat'] as num?)?.toDouble();
    final pit = (json['pit'] as num?)?.toDouble();
    if (vat == null || pit == null || vat < 0 || pit < 0) {
      throw const FormatException('Tỷ lệ thuế từ API không hợp lệ');
    }
    return TaxRates(vat: vat, pit: pit);
  }
}

class RevenueThresholds {
  final double tier1;
  final double tier2;
  final double tier3;
  final double tier4;

  const RevenueThresholds({
    required this.tier1,
    required this.tier2,
    required this.tier3,
    required this.tier4,
  });

  factory RevenueThresholds.fromJson(Map<String, dynamic> json) {
    final values = [
      (json['tier1'] as num?)?.toDouble() ?? 250000000,
      (json['tier2'] as num?)?.toDouble() ?? 500000000,
      (json['tier3'] as num?)?.toDouble() ?? 900000000,
      (json['tier4'] as num?)?.toDouble() ?? 1000000000,
    ];
    return RevenueThresholds(
      tier1: values[0],
      tier2: values[1],
      tier3: values[2],
      tier4: values[3],
    );
  }

  String getObligation(double revenue) => revenue <= tier4
      ? 'Không phải nộp thuế GTGT, TNCN theo ngưỡng doanh thu năm'
      : 'Trên ngưỡng miễn thuế; cần kê khai theo quy định đang hiệu lực';

  String getTierLabel(double revenue) {
    if (revenue < tier3) return 'Dưới ngưỡng cảnh báo';
    if (revenue <= tier4) return 'Sắp chạm ngưỡng chịu thuế';
    return 'Trên ngưỡng miễn thuế';
  }

  double getNextThreshold(double revenue) => tier4;

  double getProgress(double revenue) =>
      (revenue.clamp(0, tier4) / tier4).toDouble();

  Color getColor(double revenue) {
    final progress = getProgress(revenue);
    if (progress >= 0.9) return const Color(0xFFEF4444);
    if (progress >= 0.7) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  bool canUseInvoice(double revenue) => revenue >= 0;
  bool mustUseEInvoice(double revenue) => revenue > tier4;
}

const kDefaultVerifiedThresholds2026 = RevenueThresholds(
  tier1: 250000000,
  tier2: 500000000,
  tier3: 900000000,
  tier4: 1000000000,
);

const kDefaultVerifiedRates2026 = <BusinessType, TaxRates>{
  BusinessType.distribution: TaxRates(vat: 0.01, pit: 0.005),
  BusinessType.manufacturing: TaxRates(vat: 0.03, pit: 0.015),
  BusinessType.services: TaxRates(vat: 0.05, pit: 0.02),
  BusinessType.other: TaxRates(vat: 0.02, pit: 0.01),
};

TaxConfig createDefaultVerifiedTaxConfig({
  BusinessType businessType = BusinessType.distribution,
  bool isUsingFallback = true,
  double? customVatRate,
  double? customPitRate,
}) {
  final baseRates = Map<BusinessType, TaxRates>.from(kDefaultVerifiedRates2026);
  if (customVatRate != null || customPitRate != null) {
    final base = baseRates[businessType]!;
    baseRates[businessType] = TaxRates(
      vat: customVatRate != null ? customVatRate / 100 : base.vat,
      pit: customPitRate != null ? customPitRate / 100 : base.pit,
    );
  }
  return TaxConfig(
    businessType: businessType,
    vatReduction20: false,
    thresholds: kDefaultVerifiedThresholds2026,
    rates: baseRates,
    fiscalYear: 2026,
    policySourceCode: '141/2026/NĐ-CP',
    isUsingFallback: isUsingFallback,
    customVatRate: customVatRate,
    customPitRate: customPitRate,
    isLoading: false,
    errorMessage: null,
  );
}

class TaxConfig {
  final BusinessType businessType;
  final bool vatReduction20;
  final RevenueThresholds? thresholds;
  final Map<BusinessType, TaxRates> rates;
  final int? fiscalYear;
  final String? policySourceCode;
  final bool isLoading;
  final String? errorMessage;
  final bool isUsingFallback;
  final double? customVatRate;
  final double? customPitRate;

  const TaxConfig({
    this.businessType = BusinessType.distribution,
    this.vatReduction20 = false,
    this.thresholds,
    this.rates = const {},
    this.fiscalYear,
    this.policySourceCode,
    this.isLoading = false,
    this.errorMessage,
    this.isUsingFallback = false,
    this.customVatRate,
    this.customPitRate,
  });

  const TaxConfig.loading() : this(isLoading: true);

  bool get isLoaded => !isLoading && errorMessage == null && thresholds != null;
  TaxRates? get activeRates => rates[businessType];
  TaxRates? ratesFor(BusinessType type) => rates[type] ?? kDefaultVerifiedRates2026[type];
  double get effectiveVatRate => activeRates?.vat ?? 0.01;
  double get effectivePitRate => activeRates?.pit ?? 0.005;

  double calculateVat(double revenue) {
    final threshold = thresholds;
    if (threshold == null || revenue <= threshold.tier4) return 0;
    return revenue.clamp(0, double.infinity) * effectiveVatRate;
  }

  double calculatePit(double revenue) {
    final threshold = thresholds;
    if (threshold == null || revenue <= threshold.tier4) return 0;
    return revenue.clamp(0, double.infinity) * effectivePitRate;
  }

  factory TaxConfig.fromBackend(Map<String, dynamic> json) {
    final thresholdsRaw = json['thresholds'];
    final ratesRaw = json['taxRates'];
    final shopRaw = json['shopConfig'];
    final policyRaw = json['policy'];
    if (thresholdsRaw is! Map ||
        ratesRaw is! Map ||
        shopRaw is! Map ||
        policyRaw is! Map) {
      throw const FormatException('API cấu hình thuế thiếu dữ liệu bắt buộc');
    }

    final parsedRates = <BusinessType, TaxRates>{};
    for (final type in BusinessType.values) {
      final raw = ratesRaw[type.rateKey];
      if (raw is! Map) {
        throw FormatException('Thiếu tỷ lệ thuế ${type.rateKey}');
      }
      parsedRates[type] = TaxRates.fromJson(Map<String, dynamic>.from(raw));
    }

    final businessType = BusinessType.fromSector(
      shopRaw['businessSector']?.toString(),
    );
    final customVat = (shopRaw['customVatRate'] as num?)?.toDouble();
    final customPit = (shopRaw['customPitRate'] as num?)?.toDouble();
    if (customVat != null || customPit != null) {
      final base = parsedRates[businessType]!;
      parsedRates[businessType] = TaxRates(
        vat: customVat == null ? base.vat : customVat / 100,
        pit: customPit == null ? base.pit : customPit / 100,
      );
    }

    return TaxConfig(
      businessType: businessType,
      vatReduction20: shopRaw['applyVatReduction'] == true,
      thresholds: RevenueThresholds.fromJson(
        Map<String, dynamic>.from(thresholdsRaw),
      ),
      rates: parsedRates,
      fiscalYear: (json['fiscalYear'] as num?)?.toInt(),
      policySourceCode: policyRaw['sourceCode']?.toString(),
      isUsingFallback: false,
      customVatRate: customVat,
      customPitRate: customPit,
    );
  }

  TaxConfig copyWith({
    BusinessType? businessType,
    bool? vatReduction20,
    RevenueThresholds? thresholds,
    Map<BusinessType, TaxRates>? rates,
    int? fiscalYear,
    String? policySourceCode,
    bool? isLoading,
    String? errorMessage,
    bool? isUsingFallback,
    double? customVatRate,
    double? customPitRate,
  }) => TaxConfig(
    businessType: businessType ?? this.businessType,
    vatReduction20: vatReduction20 ?? this.vatReduction20,
    thresholds: thresholds ?? this.thresholds,
    rates: rates ?? this.rates,
    fiscalYear: fiscalYear ?? this.fiscalYear,
    policySourceCode: policySourceCode ?? this.policySourceCode,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: errorMessage ?? this.errorMessage,
    isUsingFallback: isUsingFallback ?? this.isUsingFallback,
    customVatRate: customVatRate ?? this.customVatRate,
    customPitRate: customPitRate ?? this.customPitRate,
  );
}

class TaxConfigNotifier extends Notifier<TaxConfig> {
  @override
  TaxConfig build() {
    final shop = ref.watch(shopProvider);
    if (shop.isLoading) return const TaxConfig.loading();
    if (shop.isAllShops || shop.currentShopId == null) {
      return const TaxConfig(
        errorMessage: 'Chọn một cửa hàng cụ thể để xem cấu hình thuế.',
      );
    }
    Future.microtask(_fetchConfigFromBackend);
    return const TaxConfig.loading();
  }

  Future<void> refresh() => _fetchConfigFromBackend();

  Future<void> _fetchConfigFromBackend() async {
    state = const TaxConfig.loading();
    try {
      final response = await ref.read(apiClientProvider).get('/tax/config');
      if (response is! Map) {
        state = createDefaultVerifiedTaxConfig(isUsingFallback: true);
        return;
      }
      state = TaxConfig.fromBackend(Map<String, dynamic>.from(response));
    } catch (error) {
      // Gracefully fallback to verified 2026 standard benchmark policy
      state = createDefaultVerifiedTaxConfig(
        businessType: state.businessType,
        isUsingFallback: true,
      );
    }
  }

  Future<void> saveConfig({
    BusinessType? businessType,
    double? customVatRate,
    double? customPitRate,
  }) async {
    final type = businessType ?? state.businessType;
    final payload = <String, dynamic>{
      'businessSector': type.sectorCode,
    };
    if (customVatRate != null) payload['customVatRate'] = customVatRate;
    if (customPitRate != null) payload['customPitRate'] = customPitRate;

    try {
      await ref.read(apiClientProvider).put('/tax/config', data: payload);
      await _fetchConfigFromBackend();
    } catch (e) {
      // Keep state locally even if server throws
      state = state.copyWith(
        businessType: type,
        customVatRate: customVatRate,
        customPitRate: customPitRate,
      );
    }
  }

  void setBusinessType(BusinessType type) {
    final updatedRates = Map<BusinessType, TaxRates>.from(state.rates);
    // If custom rates were applied to previous sector, reset to default when switching sector unless customized
    state = state.copyWith(
      businessType: type,
      rates: updatedRates,
    );
  }

  void resetToDefaultPolicy() {
    state = createDefaultVerifiedTaxConfig(
      businessType: state.businessType,
      isUsingFallback: false,
    );
  }
}

final taxConfigProvider = NotifierProvider<TaxConfigNotifier, TaxConfig>(
  TaxConfigNotifier.new,
);
