import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/models/user_model.dart';
import 'package:finance_ai_app/models/wallet_model.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/sqflite_helper.dart';

/// The server understood a transaction and refused it (a category that does not exist, a balance that is too low ...),
/// so sending it again cannot help until the data changes. [message] is the reason core-backend gave, if any, in its
/// own language; screens show [messageFor].
class TransactionRefusedException implements Exception {
  const TransactionRefusedException(this.message);

  final String? message;

  /// The reason, ready to show in the language of [loc]: the server's own when the user can read it, else a fixed text.
  String messageFor(AppLocalizations loc) =>
      (UserFacingError.readsServerMessages(loc) ? message : null) ??
      loc.transactionRefused;

  @override
  String toString() => 'TransactionRefusedException: $message';
}

/// The server took a scanned receipt for one the user already saved (409 with the id of that transaction) and wrote
/// nothing. Sending it again with allowDuplicate saves it anyway; a manual transaction is never checked.
class DuplicateReceiptException extends TransactionRefusedException {
  const DuplicateReceiptException(
    super.message, {
    required this.existingTransactionId,
    this.existingTransactionDate,
  });

  /// The server id of the transaction already saved, and its date when the server sent one.
  final int existingTransactionId;
  final DateTime? existingTransactionDate;

  static const String _fieldExistingId = 'existingTransactionId';
  static const String _fieldExistingDate = 'existingTransactionDate';

  /// The duplicate that [e] reports, or null when it is another answer (a 409 without the id of a transaction is a
  /// plain refusal).
  static DuplicateReceiptException? from(DioException e) {
    final response = e.response;
    if (response?.statusCode != HttpStatus.conflict) return null;
    final body = response?.data;
    final data = body is Map ? body['data'] : null;
    if (data is! Map) return null;
    final id = data[_fieldExistingId];
    if (id is! num) return null;
    final date = data[_fieldExistingDate];
    return DuplicateReceiptException(
      UserFacingError.serverMessageOf(body),
      existingTransactionId: id.toInt(),
      existingTransactionDate: date is String ? DateTime.tryParse(date) : null,
    );
  }

  @override
  String toString() =>
      'DuplicateReceiptException: $message (transaction $existingTransactionId)';
}

class AppRepository {
  static final AppRepository instance = AppRepository._();
  AppRepository._();

  /// How the backend labels expense categories in GET /api/categories.
  static const String _serverExpenseType = 'EXPENSE';

  /// 4xx answers that say nothing about the transaction itself (the session ran out, the server timed out or is busy),
  /// so the transaction is kept and can be sent again. Every other 4xx is a refusal of the transaction.
  static const Set<int> _retryableClientErrors = {
    HttpStatus.unauthorized,
    HttpStatus.requestTimeout,
    HttpStatus.tooManyRequests,
  };

  /// Where the transactions that the server has not confirmed are kept; only tests replace it.
  SqfliteHelper _localStore = SqfliteHelper.instance;

  @visibleForTesting
  set localStore(SqfliteHelper store) => _localStore = store;

  /// The send of the whole outbox in flight (see [resendUnsyncedTransactions]); a second call joins it.
  Future<void>? _outboxResend;

  /// The transactions of the server plus the ones created on this device that it has not confirmed yet (see
  /// [getUnsyncedTransactions]), those first because they need the attention of the user. Throws when the server cannot
  /// be reached.
  ///
  /// A waiting transaction whose clientId is already in the server list did arrive (only the answer got lost), so it is
  /// left out, otherwise it would count twice, and flagged synced on this device.
  Future<List<TransactionModel>> getTransactions(int userId) async {
    final onServer = await RemoteApiHelper.instance.fetchTransactions();
    final onServerClientIds = {
      for (final tx in onServer)
        if (tx.clientId != null) tx.clientId!,
    };
    final waiting = <TransactionModel>[];
    for (final tx in await getUnsyncedTransactions(userId)) {
      if (onServerClientIds.contains(tx.clientId)) {
        await _localStore.updateTransactionSyncStatus(
          userId,
          tx.clientId!,
          SyncStatus.synced,
        );
      } else {
        waiting.add(tx);
      }
    }
    return [...waiting, ...onServer];
  }

  /// The transactions created on this device that the server has not confirmed: waiting to be sent, or failed.
  Future<List<TransactionModel>> getUnsyncedTransactions(int userId) async {
    return _localStore.getUnsyncedTransactions(userId);
  }

  /// The name /api/users/me carries (username, set from the profile form), unless it is only the email the account
  /// was registered with: then the part of the email before the @, as before. Without either, the default name in the
  /// language the app shows.
  @visibleForTesting
  static String displayNameOf(Map<String, dynamic> me) {
    final email = (me['email'] ?? '').toString().trim();
    final username = (me['username'] ?? '').toString().trim();
    if (username.isNotEmpty && username != email) return username;
    return email.isNotEmpty
        ? email.split('@').first
        : AppLanguage.current.localizations.defaultUserName;
  }

