import 'package:intl/intl.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';

/// How the period of the spending report is chosen.
enum SpendingPeriod { week, month, custom }

/// One point of the daily chart: the days from [start] up to, but not including, [end].
class SpendingBucket {
  final String label;
  final DateTime start;
  final DateTime end;

  const SpendingBucket({
    required this.label,
    required this.start,
    required this.end,
  });

  /// Whether [date] is on one of the days of the bucket, whatever its time of day.
  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && day.isBefore(end);
  }
}

/// The days the spending report covers, the first and the last one included, and the points its chart is split into.
class SpendingRange {
  /// The daily chart shows at most this many points: a month has one per day.
  static const int maxDayPoints = 31;

  static final DateFormat _dayMonth = DateFormat('dd/MM');
  static final DateFormat _dayMonthYear = DateFormat('dd/MM/yy');

  /// A range longer than this names its points with the year, so that the same day of two years cannot be confused.
  static const int _daysPerYear = 365;
  static final DateFormat _fullDate = DateFormat('dd/MM/yyyy');

  final SpendingPeriod period;

  /// First day of the range, at midnight.
  final DateTime start;

  /// Last day of the range, at midnight. The day itself belongs to the range.
  final DateTime end;

  const SpendingRange._(this.period, this.start, this.end);

  /// The Monday-to-Sunday week that contains [now], the same week the Ledger shows.
  factory SpendingRange.week(DateTime now) {
    final monday = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - DateTime.monday),
    );
    return SpendingRange._(
      SpendingPeriod.week,
      monday,
      _shift(monday, DateTime.daysPerWeek - 1),
    );
  }

  /// The calendar month that contains [now].
  factory SpendingRange.month(DateTime now) => SpendingRange._(
    SpendingPeriod.month,
    DateTime(now.year, now.month, 1),
    DateTime(now.year, now.month + 1, 0),
  );

  /// The days from [from] to [to], both included. They may come in either order and at any time of day.
  factory SpendingRange.custom(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return a.isAfter(b)
        ? SpendingRange._(SpendingPeriod.custom, b, a)
        : SpendingRange._(SpendingPeriod.custom, a, b);
  }

  /// The range of [period] as of [now]. [custom] is the range the user picked, which only [SpendingPeriod.custom] uses;
  /// without one the month is reported.
  factory SpendingRange.of(
    SpendingPeriod period,
    DateTime now, {
    SpendingRange? custom,
  }) {
    switch (period) {
      case SpendingPeriod.week:
        return SpendingRange.week(now);
      case SpendingPeriod.month:
        return SpendingRange.month(now);
      case SpendingPeriod.custom:
        return custom ?? SpendingRange.month(now);
    }
  }

  /// How many days the range has. Counted between UTC dates, so a daylight saving change cannot skew it.
  int get days =>
      DateTime.utc(
        end.year,
        end.month,
        end.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
      1;

  /// The first and the last day as text, for example `21/09/2026 - 27/09/2026`.
  String get label => '${_fullDate.format(start)} - ${_fullDate.format(end)}';

  /// Whether [date] is on one of the days of the range, whatever its time of day.
  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  /// The points of the daily chart, in order, with no gap between them; together they cover exactly the days of the
  /// range. One point per day, unless the range has more than [maxPoints] days: then as few days per point as keep it
  /// within [maxPoints], the last point taking what is left. The week's points are named after their weekdays in the
  /// language of [loc], the others after their first day (dd/MM, dd/MM/yy for a range of more than a year).
  List<SpendingBucket> dayBuckets(
    AppLocalizations loc, {
    int maxPoints = maxDayPoints,
  }) {
    final endExclusive = _shift(end, 1);
    final daysPerBucket = (days / maxPoints).ceil();
    final count = (days / daysPerBucket).ceil();
    return List.generate(count, (i) {
      final from = _shift(start, i * daysPerBucket);
      final to = _shift(from, daysPerBucket);
      return SpendingBucket(
        label: period == SpendingPeriod.week
            ? _weekdayLabel(loc, from.weekday)
            : (days > _daysPerYear ? _dayMonthYear : _dayMonth).format(from),
        start: from,
        end: to.isAfter(endExclusive) ? endExclusive : to,
      );
    });
  }

  /// The short name of [weekday] (DateTime.monday ... DateTime.sunday).
  static String _weekdayLabel(AppLocalizations loc, int weekday) =>
      switch (weekday) {
        DateTime.monday => loc.weekdayShortMon,
        DateTime.tuesday => loc.weekdayShortTue,
        DateTime.wednesday => loc.weekdayShortWed,
        DateTime.thursday => loc.weekdayShortThu,
        DateTime.friday => loc.weekdayShortFri,
        DateTime.saturday => loc.weekdayShortSat,
        _ => loc.weekdayShortSun,
      };

  static DateTime _shift(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  @override
  bool operator ==(Object other) =>
      other is SpendingRange &&
      other.period == period &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(period, start, end);
}
