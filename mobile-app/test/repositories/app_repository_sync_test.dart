import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/models/wallet_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';

import '../helpers/captured_logs.dart';
import '../helpers/fake_backend.dart';
import '../helpers/fake_local_store.dart';

const int _userId = 1;
const String _checkout = '/api/transactions/checkout';
const String _mine = '/api/transactions/mine';
const String _sendFailedLog = 'Lỗi gửi giao dịch';

TransactionModel _draft() => TransactionModel.draft(
  title: 'Cà phê',
  category: 'Ăn uống',
  amount: 45000,
  date: DateTime(2026, 9, 20, 8, 30),
  isExpense: true,
);

/// What core-backend answers to a first checkout.
ResponseBody _created() => okResponse({
  'transactionId': 5,
  'finalAmount': 45000,
  'remainingBalance': 955000,
  'warning': '',
});

/// The network is gone: the request never reaches the server.
Never _noNetwork(RequestOptions options) => throw DioException(
  requestOptions: options,
  type: DioExceptionType.connectionError,
  error: 'no network',
);

final AppLocalizations _vi = lookupAppLocalizations(const Locale('vi'));

void main() {
  // The interceptor of RemoteApiHelper answers a 401 by asking navigatorKey for the navigator, to go back to the login
  // screen, and a GlobalKey lookup needs a binding. Without one it throws inside the interceptor; Dio ignores that error,
  // so the request never completes and the test ends with a timeout. With a binding the key finds no navigator (nothing
  // is mounted here) and the 401 comes out as a plain DioException.
  TestWidgetsFlutterBinding.ensureInitialized();

  final backend = FakeBackend();
  late FakeLocalStore store;

  setUpAll(() {
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = FakeLocalStore();
    AppRepository.instance.localStore = store;
    backend.reset();
  });

  /// The bodies of the requests that reached POST /api/transactions/checkout.
  List<Map<String, dynamic>> sentBodies() => [
    for (final request in backend.requests)
      if (request.path == _checkout)
        Map<String, dynamic>.from(request.data as Map),
  ];

  group('createTransaction', () {
    test(
      'sends the transaction with its clientId and leaves it flagged synced',
      () async {
        backend.on('POST', _checkout, (_) => _created());
        final draft = _draft();

        final status = await AppRepository.instance.createTransaction(
          _userId,
          draft,
        );

        expect(status, SyncStatus.synced);
        expect(sentBodies(), hasLength(1));
        expect(sentBodies().single['clientId'], draft.clientId);
        expect(sentBodies().single['categoryName'], 'Ăn uống');
        expect(sentBodies().single['amount'], 45000.0);
        expect(store.rows.single.syncStatus, SyncStatus.synced);
        expect(
          await AppRepository.instance.getUnsyncedTransactions(_userId),
          isEmpty,
        );
      },
    );

    test(
      'writes the transaction as pending before the request goes out, so a crash cannot lose it',
      () async {
        final draft = _draft();
        SyncStatus? duringRequest;
        backend.on('POST', _checkout, (_) {
          duringRequest = store.byClientId(draft.clientId!)?.syncStatus;
          return _created();
        });

        await AppRepository.instance.createTransaction(_userId, draft);

        expect(duringRequest, SyncStatus.pending);
      },
    );

    test(
      'without a network the transaction stays on the device flagged error, and nothing is thrown',
      () {
        return withCapturedLogs((logs) async {
          backend.on('POST', _checkout, _noNetwork);
          final draft = _draft();

          final status = await AppRepository.instance.createTransaction(
            _userId,
            draft,
          );

          expect(status, SyncStatus.error);
          expect(store.rows.single.clientId, draft.clientId);
          expect(store.rows.single.syncStatus, SyncStatus.error);
          expect(
            await AppRepository.instance.getUnsyncedTransactions(_userId),
            hasLength(1),
          );
          expect(
            logs.where((line) => line.contains(_sendFailedLog)),
            isNotEmpty,
          );
        });
      },
    );

    test(
      'a timeout, a server error and an expired session are kept for a resend, not treated as a refusal',
      () {
        return withCapturedLogs((logs) async {
          final failures = <FutureOr<ResponseBody> Function(RequestOptions)>[
            (options) => throw DioException(
              requestOptions: options,
              type: DioExceptionType.receiveTimeout,
            ),
            (_) => jsonResponse(500, {'code': 500, 'message': 'Lỗi hệ thống'}),
            (_) => jsonResponse(401, {'code': 401, 'message': 'Hết phiên'}),
            (_) => jsonResponse(408, {
              'code': 408,
              'message': 'Hết thời gian chờ',
            }),
            (_) => jsonResponse(429, {
              'code': 429,
              'message': 'Quá nhiều yêu cầu',
            }),
          ];
          for (final failure in failures) {
            store.clear();
            backend.on('POST', _checkout, failure);

            final status = await AppRepository.instance.createTransaction(
              _userId,
              _draft(),
            );

            expect(status, SyncStatus.error);
            expect(store.rows.single.syncStatus, SyncStatus.error);
          }
        });
      },
    );

    test(
      'a refusal of the server is thrown with its reason, and nothing is kept: the user still has the form',
      () {
        return withCapturedLogs((logs) async {
          backend.on(
            'POST',
            _checkout,
            (_) => jsonResponse(400, {
              'code': 400,
              'message': 'Số dư ví không đủ',
            }),
          );

          await expectLater(
            AppRepository.instance.createTransaction(_userId, _draft()),
            throwsA(
              isA<TransactionRefusedException>().having(
                (e) => e.message,
                'message',
                'Số dư ví không đủ',
              ),
            ),
          );

          expect(store.rows, isEmpty);
        });
      },
    );

    test('a refusal without a reason still says something', () {
      return withCapturedLogs((logs) async {
        backend.on('POST', _checkout, (_) => jsonResponse(422, {}));

        await expectLater(
          AppRepository.instance.createTransaction(_userId, _draft()),
          throwsA(
            isA<TransactionRefusedException>()
                .having((e) => e.message, 'message', isNull)
                .having(
                  (e) => e.messageFor(_vi),
                  'messageFor(vi)',
                  _vi.transactionRefused,
                ),
          ),
        );
      });
    });
  });

  group('TransactionRefusedException.messageFor', () {
    test(
      'shows the server\'s Vietnamese reason only to a Vietnamese reader',
      () {
        final en = lookupAppLocalizations(const Locale('en'));
        const refusal = TransactionRefusedException('Số dư ví không đủ');
        expect(refusal.messageFor(_vi), 'Số dư ví không đủ');
        expect(refusal.messageFor(en), en.transactionRefused);
      },
    );
  });

  group('resendTransaction', () {
    test(
      'sends the same clientId again and flags the transaction synced',
      () async {
        final draft = _draft();
        await store.insertTransaction(
          draft.withSyncStatus(SyncStatus.error),
          _userId,
        );
        SyncStatus? duringRequest;
        backend.on('POST', _checkout, (_) {
          duringRequest = store.byClientId(draft.clientId!)?.syncStatus;
          return _created();
        });

        final status = await AppRepository.instance.resendTransaction(
          _userId,
          draft,
        );

        expect(status, SyncStatus.synced);
        expect(
          duringRequest,
          SyncStatus.pending,
          reason: 'it is being sent again',
        );
        expect(sentBodies().single['clientId'], draft.clientId);
        expect(store.rows.single.syncStatus, SyncStatus.synced);
      },
    );

    test(
      'when the first send arrived and only the answer was lost, the resend carries the same clientId',
      () {
        return withCapturedLogs((logs) async {
          // An idempotent server: it stores a transaction once per clientId, whatever the number of sends.
          final onServer = <String>{};
          var answerLost = true;
          backend.on('POST', _checkout, (options) {
            onServer.add((options.data as Map)['clientId'] as String);
            if (answerLost) {
              throw DioException(
                requestOptions: options,
                type: DioExceptionType.receiveTimeout,
              );
            }
            return _created();
          });
          final draft = _draft();

          expect(
            await AppRepository.instance.createTransaction(_userId, draft),
            SyncStatus.error,
          );
          answerLost = false;
          expect(
            await AppRepository.instance.resendTransaction(_userId, draft),
            SyncStatus.synced,
          );

          expect(sentBodies().map((body) => body['clientId']), [
            draft.clientId,
            draft.clientId,
          ]);
          expect(onServer, {
            draft.clientId,
          }, reason: 'one transaction on the server');
          expect(store.rows.single.syncStatus, SyncStatus.synced);
        });
      },
    );

    test('a resend that fails again keeps the transaction flagged error', () {
      return withCapturedLogs((logs) async {
        final draft = _draft();
        await store.insertTransaction(
          draft.withSyncStatus(SyncStatus.error),
          _userId,
        );
        backend.on('POST', _checkout, _noNetwork);

        final status = await AppRepository.instance.resendTransaction(
          _userId,
          draft,
        );

        expect(status, SyncStatus.error);
        expect(store.rows.single.syncStatus, SyncStatus.error);
      });
    });

    test(
      'a refusal on a resend is thrown, and the transaction stays (flagged error) so the user can delete it',
      () {
        return withCapturedLogs((logs) async {
          final draft = _draft();
          await store.insertTransaction(
            draft.withSyncStatus(SyncStatus.error),
            _userId,
          );
          backend.on(
            'POST',
            _checkout,
            (_) => jsonResponse(404, {
              'code': 404,
              'message': 'Danh mục không tồn tại',
            }),
          );

          await expectLater(
            AppRepository.instance.resendTransaction(_userId, draft),
            throwsA(
              isA<TransactionRefusedException>().having(
                (e) => e.message,
                'message',
                'Danh mục không tồn tại',
              ),
            ),
          );

          expect(store.rows.single.syncStatus, SyncStatus.error);
        });
      },
    );

    test(
      'a transaction that was not created on this device has no clientId and cannot be resent',
      () async {
        final fromServer = TransactionModel.fromJson({
          'id': 9,
          'amount': 1,
          'category': 'Khác',
        });

        await expectLater(
          AppRepository.instance.resendTransaction(_userId, fromServer),
          throwsArgumentError,
        );
        expect(backend.requests, isEmpty);
      },
    );
  });

  group('reading', () {
    Map<String, Object?> serverRow() => {
      'id': 1,
      'title': 'Trên máy chủ',
      'amount': 1000,
      'date': '2026-09-20T08:00:00',
      'category': 'Ăn uống',
      'isExpense': true,
    };

    test(
      'the list is the transactions waiting to be sent, then those of the server, and only the ones of the user',
      () async {
        backend.on('GET', _mine, (_) => okResponse([serverRow()]));
        final waiting = _draft().withSyncStatus(SyncStatus.pending);
        final failed = _draft().withSyncStatus(SyncStatus.error);
        await store.insertTransaction(waiting, _userId);
        await store.insertTransaction(failed, _userId);
        await store.insertTransaction(
          _draft().withSyncStatus(SyncStatus.synced),
          _userId,
        );
        await store.insertTransaction(
          _draft().withSyncStatus(SyncStatus.error),
          2,
        );

        final list = await AppRepository.instance.getTransactions(_userId);

        expect(list.map((t) => t.clientId), [
          waiting.clientId,
          failed.clientId,
          null,
        ]);
        expect(list.map((t) => t.syncStatus), [
          SyncStatus.pending,
          SyncStatus.error,
          SyncStatus.synced,
        ]);
        expect(list.map((t) => t.id), [null, null, '1']);
      },
    );

    test(
      'when the server cannot be reached the list throws, and the waiting transactions can still be read',
      () async {
        backend.on('GET', _mine, _noNetwork);
        await store.insertTransaction(
          _draft().withSyncStatus(SyncStatus.error),
          _userId,
        );

        await expectLater(
          AppRepository.instance.getTransactions(_userId),
          throwsA(isA<DioException>()),
        );

        expect(
          await AppRepository.instance.getUnsyncedTransactions(_userId),
          hasLength(1),
        );
      },
    );

    test(
      'deleting a transaction that was never confirmed only touches the device, never the server',
      () async {
        final tx = _draft().withSyncStatus(SyncStatus.error);
        await store.insertTransaction(tx, _userId);

        await AppRepository.instance.deleteUnsyncedTransaction(
          _userId,
          tx.clientId!,
        );

        expect(store.rows, isEmpty);
        expect(backend.requests, isEmpty);
      },
    );
  });

  group('the server already has a waiting transaction', () {
    test(
      'the copy on this device is left out, so it counts once, and flagged synced',
      () async {
        final arrived = _draft().withSyncStatus(SyncStatus.error);
        final stillWaiting = _draft().withSyncStatus(SyncStatus.pending);
        await store.insertTransaction(arrived, _userId);
        await store.insertTransaction(stillWaiting, _userId);
        backend.on(
          'GET',
          _mine,
          (_) => okResponse([
            {
              'id': 9,
              'title': 'Cà phê',
              'amount': 45000,
              'date': '2026-09-20T08:30:00',
              'category': 'Ăn uống',
              'isExpense': true,
              'clientId': arrived.clientId,
            },
          ]),
        );

        final list = await AppRepository.instance.getTransactions(_userId);

        expect(list.map((t) => t.id), [null, '9']);
        expect(list.first.clientId, stillWaiting.clientId);
        expect(
          store.byClientId(arrived.clientId!)!.syncStatus,
          SyncStatus.synced,
        );
        expect(
          store.byClientId(stillWaiting.clientId!)!.syncStatus,
          SyncStatus.pending,
        );
      },
    );
  });

  group('resendUnsyncedTransactions', () {
    test('sends every waiting transaction of the user once', () async {
      final failed = _draft().withSyncStatus(SyncStatus.error);
      final pending = _draft().withSyncStatus(SyncStatus.pending);
      await store.insertTransaction(failed, _userId);
      await store.insertTransaction(pending, _userId);
      await store.insertTransaction(
        _draft().withSyncStatus(SyncStatus.synced),
        _userId,
      );
      await store.insertTransaction(
        _draft().withSyncStatus(SyncStatus.error),
        2,
      );
      backend.on('POST', _checkout, (_) => _created());

      await AppRepository.instance.resendUnsyncedTransactions(_userId);

      expect(sentBodies().map((b) => b['clientId']), [
        failed.clientId,
        pending.clientId,
      ]);
      expect(
        await AppRepository.instance.getUnsyncedTransactions(_userId),
        isEmpty,
      );
    });

    test(
      'a refusal keeps that transaction flagged error and the next one is still sent',
      () {
        return withCapturedLogs((logs) async {
          final refused = _draft().withSyncStatus(SyncStatus.error);
          final next = _draft().withSyncStatus(SyncStatus.error);
          await store.insertTransaction(refused, _userId);
          await store.insertTransaction(next, _userId);
          backend.on('POST', _checkout, (options) {
            final body = Map<String, dynamic>.from(options.data as Map);
            return body['clientId'] == refused.clientId
                ? jsonResponse(400, {
                    'code': 400,
                    'message': 'Danh mục không tồn tại',
                  })
                : _created();
          });

          await AppRepository.instance.resendUnsyncedTransactions(_userId);

          expect(sentBodies(), hasLength(2));
          expect(
            store.byClientId(refused.clientId!)!.syncStatus,
            SyncStatus.error,
          );
          expect(
            store.byClientId(next.clientId!)!.syncStatus,
            SyncStatus.synced,
          );
          expect(logs, contains(contains('Danh mục không tồn tại')));
        });
      },
    );

    test('offline it never throws and keeps everything flagged error', () {
      return withCapturedLogs((logs) async {
        final waiting = _draft().withSyncStatus(SyncStatus.pending);
        await store.insertTransaction(waiting, _userId);
        backend.on('POST', _checkout, _noNetwork);

        await AppRepository.instance.resendUnsyncedTransactions(_userId);

        expect(
          store.byClientId(waiting.clientId!)!.syncStatus,
          SyncStatus.error,
        );
        expect(logs, contains(startsWith(_sendFailedLog)));
      });
    });

    test(
      'a second call while the first one runs joins it instead of sending again',
      () async {
        await store.insertTransaction(
          _draft().withSyncStatus(SyncStatus.error),
          _userId,
        );
        final answer = Completer<void>();
        backend.on('POST', _checkout, (_) async {
          await answer.future;
          return _created();
        });

        final first = AppRepository.instance.resendUnsyncedTransactions(
          _userId,
        );
        final second = AppRepository.instance.resendUnsyncedTransactions(
          _userId,
        );
        answer.complete();
        await Future.wait([first, second]);

        expect(sentBodies(), hasLength(1));
      },
    );

    test('with nothing waiting no request goes out', () async {
      await AppRepository.instance.resendUnsyncedTransactions(_userId);

      expect(backend.requests, isEmpty);
    });
  });

  group('dataChangedNotifier', () {
    final notifier = RemoteApiHelper.instance.dataChangedNotifier;

    /// The sync state of the row with [clientId] at every move of the notifier while [action] runs.
    Future<List<SyncStatus?>> statesAtEachChange(
      String clientId,
      Future<void> Function() action,
    ) async {
      final states = <SyncStatus?>[];
      void record() => states.add(store.byClientId(clientId)?.syncStatus);
      notifier.addListener(record);
      try {
        await action();
      } finally {
        notifier.removeListener(record);
      }
      return states;
    }

    test(
      'moves after a create, the last time once the row is flagged synced',
      () async {
        backend.on('POST', _checkout, (_) => _created());
        final draft = _draft();

        final states = await statesAtEachChange(
          draft.clientId!,
          () => AppRepository.instance.createTransaction(_userId, draft),
        );

        expect(states, isNotEmpty);
        expect(states.last, SyncStatus.synced);
      },
    );

    test('moves after a create that could not be sent', () {
      return withCapturedLogs((logs) async {
        backend.on('POST', _checkout, _noNetwork);
        final draft = _draft();

        final states = await statesAtEachChange(
          draft.clientId!,
          () => AppRepository.instance.createTransaction(_userId, draft),
        );

        expect(states, [SyncStatus.error]);
      });
    });

    test('moves after a resend that was refused', () {
      return withCapturedLogs((logs) async {
        final tx = _draft().withSyncStatus(SyncStatus.error);
        await store.insertTransaction(tx, _userId);
        backend.on(
          'POST',
          _checkout,
          (_) => jsonResponse(400, {'code': 400, 'message': 'Không hợp lệ'}),
        );

        final states = await statesAtEachChange(
          tx.clientId!,
          () => expectLater(
            AppRepository.instance.resendTransaction(_userId, tx),
            throwsA(isA<TransactionRefusedException>()),
          ),
        );

        expect(states, [SyncStatus.error]);
      });
    });

    test('moves after a waiting transaction is deleted', () async {
      final tx = _draft().withSyncStatus(SyncStatus.error);
      await store.insertTransaction(tx, _userId);

      final states = await statesAtEachChange(
        tx.clientId!,
        () => AppRepository.instance.deleteUnsyncedTransaction(
          _userId,
          tx.clientId!,
        ),
      );

      expect(states, [null], reason: 'once, after the row is gone');
    });
  });

  // T10d: core-backend answers a scanned receipt that looks already saved with 409 and the id of that transaction.
  group('a duplicate receipt (409)', () {
    ResponseBody duplicate() => jsonResponse(409, {
      'code': 409,
      'message': 'Hóa đơn này có vẻ đã được lưu trước đó',
      'data': {
        'existingTransactionId': 123,
        'existingTransactionDate': '2026-05-27T10:30:00',
      },
    });

    test(
      'create throws DuplicateReceiptException with the saved transaction and keeps nothing on the device',
      () {
        return withCapturedLogs((logs) async {
          backend.on('POST', _checkout, (_) => duplicate());

          await expectLater(
            AppRepository.instance.createTransaction(_userId, _draft()),
            throwsA(
              isA<DuplicateReceiptException>()
                  .having((e) => e.existingTransactionId, 'id', 123)
                  .having(
                    (e) => e.existingTransactionDate,
                    'date',
                    DateTime(2026, 5, 27, 10, 30),
                  )
                  .having(
                    (e) => e.message,
                    'message',
                    'Hóa đơn này có vẻ đã được lưu trước đó',
                  ),
            ),
          );
          expect(store.rows, isEmpty, reason: 'a 409 is not queued');
          expect(sentBodies().single.containsKey('allowDuplicate'), isFalse);
        });
      },
    );

    test('allowDuplicate is sent only when asked for, and saves', () async {
      backend.on('POST', _checkout, (_) => _created());
      final draft = _draft();

      final status = await AppRepository.instance.createTransaction(
        _userId,
        draft,
        allowDuplicate: true,
      );

      expect(status, SyncStatus.synced);
      expect(sentBodies().single['allowDuplicate'], isTrue);
      expect(sentBodies().single['clientId'], draft.clientId);
      expect(store.rows.single.syncStatus, SyncStatus.synced);
    });

    test(
      'a resend from the outbox that is taken for a duplicate stays flagged error',
      () {
        return withCapturedLogs((logs) async {
          final draft = _draft();
          await store.insertTransaction(
            draft.withSyncStatus(SyncStatus.error),
            _userId,
          );
          backend.on('POST', _checkout, (_) => duplicate());

          await expectLater(
            AppRepository.instance.resendTransaction(_userId, draft),
            throwsA(isA<DuplicateReceiptException>()),
          );
          expect(store.rows.single.syncStatus, SyncStatus.error);
        });
      },
    );

    test('a 409 without a transaction id is a plain refusal', () {
      return withCapturedLogs((logs) async {
        backend.on(
          'POST',
          _checkout,
          (_) => jsonResponse(409, {'code': 409, 'message': 'Xung đột'}),
        );

        await expectLater(
          AppRepository.instance.createTransaction(_userId, _draft()),
          throwsA(
            isA<TransactionRefusedException>().having(
              (e) => e is DuplicateReceiptException,
              'is a duplicate',
              isFalse,
            ),
          ),
        );
        expect(store.rows, isEmpty);
      });
    });
  });

  group('getHomeSummary', () {
    Map<String, Object?> income(num amount) => {
      'id': 1,
      'title': 'Lương',
      'amount': amount,
      'date': DateTime(2026, 9, 1).toIso8601String(),
      'category': 'Lương',
      'isExpense': false,
    };

    void serverHas({num walletBalance = 750000}) {
      backend.on(
        'GET',
        '/api/users/me',
        (_) => okResponse({
          'id': 1,
          'email': 'a@x.com',
          'walletBalance': walletBalance,
        }),
      );
      backend.on('GET', _mine, (_) => okResponse([income(1000000)]));
    }

    test(
      'the wallet is the balance the server keeps, not a sum of the list',
      () async {
        serverHas();

        final s = await AppRepository.instance.getHomeSummary(_userId);

        expect(
          (s[AppRepository.summaryWallets] as List<WalletModel>).single.balance,
          750000,
        );
      },
    );

    test(
      'waiting transactions are reported apart, not added to the balance',
      () async {
        serverHas();
        await store.insertTransaction(
          _draft().withSyncStatus(SyncStatus.pending),
          _userId,
        );

        final s = await AppRepository.instance.getHomeSummary(_userId);

        expect(s[AppRepository.summaryPendingWalletChange], -45000);
        expect(
          (s[AppRepository.summaryWallets] as List<WalletModel>).single.balance,
          750000,
        );
      },
    );

    test('nothing is pending when everything reached the server', () async {
      serverHas();

      final s = await AppRepository.instance.getHomeSummary(_userId);

      expect(s[AppRepository.summaryPendingWalletChange], 0);
    });

    test('the summary asks for /mine and /me once each', () async {
      serverHas();

      await AppRepository.instance.getHomeSummary(_userId);

      expect(backend.calls.where((c) => c == 'GET $_mine'), hasLength(1));
      expect(
        backend.calls.where((c) => c == 'GET /api/users/me'),
        hasLength(1),
      );
    });

    test('walletBalanceOf reads the field, 0 when it is missing', () {
      expect(AppRepository.walletBalanceOf({'walletBalance': 12.5}), 12.5);
      expect(AppRepository.walletBalanceOf({}), 0);
    });
  });
}
