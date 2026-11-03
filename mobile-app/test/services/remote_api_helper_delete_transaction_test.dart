import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

import '../helpers/fake_backend.dart';

const String _path = '/api/transactions/5';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final backend = FakeBackend();
  late int changes;

  setUpAll(() {
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend.reset();
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(42);
    await SessionService.setTokens('access-token', 'refresh-token');
    changes = RemoteApiHelper.instance.dataChangedNotifier.value;
  });

  tearDown(() async {
    await SessionService.clearSession();
  });

  int notified() =>
      RemoteApiHelper.instance.dataChangedNotifier.value - changes;

  group('deleteTransaction', () {
    test('a network failure is thrown and nothing is announced', () async {
      backend.on(
        'DELETE',
        _path,
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );
      await expectLater(
        RemoteApiHelper.instance.deleteTransaction('5'),
        throwsA(isA<DioException>()),
      );
      expect(notified(), 0);
    });

    test(
      'a rejection from the server is thrown and nothing is announced',
      () async {
        backend.on(
          'DELETE',
          _path,
          (_) => jsonResponse(403, {'code': 403, 'message': 'Không có quyền'}),
        );
        await expectLater(
          RemoteApiHelper.instance.deleteTransaction('5'),
          throwsA(isA<DioException>()),
        );
        expect(notified(), 0);
      },
    );

    test('a 200 answer carrying an error code is thrown too', () async {
      backend.on(
        'DELETE',
        _path,
        (_) => jsonResponse(200, {'code': 409, 'message': 'Xung đột'}),
      );
      await expectLater(
        RemoteApiHelper.instance.deleteTransaction('5'),
        throwsA(isA<DioException>()),
      );
      expect(notified(), 0);
    });

    test(
      'an error code that is not an int is still thrown as a DioException',
      () async {
        backend.on(
          'DELETE',
          _path,
          (_) => jsonResponse(200, {'code': '409', 'message': 'Xung đột'}),
        );
        await expectLater(
          RemoteApiHelper.instance.deleteTransaction('5'),
          throwsA(isA<DioException>()),
        );
        expect(notified(), 0);
      },
    );

    test('a confirmed delete announces the change exactly once', () async {
      backend.on('DELETE', _path, (_) => okResponse(null));
      await RemoteApiHelper.instance.deleteTransaction('5');
      expect(notified(), 1);
    });
  });
}
