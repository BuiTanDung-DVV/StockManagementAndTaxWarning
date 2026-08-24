import 'package:flutter_app/features/settings/providers/tax_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> backendTaxConfig() => {
  'fiscalYear': 2026,
  'thresholds': {
    'tier1': 250000000,
    'tier2': 500000000,
    'tier3': 900000000,
    'tier4': 1000000000,
  },
  'policy': {'sourceCode': '141/2026/NĐ-CP'},
  'taxRates': {
    'wholesale_retail': {'vat': 0.01, 'pit': 0.005},
    'manufacturing_transport': {'vat': 0.03, 'pit': 0.015},
    'services': {'vat': 0.05, 'pit': 0.02},
    'other': {'vat': 0.02, 'pit': 0.01},
  },
  'shopConfig': {'businessSector': 'TRADE', 'applyVatReduction': false},
};

void main() {
  group('TaxConfig from backend DB payload', () {
    final config = TaxConfig.fromBackend(backendTaxConfig());

    test('uses the annual revenue threshold supplied by backend', () {
      expect(config.thresholds!.tier4, 1000000000);
      expect(config.fiscalYear, 2026);
    });

    test('does not estimate GTGT or TNCN at or below the threshold', () {
      expect(config.calculateVat(1000000000), 0);
      expect(config.calculatePit(1000000000), 0);
    });

    test('estimates tax using the selected DB industry rates', () {
      expect(config.calculateVat(1200000000), 12000000);
      expect(config.calculatePit(1200000000), 6000000);
    });

    test('never produces negative tax', () {
      expect(config.calculateVat(-1), 0);
      expect(config.calculatePit(-1), 0);
    });

    test('requires e-invoice only above the backend threshold', () {
      expect(config.thresholds!.mustUseEInvoice(1000000000), isFalse);
      expect(config.thresholds!.mustUseEInvoice(1000000001), isTrue);
    });

    test('rejects a payload missing authoritative rates', () {
      final invalid = backendTaxConfig();
      (invalid['taxRates'] as Map).remove('services');
      expect(() => TaxConfig.fromBackend(invalid), throwsFormatException);
    });

    test('rejects missing or unknown database business sectors', () {
      final missing = backendTaxConfig();
      (missing['shopConfig'] as Map).remove('businessSector');
      expect(() => TaxConfig.fromBackend(missing), throwsFormatException);

      final unknown = backendTaxConfig();
      (unknown['shopConfig'] as Map)['businessSector'] = 'UNSUPPORTED';
      expect(() => TaxConfig.fromBackend(unknown), throwsFormatException);
    });
  });
}
