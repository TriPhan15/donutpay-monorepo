import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/core/utils/money_input_formatter.dart';
import 'package:finance_ai_app/models/app_language.dart';

TextEditingValue _value(String text, [int? caret]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: caret ?? text.length),
);

void main() {
  final vi = MoneyInputFormatter('vi');
  final en = MoneyInputFormatter('en');

  TextEditingValue type(
    MoneyInputFormatter formatter,
    TextEditingValue before,
    TextEditingValue after,
  ) => formatter.formatEditUpdate(before, after);

  group('grouping while typing', () {
    test('groups with dots in Vietnamese and commas in English', () {
      expect(type(vi, _value('100.000'), _value('1000000')).text, '1.000.000');
      expect(type(en, _value('100,000'), _value('1000000')).text, '1,000,000');
    });

    test('uses the same grouping as CurrencyHelper.formatVND', () {
      for (final language in AppLanguage.values) {
        final loc = language.localizations;
        final typed = MoneyInputFormatter(
          loc.localeName,
        ).formatEditUpdate(TextEditingValue.empty, _value('1234567')).text;
        expect(
          CurrencyHelper.formatVND(1234567, loc, showSign: false),
          loc.currencyVnd(typed),
        );
      }
    });

    test(
      'drops everything that is not a digit, and the zeros in front of the number',
      () {
        expect(type(vi, _value(''), _value('12a3 đ')).text, '123');
        expect(type(vi, _value('0'), _value('05')).text, '5');
        expect(type(vi, _value(''), _value('0')).text, '0');
      },
    );

    test('an empty or digit-free field ends up empty', () {
      expect(type(vi, _value('5'), _value('')), TextEditingValue.empty);
      expect(type(vi, _value(''), _value('abc')), TextEditingValue.empty);
    });

    test('refuses more than maxDigits digits and keeps what was there', () {
      final full = _value('999.999.999.999.999');
      final result = type(vi, full, _value('9999999999999999'));
      expect(result, full);
    });
  });

  group('the caret', () {
    test('stays at the end when typing at the end', () {
      final result = type(vi, _value('1.234'), _value('1.2345'));
      expect(result.text, '12.345');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('keeps the digits on its right when typing in the middle', () {
      // "1|.000" + "5" -> "15.000" with the caret before the three zeros.
      final result = type(vi, _value('1.000', 1), _value('15.000', 2));
      expect(result.text, '15.000');
      expect(result.text.substring(result.selection.baseOffset), '000');
    });

    test('a backspace on a separator deletes the digit in front of it', () {
      // "1.|000", backspace removes the dot: the 1 goes, not the dot.
      final result = type(vi, _value('1.000', 2), _value('1000', 1));
      expect(result.text, '0');
    });

    test('replacing the whole text with one digit fewer is not taken for a backspace', () {
      expect(type(vi, _value('45.000'), _value('50000')).text, '50.000');
      expect(type(en, _value('45,000'), _value('50000')).text, '50,000');
    });

    test('a backspace on a separator in a longer number', () {
      // "12.|345" -> backspace -> "1.345" with the caret before 345.
      final result = type(vi, _value('12.345', 3), _value('12345', 2));
      expect(result.text, '1.345');
      expect(result.text.substring(result.selection.baseOffset), '345');
    });
  });

  group('MoneyInputFormatter.parse', () {
    test('reads back what either language grouped', () {
      expect(MoneyInputFormatter.parse('45000'), 45000.0);
      expect(MoneyInputFormatter.parse(' 1.250.000 đ '), 1250000.0);
      expect(MoneyInputFormatter.parse('2,500,000'), 2500000.0);
    });

    test('is null for an empty field, text without digits, and zero', () {
      expect(MoneyInputFormatter.parse(''), isNull);
      expect(MoneyInputFormatter.parse('abc'), isNull);
      expect(MoneyInputFormatter.parse('0'), isNull);
      expect(MoneyInputFormatter.parse('000'), isNull);
    });
  });

  group('MoneyInputFormatter.format', () {
    test('shows a starting amount rounded to whole dong', () {
      expect(MoneyInputFormatter.format(45000.5, 'vi'), '45.001');
      expect(MoneyInputFormatter.format(45000, 'en'), '45,000');
    });
  });
}
