import 'package:intl/intl.dart';

String activityLogDateLabel(DateTime date, DateTime now) {
  final day = DateTime.utc(date.year, date.month, date.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  final elapsed = today.difference(day).inDays;
  if (elapsed == 0) return 'Hôm nay';
  if (elapsed == 1) return 'Hôm qua';
  return DateFormat('dd/MM/yyyy').format(date);
}
