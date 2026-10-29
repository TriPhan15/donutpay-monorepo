import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/models/notification_age.dart';

void main() {
  final now = DateTime(2026, 10, 29, 9);

  test('the same calendar day is today, from its first to its last minute', () {
    expect(
      NotificationAge.of(DateTime(2026, 10, 29, 0, 1), now),
      NotificationAge.today,
    );
    expect(
      NotificationAge.of(DateTime(2026, 10, 29, 23, 59), now),
      NotificationAge.today,
    );
  });

  test('the calendar day before is yesterday, however late or early', () {
    expect(
      NotificationAge.of(DateTime(2026, 10, 28, 23, 59), now),
      NotificationAge.yesterday,
    );
    expect(
      NotificationAge.of(DateTime(2026, 10, 28), now),
      NotificationAge.yesterday,
    );
  });

  test('earlier days of the same year are this year', () {
    expect(
      NotificationAge.of(DateTime(2026, 10, 27, 23), now),
      NotificationAge.thisYear,
    );
    expect(
      NotificationAge.of(DateTime(2026, 1, 1), now),
      NotificationAge.thisYear,
    );
  });

  test('a day of an earlier year is older', () {
    expect(
      NotificationAge.of(DateTime(2025, 12, 31, 23), now),
      NotificationAge.older,
    );
  });

  test('yesterday crosses the end of a month and of a year', () {
    expect(
      NotificationAge.of(DateTime(2026, 2, 28, 12), DateTime(2026, 3, 1)),
      NotificationAge.yesterday,
    );
    expect(
      NotificationAge.of(DateTime(2026, 12, 31, 22), DateTime(2027, 1, 1, 8)),
      NotificationAge.yesterday,
    );
  });

  test('a time after now (clock skew) counts as today', () {
    expect(
      NotificationAge.of(DateTime(2026, 10, 30, 1), now),
      NotificationAge.today,
    );
  });
}
