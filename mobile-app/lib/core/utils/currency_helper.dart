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
}
