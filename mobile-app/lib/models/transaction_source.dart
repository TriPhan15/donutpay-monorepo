import 'package:finance_ai_app/l10n/app_localizations.dart';

/// Where a transaction comes from, as core-backend says it in the `source` field (TransactionSource).
///
/// Only a [normal] transaction is income or spending of the user. The other two move money without earning or spending
/// it: the wallet changes, but no total, budget or analysis may count them.
enum TransactionSource {
  /// Made by the user: an income or an expense.
  normal,

  /// The money of a deleted savings goal going back to the wallet.
  goalRefund,

  /// Money moved between the wallet of the app and a linked e-wallet.
  walletTransfer,

  /// A value this version of the app does not know: kept out of the totals, like the two above, and shown without a label.
  unknown;

  static const String _serverNormal = 'NORMAL';
  static const String _serverGoalRefund = 'GOAL_REFUND';
  static const String _serverWalletTransfer = 'WALLET_TRANSFER';

  /// The source for the value the server sent. A missing or empty one (an old server, an old JSON) is [normal].
  static TransactionSource fromServer(Object? raw) {
    if (raw == null) return TransactionSource.normal;
    if (raw is! String) return TransactionSource.unknown;
    return switch (raw.trim().toUpperCase()) {
      '' || _serverNormal => TransactionSource.normal,
      _serverGoalRefund => TransactionSource.goalRefund,
      _serverWalletTransfer => TransactionSource.walletTransfer,
      _ => TransactionSource.unknown,
    };
  }

  /// The text that names the source on a transaction row, or null when there is nothing to say.
  String? label(AppLocalizations loc) => switch (this) {
    TransactionSource.goalRefund => loc.transactionSourceGoalRefund,
    TransactionSource.walletTransfer => loc.transactionSourceWalletTransfer,
    TransactionSource.normal || TransactionSource.unknown => null,
  };
}
