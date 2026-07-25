import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';

/// Ngành nghề kinh doanh theo Sổ tay HKD
enum BusinessType {
  distribution('Phân phối, cung cấp hàng hóa', 0.01, 0.005),
  manufacturing('Sản xuất, vận tải, xây dựng có bao thầu NVL', 0.03, 0.015),
  services('Dịch vụ, xây dựng không bao thầu NVL', 0.05, 0.02),
  other('Hoạt động khác', 0.02, 0.01);

  final String label;
  final double vatRate;
  final double pitRate;
  const BusinessType(this.label, this.vatRate, this.pitRate);
}

/// Ngưỡng doanh thu theo Sổ tay HKD
class RevenueThresholds {
  final double tier1;
  final double tier2;
  final double tier3;
  final double tier4;

  const RevenueThresholds({
    this.tier1 = 250000000,
    this.tier2 = 500000000,
    this.tier3 = 900000000,
    this.tier4 = 1000000000,
  });

  String getObligation(double revenue) {
    if (revenue <= tier4) {
      return 'Không phải nộp thuế GTGT, TNCN theo ngưỡng doanh thu năm';
    }
    return 'Trên ngưỡng miễn thuế; cần kê khai và áp dụng HĐĐT';
  }

  String getTierLabel(double revenue) {
    if (revenue < tier3) return 'Dưới ngưỡng 1 tỷ';
    if (revenue <= tier4) return 'Sắp chạm ngưỡng 1 tỷ';
    return '> 1 tỷ';
  }

  double getNextThreshold(double revenue) {
    return tier4;
  }

  double getProgress(double revenue) {
    if (tier4 <= 0) return 0;
    return (revenue.clamp(0, tier4) / tier4).toDouble();
  }

  Color getColor(double revenue) {
    final progress = getProgress(revenue);
    if (progress >= 0.9) return const Color(0xFFEF4444); // danger
    if (progress >= 0.7) return const Color(0xFFF59E0B); // warning
    return const Color(0xFF10B981); // success
  }

  bool canUseInvoice(double revenue) => revenue >= 0;
  bool mustUseEInvoice(double revenue) => revenue > tier4;

  factory RevenueThresholds.fromJson(Map<String, dynamic> json) =>
      RevenueThresholds(
        tier1: (json['tier1'] as num?)?.toDouble() ?? 250000000,
        tier2: (json['tier2'] as num?)?.toDouble() ?? 500000000,
        tier3: (json['tier3'] as num?)?.toDouble() ?? 900000000,
        tier4: (json['tier4'] as num?)?.toDouble() ?? 1000000000,
      );
  Map<String, dynamic> toJson() => {
    'tier1': tier1,
    'tier2': tier2,
    'tier3': tier3,
    'tier4': tier4,
  };
}

/// Tax configuration state
class TaxConfig {
  final BusinessType businessType;
  final bool vatReduction20; // Giảm 20% GTGT theo NQ 204/2025
  final RevenueThresholds thresholds;

  const TaxConfig({
    this.businessType = BusinessType.distribution,
    this.vatReduction20 = false,
    this.thresholds = const RevenueThresholds(),
  });

  // Chưa áp dụng giảm GTGT tự động vì chính sách phụ thuộc từng nhóm hàng hóa.
  double get effectiveVatRate => businessType.vatRate;

  double calculateVat(double revenue) {
    final safeRevenue = revenue < 0 ? 0.0 : revenue;
    if (safeRevenue <= thresholds.tier4) return 0;
    return safeRevenue * effectiveVatRate;
  }

  double calculatePit(double revenue) {
    final safeRevenue = revenue < 0 ? 0.0 : revenue;
    if (safeRevenue <= thresholds.tier4) return 0;
    return safeRevenue * businessType.pitRate;
  }

  double calculateTotalTax(double revenue) =>
      calculateVat(revenue) + calculatePit(revenue);

  Map<String, dynamic> toJson() => {
    'businessType': businessType.index,
    'vatReduction20': false,
    'thresholds': thresholds.toJson(),
  };

