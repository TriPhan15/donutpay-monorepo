import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/app_language.dart';

/// What the user is told, and what the log keeps, when a request fails. The screen only ever shows a fixed text or a
/// message core-backend wrote for a 4xx: never the exception, its stack trace or the request URL.
class UserFacingError {
  UserFacingError._();

  /// The language core-backend writes `message` in. It ignores Accept-Language, so in any other language the app shows
  /// its own text instead.
  static const AppLanguage serverLanguage = AppLanguage.vietnamese;

  static const Set<DioExceptionType> _timeouts = {
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  };

  /// No answer = [AppLocalizations.errorTimeout] or [AppLocalizations.errorNetwork]; 5xx =
  /// [AppLocalizations.errorServer] (core-backend puts raw exceptions there); 401 = the server's message or
  /// [unauthorizedMessage]; other 4xx = the server's message or [rejectedMessage]. The server's message is used only
  /// while [loc] is in [serverLanguage]. Anything that is not a [DioException] gets [fallback]. Unset texts default to
  /// [AppLocalizations.errorSessionExpired] and [AppLocalizations.errorUnexpected].
  static String messageOf(
    Object error,
    AppLocalizations loc, {
    String? unauthorizedMessage,
    String? rejectedMessage,
    String? fallback,
  }) {
    if (error is! DioException) return fallback ?? loc.errorUnexpected;
    final status = error.response?.statusCode;
    if (status == null) {
      return _timeouts.contains(error.type)
          ? loc.errorTimeout
          : loc.errorNetwork;
    }
    if (status >= HttpStatus.internalServerError) return loc.errorServer;
    final serverMessage = readsServerMessages(loc)
        ? serverMessageOf(error.response?.data)
        : null;
    if (status == HttpStatus.unauthorized) {
      return serverMessage ?? unauthorizedMessage ?? loc.errorSessionExpired;
    }
    return serverMessage ?? rejectedMessage ?? loc.errorUnexpected;
  }

  /// Whether a user reading [loc] can read the messages core-backend writes (see [serverLanguage]).
  static bool readsServerMessages(AppLocalizations loc) =>
      loc.localeName.startsWith(serverLanguage.languageCode);

  /// The non-blank `message` of a core-backend answer [body], trimmed, or null when there is none. It is in
  /// [serverLanguage]: check [readsServerMessages] before showing it.
  static String? serverMessageOf(Object? body) {
    final message = body is Map ? body['message'] : null;
    if (message is! String) return null;
    final trimmed = message.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Logs that [operation] failed with the status or the kind of error only; the raw text stays out of the UI.
  static void log(String operation, Object error) {
    final reason = error is DioException
        ? '${error.response?.statusCode ?? error.type.name}'
        : '${error.runtimeType}';
    debugPrint('$operation failed ($reason): $error');
  }
}
