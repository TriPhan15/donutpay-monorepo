import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

import '../helpers/captured_logs.dart';
import '../helpers/fake_backend.dart';

const String _photo = 'https://res.cloudinary.com/demo/image/upload/r1.jpg';

void main() {
  final backend = FakeBackend();

  setUpAll(() {
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    await SessionService.setTokens('access-token', 'refresh-token');
    backend.reset();
  });

  test(
    'downloadToTemp saves the photo and sends no Authorization header to the image host',
    () async {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]);
      backend.on('GET', _photo, (_) => ResponseBody.fromBytes(bytes, 200));

      final path = await RemoteApiHelper.instance.downloadToTemp(_photo);

      expect(path, isNotNull);
      expect(await File(path!).readAsBytes(), bytes);
      final request = backend.requests.single;
      expect(
        request.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(
        request.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('accept-language')),
      );
    },
  );

  test('the same photo lands in the same file', () async {
    backend.on('GET', _photo, (_) => ResponseBody.fromBytes(Uint8List(4), 200));

    final first = await RemoteApiHelper.instance.downloadToTemp(_photo);
    final second = await RemoteApiHelper.instance.downloadToTemp(_photo);

    expect(second, first);
  });

  test('a 404 returns null', () async {
    await withCapturedLogs((logs) async {
      expect(await RemoteApiHelper.instance.downloadToTemp(_photo), isNull);
      expect(logs, isNotEmpty);
    });
  });
}