  Future<UserModel?> getCurrentUser(int userId) async {
    return _userOf(await RemoteApiHelper.instance.fetchMe());
  }

  static UserModel _userOf(Map<String, dynamic> me) => UserModel(
    id: (me['id'] as num?)?.toInt(),
    email: (me['email'] ?? '').toString(),
    password: '',
    fullName: displayNameOf(me),
    phone: me['phone']?.toString(),
  );

  /// The balance the server keeps for the user (/api/users/me), 0 when it does not send one.
  @visibleForTesting
  static double walletBalanceOf(Map<String, dynamic> me) =>
      (me['walletBalance'] as num?)?.toDouble() ?? 0;

  /// The single wallet of the user, named in the language the app shows.
  static WalletModel _mainWallet(double balance, int userId) => WalletModel(
    name: AppLanguage.current.localizations.mainWalletName,
    balance: balance,
    userId: userId,
  );

  /// Keys of the map [getHomeSummary] returns.
  static const String summaryUser = 'user';
  static const String summaryTransactions = 'transactions';
  static const String summaryWallets = 'wallets';

  /// The signed total (income plus, expense minus) of the transactions that wait on this device: the server balance
  /// does not include them yet.
  static const String summaryPendingWalletChange = 'pendingWalletChange';

  /// The user, the transactions and the wallet in one round trip each: /me once and /mine once. The wallet carries the
  /// balance of the server; what still waits on the device is reported apart in [summaryPendingWalletChange].
  Future<Map<String, dynamic>> getHomeSummary(int userId) async {
    final results = await Future.wait<Object>([
      RemoteApiHelper.instance.fetchMe(),
      getTransactions(userId),
    ]);

    final me = results[0] as Map<String, dynamic>;
    final txs = results[1] as List<TransactionModel>;
    final pending = txs
        .where((t) => t.isUnsynced)
        .fold<double>(0.0, (s, t) => s + (t.isExpense ? -t.amount : t.amount));

    return {
      summaryUser: _userOf(me),
      summaryTransactions: txs,
      summaryWallets: [_mainWallet(walletBalanceOf(me), userId)],
      summaryPendingWalletChange: pending,
    };
  }

  /// Saves a new transaction made on this device and returns where it ended up.
  ///
  /// It is first written to the local table as pending, so that it survives a crash or a lost connection,
  /// and then sent to the server together with its clientId. The result is [SyncStatus.synced] once the server has it, or
  /// [SyncStatus.error] when it could not be sent for a reason that sending again can fix (no network, timeout, server
  /// error): it stays on the device, flagged, until the user resends it. Throws [TransactionRefusedException] when the
  /// server refuses it, and keeps nothing then, because the user still has the form to correct. A scanned receipt the
  /// server takes for one already saved is such a refusal too ([DuplicateReceiptException]): nothing waits on the
  /// device, and the user decides whether to create it again with [allowDuplicate], which is stored with the row so a
  /// resend from the outbox carries it too.
  ///
  /// dataChangedNotifier moves once, after the row is flagged (not at all on a refusal: nothing changed).
  Future<SyncStatus> createTransaction(
    int userId,
    TransactionModel draft, {
    bool allowDuplicate = false,
  }) async {
    final clientId = _clientIdOf(draft);
    final stored = allowDuplicate ? draft.allowingDuplicate() : draft;
    await _localStore.insertTransaction(
      stored.withSyncStatus(SyncStatus.pending),
      userId,
    );
    try {
      return await _send(userId, stored);
    } on TransactionRefusedException {
      await _localStore.deleteTransactionByClientId(userId, clientId);
      rethrow;
    }
  }

  /// Sends a transaction that the server has not confirmed again, with the same clientId: when the first send did arrive
  /// and only the answer got lost, the server answers with the transaction it already has instead of creating a second
  /// one. The result is that of [createTransaction], except that a refusal keeps the transaction (flagged error), so the
  /// user can still delete it. Null when the row is no longer on the device (the user deleted it meanwhile): nothing is
  /// sent then.
  Future<SyncStatus?> resendTransaction(
    int userId,
    TransactionModel transaction,
  ) async {
    final flagged = await _localStore.updateTransactionSyncStatus(
      userId,
      _clientIdOf(transaction),
      SyncStatus.pending,
    );
    if (flagged == 0) return null;
    try {
      return await _send(userId, transaction);
    } on TransactionRefusedException {
      // Kept, flagged error; create shows nothing here because it deletes its row again.
      _notifyOutboxChanged();
      rethrow;
    }
  }

  /// Sends every transaction waiting on this device once more, oldest first, without asking the user: called when the
  /// app opens and when the user refreshes the Ledger. A refusal keeps the transaction flagged error, for the user to
  /// correct or delete, and the others are still sent. Never throws.
  ///
  /// Each send moves dataChangedNotifier, so it must not be started from a listener of it: offline, every failed send
  /// would start the next one.
  ///
  /// The server answers a clientId it already has with that transaction, so a row being resent by the user meanwhile is
  /// not created twice.
  Future<void> resendUnsyncedTransactions(int userId) {
    return _outboxResend ??= _resendOutbox(
      userId,
    ).whenComplete(() => _outboxResend = null);
  }

