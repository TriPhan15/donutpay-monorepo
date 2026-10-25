import 'dart:ui' show Locale;

import 'package:intl/intl.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';

enum AppLanguage {
  vietnamese('vi', 'vi_VN', 'vi-VN'),
  english('en', 'en_US', 'en-US');

  const AppLanguage(this.languageCode, this.intlLocale, this.localeTag);

  final String languageCode;
  final String intlLocale;
  final String localeTag;

  static const AppLanguage fallback = AppLanguage.vietnamese;

  Locale get locale => Locale(languageCode);

  /// The texts of this language, for code that has no BuildContext (repositories) or may run outside a localized app.
  AppLocalizations get localizations => lookupAppLocalizations(locale);

  /// The language the app currently shows, read from Intl's default locale (LanguageCubit sets it, and MaterialApp sets
  /// it again to the locale it resolved, e.g. `vi` or `en_US`). [fallback] before either has run.
  static AppLanguage get current {
    final tag = Intl.defaultLocale;
    if (tag == null) return fallback;
    return fromLanguageCode(Intl.shortLocale(tag)) ?? fallback;
  }

  static AppLanguage? fromLanguageCode(String? languageCode) {
    for (final language in values) {
      if (language.languageCode == languageCode) return language;
    }
    return null;
  }
}
