import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';

/// A day and a time, as the duplicate dialog names the day of the saved receipt.
const String _dateTimeFormat = 'dd/MM/yyyy HH:mm';

/// How sending a receipt ended: at most one of [duplicate] and [failure] is set, and [status] only when neither is.
class ReceiptSubmitResult {
  const ReceiptSubmitResult({this.status, this.failure, this.duplicate});

  /// Where the transaction was written ([SyncStatus.synced] when the server has it).
  final SyncStatus? status;

  /// The reason the receipt was refused or could not be saved, ready to show.
  final String? failure;

  /// Set when the server takes the receipt for one already saved.
  final DuplicateReceiptException? duplicate;
}

/// Sending a receipt of the review form, without the screen (pure Dart: no context, no dialogs).
class ReceiptSubmitter {
  const ReceiptSubmitter._();

  /// Sends [draft] through AppRepository; the answer, or the reason it failed, in the language of [loc].
  static Future<ReceiptSubmitResult> send(
    int userId,
    TransactionModel draft,
    AppLocalizations loc, {
    bool allowDuplicate = false,
  }) async {
    try {
      final status = await AppRepository.instance.createTransaction(
        userId,
        draft,
        allowDuplicate: allowDuplicate,
      );
      return ReceiptSubmitResult(status: status);
    } on DuplicateReceiptException catch (e) {
      debugPrint('Hóa đơn trùng với giao dịch ${e.existingTransactionId}');
      return ReceiptSubmitResult(duplicate: e);
    } on TransactionRefusedException catch (e) {
      return ReceiptSubmitResult(failure: e.messageFor(loc));
    } catch (e) {
      debugPrint('Lỗi lưu giao dịch từ hóa đơn: $e');
      return ReceiptSubmitResult(failure: loc.transactionSaveFailed);
    }
  }

  /// The title of the question about a duplicate: it names the day of the saved one when the server sent it.
  static String duplicateTitle(
    AppLocalizations loc,
    DuplicateReceiptException duplicate,
  ) {
    final savedAt = duplicate.existingTransactionDate;
    return savedAt == null
        ? loc.reviewDuplicateTitleNoDate
        : loc.reviewDuplicateTitle(DateFormat(_dateTimeFormat).format(savedAt));
  }
}
