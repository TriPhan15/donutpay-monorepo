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

  group('CurrencyHelper.formatCompactVND', () {
    final vi = AppLanguage.vietnamese.localizations;
    final en = AppLanguage.english.localizations;

    test(
      'compact amounts pick the largest unit that still rounds to at least 1',
      () {
        expect(CurrencyHelper.formatCompactVND(850000, vi), '850k');
        expect(CurrencyHelper.formatCompactVND(18500000, vi), '18,5 tr');
        expect(CurrencyHelper.formatCompactVND(6020000, vi), '6,02 tr');
        expect(CurrencyHelper.formatCompactVND(1985000, vi), '1,99 tr');
        expect(CurrencyHelper.formatCompactVND(999999, vi), '1 tr');
        expect(CurrencyHelper.formatCompactVND(1200000000, vi), '1,2 tỷ');
        expect(CurrencyHelper.formatCompactVND(-400000, vi), '-400k');
        expect(
          CurrencyHelper.formatCompactVND(999, vi),
          CurrencyHelper.formatVND(999, vi, showSign: false),
        );
        expect(CurrencyHelper.formatCompactVND(18500000, en), '18.5M');
        expect(CurrencyHelper.formatCompactVND(850000, en), '850K');
      },
    );

    test('a small negative amount keeps its minus', () {
      expect(CurrencyHelper.formatCompactVND(-999, vi), vi.currencyVnd('-999'));
    });
  });
}
