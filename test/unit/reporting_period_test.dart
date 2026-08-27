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

  test('partial week compares the same weekdays from the previous week', () {
    final dates = comparisonReportingDates('week', DateTime(2026, 8, 6));

    expect(dates.currentFrom, '2026-08-03');
    expect(dates.currentTo, '2026-08-06');
    expect(dates.previousFrom, '2026-07-27');
    expect(dates.previousTo, '2026-07-30');
  });

  test('partial month compares the same elapsed days', () {
    final dates = comparisonReportingDates('month', DateTime(2026, 8, 9));

    expect(dates.currentFrom, '2026-08-01');
    expect(dates.currentTo, '2026-08-09');
    expect(dates.previousFrom, '2026-07-01');
    expect(dates.previousTo, '2026-07-09');
  });

  test('month comparison clamps dates at the previous month end', () {
    final dates = comparisonReportingDates('month', DateTime(2026, 3, 31));

    expect(dates.previousFrom, '2026-02-01');
    expect(dates.previousTo, '2026-02-28');
  });

  test('year comparison uses year-to-date and handles leap day', () {
    final dates = comparisonReportingDates('year', DateTime(2024, 2, 29));

    expect(dates.currentFrom, '2024-01-01');
    expect(dates.currentTo, '2024-02-29');
    expect(dates.previousFrom, '2023-01-01');
    expect(dates.previousTo, '2023-02-28');
  });

  test('six-month comparison uses the same partial ending month', () {
    final dates = comparisonReportingDates('6_months', DateTime(2026, 8, 9));

    expect(dates.currentFrom, '2026-03-01');
    expect(dates.currentTo, '2026-08-09');
    expect(dates.previousFrom, '2025-09-01');
    expect(dates.previousTo, '2026-02-09');
  });

  test('range labels expose exact partial-period boundaries', () {
    expect(
      reportingRangeLabel(DateTime(2026, 8, 1), DateTime(2026, 8, 9)),
      '01/08–09/08/2026',
    );
    expect(
      reportingRangeLabel(DateTime(2025, 9, 1), DateTime(2026, 2, 9)),
      '01/09/2025–09/02/2026',
    );
  });

  test('compact range labels fit KPI cards without losing date scope', () {
    expect(
      reportingCompactRangeLabel(DateTime(2026, 8, 1), DateTime(2026, 8, 9)),
      '01–09/08',
    );
    expect(
      reportingCompactRangeLabel(DateTime(2026, 7, 27), DateTime(2026, 8, 2)),
      '27/07–02/08',
    );
  });

  test('quarter selection uses elapsed days and previous quarter', () {
    final result = resolveReportingPeriods(
      ReportingPeriodSelection(
        periodType: ReportingPeriodType.quarter,
        anchorDate: DateTime(2026, 8, 26),
        comparisonType: ReportingComparisonType.previousPeriod,
      ),
      today: DateTime(2026, 8, 26),
    );

    expect(result.currentFrom, DateTime(2026, 7, 1));
    expect(result.currentTo, DateTime(2026, 8, 26));
    expect(result.comparisonFrom, DateTime(2026, 4, 1));
    expect(result.comparisonTo, DateTime(2026, 5, 26));
  });

  test('same period last year keeps like-for-like boundaries', () {
    final result = resolveReportingPeriods(
      ReportingPeriodSelection(
        periodType: ReportingPeriodType.month,
        anchorDate: DateTime(2026, 8, 26),
        comparisonType: ReportingComparisonType.samePeriodLastYear,
      ),
      today: DateTime(2026, 8, 26),
    );

    expect(result.currentFrom, DateTime(2026, 8, 1));
    expect(result.currentTo, DateTime(2026, 8, 26));
    expect(result.comparisonFrom, DateTime(2025, 8, 1));
    expect(result.comparisonTo, DateTime(2025, 8, 26));
  });

  test('custom comparison accepts an explicit date range', () {
    final result = resolveReportingPeriods(
      ReportingPeriodSelection(
        periodType: ReportingPeriodType.day,
        anchorDate: DateTime(2026, 8, 26),
        comparisonType: ReportingComparisonType.custom,
        customComparisonFrom: DateTime(2026, 7, 10),
        customComparisonTo: DateTime(2026, 7, 16),
      ),
      today: DateTime(2026, 8, 26),
    );

    expect(result.currentFrom, DateTime(2026, 8, 26));
    expect(result.currentTo, DateTime(2026, 8, 26));
    expect(result.comparisonFrom, DateTime(2026, 7, 10));
    expect(result.comparisonTo, DateTime(2026, 7, 16));
  });

  test('custom comparison editor starts with the complete previous period', () {
    final initial = reportingInitialCustomComparison(
      ReportingPeriodSelection(
        periodType: ReportingPeriodType.month,
        anchorDate: DateTime(2026, 8, 26),
        comparisonType: ReportingComparisonType.previousPeriod,
      ),
      today: DateTime(2026, 8, 26),
    );

    expect(initial.from, DateTime(2026, 7, 1));
    expect(initial.to, DateTime(2026, 7, 26));
  });

  test('selection labels distinguish the current operational period', () {
    final selection = ReportingPeriodSelection(
      periodType: ReportingPeriodType.quarter,
      anchorDate: DateTime(2026, 8, 1),
      comparisonType: ReportingComparisonType.previousPeriod,
    );

    expect(
      reportingPeriodSelectionLabel(selection, DateTime(2026, 8, 26)),
      'Quý này',
    );
  });
}
