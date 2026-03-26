import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
class RevenueThreshold {
  static const double tier1 = 100000000;   // 100 triệu
  static const double tier2 = 300000000;   // 300 triệu
  static const double tier3 = 500000000;   // 500 triệu
  static const double tier4 = 1000000000;  // 1 tỷ

  static String getObligation(double revenue) {
    if (revenue <= tier1) return 'Không phải nộp thuế GTGT, TNCN';
    if (revenue <= tier2) return 'Nộp thuế theo phương pháp khoán';
    if (revenue <= tier3) return 'Kê khai thuế theo quý/năm';
    return 'Bắt buộc dùng HĐĐT, kê khai đầy đủ';
  }

  static String getTierLabel(double revenue) {
    if (revenue <= tier1) return '≤ 100 triệu';
    if (revenue <= tier2) return '100 - 300 triệu';
    if (revenue <= tier3) return '300 triệu - 500 triệu';
    if (revenue <= tier4) return '500 triệu - 1 tỷ';
    return '> 1 tỷ';
  }

  static double getNextThreshold(double revenue) {
    if (revenue < tier1) return tier1;
    if (revenue < tier2) return tier2;
    if (revenue < tier3) return tier3;
    if (revenue < tier4) return tier4;
    return tier4;
  }

  static double getProgress(double revenue) {
    final next = getNextThreshold(revenue);
    if (next <= tier1) return revenue / tier1;
    if (next <= tier2) return (revenue - tier1) / (tier2 - tier1);
    if (next <= tier3) return (revenue - tier2) / (tier3 - tier2);
    if (next <= tier4) return (revenue - tier3) / (tier4 - tier3);
    return 1.0;
  }

  static Color getColor(double revenue) {
    final progress = getProgress(revenue);
    if (progress >= 0.9) return const Color(0xFFEF4444); // danger
    if (progress >= 0.7) return const Color(0xFFF59E0B); // warning
    return const Color(0xFF10B981); // success
  }

  static bool canUseInvoice(double revenue) => revenue >= tier3;
  static bool mustUseEInvoice(double revenue) => revenue >= tier4;
}

/// Tax configuration state
class TaxConfig {
  final BusinessType businessType;
  final bool vatReduction20; // Giảm 20% GTGT theo NQ 204/2025

  const TaxConfig({
    this.businessType = BusinessType.distribution,
    this.vatReduction20 = false,
  });

  double get effectiveVatRate =>
      vatReduction20 ? businessType.vatRate * 0.8 : businessType.vatRate;

  double calculateVat(double revenue) => revenue * effectiveVatRate;
  double calculatePit(double revenue) => revenue * businessType.pitRate;
  double calculateTotalTax(double revenue) =>
      calculateVat(revenue) + calculatePit(revenue);

  Map<String, dynamic> toJson() => {
    'businessType': businessType.index,
    'vatReduction20': vatReduction20,
  };

  factory TaxConfig.fromJson(Map<String, dynamic> json) => TaxConfig(
    businessType: BusinessType.values[json['businessType'] ?? 0],
    vatReduction20: json['vatReduction20'] ?? false,
  );

  TaxConfig copyWith({BusinessType? businessType, bool? vatReduction20}) =>
      TaxConfig(
        businessType: businessType ?? this.businessType,
        vatReduction20: vatReduction20 ?? this.vatReduction20,
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
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  void setBusinessType(BusinessType type) {
    state = state.copyWith(businessType: type);
    _save();
  }

  void setVatReduction20(bool value) {
    state = state.copyWith(vatReduction20: value);
    _save();
  }
}

final taxConfigProvider =
    NotifierProvider<TaxConfigNotifier, TaxConfig>(
        TaxConfigNotifier.new);