  factory TaxConfig.fromJson(Map<String, dynamic> json) => TaxConfig(
    businessType: BusinessType.values[json['businessType'] ?? 0],
    vatReduction20: false,
    thresholds: json['thresholds'] != null
        ? RevenueThresholds.fromJson(json['thresholds'])
        : const RevenueThresholds(),
  );

  TaxConfig copyWith({
    BusinessType? businessType,
    bool? vatReduction20,
    RevenueThresholds? thresholds,
  }) => TaxConfig(
    businessType: businessType ?? this.businessType,
    vatReduction20: vatReduction20 ?? this.vatReduction20,
    thresholds: thresholds ?? this.thresholds,
  );
}

/// Notifier for tax config with SharedPreferences persistence
class TaxConfigNotifier extends Notifier<TaxConfig> {
  static const _key = 'tax_config';

  @override
  TaxConfig build() {
    _load();
    return const TaxConfig();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json != null) {
      state = TaxConfig.fromJson(jsonDecode(json));
    }

    // Migrate old cached thresholds if exist and no current thresholds in JSON
    if (json == null) {
      final thresholdsJson = prefs.getString('tax_thresholds');
      if (thresholdsJson != null) {
        final th = jsonDecode(thresholdsJson);
        state = state.copyWith(thresholds: RevenueThresholds.fromJson(th));
      }
    }

    // Fetch dynamic config from backend
    _fetchConfigFromBackend();
  }

  Future<void> _fetchConfigFromBackend() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/tax/config');
      if (res != null) {
        final data = res;

        if (data['thresholds'] != null) {
          final th = data['thresholds'] as Map<String, dynamic>;
          state = state.copyWith(thresholds: RevenueThresholds.fromJson(th));
        }

        if (data['currentPolicies'] != null) {
          final policies = data['currentPolicies'];
          if (policies['vatReductionActive'] != null) {
            setVatReduction20(policies['vatReductionActive']);
          }
        }

        if (data['shopConfig'] != null) {
          final shopConf = data['shopConfig'];
          if (shopConf['businessSector'] != null) {
            final sectorStr = shopConf['businessSector'];
            final type = BusinessType.values.firstWhere(
              (e) =>
                  e.name.toUpperCase() == sectorStr ||
                  e.name == sectorStr ||
                  (e == BusinessType.distribution && sectorStr == 'TRADE') ||
                  (e == BusinessType.manufacturing &&
                      sectorStr == 'PRODUCTION') ||
                  (e == BusinessType.services && sectorStr == 'SERVICE') ||
                  (e == BusinessType.other && sectorStr == 'OTHER'),
              orElse: () => BusinessType.distribution,
            );
            state = state.copyWith(businessType: type);
          }
          if (shopConf['applyVatReduction'] != null) {
            state = state.copyWith(
              vatReduction20: shopConf['applyVatReduction'],
            );
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_key, jsonEncode(state.toJson()));
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch tax config from backend: $e');
    }
  }

  Future<void> saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));

    // Sync to backend
    final api = ref.read(apiClientProvider);

    String sectorStr = 'TRADE';
    if (state.businessType == BusinessType.manufacturing) {
      sectorStr = 'PRODUCTION';
    }
    if (state.businessType == BusinessType.services) {
      sectorStr = 'SERVICE';
    }
    if (state.businessType == BusinessType.other) {
      sectorStr = 'OTHER';
    }

    try {
      await api.put(
        '/tax/config',
        data: {'businessSector': sectorStr, 'applyVatReduction': false},
      );
    } catch (e) {
      debugPrint('Lưu cấu hình thuế lên server thất bại, đã lưu cục bộ: $e');
    }
  }

  void setBusinessType(BusinessType type) {
    state = state.copyWith(businessType: type);
  }

  void setVatReduction20(bool value) {
    state = state.copyWith(vatReduction20: value);
  }
}

final taxConfigProvider = NotifierProvider<TaxConfigNotifier, TaxConfig>(
  TaxConfigNotifier.new,
);
