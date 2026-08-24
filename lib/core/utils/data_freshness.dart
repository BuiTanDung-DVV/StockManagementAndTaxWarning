enum DataFreshnessState {
  current,
  incompletePeriod,
  missingPeriod,
  unavailable,
}

class DataFreshnessAssessment {
  final DataFreshnessState state;
  final DateTime? latestDate;
  final int daysBehind;

  const DataFreshnessAssessment({
    required this.state,
    required this.latestDate,
    required this.daysBehind,
  });

  bool get requiresAttention => state != DataFreshnessState.current;
}

DataFreshnessAssessment assessDataFreshness({
  required dynamic latestDate,
  required DateTime periodFrom,
  required DateTime periodTo,
  required int recordCount,
}) {
  final parsed = DateTime.tryParse(latestDate?.toString() ?? '');
  if (parsed == null) {
    return const DataFreshnessAssessment(
      state: DataFreshnessState.unavailable,
      latestDate: null,
      daysBehind: 0,
    );
  }

  DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  final latest = dateOnly(parsed);
  final from = dateOnly(periodFrom);
  final to = dateOnly(periodTo);
  final daysBehind = to.difference(latest).inDays.clamp(0, 1000000);

  if (recordCount == 0 && latest.isBefore(from)) {
    return DataFreshnessAssessment(
      state: DataFreshnessState.missingPeriod,
      latestDate: latest,
      daysBehind: daysBehind,
    );
  }
  if (latest.isBefore(to)) {
    return DataFreshnessAssessment(
      state: DataFreshnessState.incompletePeriod,
      latestDate: latest,
      daysBehind: daysBehind,
    );
  }
  return DataFreshnessAssessment(
    state: DataFreshnessState.current,
    latestDate: latest,
    daysBehind: 0,
  );
}
