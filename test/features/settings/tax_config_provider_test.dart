import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/settings/providers/tax_config_provider.dart';

void main() {
  group('TaxConfig 2026', () {
    const config = TaxConfig();

    test('uses the one-billion annual revenue threshold', () {
      expect(config.thresholds.tier4, 1000000000);
    });

    test('does not estimate GTGT or TNCN at or below the threshold', () {
      expect(config.calculateVat(1000000000), 0);
      expect(config.calculatePit(1000000000), 0);
    });

    test('estimates tax from non-negative revenue above the threshold', () {
      expect(config.calculateVat(1200000000), 12000000);
      expect(config.calculatePit(1200000000), 6000000);
    });

    test('never produces negative tax', () {
      expect(config.calculateVat(-1), 0);
      expect(config.calculatePit(-1), 0);
    });

    test('does not apply a shop-wide VAT reduction automatically', () {
      const legacyConfig = TaxConfig(vatReduction20: true);
      expect(legacyConfig.calculateVat(1200000000), 12000000);
    });

    test('requires e-invoice only when revenue is above one billion', () {
      expect(config.thresholds.mustUseEInvoice(1000000000), isFalse);
      expect(config.thresholds.mustUseEInvoice(1000000001), isTrue);
    });
  });
}
