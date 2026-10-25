import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/app_language.dart';

/// [amount] as the Vietnamese app shows it ("1.000.000 đ"), with a minus in front only when it is below zero.
String vnd(double amount) => CurrencyHelper.formatVND(
  amount,
  AppLanguage.vietnamese.localizations,
  showSign: amount < 0,
);
