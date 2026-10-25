import 'package:finance_ai_app/l10n/app_localizations.dart';

class DateHelper {
  /// "Today, HH:mm" or "Yesterday, HH:mm" in the language of [loc]; an older day as dd/MM/yyyy.
  static String formatTransactionDate(AppLocalizations loc, DateTime date) {
    final now = DateTime.now();

    final isSameDay =
        now.year == date.year && now.month == date.month && now.day == date.day;

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        yesterday.year == date.year &&
        yesterday.month == date.month &&
        yesterday.day == date.day;

    final timeString =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (isSameDay) {
      return loc.dateTodayAt(timeString);
    }

    if (isYesterday) {
      return loc.dateYesterdayAt(timeString);
    }

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
