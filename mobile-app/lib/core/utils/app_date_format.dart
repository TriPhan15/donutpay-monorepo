import 'package:intl/intl.dart';

/// The numeric date formats of the app, built once.
///
/// Every pattern here is digits and separators only: it names no month or day, so it reads the same in every language
/// of the app and a formatter built under one locale stays right under the other. A format that names a month or a
/// weekday (`MMMM yyyy`, `EEEE, HH:mm`) depends on the language: it is built where it is shown, with the locale of the
/// moment, and does not belong here.
class AppDateFormat {
  AppDateFormat._();

  /// 03/03/2026
  static final DateFormat date = DateFormat('dd/MM/yyyy');

  /// 03/03/2026 07:05
  static final DateFormat dateTime = DateFormat('dd/MM/yyyy HH:mm');

  /// 03/03/2026, 07:05
  static final DateFormat dateCommaTime = DateFormat('dd/MM/yyyy, HH:mm');

  /// 03/03
  static final DateFormat dayMonth = DateFormat('dd/MM');

  /// 03/03 07:05
  static final DateFormat dayMonthTime = DateFormat('dd/MM HH:mm');

  /// 03/03/26
  static final DateFormat dayMonthShortYear = DateFormat('dd/MM/yy');
}
