import 'package:finance_ai_app/l10n/app_localizations.dart';

/// The five rules of the password checklist shown under a new password (Register, Change password). They are stricter
/// than [PasswordPolicy.validate], which mirrors the backend; a form asks for both.
enum PasswordRule {
  minLength,
  uppercase,
  lowercase,
  digit,
  special;

  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _lower = RegExp(r'[a-z]');
  static final RegExp _special = RegExp(r'[!@#$%^&*(),.?":{}|<>]');

  bool isMetBy(String password) => switch (this) {
    minLength => PasswordPolicy.hasMinLength(password),
    uppercase => _upper.hasMatch(password),
    lowercase => _lower.hasMatch(password),
    digit => PasswordPolicy.hasDigit(password),
    special => _special.hasMatch(password),
  };

  String label(AppLocalizations loc) => switch (this) {
    minLength => loc.registerRuleMinLength(PasswordPolicy.minLength),
    uppercase => loc.registerRuleUppercase,
    lowercase => loc.registerRuleLowercase,
    digit => loc.registerRuleDigit,
    special => loc.registerRuleSpecial,
  };
}

/// Password rules of the app. They mirror the backend's @StrongPassword
/// (core-backend/.../Security/StrongPassword.java): change both together.
class PasswordPolicy {
  static const int minLength = 8;

  /// BCrypt only reads the first 72 bytes, so the backend rejects anything longer.
  static const int maxLength = 72;

  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);
  static final RegExp _digit = RegExp(r'[0-9]');

  static bool hasMinLength(String password) => password.length >= minLength;

  static bool hasLetter(String password) => _letter.hasMatch(password);

  static bool hasDigit(String password) => _digit.hasMatch(password);

  /// Whether [password] meets every [PasswordRule] of the checklist.
  static bool meetsAllRules(String password) =>
      PasswordRule.values.every((rule) => rule.isMetBy(password));

  /// The first rule [password] breaks, worded for the user in the language of [loc], or null when it meets the policy.
  static String? validate(String password, AppLocalizations loc) {
    if (password.trim().isEmpty) {
      return loc.passwordEmpty;
    }
    if (password.length < minLength || password.length > maxLength) {
      return loc.passwordLength(minLength, maxLength);
    }
    if (!hasLetter(password) || !hasDigit(password)) {
      return loc.passwordLetterAndDigit;
    }
    return null;
  }
}
