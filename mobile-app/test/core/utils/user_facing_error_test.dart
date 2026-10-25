import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';

DioException _answered(int status, [Object? body]) {
  final options = RequestOptions(path: '/api/x');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status, data: body),
    type: DioExceptionType.badResponse,
  );
}

DioException _unanswered(DioExceptionType type) => DioException(
  requestOptions: RequestOptions(path: '/api/x'),
  type: type,
);

final AppLocalizations _vi = lookupAppLocalizations(const Locale('vi'));
final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));

void main() {
  group('UserFacingError.messageOf', () {
    test('no answer is a lost connection, or a timeout', () {
      expect(
        UserFacingError.messageOf(
          _unanswered(DioExceptionType.connectionError),
          _vi,
        ),
        _vi.errorNetwork,
      );
      expect(
        UserFacingError.messageOf(
          _unanswered(DioExceptionType.receiveTimeout),
          _vi,
        ),
        _vi.errorTimeout,
      );
    });

    test(
      'a 5xx is the fixed server text, never the raw exception of the backend',
      () {
        expect(
          UserFacingError.messageOf(
            _answered(500, {
              'message': 'Hệ thống sự cố: java.lang.NullPointerException',
            }),
            _vi,
          ),
          _vi.errorServer,
        );
      },
    );

    test('a 401 is the server message, or the text the caller gives', () {
      expect(
        UserFacingError.messageOf(
          _answered(401, {'message': 'Tài khoản hoặc mật khẩu không đúng'}),
          _vi,
          unauthorizedMessage: 'Sai email hoặc mật khẩu!',
        ),
        'Tài khoản hoặc mật khẩu không đúng',
      );
      expect(
        UserFacingError.messageOf(
          _answered(401),
          _vi,
          unauthorizedMessage: 'Sai email hoặc mật khẩu!',
        ),
        'Sai email hoặc mật khẩu!',
      );
    });

    test('another 4xx is the server message, or the rejected text', () {
      expect(
        UserFacingError.messageOf(
          _answered(409, {'message': ' Email đã tồn tại '}),
          _vi,
        ),
        'Email đã tồn tại',
      );
      expect(
        UserFacingError.messageOf(
          _answered(400, {'message': '   '}),
          _vi,
          rejectedMessage: 'Bị từ chối',
        ),
        'Bị từ chối',
      );
    });

    test('anything else is the fallback, never its text', () {
      expect(
        UserFacingError.messageOf(StateError('LỖI THẬT: Code 401'), _vi),
        _vi.errorUnexpected,
      );
      expect(
        UserFacingError.messageOf(Exception('x'), _vi, fallback: 'Thất bại'),
        'Thất bại',
      );
    });

    test(
      'the server writes Vietnamese only, so in English the app shows its own text',
      () {
        expect(
          UserFacingError.messageOf(
            _answered(409, {'message': 'Email đã tồn tại'}),
            _en,
          ),
          _en.errorUnexpected,
        );
        expect(
          UserFacingError.messageOf(
            _answered(401, {'message': 'Tài khoản hoặc mật khẩu không đúng'}),
            _en,
            unauthorizedMessage: 'Wrong email or password',
          ),
          'Wrong email or password',
        );
        expect(
          UserFacingError.messageOf(_answered(401), _en),
          _en.errorSessionExpired,
        );
      },
    );
  });
}
