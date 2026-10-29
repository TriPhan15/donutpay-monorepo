import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/spending_range.dart';

/// A Wednesday: its week runs from Monday 21 to Sunday 27 September 2026 and its month from the 1st to the 30th.
final DateTime _wednesday = DateTime(2026, 9, 23, 14, 30);

final AppLocalizations _vi = lookupAppLocalizations(const Locale('vi'));

void main() {
  group('SpendingRange.week', () {
    test(
      'runs from the Monday to the Sunday around the given day, both at midnight',
      () {
        final range = SpendingRange.week(_wednesday);

        expect(range.period, SpendingPeriod.week);
        expect(range.start, DateTime(2026, 9, 21));
        expect(range.end, DateTime(2026, 9, 27));
        expect(range.days, 7);
        expect(range.label, '21/09/2026 - 27/09/2026');
      },
    );

    test(
      'a Monday and a Sunday belong to their own week, not to a neighbouring one',
      () {
        expect(
          SpendingRange.week(DateTime(2026, 9, 21)).start,
          DateTime(2026, 9, 21),
        );
        expect(
          SpendingRange.week(DateTime(2026, 9, 27, 23, 59)).start,
          DateTime(2026, 9, 21),
        );
        expect(
          SpendingRange.week(DateTime(2026, 9, 28)).start,
          DateTime(2026, 9, 28),
        );
      },
    );

    test('a week can begin in the month before', () {
      final range = SpendingRange.week(DateTime(2026, 10, 1));

      expect(range.start, DateTime(2026, 9, 28));
      expect(range.end, DateTime(2026, 10, 4));
    });
  });

  group('SpendingRange.month', () {
    test('runs from the first to the last day of the month', () {
      final range = SpendingRange.month(_wednesday);

      expect(range.period, SpendingPeriod.month);
      expect(range.start, DateTime(2026, 9, 1));
      expect(range.end, DateTime(2026, 9, 30));
      expect(range.days, 30);
      expect(range.label, '01/09/2026 - 30/09/2026');
    });

    test('knows how long February and December are', () {
      expect(
        SpendingRange.month(DateTime(2028, 2, 10)).end,
        DateTime(2028, 2, 29),
      );
      expect(
        SpendingRange.month(DateTime(2027, 2, 10)).end,
        DateTime(2027, 2, 28),
      );
      expect(
        SpendingRange.month(DateTime(2026, 12, 31)).end,
        DateTime(2026, 12, 31),
      );
    });
  });

  group('SpendingRange.custom', () {
    test('takes the days as they are and drops the time of day', () {
      final range = SpendingRange.custom(
        DateTime(2026, 9, 20, 7, 15),
        DateTime(2026, 9, 25, 18, 30),
      );

      expect(range.period, SpendingPeriod.custom);
      expect(range.start, DateTime(2026, 9, 20));
      expect(range.end, DateTime(2026, 9, 25));
      expect(range.days, 6);
    });

    test('puts the two days in order when they come reversed', () {
      final range = SpendingRange.custom(
        DateTime(2026, 9, 25),
        DateTime(2026, 9, 20),
      );

      expect(range.start, DateTime(2026, 9, 20));
      expect(range.end, DateTime(2026, 9, 25));
    });

    test('one day is a range of one day', () {
      final range = SpendingRange.custom(
        DateTime(2026, 9, 20, 8),
        DateTime(2026, 9, 20, 22),
      );

      expect(range.days, 1);
      expect(range.label, '20/09/2026 - 20/09/2026');
    });

    test('counts every day of a range that crosses a year end', () {
      expect(
        SpendingRange.custom(DateTime(2026, 12, 30), DateTime(2027, 1, 2)).days,
        4,
      );
    });
  });

  group('SpendingRange.of', () {
    test('gives the week or the month as of the given day', () {
      expect(
        SpendingRange.of(SpendingPeriod.week, _wednesday),
        SpendingRange.week(_wednesday),
      );
      expect(
        SpendingRange.of(SpendingPeriod.month, _wednesday),
        SpendingRange.month(_wednesday),
      );
    });

    test(
      'a custom period uses the range the user picked, and the month while none is picked',
      () {
        final picked = SpendingRange.custom(
          DateTime(2026, 8, 1),
          DateTime(2026, 8, 15),
        );

        expect(
          SpendingRange.of(SpendingPeriod.custom, _wednesday, custom: picked),
          picked,
        );
        expect(
          SpendingRange.of(SpendingPeriod.custom, _wednesday),
          SpendingRange.month(_wednesday),
        );
      },
    );

    test('follows the clock: the month of another day is another range', () {
      expect(
        SpendingRange.of(SpendingPeriod.month, DateTime(2026, 10, 2)).start,
        DateTime(2026, 10, 1),
      );
    });
  });

  group('equality', () {
    test('ranges of the same period over the same days are equal', () {
      expect(
        SpendingRange.week(_wednesday),
        SpendingRange.week(DateTime(2026, 9, 25)),
      );
      expect(
        SpendingRange.week(_wednesday).hashCode,
        SpendingRange.week(DateTime(2026, 9, 25)).hashCode,
      );
    });

    test(
      'a week and a custom range over the same days are different ranges',
      () {
        final week = SpendingRange.week(_wednesday);

        expect(SpendingRange.custom(week.start, week.end), isNot(week));
      },
    );

    test('other days are other ranges', () {
      expect(
        SpendingRange.week(_wednesday),
        isNot(SpendingRange.week(DateTime(2026, 9, 30))),
      );
    });
  });

  group('SpendingRange.contains', () {
    final september = SpendingRange.month(_wednesday);

    test('includes the first and the last day at any time of day', () {
      expect(september.contains(DateTime(2026, 9, 1)), isTrue);
      expect(september.contains(DateTime(2026, 9, 1, 0, 0, 1)), isTrue);
      expect(september.contains(DateTime(2026, 9, 30, 23, 59, 59)), isTrue);
    });

    test('leaves out the day before and the day after', () {
      expect(september.contains(DateTime(2026, 8, 31, 23, 59, 59)), isFalse);
      expect(september.contains(DateTime(2026, 10, 1)), isFalse);
    });
  });

  group('SpendingBucket.contains', () {
    final bucket = SpendingBucket(
      label: 'W2',
      start: DateTime(2026, 9, 8),
      end: DateTime(2026, 9, 15),
    );

    test(
      'includes the days from the start up to the day before the end, at any time of day',
      () {
        expect(bucket.contains(DateTime(2026, 9, 8)), isTrue);
        expect(bucket.contains(DateTime(2026, 9, 14, 23, 59, 59)), isTrue);
      },
    );

    test('leaves out the day before the start and the end day itself', () {
      expect(bucket.contains(DateTime(2026, 9, 7, 23, 59, 59)), isFalse);
      expect(bucket.contains(DateTime(2026, 9, 15)), isFalse);
    });
  });

  group('dayBuckets', () {
    void expectContiguous(SpendingRange range, List<SpendingBucket> buckets) {
      expect(buckets.first.start, range.start);
      expect(
        buckets.last.end,
        DateTime(range.end.year, range.end.month, range.end.day + 1),
      );
      for (var i = 1; i < buckets.length; i++) {
        expect(buckets[i].start, buckets[i - 1].end, reason: 'bucket $i');
      }
    }

    test('a week is its seven days, named after their weekdays', () {
      final range = SpendingRange.week(DateTime(2026, 10, 21));
      final buckets = range.dayBuckets(_vi);

      expect(buckets.map((b) => b.label), [
        'T2',
        'T3',
        'T4',
        'T5',
        'T6',
        'T7',
        'CN',
      ]);
      expect(buckets.first.start, DateTime(2026, 10, 19));
      expectContiguous(range, buckets);
    });

    test('a month is one point per day, labelled dd/MM', () {
      final range = SpendingRange.month(DateTime(2026, 2, 10));
      final buckets = range.dayBuckets(_vi);

      expect(buckets, hasLength(28));
      expect(buckets.first.label, '01/02');
      expect(buckets.last.label, '28/02');
      expectContiguous(range, buckets);
    });

    test('a month of 31 days still has one point per day', () {
      expect(
        SpendingRange.month(DateTime(2026, 10, 1)).dayBuckets(_vi),
        hasLength(31),
      );
    });

    test(
      'a long custom range groups days so that it stays within 31 points',
      () {
        final range = SpendingRange.custom(
          DateTime(2026, 1, 1),
          DateTime(2026, 3, 3),
        );
        final buckets = range.dayBuckets(_vi);

        expect(range.days, 62);
        expect(buckets, hasLength(31));
        expect(buckets[1].start, DateTime(2026, 1, 3));
        expectContiguous(range, buckets);
      },
    );

    test(
      'the last group of an uneven range is shorter and ends with the range',
      () {
        final range = SpendingRange.custom(
          DateTime(2026, 1, 1),
          DateTime(2026, 12, 31),
        );
        final buckets = range.dayBuckets(_vi);

        expect(buckets.length, lessThanOrEqualTo(31));
        expectContiguous(range, buckets);
      },
    );

    test('a range of more than a year names its points with the year', () {
      final range = SpendingRange.custom(
        DateTime(2025, 1, 1),
        DateTime(2026, 6, 30),
      );
      final labels = range.dayBuckets(_vi).map((b) => b.label).toList();

      expect(labels.first, '01/01/25');
      expect(labels.toSet(), hasLength(labels.length));
    });

    test('a short custom range of one day is one point', () {
      final range = SpendingRange.custom(
        DateTime(2026, 5, 5),
        DateTime(2026, 5, 5),
      );
      expect(range.dayBuckets(_vi).single.label, '05/05');
    });
  });
}
