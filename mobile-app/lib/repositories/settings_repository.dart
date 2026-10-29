import 'package:flutter/material.dart';

import 'package:finance_ai_app/models/app_language.dart';

/// App settings kept on the device. Reads are synchronous and served from memory, so they are safe on hot paths such
/// as a Dio interceptor.
abstract class SettingsRepository {
  ThemeMode get themeMode;

  AppLanguage get language;

  String get languageCode;

  String get localeTag;

  /// Updates the value in memory at once, then writes it to the device. Returns false when the write failed: the new
  /// value still applies until the app is closed.
  Future<bool> setThemeMode(ThemeMode mode);

  /// Same contract as [setThemeMode].
  Future<bool> setLanguage(AppLanguage language);

  /// The day (at midnight) of the transaction recorded last on this device, offered as a quick choice by the date
  /// picker; null when none was recorded yet.
  DateTime? get lastRecordedDay;

  /// Keeps only the day of [day]. Same contract as [setThemeMode].
  Future<bool> setLastRecordedDay(DateTime day);

  /// Whether the balance and the month totals are hidden behind dots, on the home and statistics tabs alike. True
  /// on a new device.
  bool get amountsHidden;

  /// Same contract as [setThemeMode].
  Future<bool> setAmountsHidden(bool hidden);
}
