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

enum ReportingPeriodType { day, week, month, quarter, year }

enum ReportingComparisonType { previousPeriod, samePeriodLastYear, custom }

class ReportingPeriodSelection {
  final ReportingPeriodType periodType;
  final DateTime anchorDate;
  final ReportingComparisonType comparisonType;
  final DateTime? customComparisonFrom;
  final DateTime? customComparisonTo;

  const ReportingPeriodSelection({
    required this.periodType,
    required this.anchorDate,
    required this.comparisonType,
    this.customComparisonFrom,
    this.customComparisonTo,
  });

  ReportingPeriodSelection copyWith({
    ReportingPeriodType? periodType,
    DateTime? anchorDate,
    ReportingComparisonType? comparisonType,
    DateTime? customComparisonFrom,
    DateTime? customComparisonTo,
    bool clearCustomComparison = false,
  }) => ReportingPeriodSelection(
    periodType: periodType ?? this.periodType,
    anchorDate: anchorDate ?? this.anchorDate,
    comparisonType: comparisonType ?? this.comparisonType,
    customComparisonFrom: clearCustomComparison
        ? null
        : customComparisonFrom ?? this.customComparisonFrom,
    customComparisonTo: clearCustomComparison
        ? null
        : customComparisonTo ?? this.customComparisonTo,
  );
}

class ResolvedReportingPeriods {
  final DateTime currentFrom;
  final DateTime currentTo;
  final DateTime comparisonFrom;
  final DateTime comparisonTo;

  const ResolvedReportingPeriods({
    required this.currentFrom,
    required this.currentTo,
    required this.comparisonFrom,
    required this.comparisonTo,
  });
}

({DateTime from, DateTime to}) reportingInitialCustomComparison(
  ReportingPeriodSelection selection, {
  required DateTime today,
}) {
  if (selection.customComparisonFrom != null &&
      selection.customComparisonTo != null) {
    final from = _dayOnly(selection.customComparisonFrom!);
    final to = _dayOnly(selection.customComparisonTo!);
    return from.isAfter(to) ? (from: to, to: from) : (from: from, to: to);
  }
  final resolved = resolveReportingPeriods(selection, today: today);
  return (from: resolved.comparisonFrom, to: resolved.comparisonTo);
}

/// Resolves the selected business period and a like-for-like comparison.
/// Past periods are complete; the active period only runs through today.
ResolvedReportingPeriods resolveReportingPeriods(
  ReportingPeriodSelection selection, {
  required DateTime today,
}) {
  final normalizedToday = _dayOnly(today);
  final anchor = _dayOnly(selection.anchorDate).isAfter(normalizedToday)
      ? normalizedToday
      : _dayOnly(selection.anchorDate);
  final current = _periodFor(selection.periodType, anchor, normalizedToday);

  late DateTime comparisonFrom;
  late DateTime comparisonTo;
  switch (selection.comparisonType) {
    case ReportingComparisonType.previousPeriod:
      final previous = _previousLikeForLike(selection.periodType, current);
      comparisonFrom = previous.$1;
      comparisonTo = previous.$2;
      break;
    case ReportingComparisonType.samePeriodLastYear:
      comparisonFrom = _shiftYearsClamped(current.$1, -1);
      comparisonTo = _shiftYearsClamped(current.$2, -1);
      break;
    case ReportingComparisonType.custom:
      final customFrom = selection.customComparisonFrom;
      final customTo = selection.customComparisonTo;
      if (customFrom == null || customTo == null) {
        final previous = _previousLikeForLike(selection.periodType, current);
        comparisonFrom = previous.$1;
        comparisonTo = previous.$2;
      } else {
        final from = _dayOnly(customFrom);
        final to = _dayOnly(customTo);
        comparisonFrom = from.isBefore(to) ? from : to;
        comparisonTo = from.isBefore(to) ? to : from;
      }
      break;
  }

  return ResolvedReportingPeriods(
    currentFrom: current.$1,
    currentTo: current.$2,
    comparisonFrom: comparisonFrom,
    comparisonTo: comparisonTo,
  );
}