  Future<void> _resendOutbox(int userId) async {
    try {
      for (final tx in await getUnsyncedTransactions(userId)) {
        try {
          await resendTransaction(userId, tx);
        } on TransactionRefusedException catch (e) {
          debugPrint('Máy chủ từ chối giao dịch ${tx.clientId}: ${e.message}');
        }
      }
    } catch (e) {
      debugPrint('Lỗi tự gửi lại giao dịch chờ: $e');
    }
  }

  /// Throws away, for good, a transaction that the server never confirmed, but only one whose last send failed: a row
  /// that is being sent (pending) may already be on the server. False when nothing was deleted for that reason (or the
  /// row is gone).
  Future<bool> deleteUnsyncedTransaction(int userId, String clientId) async {
    final deleted = await _localStore.deleteFailedTransaction(userId, clientId);
    if (deleted == 0) return false;
    _notifyOutboxChanged();
    return true;
  }

  /// One attempt to send a transaction that is already in the local table, after which its flag says how it went. Only a
  /// refusal is thrown (a duplicate receipt as [DuplicateReceiptException]); any other failure of the request is an
  /// outcome ([SyncStatus.error]), not an exception.
  Future<SyncStatus> _send(int userId, TransactionModel transaction) async {
    final clientId = _clientIdOf(transaction);
    try {
      await RemoteApiHelper.instance.addTransaction(
        transaction.toCheckoutJson(),
      );
    } on DioException catch (e) {
      debugPrint('Lỗi gửi giao dịch $clientId: $e');
      await _localStore.updateTransactionSyncStatus(
        userId,
        clientId,
        SyncStatus.error,
      );
      final duplicate = DuplicateReceiptException.from(e);
      if (duplicate != null) throw duplicate;
      if (_isRefusal(e)) throw TransactionRefusedException(_refusalMessage(e));
      _notifyOutboxChanged();
      return SyncStatus.error;
    }
    await _localStore.updateTransactionSyncStatus(
      userId,
      clientId,
      SyncStatus.synced,
    );
    _notifyOutboxChanged();
    return SyncStatus.synced;
  }

  /// The outbox changed. After a send it is the only announcement of the write: addTransaction makes none, because a
  /// reload started before the row is flagged synced would still list the row as waiting.
  static void _notifyOutboxChanged() {
    RemoteApiHelper.instance.notifyDataChanged();
  }

  static String _clientIdOf(TransactionModel transaction) {
    return transaction.clientId ??
        (throw ArgumentError.value(
          transaction,
          'transaction',
          'has no clientId, so it was not created on this device',
        ));
  }

  /// True when the server answered and said no to the transaction. No answer at all (no network, a timeout) and a server
  /// error are not a refusal: the transaction may still be accepted later.
  static bool _isRefusal(DioException e) {
    final status = e.response?.statusCode;
    if (status == null) return false;
    return status >= HttpStatus.badRequest &&
        status < HttpStatus.internalServerError &&
        !_retryableClientErrors.contains(status);
  }

  static String? _refusalMessage(DioException e) =>
      UserFacingError.serverMessageOf(e.response?.data);

  /// All the budgets of the user from the server, newest first. Callers pick the ones of a period themselves, see
  /// BudgetModel.coversDay and BudgetModel.overlaps.
  Future<List<BudgetModel>> getBudgets(int userId) {
    return RemoteApiHelper.instance.getBudgets();
  }

  /// Like [getBudgets] for screens that show budgets next to other data: a failure comes back as null, so the rest of
  /// the screen still loads and can say that the budgets are missing.
  Future<List<BudgetModel>?> tryGetBudgets(int userId) async {
    try {
      return await getBudgets(userId);
    } catch (e) {
      debugPrint('Lỗi tải ngân sách: $e');
      return null;
    }
  }

  /// Creates the budget, or updates it when it already has an id, and returns the stored copy.
  Future<BudgetModel> saveBudget(int userId, BudgetModel budget) async {
    return budget.id == null
        ? RemoteApiHelper.instance.createBudget(budget)
        : RemoteApiHelper.instance.updateBudget(budget);
  }

  Future<void> deleteBudget(int budgetId) async {
    await RemoteApiHelper.instance.deleteBudget(budgetId);
  }

  /// The expense categories a budget can be limited to, from the server; empty when there are none.
  Future<List<BudgetCategory>> getExpenseCategories(int userId) async {
    final categories = await RemoteApiHelper.instance.fetchCategories();
    return [
      for (final category in categories)
        if (category['type'] == _serverExpenseType &&
            !TransactionCategories.isSavings(category['name'].toString()))
          (
            id: (category['id'] as num).toInt(),
            name: category['name'].toString(),
          ),
    ];
  }
}
