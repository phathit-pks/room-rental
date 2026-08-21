String formatRelativeDate(DateTime date, {DateTime? relativeTo}) {
  final now = relativeTo ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final difference = target.difference(today).inDays;

  if (difference == 0) return 'วันนี้';

  final future = difference > 0;
  final days = difference.abs();
  final value = switch (days) {
    < 30 => '$days วัน',
    < 365 => '${_monthDifference(today, target).abs()} เดือน',
    _ => '${_yearDifference(today, target).abs()} ปี',
  };

  return future ? 'อีก $value' : '$valueที่แล้ว';
}

int _monthDifference(DateTime from, DateTime to) {
  final months = (to.year - from.year) * 12 + to.month - from.month;
  if (months == 0) return to.isAfter(from) ? 1 : -1;
  return months;
}

int _yearDifference(DateTime from, DateTime to) {
  final years = to.year - from.year;
  if (years == 0) return to.isAfter(from) ? 1 : -1;
  return years;
}
