import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/app_language.dart';

void main() {
  group('CurrencyHelper.formatVND', () {
    final vi = AppLanguage.vietnamese.localizations;
    final en = AppLanguage.english.localizations;

    test('groups thousands with dots in Vietnamese and commas in English', () {
      expect(
        CurrencyHelper.formatVND(1000000, vi, showSign: false),
        vi.currencyVnd('1.000.000'),
      );
      expect(
        CurrencyHelper.formatVND(1000000, en, showSign: false),
        en.currencyVnd('1,000,000'),
      );
    });

    test(
      'keeps the sign rules: + and - by default, none for zero or showSign false',
      () {
        expect(CurrencyHelper.formatVND(45000, vi), vi.currencyVnd('+45.000'));
        expect(CurrencyHelper.formatVND(-45000, en), en.currencyVnd('-45,000'));
        expect(CurrencyHelper.formatVND(0, vi), vi.currencyVnd('0'));
        expect(
          CurrencyHelper.formatVND(-45000, vi, showSign: false),
          vi.currencyVnd('45.000'),
        );
      },
    );

    test('rounds to whole dong', () {
      expect(
        CurrencyHelper.formatVND(1234.6, vi, showSign: false),
        vi.currencyVnd('1.235'),
      );
    });
  });
}
