import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/utils/password_policy.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';

final AppLocalizations _vi = lookupAppLocalizations(const Locale('vi'));

// The cases mirror core-backend/.../Security/StrongPasswordTest.java: same boundaries, same verdicts.
void main() {
  _ruleTests();

  group('PasswordPolicy.validate accepts', () {
    final accepted = <String, String>{
      'the shortest allowed (8 characters)': 'abcdefg1',
      'letters, digits and symbols': 'Passw0rd!',
      'a digit first': '1234567a',
      'non-ASCII letters': 'Mật-khẩu-mạnh-2026',
      'the longest allowed (72 characters)': 'a1${'b' * 70}',
    };
    accepted.forEach((name, password) {
      test(name, () => expect(PasswordPolicy.validate(password, _vi), isNull));
    });
  });

  group('PasswordPolicy.validate rejects', () {
    const lengthMessage = 'Mật khẩu phải từ 8 đến 72 ký tự.';
    const letterAndDigitMessage =
        'Mật khẩu phải chứa ít nhất một chữ cái và một chữ số.';

    final rejected = <String, List<String>>{
      '7 characters': ['abcdef1', lengthMessage],
      '73 characters': ['a1${'b' * 71}', lengthMessage],
      'no digit': ['abcdefgh', letterAndDigitMessage],
      'no letter': ['12345678', letterAndDigitMessage],
      'symbols only': ['!@#\$%^&*()', letterAndDigitMessage],
    };
    rejected.forEach((name, expectation) {
      test(name, () {
        expect(PasswordPolicy.validate(expectation[0], _vi), expectation[1]);
      });
    });

    test('an empty password', () {
      expect(PasswordPolicy.validate('', _vi), 'Mật khẩu không được để trống.');
    });

    test('a password of spaces only', () {
      expect(
        PasswordPolicy.validate('        ', _vi),
        'Mật khẩu không được để trống.',
      );
    });
  });

  test('the messages follow the language', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(PasswordPolicy.validate('', en), en.passwordEmpty);
    expect(PasswordPolicy.validate('abcdef1', en), en.passwordLength(8, 72));
    expect(PasswordPolicy.validate('abcdefgh', en), en.passwordLetterAndDigit);
  });

  test('the boundaries are the ones the backend enforces', () {
    expect(PasswordPolicy.minLength, 8);
    expect(PasswordPolicy.maxLength, 72);
  });
}

void _ruleTests() {
  final cases = <PasswordRule, (String met, String open)>{
    PasswordRule.minLength: ('Abcdef1!', 'Abc1!'),
    PasswordRule.uppercase: ('abcA', 'abc'),
    PasswordRule.lowercase: ('ABCa', 'ABC'),
    PasswordRule.digit: ('a1', 'ab'),
    // The underscore is not in the special-character list of the Register page.
    PasswordRule.special: ('a@', 'a_'),
  };
  group('PasswordRule', () {
    cases.forEach((rule, pair) {
      test('${rule.name} is met by "${pair.$1}" and not by "${pair.$2}"', () {
        expect(rule.isMetBy(pair.$1), isTrue);
        expect(rule.isMetBy(pair.$2), isFalse);
      });
    });

    test('the labels are the Register checklist texts', () {
      expect(PasswordRule.values.map((r) => r.label(_vi)), [
        _vi.registerRuleMinLength(PasswordPolicy.minLength),
        _vi.registerRuleUppercase,
        _vi.registerRuleLowercase,
        _vi.registerRuleDigit,
        _vi.registerRuleSpecial,
      ]);
    });

    test('meetsAllRules needs every rule', () {
      expect(PasswordPolicy.meetsAllRules('Matkhau@20'), isTrue);
      expect(PasswordPolicy.meetsAllRules('Matkhau20'), isFalse);
      expect(PasswordPolicy.meetsAllRules(''), isFalse);
    });
  });
}
