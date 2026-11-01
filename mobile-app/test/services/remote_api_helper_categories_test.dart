import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

import '../helpers/fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final backend = FakeBackend();

  setUpAll(() {
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend.reset();
    await SessionService.clearSession();
  });

  group('fetchCategories', () {
    test('returns the categories of the answer', () async {
      backend.on(
        'GET',
        '/api/categories',
        (_) => okResponse([
          {'id': 1, 'name': 'Ăn uống', 'type': 'EXPENSE'},
        ]),
      );

      final categories = await RemoteApiHelper.instance.fetchCategories();

      expect(categories, [
        {'id': 1, 'name': 'Ăn uống', 'type': 'EXPENSE'},
      ]);
    });

    test('an empty list from the server is an answer, not a failure', () async {
      backend.on('GET', '/api/categories', (_) => okResponse([]));

      expect(await RemoteApiHelper.instance.fetchCategories(), isEmpty);
    });

    test('a server error is thrown, not turned into an empty list', () async {
      backend.on(
        'GET',
        '/api/categories',
        (_) => jsonResponse(500, {'code': 500, 'message': 'Lỗi hệ thống'}),
      );

      expect(
        RemoteApiHelper.instance.fetchCategories(),
        throwsA(isA<DioException>()),
      );
    });

    test('no network is thrown, not turned into an empty list', () async {
      backend.on(
        'GET',
        '/api/categories',
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'no network',
        ),
      );

      expect(
        RemoteApiHelper.instance.fetchCategories(),
        throwsA(isA<DioException>()),
      );
    });

    test('an answer of an unknown shape is thrown too', () async {
      backend.on(
        'GET',
        '/api/categories',
        (_) => jsonResponse(200, {'unexpected': 'shape'}),
      );

      expect(
        RemoteApiHelper.instance.fetchCategories(),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
