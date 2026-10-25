import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// What the user is told, and what the log keeps, when a request fails. The screen only ever shows a fixed text or a
/// message core-backend wrote for a 4xx: never the exception, its stack trace or the request URL.
class UserFacingError {
  UserFacingError._();

  static const String networkError =
      'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.';
  static const String timeout = 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.';
  static const String serverError =
      'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';
  static const String unauthorized =
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
  static const String unexpected = 'Đã có lỗi xảy ra. Vui lòng thử lại.';

  static const Set<DioExceptionType> _timeouts = {
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  };

  /// No answer = [timeout] or [networkError]; 5xx = [serverError] (core-backend puts raw exceptions there); 401 = the
  /// server's message or [unauthorizedMessage]; other 4xx = the server's message or [rejectedMessage]. Anything that is
  /// not a [DioException] gets [fallback].
  static String messageOf(
    Object error, {
    String unauthorizedMessage = unauthorized,
    String rejectedMessage = unexpected,
    String fallback = unexpected,
  }) {
    if (error is! DioException) return fallback;
    final status = error.response?.statusCode;
    if (status == null) {
      return _timeouts.contains(error.type) ? timeout : networkError;
    }
    if (status >= HttpStatus.internalServerError) return serverError;
    final serverMessage = _serverMessageOf(error.response?.data);
    if (status == HttpStatus.unauthorized) {
      return serverMessage ?? unauthorizedMessage;
    }
    return serverMessage ?? rejectedMessage;
  }

  /// Logs that [operation] failed with the status or the kind of error only; the raw text stays out of the UI.
  static void log(String operation, Object error) {
    final reason = error is DioException
        ? '${error.response?.statusCode ?? error.type.name}'
        : '${error.runtimeType}';
    debugPrint('$operation failed ($reason): $error');
  }

  static String? _serverMessageOf(Object? body) {
    final message = body is Map ? body['message'] : null;
    if (message is! String) return null;
    final trimmed = message.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
