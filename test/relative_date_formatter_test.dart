import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/core/utils/relative_date_formatter.dart';

void main() {
  final now = DateTime(2026, 8, 6, 15);

  test('formats today', () {
    expect(formatRelativeDate(DateTime(2026, 8, 6), relativeTo: now), 'วันนี้');
  });

  test('formats past days', () {
    expect(
      formatRelativeDate(DateTime(2026, 8, 4), relativeTo: now),
      '2 วันที่แล้ว',
    );
  });

  test('formats future days', () {
    expect(
      formatRelativeDate(DateTime(2026, 8, 10), relativeTo: now),
      'อีก 4 วัน',
    );
  });

  test('formats future months', () {
    expect(
      formatRelativeDate(DateTime(2026, 10, 6), relativeTo: now),
      'อีก 2 เดือน',
    );
  });
}
