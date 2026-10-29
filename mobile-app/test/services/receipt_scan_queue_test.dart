import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finance_ai_app/models/receipt_scan_result.dart';
import 'package:finance_ai_app/models/scan_queue_item.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/services/receipt_scan_queue.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/services/sqflite_helper.dart';

import '../helpers/fake_backend.dart';
import '../helpers/fake_local_store.dart';

const int _userId = 1;
const int _otherUserId = 2;
const String _scan = '/donut/scan';
const String _upload = '/api/upload';
const String _checkout = '/api/transactions/checkout';
const String _refresh = '/api/auth/refresh';

/// A /donut/scan answer for a receipt of [seller]; [sellerValid] false marks the store name as needing a check.
Map<String, dynamic> _answer(String seller, {bool sellerValid = true}) => {
  'seller': {
    'seller_name': seller,
    'timestamp': '20/09/2026 08:30',
    'total_cost_number': 45000,
  },
  'normalized': {
    'seller': {'raw': seller, 'value': seller, 'valid': sellerValid},
    'timestamp': {'raw': '', 'iso': '2026-09-20T08:30:00', 'valid': true},
    'total_cost': {'raw': '45000', 'value': 45000, 'valid': true},
  },
};

ResponseBody _scanned(String seller, {bool sellerValid = true}) =>
    jsonResponse(200, _answer(seller, sellerValid: sellerValid));

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

/// The v7 transactions table, as the app created it before the scan queue existed.
const String _v7Transactions = '''
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  amount REAL NOT NULL,
  date TEXT NOT NULL,
  is_expense INTEGER NOT NULL,
  icon_name TEXT NOT NULL DEFAULT 'default',
  wallet_id INTEGER,
  client_id TEXT,
  sync_status TEXT NOT NULL DEFAULT 'synced',
  image_url TEXT,
  raw_receipt_data TEXT
)
''';

