import 'package:flutter_app/core/utils/reporting_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('current month period uses the same inclusive day boundaries', () {
    final period = currentMonthReportingPeriod(DateTime(2026, 7, 25, 23, 59));

    expect(period.from, '2026-07-01');
    expect(period.to, '2026-07-25');
  });

  test('current month period handles January without crossing year', () {
    final period = currentMonthReportingPeriod(DateTime(2027, 1, 2));

    expect(period.from, '2027-01-01');
    expect(period.to, '2027-01-02');
  });
}
