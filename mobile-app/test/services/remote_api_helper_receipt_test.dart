import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/models/receipt_detail.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

import '../helpers/fake_backend.dart';

const String _conflict = 'Hóa đơn đã được thay đổi, hãy tải lại rồi thử lại';

Map<String, dynamic> _receipt({
  String status = 'COMPLETED_RAW',
  int version = 4,
}) => {
  'id': 7,
  'transactionId': 42,
  'status': status,
  'version': version,
  'vendorName': 'Highlands',
  'extractedTotal': 45000,
  'extractedDate': '2026-09-20',
  'imageUrl': null,
  'errorCode': null,
  'errorMessage': null,
};

ResponseBody _conflictResponse(RequestOptions _) =>
    jsonResponse(409, {'code': 409, 'message': _conflict});

/// The message core-backend wrote for the refusal that [call] ends in.
Future<String?> _serverMessageOf(Future<Object?> Function() call) async {
  try {
    await call();
  } on DioException catch (e) {
    expect(e.response?.statusCode, 409);
    return UserFacingError.serverMessageOf(e.response?.data);
  }
  return null;
}

void main() {
  final backend = FakeBackend();
  final api = RemoteApiHelper.instance;

  setUpAll(() {
    api.init(httpClientAdapter: backend);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    await SessionService.setTokens('access-token', 'refresh-token');
    backend.reset();
  });

  test(
    'fetchReceiptOfTransaction reads GET /api/receipts/transaction/{id}',
    () async {
      backend.on(
        'GET',
        '/api/receipts/transaction/42',
        (_) => okResponse(_receipt()),
      );

      final receipt = await api.fetchReceiptOfTransaction('42');

      expect(backend.calls, ['GET /api/receipts/transaction/42']);
      expect(receipt.id, 7);
      expect(receipt.status, ReceiptLifecycle.completedRaw);
      expect(receipt.version, 4);
    },
  );

  test('fetchReceipt reads GET /api/receipts/{id}', () async {
    backend.on('GET', '/api/receipts/7', (_) => okResponse(_receipt()));

    final receipt = await api.fetchReceipt(7);

    expect(backend.calls, ['GET /api/receipts/7']);
    expect(receipt.transactionId, 42);
  });

  test(
    'updateReceipt puts the version and only the fields it was given',
    () async {
      Object? sent;
      backend.on('PUT', '/api/receipts/7', (options) {
        sent = options.data;
        return okResponse(_receipt(status: 'EDITED', version: 5));
      });

      final receipt = await api.updateReceipt(
        7,
        version: 4,
        vendorName: 'Phuc Long',
        extractedTotal: 52000,
        extractedDate: DateTime(2026, 9, 5, 14, 30),
      );

      expect(sent, {
        'version': 4,
        'vendorName': 'Phuc Long',
        'extractedTotal': 52000,
        'extractedDate': '2026-09-05',
      });
      expect(receipt.status, ReceiptLifecycle.edited);
      expect(receipt.version, 5);
    },
  );

  test('updateReceipt leaves out the fields that were not given', () async {
    Object? sent;
    backend.on('PUT', '/api/receipts/7', (options) {
      sent = options.data;
      return okResponse(_receipt(status: 'EDITED', version: 5));
    });

    await api.updateReceipt(7, version: 4, extractedTotal: 52000);

    expect(sent, {'version': 4, 'extractedTotal': 52000});
  });

  test(
    'retryReceipt posts the AI answer as one JSON text with the clientId',
    () async {
      Object? sent;
      backend.on('POST', '/api/receipts/7/retry', (options) {
        sent = options.data;
        return okResponse(_receipt());
      });

      final receipt = await api.retryReceipt(
        7,
        rawReceiptData: '{"seller":{"total_cost_number":45000}}',
        clientId: 'a1b2c3d4-0000-4000-8000-000000000001',
      );

      expect(sent, {
        'rawReceiptData': '{"seller":{"total_cost_number":45000}}',
        'clientId': 'a1b2c3d4-0000-4000-8000-000000000001',
      });
      expect(sent, isA<Map>());
      expect((sent! as Map)['rawReceiptData'], isA<String>());
      expect(receipt.status, ReceiptLifecycle.completedRaw);
    },
  );

  test(
    'submitReceiptFeedback sends the amount as a query parameter and no body',
    () async {
      RequestOptions? seen;
      backend.on('POST', '/api/receipts/feedback/7', (options) {
        seen = options;
        return okResponse(null);
      });

      await api.submitReceiptFeedback(7, 52000);

      expect(seen!.queryParameters, {'manualAmount': 52000});
      expect(seen!.data, isNull);
    },
  );

  test(
    'a 409 of an edit reaches the caller with the message of the server',
    () async {
      backend.on('PUT', '/api/receipts/7', _conflictResponse);

      expect(
        await _serverMessageOf(
          () => api.updateReceipt(7, version: 1, vendorName: 'x'),
        ),
        _conflict,
      );
    },
  );

  test(
    'a 409 of a retry reaches the caller with the message of the server',
    () async {
      backend.on('POST', '/api/receipts/7/retry', _conflictResponse);

      expect(
        await _serverMessageOf(
          () => api.retryReceipt(7, rawReceiptData: '{}', clientId: 'c'),
        ),
        _conflict,
      );
    },
  );

  test(
    'a 409 of a feedback reaches the caller with the message of the server',
    () async {
      backend.on('POST', '/api/receipts/feedback/7', _conflictResponse);

      expect(
        await _serverMessageOf(() => api.submitReceiptFeedback(7, 1000)),
        _conflict,
      );
    },
  );

  test('a write announces a change of the data, a read does not', () async {
    backend.on('GET', '/api/receipts/7', (_) => okResponse(_receipt()));
    backend.on('PUT', '/api/receipts/7', (_) => okResponse(_receipt()));
    final before = api.dataChangedNotifier.value;

    await api.fetchReceipt(7);
    expect(api.dataChangedNotifier.value, before);

    await api.updateReceipt(7, version: 4, vendorName: 'x');
    expect(api.dataChangedNotifier.value, before + 1);
  });
}
