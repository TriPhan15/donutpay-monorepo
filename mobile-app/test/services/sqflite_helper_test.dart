import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finance_ai_app/models/scan_queue_item.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/services/sqflite_helper.dart';

const int _currentVersion = 11;
const int _userId = 1;
const int _otherUserId = 2;
const String _transactions = 'transactions';

/// The transactions table of an app that never knew icon_name (created before version 4).
const String _transactionsV3 = '''
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  amount REAL NOT NULL,
  date TEXT NOT NULL,
  is_expense INTEGER NOT NULL,
  wallet_id INTEGER
)
''';

/// The transactions table as versions 4 and 5 left it: no sync columns yet.
const String _transactionsV5 = '''
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  amount REAL NOT NULL,
  date TEXT NOT NULL,
  is_expense INTEGER NOT NULL,
  icon_name TEXT NOT NULL DEFAULT 'default',
  wallet_id INTEGER
)
''';

/// Version 6 added the sync state; the receipt columns came with version 7.
const String _transactionsV6 = '''
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
  sync_status TEXT NOT NULL DEFAULT 'synced'
)
''';

/// Versions 7 and 8 have the same transactions table; the scan queue is what version 8 added.
const String _transactionsV7 = '''
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

/// The scan queue that version 8 added.
const String _scanQueueV8 = '''
CREATE TABLE receipt_scan_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  image_path TEXT NOT NULL,
  status TEXT NOT NULL,
  result_json TEXT,
  error TEXT,
  created_at TEXT NOT NULL
)
''';

const String _usersV1 = '''
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  full_name TEXT NOT NULL,
  birthdate TEXT,
  phone TEXT
)
''';

const String _budgetsV3 = '''
CREATE TABLE budgets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id INTEGER NOT NULL,
  category_name TEXT NOT NULL,
  limit_amount REAL NOT NULL,
  month INTEGER NOT NULL,
  year INTEGER NOT NULL,
  user_id INTEGER
)
''';

/// The columns every transaction row needs, for [title] with [clientId] in [syncStatus]; a null [syncStatus] or
/// [clientId] leaves the column out, as a database from before that column would.
Map<String, Object?> _row(
  String title, {
  String? clientId,
  String? syncStatus,
  int userId = _userId,
}) => {
  'user_id': userId,
  'title': title,
  'category': 'Ăn uống',
  'amount': 45000,
  'date': '2026-09-20T08:30:00.000',
  'is_expense': 1,
  'client_id': ?clientId,
  'sync_status': ?syncStatus,
};

TransactionModel _draft(String title) => TransactionModel.draft(
  title: title,
  category: 'Ăn uống',
  amount: 45000,
  date: DateTime(2026, 9, 20, 8, 30),
  isExpense: true,
);

Future<List<String>> _columnsOf(Database db, String table) async {
  final info = await db.rawQuery('PRAGMA table_info($table)');
  return [for (final c in info) c['name'] as String];
}

void main() {
  late Directory temp;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('sqflite_helper_test');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  group('outbox', () {
    late Database db;
    late SqfliteHelper store;

    setUp(() async {
      db = await SqfliteHelper.openAt(
        databaseFactoryFfiNoIsolate,
        inMemoryDatabasePath,
      );
      store = SqfliteHelper.withDatabase(db);
    });

    tearDown(() => db.close());

    test(
      'a new database is at the current version with the sync columns',
      () async {
        expect(await db.getVersion(), _currentVersion);
        expect(
          await _columnsOf(db, _transactions),
          containsAll([
            TransactionModel.columnClientId,
            TransactionModel.columnSyncStatus,
            TransactionModel.columnImageUrl,
            TransactionModel.columnRawReceiptData,
            TransactionModel.columnAllowDuplicate,
            TransactionModel.columnRating,
            TransactionModel.columnReviewNote,
            TransactionModel.columnLocation,
          ]),
        );
      },
    );

    test(
      'deleteSyncedTransactions removes only the synced rows of that user and keeps every unsent row',
      () async {
        await db.insert(
          _transactions,
          _row('a', clientId: 'a', syncStatus: 'synced'),
        );
        await db.insert(
          _transactions,
          _row('b', clientId: 'b', syncStatus: 'pending'),
        );
        await db.insert(
          _transactions,
          _row('c', clientId: 'c', syncStatus: 'error'),
        );
        await db.insert(
          _transactions,
          _row('d', clientId: 'd', syncStatus: 'synced', userId: _otherUserId),
        );

        final removed = await store.deleteSyncedTransactions(_userId);

        expect(removed, 1);
        final left = await db.query(_transactions, orderBy: 'title');
        expect([for (final r in left) '${r['user_id']}:${r['sync_status']}'], [
          '1:pending',
          '1:error',
          '2:synced',
        ]);
      },
    );

    test(
      'a pending row is stored with its client id and read back as unsynced',
      () async {
        final tx = _draft('Cà phê').withSyncStatus(SyncStatus.pending);

        await store.insertTransaction(tx, _userId);

        final waiting = await store.getUnsyncedTransactions(_userId);
        expect(waiting, hasLength(1));
        expect(waiting.single.clientId, tx.clientId);
        expect(waiting.single.syncStatus, SyncStatus.pending);
        expect(waiting.single.isUnsynced, isTrue);
        expect(waiting.single.title, 'Cà phê');
        // A row the server has not confirmed has no id there: its row number must not pass for one.
        expect(waiting.single.id, isNull);
      },
    );

    test('the receipt of a pending row survives the round trip', () async {
      final tx = TransactionModel.draft(
        title: 'Highlands',
        category: 'Ăn uống',
        amount: 45000,
        date: DateTime(2026, 9, 20, 8, 30),
        isExpense: true,
        imageUrl: '/uploads/a.jpg',
        rawReceiptData: '{"seller":"Highlands"}',
      ).withSyncStatus(SyncStatus.pending);

      await store.insertTransaction(tx, _userId);

      final read = (await store.getUnsyncedTransactions(_userId)).single;
      expect(read.imageUrl, '/uploads/a.jpg');
      expect(read.rawReceiptData, '{"seller":"Highlands"}');
    });

    test('the location of a pending row survives the round trip', () async {
      final tx = TransactionModel.draft(
        title: 'Highlands',
        category: 'Ăn uống',
        amount: 45000,
        date: DateTime(2026, 9, 20, 8, 30),
        isExpense: true,
        location: '12 Lê Lợi',
      ).withSyncStatus(SyncStatus.pending);

      await store.insertTransaction(tx, _userId);

      final read = (await store.getUnsyncedTransactions(_userId)).single;
      expect(read.location, '12 Lê Lợi');
    });

    test('the rating and review note of a pending row survive the round trip', () async {
      final tx = TransactionModel.draft(
        title: 'Highlands',
        category: 'Ăn uống',
        amount: 45000,
        date: DateTime(2026, 9, 20, 8, 30),
        isExpense: true,
        rating: 4.5,
        reviewNote: 'Phục vụ nhiệt tình',
      ).withSyncStatus(SyncStatus.pending);

      await store.insertTransaction(tx, _userId);

      final read = (await store.getUnsyncedTransactions(_userId)).single;
      expect(read.rating, 4.5);
      expect(read.reviewNote, 'Phục vụ nhiệt tình');
    });

    test(
      'changing the sync status moves the row between pending, error and synced',
      () async {
        final tx = _draft('Cà phê').withSyncStatus(SyncStatus.pending);
        await store.insertTransaction(tx, _userId);

        expect(
          await store.updateTransactionSyncStatus(
            _userId,
            tx.clientId!,
            SyncStatus.error,
          ),
          1,
        );
        expect(
          (await store.getUnsyncedTransactions(_userId)).single.syncStatus,
          SyncStatus.error,
        );

        expect(
          await store.updateTransactionSyncStatus(
            _userId,
            tx.clientId!,
            SyncStatus.pending,
          ),
          1,
        );
        expect(
          (await store.getUnsyncedTransactions(_userId)).single.syncStatus,
          SyncStatus.pending,
        );

        expect(
          await store.updateTransactionSyncStatus(
            _userId,
            tx.clientId!,
            SyncStatus.synced,
          ),
          1,
        );
        expect(await store.getUnsyncedTransactions(_userId), isEmpty);
        expect((await db.query(_transactions)).single['sync_status'], 'synced');
      },
    );

    test(
      'a status change touches only the row of that user and that client id',
      () async {
        final mine = _draft('Của tôi').withSyncStatus(SyncStatus.pending);
        final sameIdOtherUser = _draft(
          'Của người khác',
        ).withSyncStatus(SyncStatus.pending);
        final otherOfMine = _draft('Khác').withSyncStatus(SyncStatus.pending);
        await store.insertTransaction(mine, _userId);
        await store.insertTransaction(otherOfMine, _userId);
        await store.insertTransaction(sameIdOtherUser, _otherUserId);

        final changed = await store.updateTransactionSyncStatus(
          _otherUserId,
          sameIdOtherUser.clientId!,
          SyncStatus.error,
        );
        final unknown = await store.updateTransactionSyncStatus(
          _userId,
          'no-such-client-id',
          SyncStatus.error,
        );

        expect(changed, 1);
        expect(unknown, 0);
        final mineNow = await store.getUnsyncedTransactions(_userId);
        expect(
          mineNow.map((t) => t.syncStatus),
          everyElement(SyncStatus.pending),
        );
        expect(
          (await store.getUnsyncedTransactions(_otherUserId)).single.syncStatus,
          SyncStatus.error,
        );
      },
    );

    test(
      'unsynced rows are the user\'s own, newest first, without the synced ones',
      () async {
        final older = TransactionModel.draft(
          title: 'Cũ',
          category: 'Ăn uống',
          amount: 1000,
          date: DateTime(2026, 9, 1),
          isExpense: true,
        ).withSyncStatus(SyncStatus.error);
        final newer = TransactionModel.draft(
          title: 'Mới',
          category: 'Ăn uống',
          amount: 2000,
          date: DateTime(2026, 9, 25),
          isExpense: true,
        ).withSyncStatus(SyncStatus.pending);
        final confirmed = _draft('Đã gửi');
        final someoneElses = _draft(
          'Người khác',
        ).withSyncStatus(SyncStatus.pending);
        await store.insertTransaction(older, _userId);
        await store.insertTransaction(newer, _userId);
        await store.insertTransaction(confirmed, _userId);
        await store.insertTransaction(someoneElses, _otherUserId);

        final waiting = await store.getUnsyncedTransactions(_userId);

        expect(waiting.map((t) => t.title), ['Mới', 'Cũ']);
      },
    );

    test(
      'deleteTransactionByClientId removes the row of that user only',
      () async {
        final tx = _draft('Cà phê').withSyncStatus(SyncStatus.pending);
        await store.insertTransaction(tx, _userId);

        expect(
          await store.deleteTransactionByClientId(_otherUserId, tx.clientId!),
          0,
        );
        expect(await store.getUnsyncedTransactions(_userId), hasLength(1));
        expect(
          await store.deleteTransactionByClientId(_userId, tx.clientId!),
          1,
        );
        expect(await store.getUnsyncedTransactions(_userId), isEmpty);
      },
    );

    test(
      'deleteFailedTransaction keeps a pending row and a synced one',
      () async {
        final pending = _draft('Đang gửi').withSyncStatus(SyncStatus.pending);
        final failed = _draft('Lỗi').withSyncStatus(SyncStatus.error);
        final synced = _draft('Đã gửi');
        for (final tx in [pending, failed, synced]) {
          await store.insertTransaction(tx, _userId);
        }

        expect(
          await store.deleteFailedTransaction(_userId, pending.clientId!),
          0,
        );
        expect(
          await store.deleteFailedTransaction(_userId, synced.clientId!),
          0,
        );
        expect(
          await store.deleteFailedTransaction(_userId, failed.clientId!),
          1,
        );

        expect(
          (await db.query(_transactions)).map((r) => r['title']),
          unorderedEquals(['Đang gửi', 'Đã gửi']),
        );
      },
    );

    test(
      'the scan queue keeps its rows by user and moves them between statuses',
      () async {
        final createdAt = DateTime(2026, 9, 20, 8);
        final first = await store.insertScanQueueItem(
          userId: _userId,
          imagePath: 'a.jpg',
          createdAt: createdAt,
        );
        final second = await store.insertScanQueueItem(
          userId: _userId,
          imagePath: 'b.jpg',
          createdAt: createdAt,
        );
        await store.insertScanQueueItem(
          userId: _otherUserId,
          imagePath: 'c.jpg',
          createdAt: createdAt,
        );

        expect((await store.getScanQueueItems(_userId)).map((i) => i.id), [
          first,
          second,
        ]);
        expect((await store.nextQueuedScan(_userId))!.id, first);

        await store.updateScanQueueItem(
          first,
          ScanQueueStatus.failed,
          error: 'x',
        );
        expect((await store.nextQueuedScan(_userId))!.id, second);
        expect(await store.countScanQueueByStatus(_userId), {
          ScanQueueStatus.failed: 1,
          ScanQueueStatus.queued: 1,
        });

        expect(
          await store.requeueScanQueueItems(_userId, ScanQueueStatus.failed),
          1,
        );
        expect(
          (await store.getScanQueueItem(_userId, first))!.status,
          ScanQueueStatus.queued,
        );
        expect(await store.getScanQueueItem(_otherUserId, first), isNull);
        expect(await store.deleteScanQueueItem(_otherUserId, first), 0);
        expect(await store.deleteScanQueueItem(_userId, first), 1);
      },
    );
  });

  group('upgrade', () {
    /// Creates a database file at [version] with [schema], fills it through [fill], closes it, and opens it again through
    /// the app: that runs the migrations from [version] to the current one.
    Future<Database> upgraded(
      int version,
      Future<void> Function(Database db) schema, {
      Future<void> Function(Database db)? fill,
    }) async {
      final path = p.join(temp.path, 'v$version.db');
      final old = await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: version,
          onCreate: (db, _) => schema(db),
        ),
      );
      if (fill != null) await fill(old);
      await old.close();

      final db = await SqfliteHelper.openAt(databaseFactoryFfiNoIsolate, path);
      addTearDown(db.close);
      return db;
    }

    test(
      'from version 1: the transactions and budgets tables appear and the users stay',
      () async {
        final db = await upgraded(
          1,
          (db) => db.execute(_usersV1),
          fill: (db) async {
            await db.insert('users', {
              'email': 'a@b.vn',
              'password': 'hash',
              'full_name': 'An',
            });
          },
        );

        expect(await db.getVersion(), _currentVersion);
        final user = (await db.query('users')).single;
        expect(user['email'], 'a@b.vn');
        expect(await _columnsOf(db, 'users'), contains('address'));
        expect(user['address'], isNull);
        expect(
          await _columnsOf(db, _transactions),
          containsAll([
            'icon_name',
            TransactionModel.columnClientId,
            TransactionModel.columnSyncStatus,
            TransactionModel.columnImageUrl,
            TransactionModel.columnRawReceiptData,
            TransactionModel.columnAllowDuplicate,
            TransactionModel.columnRating,
            TransactionModel.columnReviewNote,
          ]),
        );
        expect(await db.query('budgets'), isEmpty);
        expect(await db.query(SqfliteHelper.receiptScanQueueTable), isEmpty);
      },
    );

    test(
      'from version 3: icon_name, address, the sync columns and allow_duplicate arrive with defaults',
      () async {
        final db = await upgraded(
          3,
          (db) async {
            await db.execute(_usersV1);
            await db.execute(_transactionsV3);
            await db.execute(_budgetsV3);
          },
          fill: (db) async {
            await db.insert('users', {
              'email': 'a@b.vn',
              'password': 'hash',
              'full_name': 'An',
            });
            await db.insert(_transactions, _row('Cà phê'));
            await db.insert('budgets', {
              'category_id': 4,
              'category_name': 'Ăn uống',
              'limit_amount': 2000000,
              'month': 9,
              'year': 2026,
              'user_id': _userId,
            });
          },
        );

        expect(await db.getVersion(), _currentVersion);
        final row = (await db.query(_transactions)).single;
        expect(row['title'], 'Cà phê');
        expect(row['icon_name'], 'default');
        expect(row[TransactionModel.columnSyncStatus], 'synced');
        expect(row[TransactionModel.columnClientId], isNull);
        expect(row[TransactionModel.columnImageUrl], isNull);
        expect(row[TransactionModel.columnAllowDuplicate], 0);
        expect((await db.query('budgets')).single['limit_amount'], 2000000);
        expect(await _columnsOf(db, 'users'), contains('address'));
        // Rows from before the outbox are not waiting to be sent.
        expect(
          await SqfliteHelper.withDatabase(db).getUnsyncedTransactions(_userId),
          isEmpty,
        );
      },
    );

    test(
      'from version 5: the old rows count as synced and a new pending row can be added',
      () async {
        final db = await upgraded(
          5,
          (db) => db.execute(_transactionsV5),
          fill: (db) => db.insert(_transactions, _row('Cũ')),
        );
        final store = SqfliteHelper.withDatabase(db);

        expect(await store.getUnsyncedTransactions(_userId), isEmpty);
        final tx = _draft('Mới').withSyncStatus(SyncStatus.pending);
        await store.insertTransaction(tx, _userId);

        expect(
          (await store.getUnsyncedTransactions(_userId)).single.clientId,
          tx.clientId,
        );
        expect(await db.query(_transactions), hasLength(2));
      },
    );

    // Versions 6, 7 and 8 are the ones that can hold rows waiting to be sent: the outbox must come through each of them.
    final outboxVersions = <int, List<String>>{
      6: [_transactionsV6],
      7: [_transactionsV7],
      8: [_transactionsV7, _scanQueueV8],
    };
    for (final entry in outboxVersions.entries) {
      test(
        'from version ${entry.key}: pending, failed and synced rows are all kept and can still be resent',
        () async {
          final db = await upgraded(
            entry.key,
            (db) async {
              for (final statement in entry.value) {
                await db.execute(statement);
              }
            },
            fill: (db) async {
              await db.insert(
                _transactions,
                _row('Đang gửi', clientId: 'c-pending', syncStatus: 'pending'),
              );
              await db.insert(
                _transactions,
                _row('Lỗi', clientId: 'c-error', syncStatus: 'error'),
              );
              await db.insert(
                _transactions,
                _row('Đã gửi', clientId: 'c-synced', syncStatus: 'synced'),
              );
            },
          );
          final store = SqfliteHelper.withDatabase(db);

          expect(await db.getVersion(), _currentVersion);
          expect(await db.query(_transactions), hasLength(3));
          final waiting = await store.getUnsyncedTransactions(_userId);
          expect(
            {for (final t in waiting) t.clientId: t.syncStatus},
            {'c-pending': SyncStatus.pending, 'c-error': SyncStatus.error},
          );
          expect(waiting.map((t) => t.allowDuplicate), everyElement(isFalse));

          // The status can be changed on the upgraded table, and the row keeps its client id.
          expect(
            await store.updateTransactionSyncStatus(
              _userId,
              'c-error',
              SyncStatus.pending,
            ),
            1,
          );
          expect(
            (await store.getUnsyncedTransactions(
              _userId,
            )).map((t) => t.syncStatus),
            everyElement(SyncStatus.pending),
          );
          expect(
            await store.updateTransactionSyncStatus(
              _userId,
              'c-pending',
              SyncStatus.synced,
            ),
            1,
          );
          expect(
            (await store.getUnsyncedTransactions(_userId)).single.clientId,
            'c-error',
          );
          expect(await db.query(SqfliteHelper.receiptScanQueueTable), isEmpty);
        },
      );
    }

    test('from version 6: the receipt columns are added empty', () async {
      final db = await upgraded(
        6,
        (db) => db.execute(_transactionsV6),
        fill: (db) => db.insert(
          _transactions,
          _row('Cà phê', clientId: 'c-1', syncStatus: 'pending'),
        ),
      );

      final row = (await db.query(_transactions)).single;
      expect(row[TransactionModel.columnImageUrl], isNull);
      expect(row[TransactionModel.columnRawReceiptData], isNull);
    });

    test('from version 10: the location column is added and rows stay', () async {
      final db = await upgraded(
        10,
        (db) => db.execute(_transactionsV6),
        fill: (db) => db.insert(
          _transactions,
          _row('Cà phê', clientId: 'c-1', syncStatus: 'pending'),
        ),
      );

      final row = (await db.query(_transactions)).single;
      expect(row['title'], 'Cà phê');
      expect(row[TransactionModel.columnLocation], isNull);
    });

    test('a column that is already there is not added twice', () async {
      // A database that took the sync columns without the version being raised (an upgrade that stopped half way).
      final db = await upgraded(
        5,
        (db) => db.execute(_transactionsV6),
        fill: (db) => db.insert(
          _transactions,
          _row('Cà phê', clientId: 'c-1', syncStatus: 'error'),
        ),
      );

      expect(await db.getVersion(), _currentVersion);
      final columns = await _columnsOf(db, _transactions);
      expect(
        columns.where((c) => c == TransactionModel.columnClientId),
        hasLength(1),
      );
      expect(
        columns.where((c) => c == TransactionModel.columnSyncStatus),
        hasLength(1),
      );
      expect(
        (await db.query(
          _transactions,
        )).single[TransactionModel.columnSyncStatus],
        'error',
      );
    });

    test('opening a current database again changes nothing', () async {
      final path = p.join(temp.path, 'current.db');
      final first = await SqfliteHelper.openAt(
        databaseFactoryFfiNoIsolate,
        path,
      );
      final tx = _draft('Cà phê').withSyncStatus(SyncStatus.pending);
      await SqfliteHelper.withDatabase(first).insertTransaction(tx, _userId);
      await first.close();

      final second = await SqfliteHelper.openAt(
        databaseFactoryFfiNoIsolate,
        path,
      );
      addTearDown(second.close);

      expect(await second.getVersion(), _currentVersion);
      final waiting = await SqfliteHelper.withDatabase(
        second,
      ).getUnsyncedTransactions(_userId);
      expect(waiting.single.clientId, tx.clientId);
    });
  });
}
