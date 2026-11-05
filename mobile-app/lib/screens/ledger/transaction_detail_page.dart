import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/app_date_format.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/models/receipt_status.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ledger/edit_transaction_page.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_detail_sheet.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_image_viewer.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_status_badge.dart';
import 'package:finance_ai_app/widgets/sync/sync_status_badge.dart';
import 'package:finance_ai_app/widgets/transactions/experience_rating_badge.dart';
import 'package:finance_ai_app/widgets/transactions/transaction_head_card.dart';

/// The details of one transaction (T9 spec, 3.4, layout B): a thin blue band, a head card with the amount, the rows
/// Danh mục / Thời gian / Đánh giá trải nghiệm / Nhận xét trải nghiệm / Hóa đơn / Đồng bộ, the receipt photo, and
/// "Sửa giao dịch" / "Xóa" at the bottom.
/// Closes with true when it edited, deleted or resent the transaction, so the list behind it reloads.
class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({super.key, required this.transaction});

  @visibleForTesting
  static const Key bandKey = ValueKey('transaction-detail-band');
  @visibleForTesting
  static const Key backKey = ValueKey('transaction-detail-back');
  @visibleForTesting
  static const Key photoKey = ValueKey('transaction-detail-photo');

  final TransactionModel transaction;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  static const double _gutter = 16;
  static const double _cardRadius = 20;
  static const double _photoMaxHeight = 360;
  static const double _photoErrorHeight = 160;

  TransactionModel get _tx => widget.transaction;

  /// Whether a savings contribution may be deleted: only by a user without any goal. Null until the goals are read.
  bool? _savingsDeletable;

  /// True while an action runs: a second tap cannot start a second send or delete.
  bool _busy = false;

  /// What the receipt sheet last reported. The page has no way to reload [_tx], so this stands in for its
  /// `receiptStatus` (the record tells "reported no status" from "reported nothing yet").
  ({ReceiptStatus? status})? _reportedReceipt;

  ReceiptStatus? get _receiptStatus =>
      _reportedReceipt == null ? _tx.receiptStatus : _reportedReceipt!.status;

  /// True while the receipt sheet is open: a second tap on the row cannot open a second one.
  bool _receiptSheetOpen = false;

  @override
  void initState() {
    super.initState();
    if (_tx.isSavingsContribution && _tx.id != null) _loadSavingsRule();
  }

  /// A savings contribution belongs to its goal: the server refuses to edit it, and to delete it while the user has a
  /// savings goal (409). When the goals cannot be read the row stays locked.
  Future<void> _loadSavingsRule() async {
    var deletable = false;
    try {
      deletable = (await RemoteApiHelper.instance.fetchSavings()).isEmpty;
    } catch (e) {
      debugPrint('Lỗi tải mục tiêu tiết kiệm: $e');
    }
    if (!mounted) return;
    setState(() => _savingsDeletable = deletable);
  }

  /// Editing goes through the server, so only a transaction it already has can be edited.
  bool get _canEdit => _tx.id != null && !_tx.isSavingsContribution;

  /// A row being sent may already be on the server: it cannot be deleted until its send is over.
  bool get _canDelete =>
      _tx.syncStatus != SyncStatus.pending &&
      (!_tx.isSavingsContribution || _savingsDeletable == true);

  void _close() {
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditTransactionPage(transaction: _tx)),
    );
    if (saved == true) _close();
  }

  Future<void> _delete() async {
    if (_busy) return;
    if (_tx.isUnsynced) return _deleteUnsynced();
    final loc = context.loc;
    final confirmed = await AppDialog.confirm(
      context,
      title: loc.ledgerDeleteTitle,
      message: loc.ledgerDeleteMessage,
      confirmText: loc.ledgerDeleteNow,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await RemoteApiHelper.instance.deleteTransaction(_tx.id!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      await AppDialog.error(
        context,
        title: loc.ledgerDeleteFailed,
        message: UserFacingError.messageOf(e, loc),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    // Deleted on the server for good (there is no restore endpoint), so the toast offers no undo.
    AppToast.success(context, loc.ledgerDeleted);
    _close();
  }

  /// Removes a transaction that the server never confirmed from the device only: there is nothing on the server to
  /// delete, and its local row number is not a server id.
  Future<void> _deleteUnsynced() async {
    final userId = SessionService.currentUserId;
    final clientId = _tx.clientId;
    if (userId == null || clientId == null) return;
    final loc = context.loc;
    final confirmed = await AppDialog.confirm(
      context,
      title: loc.ledgerDeleteUnsyncedTitle,
      message: loc.ledgerDeleteUnsyncedMessage,
      confirmText: loc.ledgerDeleteNow,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final deleted = await AppRepository.instance.deleteUnsyncedTransaction(
      userId,
      clientId,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    // Not deleted: it started being sent after the page opened (the outbox resend); its row has changed either way.
    if (deleted) {
      AppToast.success(context, loc.ledgerDeletedUnsynced);
    } else {
      AppToast.error(context, loc.ledgerDeleteWhileSending);
    }
    _close();
  }

  /// Sends a transaction that the server has not confirmed again. It carries the clientId it was created with, so when
  /// the first send did arrive the server answers with that transaction instead of creating a second one. The page
  /// closes once the outcome is told: the row it shows has changed.
  Future<void> _resend() async {
    if (_busy) return;
    final loc = context.loc;
    final userId = SessionService.currentUserId;
    if (userId == null) {
      await AppDialog.error(
        context,
        title: loc.commonSessionExpiredTitle,
        message: loc.accountInfoSignInAgain,
      );
      return;
    }
    if (_tx.clientId == null) return;
    setState(() => _busy = true);
    SyncStatus? outcome;
    String? failure;
    try {
      outcome = await AppRepository.instance.resendTransaction(userId, _tx);
    } on TransactionRefusedException catch (e) {
      failure = e.messageFor(loc);
    } catch (e) {
      debugPrint('Lỗi gửi lại giao dịch: $e');
      failure = loc.ledgerResendFailedMessage;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) {
      await AppDialog.error(
        context,
        title: loc.ledgerResendFailedTitle,
        message: failure,
      );
    } else if (outcome == SyncStatus.synced) {
      AppToast.success(context, loc.ledgerResent);
    } else if (outcome != null) {
      await AppDialog.warning(
        context,
        title: loc.ledgerStillNotSentTitle,
        message: loc.ledgerStillNotSentMessage,
      );
    }
    // A null outcome without a failure: the row was deleted meanwhile, nothing was sent and there is nothing to say.
    _close();
  }

  /// Only a transaction the server has can have its receipt opened: the receipt is found by the id of the transaction.
  bool get _canOpenReceipt => _tx.id != null && !_tx.isUnsynced;

  Future<void> _openReceipt() async {
    if (_receiptSheetOpen) return;
    _receiptSheetOpen = true;
    await showReceiptDetailSheet(
      context,
      transactionId: _tx.id!,
      onReceipt: (receipt) {
        if (mounted) {
          setState(() => _reportedReceipt = (status: receipt.listStatus));
        }
      },
    );
    _receiptSheetOpen = false;
  }

  void _openPhoto(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptImageViewerPage.network(imageUrl: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = Theme.of(context).colorScheme;
    final imageUrl = _tx.imageUrl;
    final hasButtons = _canEdit || _canDelete;
    // Leaving while a send or a delete runs would hide its outcome.
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            PageBand(
              key: TransactionDetailPage.bandKey,
              buttonKey: TransactionDetailPage.backKey,
              title: loc.transactionDetailTitle,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(_gutter, _gutter, _gutter, 0),
              child: TransactionHeadCard(transaction: _tx),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(_gutter, 12, _gutter, 0),
              child: _rowsCard(context),
            ),
            if (imageUrl != null && imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(_gutter, 16, _gutter, 0),
                child: _photo(context, imageUrl),
              ),
            if (_tx.isSavingsContribution)
              Padding(
                padding: const EdgeInsets.fromLTRB(_gutter, 16, _gutter, 0),
                child: Text(
                  loc.ledgerSavingsManagedByGoal,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: AppTextSize.secondary,
                  ),
                ),
              ),
            const SizedBox(height: _gutter),
          ],
        ),
        bottomNavigationBar: hasButtons ? _buttons(context) : null,
      ),
    );
  }

  Widget _rowsCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final valueStyle = TextStyle(
      color: colors.onSurface,
      fontSize: AppTextSize.body,
      fontWeight: FontWeight.w600,
    );
    final reviewNote = _tx.reviewNote?.trim();
    final rows = <Widget>[
      _DetailRow(
        label: loc.transactionDetailCategory,
        value: Text(
          TransactionCategories.displayName(loc, _tx.category),
          style: valueStyle,
        ),
      ),
      _DetailRow(
        label: loc.transactionDetailTime,
        value: Text(AppDateFormat.dateTime.format(_tx.date), style: valueStyle),
      ),
      if (_tx.isExpense && _tx.rating != null)
        _DetailRow(
          label: loc.transactionDetailExperience,
          value: ExperienceRatingBadge(rating: _tx.rating, compact: false),
        ),
      if (_tx.isExpense && reviewNote != null && reviewNote.isNotEmpty)
        _DetailRow(
          label: loc.transactionDetailReviewNote,
          value: Text(reviewNote, style: valueStyle),
        ),
      if (_receiptStatus != null)
        _DetailRow(
          label: loc.transactionDetailReceipt,
          value: _canOpenReceipt
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReceiptStatusBadge(status: _receiptStatus!),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                )
              : ReceiptStatusBadge(status: _receiptStatus!),
          onTap: _canOpenReceipt ? _openReceipt : null,
        ),
      if (_tx.isUnsynced) _syncRow(context),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _gutter),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.outlineVariant),
            rows[i],
          ],
        ],
      ),
    );
  }

  /// The server has no copy of an unsynced transaction, so the only thing to do with it is to send it again.
  Widget _syncRow(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailRow(
          label: loc.transactionDetailSync,
          value: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              SyncStatusBadge(status: _tx.syncStatus),
              TextButton.icon(
                onPressed: _busy ? null : _resend,
                icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                label: Text(loc.ledgerResend),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            loc.ledgerDetailUnsyncedHint,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: AppTextSize.secondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _photo(BuildContext context, String url) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.transactionDetailReceiptImage,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: AppTextSize.secondary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          key: TransactionDetailPage.photoKey,
          onTap: () => _openPhoto(url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            // Contain, not cover: a long receipt is shown whole, on a muted ground, and the viewer zooms in.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _photoMaxHeight),
              child: Image.network(
                url,
                width: double.infinity,
                fit: BoxFit.contain,
                frameBuilder: (context, child, frame, _) => ColoredBox(
                  color: colors.surfaceContainerHighest,
                  child: child,
                ),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : SizedBox(
                        height: _photoErrorHeight,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes == null
                                ? null
                                : progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!,
                          ),
                        ),
                      ),
                errorBuilder: (context, error, stack) => Container(
                  height: _photoErrorHeight,
                  color: colors.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buttons(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 12),
        child: Row(
          children: [
            if (_canEdit)
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _busy ? null : _edit,
                  child: Text(
                    loc.editTransactionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            if (_canEdit && _canDelete) const SizedBox(width: 12),
            if (_canDelete)
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.errorContainer,
                    foregroundColor: colors.error,
                  ),
                  onPressed: _busy ? null : _delete,
                  child: Text(
                    loc.transactionDetailDelete,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One label / value line of the detail card. A Wrap, not a Row: with a narrow screen or a large font the value drops
/// to its own line instead of overflowing.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.onTap});

  final String label;
  final Widget value;

  /// Makes the whole row a button; null leaves it as plain text.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: AppTextSize.secondary,
              ),
            ),
            value,
          ],
        ),
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}
