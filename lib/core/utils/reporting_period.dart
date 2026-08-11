/// Shared reporting-period rules used by Dashboard, Sales and Finance.
///
/// Keeping date boundaries in one place prevents screens from silently using
/// different periods for metrics that users expect to reconcile.
({String from, String to}) currentMonthReportingPeriod(DateTime now) {
  final from = DateTime(now.year, now.month, 1);
  return (
    from: from.toIso8601String().split('T')[0],
    to: now.toIso8601String().split('T')[0],
  );
}

typedef ComparisonReportingDates = ({
  String currentFrom,
  String currentTo,
  String previousFrom,
  String previousTo,
});

/// Produces like-for-like comparison windows.
///
/// A partial current week, month, or year is compared with the same elapsed
/// portion of the previous period instead of a misleading full period.
ComparisonReportingDates comparisonReportingDates(String filter, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);

  if (filter == 'week') {
    final currentFrom = today.subtract(Duration(days: today.weekday - 1));
    final previousFrom = currentFrom.subtract(const Duration(days: 7));
    return (
      currentFrom: _dateOnly(currentFrom),
      currentTo: _dateOnly(today),
      previousFrom: _dateOnly(previousFrom),
      previousTo: _dateOnly(
        previousFrom.add(Duration(days: today.weekday - 1)),
      ),
    );
  }

  if (filter == '6_months') {
    return (
      currentFrom: _dateOnly(DateTime(today.year, today.month - 5, 1)),
      currentTo: _dateOnly(today),
      previousFrom: _dateOnly(DateTime(today.year, today.month - 11, 1)),
      previousTo: _dateOnly(_shiftMonthsClamped(today, -6)),
    );
  }

  if (filter == 'year') {
    return (
      currentFrom: _dateOnly(DateTime(today.year, 1, 1)),
      currentTo: _dateOnly(today),
      previousFrom: _dateOnly(DateTime(today.year - 1, 1, 1)),
      previousTo: _dateOnly(_shiftYearsClamped(today, -1)),
    );
  }

  return (
    currentFrom: _dateOnly(DateTime(today.year, today.month, 1)),
    currentTo: _dateOnly(today),
    previousFrom: _dateOnly(DateTime(today.year, today.month - 1, 1)),
    previousTo: _dateOnly(_shiftMonthsClamped(today, -1)),
  );
}

DateTime _shiftMonthsClamped(DateTime value, int monthDelta) {
  final targetMonthStart = DateTime(value.year, value.month + monthDelta, 1);
  final targetMonthEnd = DateTime(
    targetMonthStart.year,
    targetMonthStart.month + 1,
    0,
  );
  final day = value.day > targetMonthEnd.day ? targetMonthEnd.day : value.day;
  return DateTime(targetMonthStart.year, targetMonthStart.month, day);
}

DateTime _shiftYearsClamped(DateTime value, int yearDelta) {
  final targetYear = value.year + yearDelta;
  final targetMonthEnd = DateTime(targetYear, value.month + 1, 0);
  final day = value.day > targetMonthEnd.day ? targetMonthEnd.day : value.day;
  return DateTime(targetYear, value.month, day);
}

String _dateOnly(DateTime value) => value.toIso8601String().split('T').first;

String reportingRangeLabel(DateTime from, DateTime to) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final start = from.year == to.year
      ? '${twoDigits(from.day)}/${twoDigits(from.month)}'
      : '${twoDigits(from.day)}/${twoDigits(from.month)}/${from.year}';
  final end = '${twoDigits(to.day)}/${twoDigits(to.month)}/${to.year}';
  return '$start–$end';
}

String reportingCompactRangeLabel(DateTime from, DateTime to) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  if (from.year == to.year && from.month == to.month) {
    return '${twoDigits(from.day)}–${twoDigits(to.day)}/${twoDigits(to.month)}';
  }
  if (from.year == to.year) {
    return '${twoDigits(from.day)}/${twoDigits(from.month)}–'
        '${twoDigits(to.day)}/${twoDigits(to.month)}';
  }
  return '${twoDigits(from.day)}/${twoDigits(from.month)}/${from.year}–'
      '${twoDigits(to.day)}/${twoDigits(to.month)}/${to.year}';
}
