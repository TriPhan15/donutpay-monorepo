import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finance_ai_app/models/scan_queue_item.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

class SqfliteHelper {
  SqfliteHelper._();

  /// A helper on a database the test opened itself (see [openAt]).
  @visibleForTesting
  SqfliteHelper.withDatabase(Database database) : _database = database;

  static final SqfliteHelper instance = SqfliteHelper._();

  static const String _dbName = 'finance_ai_app.db';
  static const int _dbVersion = 9;

  static const String usersTable = 'users';
  static const String transactionsTable = 'transactions';
  static const String categoriesTable = 'categories';
  static const String walletsTable = 'wallets';
  static const String budgetsTable = 'budgets';
  static const String receiptScanQueueTable = 'receipt_scan_queue';

  /// Column definitions of the sync state of a transaction (version 6). Rows that already exist count as synced.
  static const String _clientIdColumnDef =
      '${TransactionModel.columnClientId} TEXT';
  static final String _syncStatusColumnDef =
      "${TransactionModel.columnSyncStatus} TEXT NOT NULL DEFAULT '${SyncStatus.synced.dbValue}'";

  /// Column definitions of the receipt of a transaction that waits to be sent (version 7). Null without a receipt.
  static const String _imageUrlColumnDef =
      '${TransactionModel.columnImageUrl} TEXT';
  static const String _rawReceiptDataColumnDef =
      '${TransactionModel.columnRawReceiptData} TEXT';

  /// Column definition of the "save anyway" of a scanned receipt that waits to be sent (version 9). Rows that already
  /// exist did not ask for it.
  static const String _allowDuplicateColumnDef =
      '${TransactionModel.columnAllowDuplicate} INTEGER NOT NULL DEFAULT 0';

  /// The receipts waiting to be read or confirmed on this device (version 8).
  static const String _createReceiptScanQueueTable =
      '''
CREATE TABLE IF NOT EXISTS $receiptScanQueueTable (
  ${ScanQueueItem.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${ScanQueueItem.columnUserId} INTEGER NOT NULL,
  ${ScanQueueItem.columnImagePath} TEXT NOT NULL,
  ${ScanQueueItem.columnStatus} TEXT NOT NULL,
  ${ScanQueueItem.columnResultJson} TEXT,
  ${ScanQueueItem.columnError} TEXT,
  ${ScanQueueItem.columnCreatedAt} TEXT NOT NULL
)
''';

  Database? _database;

  Future<Database> get database async {
    final cached = _database;
    if (cached != null) return cached;

    _database = await _open();
    return _database!;
  }

  Future<Database> _open() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    return openAt(databaseFactory, p.join(dbPath, _dbName));
  }

  /// Opens (creating or upgrading) the database of the app at [path] through [factory]; the app goes through [database],
  /// tests call it with an FFI factory and a path of their own.
  @visibleForTesting
  static Future<Database> openAt(DatabaseFactory factory, String path) {
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
CREATE TABLE $usersTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  full_name TEXT NOT NULL,
  birthdate TEXT,
  phone TEXT,
  address TEXT
)
''');

    await db.execute('''
CREATE TABLE $transactionsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  amount REAL NOT NULL,
  date TEXT NOT NULL,
  is_expense INTEGER NOT NULL,
  icon_name TEXT NOT NULL DEFAULT 'default',
  wallet_id INTEGER,
  $_clientIdColumnDef,
  $_syncStatusColumnDef,
  $_imageUrlColumnDef,
  $_rawReceiptDataColumnDef,
  $_allowDuplicateColumnDef
)
''');

    await db.execute('''
CREATE TABLE $categoriesTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  icon_name TEXT NOT NULL,
  color_value INTEGER NOT NULL,
  type INTEGER NOT NULL,
  user_id INTEGER
)
''');

    await db.execute('''
CREATE TABLE $walletsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  balance REAL NOT NULL DEFAULT 0,
  color_value INTEGER NOT NULL,
  icon_name TEXT NOT NULL,
  user_id INTEGER
)
''');

    await db.execute('''
