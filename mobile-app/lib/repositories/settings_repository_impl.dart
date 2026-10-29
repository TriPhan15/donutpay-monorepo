import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  /// [deviceLocale] replaces the platform locale used when no language was saved yet; only tests pass it.
  SettingsRepositoryImpl(
    this._preferences, {
    Locale Function() deviceLocale = _platformLocale,
  }) : _themeMode = _readThemeMode(_preferences),
       _language = _readLanguage(_preferences, deviceLocale),
       _lastRecordedDay = _readDay(_preferences, lastRecordedDayKey);

  static const String themeModeKey = 'app_theme';
  static const String languageKey = 'app_language';
  static const String lastRecordedDayKey = 'last_recorded_day';
  static const String _dayPattern = 'yyyy-MM-dd';
  // With no saved choice the app follows the device's light or dark mode.
  static const ThemeMode defaultThemeMode = ThemeMode.system;

  final SharedPreferences _preferences;
  ThemeMode _themeMode;
  AppLanguage _language;
  DateTime? _lastRecordedDay;

  @override
  ThemeMode get themeMode => _themeMode;

  @override
  AppLanguage get language => _language;

  @override
  String get languageCode => _language.languageCode;

  @override
  String get localeTag => _language.localeTag;

  @override
  Future<bool> setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    return _write(themeModeKey, mode.name);
  }

  @override
  Future<bool> setLanguage(AppLanguage language) {
    _language = language;
    return _write(languageKey, language.languageCode);
  }

  @override
  DateTime? get lastRecordedDay => _lastRecordedDay;

  @override
  Future<bool> setLastRecordedDay(DateTime day) {
    final only = DateTime(day.year, day.month, day.day);
    _lastRecordedDay = only;
    return _write(lastRecordedDayKey, DateFormat(_dayPattern).format(only));
  }

  Future<bool> _write(String key, String value) async {
    try {
      final saved = await _preferences.setString(key, value);
      if (!saved) debugPrint('Settings: the device did not save "$key".');
      return saved;
    } catch (e) {
      debugPrint('Settings: saving "$key" failed: $e');
      return false;
    }
  }

  static Locale _platformLocale() => PlatformDispatcher.instance.locale;

  static String? _readString(SharedPreferences preferences, String key) {
    final value = preferences.get(key);
    return value is String ? value : null;
  }

  /// Null for anything but a real day in [_dayPattern] (a value from an older build, a corrupted file).
  static DateTime? _readDay(SharedPreferences preferences, String key) {
    final value = _readString(preferences, key);
    if (value == null) return null;
    try {
      return DateFormat(_dayPattern).parseStrict(value);
    } on FormatException {
      return null;
    }
  }

  static ThemeMode _readThemeMode(SharedPreferences preferences) =>
      ThemeMode.values.asNameMap()[_readString(preferences, themeModeKey)] ??
      defaultThemeMode;

  static AppLanguage _readLanguage(
    SharedPreferences preferences,
    Locale Function() deviceLocale,
  ) =>
      AppLanguage.fromLanguageCode(_readString(preferences, languageKey)) ??
      AppLanguage.fromLanguageCode(deviceLocale().languageCode) ??
      AppLanguage.fallback;
}
