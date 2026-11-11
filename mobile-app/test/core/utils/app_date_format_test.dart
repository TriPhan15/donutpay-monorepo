import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/utils/app_date_format.dart';

void main() {
  // 3 March 2026, 07:05: single digits in the day, the month and the time, so that a missing zero padding shows.
  final date = DateTime(2026, 3, 3, 7, 5);

  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
    await initializeDateFormatting('en_US', null);
  });

  tearDown(() => Intl.defaultLocale = null);

  group('patterns', () {
    test('date is dd/MM/yyyy', () {
      expect(AppDateFormat.date.format(date), '03/03/2026');
    });

    test('dateTime is dd/MM/yyyy HH:mm', () {
      expect(AppDateFormat.dateTime.format(date), '03/03/2026 07:05');
    });

    test('dateCommaTime is dd/MM/yyyy, HH:mm', () {
      expect(AppDateFormat.dateCommaTime.format(date), '03/03/2026, 07:05');
    });

    test('dayMonth is dd/MM', () {
      expect(AppDateFormat.dayMonth.format(date), '03/03');
    });

    test('dayMonthTime is dd/MM HH:mm', () {
      expect(AppDateFormat.dayMonthTime.format(date), '03/03 07:05');
    });

    test('dayMonthShortYear is dd/MM/yy', () {
      expect(AppDateFormat.dayMonthShortYear.format(date), '03/03/26');
    });

    test('the hour is on 24 hours, the afternoon included', () {
      final afternoon = DateTime(2026, 12, 31, 23, 59);
      expect(AppDateFormat.dateTime.format(afternoon), '31/12/2026 23:59');
    });
  });

  group('parsing', () {
    test('date reads back what it wrote', () {
      expect(
        AppDateFormat.date.parseStrict('03/03/2026'),
        DateTime(2026, 3, 3),
      );
    });

    test('date refuses a text that is not dd/MM/yyyy', () {
      expect(
        () => AppDateFormat.date.parseStrict('2026-03-03'),
        throwsFormatException,
      );
      expect(
        () => AppDateFormat.date.parseStrict('31/02/2026'),
        throwsFormatException,
      );
    });
  });

  // The formatters are built once, so they must not depend on the locale of the moment they are first used.
  group('locale', () {
    final formatters = <String, DateFormat Function()>{
      'date': () => AppDateFormat.date,
      'dateTime': () => AppDateFormat.dateTime,
      'dateCommaTime': () => AppDateFormat.dateCommaTime,
      'dayMonth': () => AppDateFormat.dayMonth,
      'dayMonthTime': () => AppDateFormat.dayMonthTime,
      'dayMonthShortYear': () => AppDateFormat.dayMonthShortYear,
    };
    final patterns = <String, String>{
      'date': 'dd/MM/yyyy',
      'dateTime': 'dd/MM/yyyy HH:mm',
      'dateCommaTime': 'dd/MM/yyyy, HH:mm',
      'dayMonth': 'dd/MM',
      'dayMonthTime': 'dd/MM HH:mm',
      'dayMonthShortYear': 'dd/MM/yy',
    };

    test(
      'every formatter writes the same text as a new DateFormat in each language of the app',
      () {
        for (final locale in ['vi_VN', 'en_US']) {
          Intl.defaultLocale = locale;
          for (final entry in formatters.entries) {
            expect(
              entry.value().format(date),
              DateFormat(patterns[entry.key]!).format(date),
              reason: '${entry.key} under $locale',
            );
          }
        }
      },
    );

    test(
      'every formatter writes the same text under vi_VN, en_US and no default locale',
      () {
        final texts = <String, Set<String>>{};
        for (final locale in ['vi_VN', 'en_US', null]) {
          Intl.defaultLocale = locale;
          for (final entry in patterns.entries) {
            texts
                .putIfAbsent(entry.key, () => {})
                .add(DateFormat(entry.value).format(date));
          }
        }
        for (final entry in texts.entries) {
          expect(entry.value, hasLength(1), reason: entry.key);
        }
      },
    );
  });
}
