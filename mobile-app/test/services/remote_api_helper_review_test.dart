import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

import '../helpers/captured_logs.dart';
import '../helpers/fake_backend.dart';

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
    'a review carries no user id: the server takes the author from the JWT',
    () async {
      Object? sent;
      backend.on('POST', '/api/reviews', (options) {
        sent = options.data;
        return okResponse(null, message: 'Gửi đánh giá góp ý thành công!');
      });

      final ok = await RemoteApiHelper.instance.submitAppReview(5, 'Rất tốt');

      expect(ok, isTrue);
      expect(sent, {'rating': 5, 'comment': 'Rất tốt'});
    },
  );

  test(
    'a refused review is false, and its error only goes to the log',
    () async {
      backend.on(
        'POST',
        '/api/reviews',
        (_) => jsonResponse(400, {
          'code': 400,
          'message': 'Đánh giá cao nhất là 5 sao',
        }),
      );

      await withCapturedLogs((logs) async {
        expect(await RemoteApiHelper.instance.submitAppReview(9, 'x'), isFalse);
        expect(logs, hasLength(1));
      });
    },
  );

  test('fetchSavings no longer hides a failure behind an empty list', () async {
    backend.on('GET', '/api/savings', (_) => jsonResponse(500, {'code': 500}));

    await expectLater(
      RemoteApiHelper.instance.fetchSavings(),
      throwsA(anything),
    );
  });
}