void main() {
  // A 401 runs the session interceptor, which looks the navigator up through a GlobalKey: that needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  final backend = FakeBackend();
  late Directory temp;
  late Database db;
  late SqfliteHelper store;
  late ReceiptScanQueue queue;
  late FakeLocalStore outbox;

  setUpAll(() {
    sqfliteFfiInit();
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(_userId);
    backend.reset();
    outbox = FakeLocalStore();
    AppRepository.instance.localStore = outbox;
    temp = await Directory.systemTemp.createTemp('receipt_scan_queue_test');
    db = await SqfliteHelper.openAt(
      databaseFactoryFfiNoIsolate,
      inMemoryDatabasePath,
    );
    store = SqfliteHelper.withDatabase(db);
    queue = ReceiptScanQueue.forTesting(
      store: store,
      baseDirectory: Directory(p.join(temp.path, 'documents')),
    );
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  /// [count] receipt images in a cache folder, as the scanner or the picker leaves them.
  Future<List<String>> images(int count) async {
    final cache = await Directory(
      p.join(temp.path, 'cache'),
    ).create(recursive: true);
    return [
      for (var i = 0; i < count; i++)
        (await File(
          p.join(cache.path, 'receipt_${cache.listSync().length}.jpg'),
        ).writeAsBytes([i, 1, 2, 3])).path,
    ];
  }

  int requestsTo(String path) =>
      backend.requests.where((r) => r.path == path).length;

  List<Map<String, dynamic>> checkoutBodies() => [
    for (final r in backend.requests)
      if (r.path == _checkout) Map<String, dynamic>.from(r.data as Map),
  ];

  /// Answers every scan with a store named after the number of the request: Store 1, Store 2 ...
  void scanAnswersInOrder() {
    var n = 0;
    backend.on('POST', _scan, (_) => _scanned('Store ${++n}'));
  }

  group('reading', () {
    test('scans one image at a time in the order they were added', () async {
      var inFlight = 0;
      var mostInFlight = 0;
      var n = 0;
      final readingWhenAsked = <int>[];
      backend.on('POST', _scan, (_) async {
        inFlight++;
        mostInFlight = max(mostInFlight, inFlight);
        readingWhenAsked.addAll([
          for (final item in await queue.items())
            if (item.status == ScanQueueStatus.reading) item.id,
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        inFlight--;
        return _scanned('Store ${++n}');
      });
      final sources = await images(3);

      expect(await queue.enqueue(sources), 3);
      await queue.resume();

      final items = await queue.items();
      expect(mostInFlight, 1);
      expect(readingWhenAsked, [for (final item in items) item.id]);
      expect(items.map((i) => i.status), everyElement(ScanQueueStatus.ready));
      expect(items.map((i) => i.result!.storeName), [
        'Store 1',
        'Store 2',
        'Store 3',
      ]);
      // The queue reads its own copies, kept in the documents of the app.
      for (final item in items) {
        expect(sources, isNot(contains(item.imagePath)));
        expect(
          p.isWithin(
            p.join(temp.path, 'documents', 'receipt_queue'),
            item.imagePath,
          ),
          isTrue,
        );
        expect(File(item.imagePath).existsSync(), isTrue);
      }
    });

    test('progress counts done over total while reading', () async {
      scanAnswersInOrder();
      final seen = <ScanQueueProgress>[];
      queue.progress.addListener(() => seen.add(queue.progress.value));

      await queue.enqueue(await images(3));
      await queue.resume();

      expect(
        [
          for (final value in seen)
            if (value.isReading) '${value.done}/${value.total}',
        ],
        ['0/3', '1/3', '2/3', '3/3'],
      );
      expect(queue.progress.value.isReading, isFalse);
      expect(queue.progress.value.total, 0);
      expect(queue.progress.value.ready, 3);
      expect(queue.progress.value.failed, 0);
    });

    test(
      'a network failure marks only that item failed and retry reads it again',
      () async {
        var n = 0;
        backend.on('POST', _scan, (options) {
          n++;
          if (n == 2) _noNetwork(options);
          return _scanned('Store $n');
        });

        await queue.enqueue(await images(3));
        await queue.resume();

        var items = await queue.items();
        expect(items.map((i) => i.status), [
          ScanQueueStatus.ready,
          ScanQueueStatus.failed,
          ScanQueueStatus.ready,
        ]);
        expect(items[1].error, ScanQueueError.network);
        expect(items[1].result, isNull);
        expect(queue.progress.value.failed, 1);

        await queue.retry(items[1].id);
        await queue.resume();

        items = await queue.items();
        expect(items.map((i) => i.status), everyElement(ScanQueueStatus.ready));
        expect(items[1].error, isNull);
        expect(requestsTo(_scan), 4);
      },
    );

    test('a 5xx marks the item failed with server', () async {
      backend.on('POST', _scan, (_) => jsonResponse(500, {'detail': 'boom'}));

      await queue.enqueue(await images(1));
      await queue.resume();

      final item = (await queue.items()).single;
      expect(item.status, ScanQueueStatus.failed);
      expect(item.error, ScanQueueError.server);
    });

    test(
      'an item left reading by a killed app is read again on resume',
      () async {
        scanAnswersInOrder();
        final image = (await images(1)).single;
        final id = await store.insertScanQueueItem(
          userId: _userId,
          imagePath: image,
          createdAt: DateTime(2026, 10, 26, 8),
        );
        await store.updateScanQueueItem(id, ScanQueueStatus.reading);

        // A fresh queue, as after the app starts again.
        final restarted = ReceiptScanQueue.forTesting(
          store: store,
          baseDirectory: Directory(p.join(temp.path, 'documents')),
        );
        await restarted.resume();

        final item = (await restarted.items()).single;
        expect(item.status, ScanQueueStatus.ready);
        expect(item.result!.storeName, 'Store 1');
        expect(requestsTo(_scan), 1);
      },
    );

    test(
      'a signed-out or expired session stops the loop and keeps the rest queued',
      () async {
        await SessionService.setTokens('access', 'refresh');
        // The token ran out and cannot be renewed: the session ends.
        backend.on(
          'POST',
          _scan,
          (_) => jsonResponse(401, {'code': 401, 'message': 'expired'}),
        );
        backend.on(
          'POST',
          _refresh,
          (_) => jsonResponse(401, {'code': 401, 'message': 'refused'}),
        );

        await queue.enqueue(await images(3));
        await queue.resume();

        expect(SessionService.currentUserId, isNull);
        expect(requestsTo(_scan), 1);
        expect(
          (await store.getScanQueueItems(_userId)).map((i) => i.status),
          everyElement(ScanQueueStatus.queued),
        );
        expect(queue.progress.value, ScanQueueProgress.idle);
        expect(await queue.items(), isEmpty);

        // Someone else signs in on the same phone: they see nothing and nothing of the first user is read.
        await SessionService.setCurrentUserId(_otherUserId);
        await queue.resume();
        expect(await queue.items(), isEmpty);
        expect(requestsTo(_scan), 1);

        // The first user signs in again: the queue reads on.
        await SessionService.setCurrentUserId(_userId);
        scanAnswersInOrder();
        await queue.resume();
        final items = await queue.items();
        expect(items, hasLength(3));
        expect(items.map((i) => i.status), everyElement(ScanQueueStatus.ready));
      },
    );

    test('signing out during a reading stops before the next item', () async {
      var n = 0;
      backend.on('POST', _scan, (_) async {
        n++;
        await SessionService.clearSession();
        return _scanned('Store $n');
      });

      await queue.enqueue(await images(3));
      await queue.resume();

      expect(requestsTo(_scan), 1);
      expect((await store.getScanQueueItems(_userId)).map((i) => i.status), [
        ScanQueueStatus.ready,
        ScanQueueStatus.queued,
        ScanQueueStatus.queued,
      ]);
    });

    test('accepts at most 20 queued or reading items', () async {
      final gate = Completer<void>();
      backend.on('POST', _scan, (_) async {
        await gate.future;
        return _scanned('Store');
      });

      expect(await queue.enqueue(await images(15)), 15);
      final later = await images(10);
      expect(await queue.enqueue(later), 5);
      expect(await queue.enqueue(await images(1)), 0);

      var items = await queue.items();
      expect(items, hasLength(ReceiptScanQueue.maxBatch));

      gate.complete();
      await queue.resume();

      items = await queue.items();
      expect(items.map((i) => i.status), everyElement(ScanQueueStatus.ready));
      expect(requestsTo(_scan), ReceiptScanQueue.maxBatch);
      // Ready items wait for a confirmation and no longer count against the limit.
      expect(await queue.enqueue(await images(1)), 1);
      await queue.resume();
    });

    test('a copied image that disappeared fails with missing_image', () async {
      scanAnswersInOrder();
      final real = (await images(1)).single;
      final gone = p.join(temp.path, 'cache', 'cleared_by_the_system.jpg');

      expect(await queue.enqueue([gone, real]), 2);
      // The cache is cleared after the images were queued: the queue reads its own copy.
      await File(real).delete();
      await queue.resume();

      final items = await queue.items();
      expect(items[0].status, ScanQueueStatus.failed);
      expect(items[0].error, ScanQueueError.missingImage);
      expect(items[1].status, ScanQueueStatus.ready);
      expect(requestsTo(_scan), 1);
    });

    test('remove deletes the row and the copied image', () async {
      scanAnswersInOrder();
      await queue.enqueue(await images(1));
      await queue.resume();
      final item = (await queue.items()).single;
      expect(File(item.imagePath).existsSync(), isTrue);
      expect(queue.progress.value.ready, 1);

      await queue.remove(item.id);

      expect(await queue.items(), isEmpty);
      expect(File(item.imagePath).existsSync(), isFalse);
      expect(queue.progress.value.ready, 0);
    });
  });

  group('migration', () {
    test(
      'opening a v7 database creates the queue table and keeps the transactions',
      () async {
        final path = p.join(temp.path, 'v7.db');
        final v7 = await databaseFactoryFfiNoIsolate.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 7,
            onCreate: (db, _) => db.execute(_v7Transactions),
          ),
        );
        await v7.insert('transactions', {
          'user_id': _userId,
          'title': 'Cà phê',
          'category': 'Ăn uống',
          'amount': 45000,
          'date': '2026-09-20T08:30:00.000',
          'is_expense': 1,
          'client_id': 'c-1',
          'sync_status': 'error',
        });
        await v7.close();

        final v8 = await SqfliteHelper.openAt(
          databaseFactoryFfiNoIsolate,
          path,
        );
        addTearDown(v8.close);

        expect(await v8.getVersion(), 9);
        final columns = await v8.rawQuery(
          'PRAGMA table_info(${SqfliteHelper.receiptScanQueueTable})',
        );
        expect(columns.map((c) => c['name']), [
          'id',
          'user_id',
          'image_path',
          'status',
          'result_json',
          'error',
          'created_at',
        ]);
        final transactions = await v8.query('transactions');
        expect(transactions, hasLength(1));
        expect(transactions.single['client_id'], 'c-1');
        expect(transactions.single['sync_status'], 'error');
      },
    );

    test(
      'opening a v8 database as v9 adds allow_duplicate (0 for the rows already there), and they can still be resent',
      () async {
        final path = p.join(temp.path, 'v8.db');
        final v8 = await databaseFactoryFfiNoIsolate.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 8,
            onCreate: (db, _) => db.execute(_v7Transactions),
          ),
        );
        await v8.insert('transactions', {
          'user_id': _userId,
          'title': 'Cà phê',
          'category': 'Ăn uống',
          'amount': 45000,
          'date': '2026-09-20T08:30:00.000',
          'is_expense': 1,
          'client_id': 'c-1',
          'sync_status': 'error',
        });
        await v8.close();

        final v9 = await SqfliteHelper.openAt(
          databaseFactoryFfiNoIsolate,
          path,
        );
        addTearDown(v9.close);

        expect(await v9.getVersion(), 9);
        final row = (await v9.query('transactions')).single;
        expect(row[TransactionModel.columnAllowDuplicate], 0);
        final waiting = (await SqfliteHelper.withDatabase(
          v9,
        ).getUnsyncedTransactions(_userId)).single;
        expect(waiting.clientId, 'c-1');
        expect(waiting.allowDuplicate, isFalse);
        expect(waiting.toCheckoutJson()['clientId'], 'c-1');
      },
    );
  });

  group('outbox rows', () {
    TransactionModel draft() => TransactionModel.draft(
      title: 'Highlands',
      category: 'Ăn uống',
      amount: 45000,
      date: DateTime(2026, 9, 20, 8, 30),
      isExpense: true,
    );

    test('allowDuplicate is written to the table and read back', () async {
      final tx = draft().allowingDuplicate().withSyncStatus(SyncStatus.error);
      await store.insertTransaction(tx, _userId);

      final read = (await store.getUnsyncedTransactions(_userId)).single;
      expect(read.allowDuplicate, isTrue);
      expect(
        read.toCheckoutJson()[TransactionModel.checkoutAllowDuplicate],
        isTrue,
      );
    });

    test(
      'deleteFailedTransaction deletes a failed row and leaves a pending one',
      () async {
        final failed = draft().withSyncStatus(SyncStatus.error);
        final pending = draft().withSyncStatus(SyncStatus.pending);
        await store.insertTransaction(failed, _userId);
        await store.insertTransaction(pending, _userId);

        expect(
          await store.deleteFailedTransaction(_otherUserId, failed.clientId!),
          0,
          reason: 'not a row of that user',
        );
        expect(
          await store.deleteFailedTransaction(_userId, pending.clientId!),
          0,
          reason: 'it is being sent',
        );
        expect(
          await store.deleteFailedTransaction(_userId, failed.clientId!),
          1,
        );
        expect(
          (await store.getUnsyncedTransactions(_userId)).map((t) => t.clientId),
          [pending.clientId],
        );
      },
    );
  });

  group('confirmAllValid', () {
    /// Queues one image per answer and reads them all; an answer of null is a lost connection (a failed item).
    Future<List<ScanQueueItem>> readyItems(List<ResponseBody?> answers) async {
      var n = 0;
      backend.on('POST', _scan, (options) {
        final answer = answers[n++];
        return answer ?? _noNetwork(options);
      });
      await queue.enqueue(await images(answers.length));
      await queue.resume();
      return queue.items();
    }

    void uploadsSucceed() {
      var n = 0;
      backend.on(
        'POST',
        _upload,
        (_) => okResponse({'url': 'https://img/${++n}'}),
      );
    }

    test('confirms only the valid ready items', () async {
      await readyItems([
        _scanned('A'),
        _scanned('B', sellerValid: false),
        _scanned('C'),
        null,
      ]);
      uploadsSucceed();
      backend.on('POST', _checkout, (_) => _created());
      final changesBefore = RemoteApiHelper.instance.dataChangedNotifier.value;

      final result = await queue.confirmAllValid();

      expect(result.saved, 2);
      expect(result.duplicates, 0);
      expect(result.notSaved, 0);
      final left = await queue.items();
      expect(left, hasLength(2));
      expect(left[0].result!.storeName, 'B');
      expect(left[0].status, ScanQueueStatus.ready);
      expect(left[1].status, ScanQueueStatus.failed);
      expect(requestsTo(_upload), 2);
      expect(checkoutBodies().map((b) => b['note']), ['A', 'C']);
      expect(checkoutBodies().map((b) => b['imageUrl']), [
        'https://img/1',
        'https://img/2',
      ]);
      expect(
        checkoutBodies().every((b) => b['rawReceiptData'] != null),
        isTrue,
      );
      expect(
        RemoteApiHelper.instance.dataChangedNotifier.value,
        greaterThan(changesBefore),
      );
      expect(queue.progress.value.ready, 1);
    });

    test(
      'a duplicate (409) is kept and counted, the others are saved',
      () async {
        await readyItems([_scanned('A'), _scanned('B'), _scanned('C')]);
        uploadsSucceed();
        var n = 0;
        backend.on('POST', _checkout, (_) {
          n++;
          if (n == 2) {
            return jsonResponse(409, {
              'code': 409,
              'message': 'Hóa đơn này đã được lưu',
              'data': {'existingTransactionId': 7},
            });
          }
          return _created();
        });

        final result = await queue.confirmAllValid();

        expect(result.saved, 2);
        expect(result.duplicates, 1);
        expect(result.notSaved, 0);
        final left = (await queue.items()).single;
        expect(left.result!.storeName, 'B');
        // Each receipt went out once: nothing is saved twice.
        expect(checkoutBodies().map((b) => b['note']), ['A', 'B', 'C']);
        expect(
          checkoutBodies().map((b) => b['clientId']).toSet(),
          hasLength(3),
        );
        expect(
          checkoutBodies().any(
            (b) => b.containsKey(TransactionModel.checkoutAllowDuplicate),
          ),
          isFalse,
        );
      },
    );

    test('an upload failure keeps that item and saves the rest', () async {
      await readyItems([_scanned('A'), _scanned('B'), _scanned('C')]);
      var n = 0;
      backend.on('POST', _upload, (_) {
        n++;
        if (n == 2) return jsonResponse(500, {'code': 500, 'message': 'boom'});
        return okResponse({'url': 'https://img/$n'});
      });
      backend.on('POST', _checkout, (_) => _created());

      final result = await queue.confirmAllValid();

      expect(result.saved, 2);
      expect(result.duplicates, 0);
      expect(result.notSaved, 1);
      expect((await queue.items()).single.result!.storeName, 'B');
      expect(checkoutBodies().map((b) => b['note']), ['A', 'C']);
    });

    test('a second call while confirming does nothing', () async {
      await readyItems([_scanned('A'), _scanned('B')]);
      uploadsSucceed();
      final arrived = Completer<void>();
      final gate = Completer<void>();
      backend.on('POST', _checkout, (_) async {
        if (!arrived.isCompleted) arrived.complete();
        await gate.future;
        return _created();
      });

      final first = queue.confirmAllValid();
      await arrived.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TestFailure('the first checkout never arrived'),
      );
      final second = await queue.confirmAllValid();
      gate.complete();
      final result = await first;

      expect(second.saved, 0);
      expect(second.duplicates, 0);
      expect(second.notSaved, 0);
      expect(result.saved, 2);
      expect(requestsTo(_checkout), 2);
      expect(await queue.items(), isEmpty);
    });

    test(
      'confirming several receipts moves dataChangedNotifier once',
      () async {
        await readyItems([_scanned('A'), _scanned('B'), _scanned('C')]);
        uploadsSucceed();
        backend.on('POST', _checkout, (_) => _created());
        var changes = 0;
        void count() => changes++;
        RemoteApiHelper.instance.dataChangedNotifier.addListener(count);
        addTearDown(
          () => RemoteApiHelper.instance.dataChangedNotifier.removeListener(
            count,
          ),
        );

        final result = await queue.confirmAllValid();

        expect(result.saved, 3);
        expect(requestsTo(_checkout), 3);
        expect(changes, 1);
      },
    );

    test(
      'offline: the draft goes to the outbox and the item leaves the queue',
      () async {
        await readyItems([_scanned('A')]);
        uploadsSucceed();
        backend.on('POST', _checkout, _noNetwork);

        final result = await queue.confirmAllValid();

        expect(result.saved, 1);
        expect(result.notSaved, 0);
        expect(await queue.items(), isEmpty);
        final waiting = outbox.rows.single;
        expect(waiting.syncStatus, SyncStatus.error);
        expect(waiting.title, 'A');
        expect(waiting.imageUrl, 'https://img/1');
        expect(waiting.rawReceiptData, isNotNull);
      },
    );
  });

  test(
    'a scan result read back from the table equals the one stored',
    () async {
      scanAnswersInOrder();
      await queue.enqueue(await images(1));
      await queue.resume();

      final result = (await queue.items()).single.result!;
      final again = ReceiptScanResult.fromResponse(result.toJson());
      expect(again.storeName, 'Store 1');
      expect(again.allValid, isTrue);
    },
  );
}
