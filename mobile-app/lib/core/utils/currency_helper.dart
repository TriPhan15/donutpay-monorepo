import 'package:intl/intl.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';

class CurrencyHelper {
  /// [amount] in VND, the unit of the app in every language, with thousands grouped the way the language of [loc]
  /// groups them (dots in Vietnamese, commas in English) and, unless [showSign]
  /// is false, a + or - in front. The unit is placed the way [loc] words it.
  static String formatVND(
    double amount,
    AppLocalizations loc, {
    bool showSign = true,
  }) {
    final isNegative = amount < 0;
    final formatted = NumberFormat.decimalPattern(
      loc.localeName,
    ).format(amount.abs().round());

    if (formatted == '0' || !showSign) return loc.currencyVnd(formatted);

    return loc.currencyVnd(isNegative ? '-$formatted' : '+$formatted');
  }

  /// [amount] shortened to the largest unit (billion, million, thousand) that still rounds to at least 1, with at
  /// most two decimals: "18,5 tr", "850k" in Vietnamese, "18.5M", "850K" in English. Below a thousand dong it is the full
  /// amount. Never a + in front; a - when below zero.
  static String formatCompactVND(double amount, AppLocalizations loc) {
    final units = <(double, String Function(String))>[
      (1e9, loc.currencyBillionShort),
      (1e6, loc.currencyMillionShort),
      (1e3, loc.currencyThousandShort),
    ];
    final abs = amount.abs();
    if (abs < 1e3) {
      // Whole dong, with the - kept for a negative amount.
      return formatVND(amount, loc, showSign: amount < 0);
    }
    for (final (size, wording) in units) {
      final scaled = (abs / size * 100).round() / 100;
      if (scaled >= 1) {
        final number = NumberFormat('#,##0.##', loc.localeName).format(scaled);
        return wording(amount < 0 ? '-$number' : number);
      }
    }
    return formatVND(amount, loc, showSign: amount < 0);
  }
}
