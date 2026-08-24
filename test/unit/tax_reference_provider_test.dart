import 'package:flutter_app/features/finance/providers/tax_reference_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tax reference data is parsed only from backend response', () {
    final data = TaxReferenceData.fromJson({
      'forms': [
        {
          'code': '01/CNKD',
          'name': 'Tờ khai',
          'description': 'Mô tả',
          'status': 'READY',
          'iconKey': 'description',
        },
      ],
      'supportLinks': [
        {
          'title': 'Cục Thuế',
          'description': 'Cổng chính thức',
          'url': 'https://www.gdt.gov.vn/',
          'iconKey': 'authority',
          'colorRole': 'PRIMARY',
        },
      ],
    });

    expect(data.forms.single.code, '01/CNKD');
    expect(data.forms.single.isReady, isTrue);
    expect(data.supportLinks.single.colorRole, 'PRIMARY');
  });

  test('tax reference data fails closed when DB payload is incomplete', () {
    expect(
      () => TaxReferenceData.fromJson({'forms': [], 'supportLinks': []}),
      throwsFormatException,
    );
  });
}
