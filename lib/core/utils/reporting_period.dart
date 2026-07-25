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