CREATE TABLE $budgetsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id INTEGER NOT NULL,
  category_name TEXT NOT NULL,
  limit_amount REAL NOT NULL,
  month INTEGER NOT NULL,
  year INTEGER NOT NULL,
  user_id INTEGER
)
''');

    await db.execute(_createReceiptScanQueueTable);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS $transactionsTable (
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
''');
    }
    if (oldVersion < 3) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS $budgetsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id INTEGER NOT NULL,
  category_name TEXT NOT NULL,
  limit_amount REAL NOT NULL,
  month INTEGER NOT NULL,
  year INTEGER NOT NULL,
  user_id INTEGER
)
''');
    }

    if (oldVersion < 4) {
      final columns = await db.rawQuery(
        'PRAGMA table_info($transactionsTable)',
      );
      final hasIconName = columns.any((c) => c['name'] == 'icon_name');
      if (!hasIconName) {
        await db.execute(
          "ALTER TABLE $transactionsTable ADD COLUMN icon_name TEXT NOT NULL DEFAULT 'default'",
        );
      }
    }

    if (oldVersion < 5) {
      final columns = await db.rawQuery('PRAGMA table_info($usersTable)');
      final hasAddress = columns.any((c) => c['name'] == 'address');
      if (!hasAddress) {
        await db.execute('ALTER TABLE $usersTable ADD COLUMN address TEXT');
      }
    }

    if (oldVersion < 6) {
      final columns = await db.rawQuery(
        'PRAGMA table_info($transactionsTable)',
      );
      bool hasColumn(String name) => columns.any((c) => c['name'] == name);
      if (!hasColumn(TransactionModel.columnClientId)) {
        await db.execute(
          'ALTER TABLE $transactionsTable ADD COLUMN $_clientIdColumnDef',
        );
      }
      if (!hasColumn(TransactionModel.columnSyncStatus)) {
        await db.execute(
          'ALTER TABLE $transactionsTable ADD COLUMN $_syncStatusColumnDef',
        );
      }
    }

    if (oldVersion < 7) {
      final columns = await db.rawQuery(
        'PRAGMA table_info($transactionsTable)',
      );
      bool hasColumn(String name) => columns.any((c) => c['name'] == name);
      if (!hasColumn(TransactionModel.columnImageUrl)) {
        await db.execute(
          'ALTER TABLE $transactionsTable ADD COLUMN $_imageUrlColumnDef',
        );
      }
      if (!hasColumn(TransactionModel.columnRawReceiptData)) {
        await db.execute(
          'ALTER TABLE $transactionsTable ADD COLUMN $_rawReceiptDataColumnDef',
        );
      }
    }

    if (oldVersion < 8) {
      await db.execute(_createReceiptScanQueueTable);
    }

    if (oldVersion < 9) {
      final columns = await db.rawQuery(
        'PRAGMA table_info($transactionsTable)',
      );
      final hasAllowDuplicate = columns.any(
        (c) => c['name'] == TransactionModel.columnAllowDuplicate,
      );
      if (!hasAllowDuplicate) {
        await db.execute(
          'ALTER TABLE $transactionsTable ADD COLUMN $_allowDuplicateColumnDef',
        );
      }
    }
  }

  Future<int> insertTransaction(
    TransactionModel transaction,
    int userId,
  ) async {
    final db = await database;
    return db.insert(
      transactionsTable,
      transaction.toDbMap(userId),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// The transactions of the user that the server has not confirmed (waiting to be sent, or failed), newest first.
  Future<List<TransactionModel>> getUnsyncedTransactions(int userId) async {
    final db = await database;
    final rows = await db.query(
      transactionsTable,
      where: 'user_id = ? AND ${TransactionModel.columnSyncStatus} != ?',
      whereArgs: [userId, SyncStatus.synced.dbValue],
      orderBy: 'date DESC',
    );
    return rows.map(TransactionModel.fromDbMap).toList();
  }

  /// Moves the transaction of the user with this clientId to [status]. Returns how many rows changed.
  Future<int> updateTransactionSyncStatus(
    int userId,
    String clientId,
    SyncStatus status,
  ) async {
    final db = await database;
    return db.update(
      transactionsTable,
      {TransactionModel.columnSyncStatus: status.dbValue},
      where: 'user_id = ? AND ${TransactionModel.columnClientId} = ?',
      whereArgs: [userId, clientId],
    );
  }

  Future<int> deleteTransactionByClientId(int userId, String clientId) async {
    final db = await database;
    return db.delete(
      transactionsTable,
      where: 'user_id = ? AND ${TransactionModel.columnClientId} = ?',
      whereArgs: [userId, clientId],
    );
  }

  /// Deletes the transaction of the user with this clientId only while its last send failed: a row that is being sent
  /// (pending) or that the server confirmed is left alone. Returns how many rows went (0 or 1).
  Future<int> deleteFailedTransaction(int userId, String clientId) async {
    final db = await database;
    return db.delete(
      transactionsTable,
      where:
          'user_id = ? AND ${TransactionModel.columnClientId} = ? AND ${TransactionModel.columnSyncStatus} = ?',
      whereArgs: [userId, clientId, SyncStatus.error.dbValue],
    );
  }

  /// Deletes the rows of the user that the server already confirmed (synced). Rows still waiting or failed (pending,
  /// error) are never touched, nor are the rows of any other user. Returns how many rows went.
  Future<int> deleteSyncedTransactions(int userId) async {
    final db = await database;
    return db.delete(
      transactionsTable,
      where: 'user_id = ? AND ${TransactionModel.columnSyncStatus} = ?',
      whereArgs: [userId, SyncStatus.synced.dbValue],
    );
  }

  /// Adds a receipt image to the scan queue of [userId] as queued and returns the id of its row.
  Future<int> insertScanQueueItem({
    required int userId,
    required String imagePath,
    required DateTime createdAt,
  }) async {
    final db = await database;
    return db.insert(receiptScanQueueTable, {
      ScanQueueItem.columnUserId: userId,
      ScanQueueItem.columnImagePath: imagePath,
      ScanQueueItem.columnStatus: ScanQueueStatus.queued.name,
      ScanQueueItem.columnCreatedAt: createdAt.toIso8601String(),
    });
  }

  /// The scan queue of [userId], oldest first.
  Future<List<ScanQueueItem>> getScanQueueItems(int userId) async {
    final db = await database;
    final rows = await db.query(
      receiptScanQueueTable,
      where: '${ScanQueueItem.columnUserId} = ?',
      whereArgs: [userId],
      orderBy: '${ScanQueueItem.columnId} ASC',
    );
    return rows.map(ScanQueueItem.fromDbMap).toList();
  }

  /// The row [id] of the scan queue of [userId], or null when that user has no such row.
  Future<ScanQueueItem?> getScanQueueItem(int userId, int id) async {
    final db = await database;
    final rows = await db.query(
      receiptScanQueueTable,
      where:
          '${ScanQueueItem.columnUserId} = ? AND ${ScanQueueItem.columnId} = ?',
      whereArgs: [userId, id],
      limit: 1,
    );
    return rows.isEmpty ? null : ScanQueueItem.fromDbMap(rows.first);
  }

  /// The oldest queued row of [userId], or null when nothing waits to be read.
  Future<ScanQueueItem?> nextQueuedScan(int userId) async {
    final db = await database;
    final rows = await db.query(
      receiptScanQueueTable,
      where:
          '${ScanQueueItem.columnUserId} = ? AND ${ScanQueueItem.columnStatus} = ?',
      whereArgs: [userId, ScanQueueStatus.queued.name],
      orderBy: '${ScanQueueItem.columnId} ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : ScanQueueItem.fromDbMap(rows.first);
  }

  /// How many rows of the scan queue of [userId] are in each status; a status without rows is left out.
  Future<Map<ScanQueueStatus, int>> countScanQueueByStatus(int userId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT ${ScanQueueItem.columnStatus} AS status, COUNT(*) AS total FROM $receiptScanQueueTable '
      'WHERE ${ScanQueueItem.columnUserId} = ? GROUP BY ${ScanQueueItem.columnStatus}',
      [userId],
    );
    return {
      for (final row in rows)
        ScanQueueStatus.fromName(row['status'] as String): (row['total'] as num)
            .toInt(),
    };
  }

  /// Moves row [id] to [status] with its [resultJson] and [error] (null clears them). Returns how many rows changed.
  Future<int> updateScanQueueItem(
    int id,
    ScanQueueStatus status, {
    String? resultJson,
    String? error,
  }) async {
    final db = await database;
    return db.update(
      receiptScanQueueTable,
      {
        ScanQueueItem.columnStatus: status.name,
        ScanQueueItem.columnResultJson: resultJson,
        ScanQueueItem.columnError: error,
      },
      where: '${ScanQueueItem.columnId} = ?',
      whereArgs: [id],
    );
  }

  /// Moves the rows of [userId] in status [from] back to queued, keeping nothing of an earlier reading. Returns how many
  /// rows changed. With [id] only that row moves.
  Future<int> requeueScanQueueItems(
    int userId,
    ScanQueueStatus from, {
    int? id,
  }) async {
    final db = await database;
    return db.update(
      receiptScanQueueTable,
      {
        ScanQueueItem.columnStatus: ScanQueueStatus.queued.name,
        ScanQueueItem.columnResultJson: null,
        ScanQueueItem.columnError: null,
      },
      where:
          '${ScanQueueItem.columnUserId} = ? AND ${ScanQueueItem.columnStatus} = ?'
          '${id == null ? '' : ' AND ${ScanQueueItem.columnId} = ?'}',
      whereArgs: [userId, from.name, ?id],
    );
  }

  Future<int> deleteScanQueueItem(int userId, int id) async {
    final db = await database;
    return db.delete(
      receiptScanQueueTable,
      where:
          '${ScanQueueItem.columnUserId} = ? AND ${ScanQueueItem.columnId} = ?',
      whereArgs: [userId, id],
    );
  }
}
