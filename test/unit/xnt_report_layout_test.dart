import 'package:flutter_app/features/inventory/presentation/xnt_report_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('XNT uses readable cards on mobile and a table on desktop', () {
    expect(xntUsesCardLayout(390), isTrue);
    expect(xntUsesCardLayout(719), isTrue);
    expect(xntUsesCardLayout(720), isFalse);
    expect(xntUsesCardLayout(1440), isFalse);
  });

  test('XNT quantities keep Vietnamese separators and decimal values', () {
    expect(formatXntQuantity(1234), '1.234');
    expect(formatXntQuantity(1234.5), '1.234,5');
    expect(formatXntQuantity('bad-data'), '0');
  });
}