(DateTime, DateTime) _periodFor(
  ReportingPeriodType type,
  DateTime anchor,
  DateTime today,
) {
  late DateTime from;
  late DateTime naturalTo;
  switch (type) {
    case ReportingPeriodType.day:
      from = anchor;
      naturalTo = anchor;
      break;
    case ReportingPeriodType.week:
      from = anchor.subtract(Duration(days: anchor.weekday - 1));
      naturalTo = from.add(const Duration(days: 6));
      break;
    case ReportingPeriodType.month:
      from = DateTime(anchor.year, anchor.month, 1);
      naturalTo = DateTime(anchor.year, anchor.month + 1, 0);
      break;
    case ReportingPeriodType.quarter:
      final startMonth = ((anchor.month - 1) ~/ 3) * 3 + 1;
      from = DateTime(anchor.year, startMonth, 1);
      naturalTo = DateTime(anchor.year, startMonth + 3, 0);
      break;
    case ReportingPeriodType.year:
      from = DateTime(anchor.year, 1, 1);
      naturalTo = DateTime(anchor.year, 12, 31);
      break;
  }
  final to = naturalTo.isAfter(today) ? today : naturalTo;
  return (from, to.isBefore(from) ? from : to);
}

(DateTime, DateTime) _previousLikeForLike(
  ReportingPeriodType type,
  (DateTime, DateTime) current,
) {
  switch (type) {
    case ReportingPeriodType.day:
      return (
        current.$1.subtract(const Duration(days: 1)),
        current.$2.subtract(const Duration(days: 1)),
      );
    case ReportingPeriodType.week:
      return (
        current.$1.subtract(const Duration(days: 7)),
        current.$2.subtract(const Duration(days: 7)),
      );
    case ReportingPeriodType.month:
      return (
        DateTime(current.$1.year, current.$1.month - 1, 1),
        _shiftMonthsClamped(current.$2, -1),
      );
    case ReportingPeriodType.quarter:
      return (
        DateTime(current.$1.year, current.$1.month - 3, 1),
        _shiftMonthsClamped(current.$2, -3),
      );
    case ReportingPeriodType.year:
      return (
        _shiftYearsClamped(current.$1, -1),
        _shiftYearsClamped(current.$2, -1),
      );
  }
}

String reportingPeriodTypeLabel(ReportingPeriodType type) => switch (type) {
  ReportingPeriodType.day => 'Ngày',
  ReportingPeriodType.week => 'Tuần',
  ReportingPeriodType.month => 'Tháng',
  ReportingPeriodType.quarter => 'Quý',
  ReportingPeriodType.year => 'Năm',
};

String reportingComparisonTypeLabel(ReportingComparisonType type) =>
    switch (type) {
      ReportingComparisonType.previousPeriod => 'Kỳ trước',
      ReportingComparisonType.samePeriodLastYear => 'Cùng kỳ năm trước',
      ReportingComparisonType.custom => 'Tự chọn',
    };

String reportingPeriodSelectionLabel(
  ReportingPeriodSelection selection,
  DateTime today,
) {
  final anchor = DateTime(
    selection.anchorDate.year,
    selection.anchorDate.month,
    selection.anchorDate.day,
  );
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final isCurrent = switch (selection.periodType) {
    ReportingPeriodType.day => anchor == normalizedToday,
    ReportingPeriodType.week =>
      anchor.subtract(Duration(days: anchor.weekday - 1)) ==
          normalizedToday.subtract(Duration(days: normalizedToday.weekday - 1)),
    ReportingPeriodType.month =>
      anchor.year == normalizedToday.year &&
          anchor.month == normalizedToday.month,
    ReportingPeriodType.quarter =>
      anchor.year == normalizedToday.year &&
          ((anchor.month - 1) ~/ 3) == ((normalizedToday.month - 1) ~/ 3),
    ReportingPeriodType.year => anchor.year == normalizedToday.year,
  };
  if (isCurrent) {
    return switch (selection.periodType) {
      ReportingPeriodType.day => 'Hôm nay',
      ReportingPeriodType.week => 'Tuần này',
      ReportingPeriodType.month => 'Tháng này',
      ReportingPeriodType.quarter => 'Quý này',
      ReportingPeriodType.year => 'Năm nay',
    };
  }
  return reportingPeriodTypeLabel(selection.periodType);
}

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

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

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
