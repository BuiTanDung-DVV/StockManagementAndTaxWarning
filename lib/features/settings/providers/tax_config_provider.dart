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
      throw const FormatException('API cấu hình thuế thiếu ngành nghề cửa hàng');
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
      (json['tier1'] as num?)?.toDouble(),
      (json['tier2'] as num?)?.toDouble(),
      (json['tier3'] as num?)?.toDouble(),
      (json['tier4'] as num?)?.toDouble(),
    ];
    if (values.any((value) => value == null || value <= 0) ||
        values[0]! >= values[1]! ||
        values[1]! >= values[2]! ||
        values[2]! >= values[3]!) {
      throw const FormatException('Các ngưỡng doanh thu từ API không hợp lệ');
    }
    return RevenueThresholds(
      tier1: values[0]!,
      tier2: values[1]!,
      tier3: values[2]!,
      tier4: values[3]!,
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

class TaxConfig {
  final BusinessType businessType;
  final bool vatReduction20;
  final RevenueThresholds? thresholds;
  final Map<BusinessType, TaxRates> rates;
  final int? fiscalYear;
  final String? policySourceCode;
  final bool isLoading;
  final String? errorMessage;

  const TaxConfig({
    this.businessType = BusinessType.distribution,
    this.vatReduction20 = false,
    this.thresholds,
    this.rates = const {},
    this.fiscalYear,
    this.policySourceCode,
    this.isLoading = false,
    this.errorMessage,
  });

  const TaxConfig.loading() : this(isLoading: true);

  bool get isLoaded => !isLoading && errorMessage == null && thresholds != null;
  TaxRates? get activeRates => rates[businessType];
  TaxRates? ratesFor(BusinessType type) => rates[type];
  double get effectiveVatRate => activeRates?.vat ?? 0;
  double get effectivePitRate => activeRates?.pit ?? 0;

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
    );
  }

  TaxConfig copyWith({BusinessType? businessType}) => TaxConfig(
    businessType: businessType ?? this.businessType,
    vatReduction20: vatReduction20,
    thresholds: thresholds,
    rates: rates,
    fiscalYear: fiscalYear,
    policySourceCode: policySourceCode,
    isLoading: isLoading,
    errorMessage: errorMessage,
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
    try {
      final response = await ref.read(apiClientProvider).get('/tax/config');
      if (response is! Map) {
        throw const FormatException('API cấu hình thuế trả về sai định dạng');
      }
      state = TaxConfig.fromBackend(Map<String, dynamic>.from(response));
    } catch (error) {
      state = TaxConfig(errorMessage: error.toString());
    }
  }

  Future<void> saveConfig() async {
    if (!state.isLoaded) {
      throw StateError('Cấu hình thuế chưa được tải từ DB');
    }
    await ref
        .read(apiClientProvider)
        .put(
          '/tax/config',
          data: {'businessSector': state.businessType.sectorCode},
        );
    await _fetchConfigFromBackend();
  }

  void setBusinessType(BusinessType type) {
    if (!state.isLoaded) return;
    state = state.copyWith(businessType: type);
  }
}

final taxConfigProvider = NotifierProvider<TaxConfigNotifier, TaxConfig>(
  TaxConfigNotifier.new,
);
