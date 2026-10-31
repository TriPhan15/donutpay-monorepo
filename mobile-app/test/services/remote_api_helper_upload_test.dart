import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

import '../helpers/fake_backend.dart';

/// A real file of the project, so that the upload can read it: it stands for the photo of a receipt.
const String _photo = 'assets/images/logo.png';
const String _upload = '/api/upload';
const String _checkout = '/api/transactions/checkout';
const String _payment = '/api/payment/create';
const String _photoUrl = 'https://example.com/receipt.png';

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
    backend.on('POST', _checkout, (_) => okResponse({'transactionId': 5}));
  });

  Map<String, dynamic> checkoutBody() {
    final request = backend.requests.singleWhere((r) => r.path == _checkout);
    return Map<String, dynamic>.from(request.data as Map);
  }

  group('uploadImage', () {
    test('gives the link core-backend answers', () async {
      backend.on('POST', _upload, (_) => jsonResponse(200, {'url': _photoUrl}));

      expect(await RemoteApiHelper.instance.uploadImage(_photo), _photoUrl);
    });

    for (final status in [400, 413, 503]) {
      test(
        'a $status is thrown for the caller to tell, not turned into null',
        () async {
          backend.on('POST', _upload, (_) => jsonResponse(status, {}));

          await expectLater(
            RemoteApiHelper.instance.uploadImage(_photo),
            throwsA(
              isA<DioException>().having(
                (e) => e.response?.statusCode,
                'status',
                status,
              ),
            ),
          );
        },
      );
    }

    test('an answer without a link is thrown too', () async {
      backend.on('POST', _upload, (_) => jsonResponse(200, {'data': {}}));

      await expectLater(
        RemoteApiHelper.instance.uploadImage(_photo),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('addTransaction with a photo', () {
    test(
      'a failed upload is reported and the transaction is still saved',
      () async {
        backend.on('POST', _upload, (_) => jsonResponse(413, {}));
        final failures = <Object>[];

        await RemoteApiHelper.instance.addTransaction(
          {'amount': 45000},
          imagePath: _photo,
          onImageUploadFailed: failures.add,
        );

        expect(failures.single, isA<DioException>());
        expect(backend.calls, contains('POST $_checkout'));
        expect(checkoutBody().containsKey('imageUrl'), isFalse);
      },
    );

    test('a photo that went up is sent with the transaction', () async {
      backend.on('POST', _upload, (_) => jsonResponse(200, {'url': _photoUrl}));
      final failures = <Object>[];

      await RemoteApiHelper.instance.addTransaction(
        {'amount': 45000},
        imagePath: _photo,
        onImageUploadFailed: failures.add,
      );

      expect(failures, isEmpty);
      expect(checkoutBody()['imageUrl'], _photoUrl);
    });
  });

  group('createPayment', () {
    test('sends whole dong, even when the amount came with decimals', () async {
      Object? sent;
      backend.on('POST', _payment, (options) {
        sent = options.data;
        return okResponse({'orderCode': 'A1', 'payUrl': 'https://pay.example'});
      });

      await RemoteApiHelper.instance.createPayment(
        type: 'DEPOSIT',
        amount: 50000.6,
        provider: 'ZALOPAY',
      );

      expect((sent as Map)['amount'], 50001);
    });
  });
}
