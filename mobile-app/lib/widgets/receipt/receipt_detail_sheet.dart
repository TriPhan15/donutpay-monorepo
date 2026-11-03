import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/core/utils/money_input_formatter.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/receipt_detail.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/common/custom_text_field.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';
import 'package:finance_ai_app/widgets/inputs/date_field.dart';

/// Opens the sheet of the receipt that belongs to the transaction [transactionId] (a transaction the server has): its
/// state in the lifecycle, and, depending on it, editing it, reading the photo again or sending the right amount.
/// Returns true when one of those actions went through, so the caller knows the receipt is not what it was.
///
/// [onReceipt] is told every time the sheet has the receipt from the server, so a page behind it can keep the label of
/// its status up to date while the sheet is still open.
///
/// The sheet is not dragged away: while a request runs it cannot be closed at all, and a drag would not ask first.
Future<bool> showReceiptDetailSheet(
  BuildContext context, {
  required String transactionId,
  ValueChanged<ReceiptDetail>? onReceipt,
}) async {
  var changed = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ReceiptDetailSheet(
      transactionId: transactionId,
      onReceipt: onReceipt,
      onChanged: () => changed = true,
    ),
  );
  return changed;
}

const double _blockRadius = 16;

/// What the sheet shows below its title.
enum _Mode { view, edit, sendAmount }

/// The photo of a FAILED receipt could not be downloaded for a new scan.
class _PhotoUnavailable implements Exception {
  const _PhotoUnavailable();
}

class ReceiptDetailSheet extends StatefulWidget {
  const ReceiptDetailSheet({
    super.key,
    required this.transactionId,
    this.onReceipt,
    this.onChanged,
  });

  final String transactionId;
  final ValueChanged<ReceiptDetail>? onReceipt;
  final VoidCallback? onChanged;

  @override
  State<ReceiptDetailSheet> createState() => _ReceiptDetailSheetState();
}

class _ReceiptDetailSheetState extends State<ReceiptDetailSheet> {
  static const double _gutter = 16;
  static const Uuid _uuid = Uuid();

  final TextEditingController _vendorController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();
  MoneyInputFormatter? _moneyFormatter;

  ReceiptDetail? _receipt;
  _Mode _mode = _Mode.view;

  /// True until the first answer; a reload keeps showing the receipt it has.
  bool _loading = true;

  /// True while a request runs: a second tap cannot start a second one, and the sheet cannot be closed.
  bool _busy = false;

  /// The day picked in the edit form; null while the receipt's own day stands.
  DateTime? _pickedDate;

  /// The key of the last retry request, kept while that request may have reached the server (no answer, or a 5xx) so
  /// that tapping "Read again" once more records the same reading once, not twice.
  String? _retryClientId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_receipt == null) setState(() => _loading = true);
    try {
      final receipt = await RemoteApiHelper.instance.fetchReceiptOfTransaction(
        widget.transactionId,
      );
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _loading = false;
      });
      widget.onReceipt?.call(receipt);
    } catch (e) {
      UserFacingError.log('loadReceipt', e);
      if (!mounted) return;
      setState(() => _loading = false);
      // A receipt already on screen stays; only a first load that failed has nothing to show but the error.
      if (_receipt != null) AppToast.error(context, _messageOf(e));
    }
  }

  String _messageOf(Object error) {
    final loc = context.loc;
    final conflict =
        error is DioException &&
        error.response?.statusCode == HttpStatus.conflict;
    return error is _PhotoUnavailable
        ? loc.receiptDetailPhotoFailed
        : UserFacingError.messageOf(
            error,
            loc,
            rejectedMessage: conflict ? loc.receiptDetailConflict : null,
          );
  }

  /// Runs one action of the receipt: [run] makes the request and returns the toast to show once it went through. A
  /// refusal because the receipt has changed (409) is told with the message of the server and the receipt is loaded
  /// again, to get the version and the state it has now.
  Future<void> _act(Future<(AppToastKind, String)> Function() run) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final (kind, message) = await run();
      if (!mounted) return;
      widget.onChanged?.call();
      setState(() => _mode = _Mode.view);
      AppToast.show(context, kind, message);
      await _load();
    } catch (e) {
      UserFacingError.log('receiptAction', e);
      if (!mounted) return;
      AppToast.error(context, _messageOf(e));
      if (e is DioException && e.response?.statusCode == HttpStatus.conflict) {
        setState(() => _mode = _Mode.view);
        await _load();
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
  }

  // ---- edit ----

  void _startEdit(ReceiptDetail receipt) {
    final total = receipt.extractedTotal;
    _vendorController.text = receipt.vendorName ?? '';
    _totalController.text = total == null
        ? ''
        : MoneyInputFormatter.format(total, context.loc.localeName);
    _moneyFormatter = MoneyInputFormatter(context.loc.localeName);
    setState(() {
      _pickedDate = null;
      _mode = _Mode.edit;
    });
  }

  /// The fields of the edit form that differ from the receipt; a field left as it was is not sent.
  ({String? vendorName, double? total, DateTime? date}) _edits(
    ReceiptDetail receipt,
  ) {
    final vendor = _vendorController.text.trim();
    final total = MoneyInputFormatter.parse(_totalController.text);
    final picked = _pickedDate;
    final shownDate = receipt.extractedDate;
    return (
      vendorName: vendor == (receipt.vendorName ?? '') ? null : vendor,
      total: total == null || total == receipt.extractedTotal?.roundToDouble()
          ? null
          : total,
      date: picked == null || _sameDay(picked, shownDate) ? null : picked,
    );
  }

  static bool _sameDay(DateTime a, DateTime? b) =>
      b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  /// Something changed, and the total is either left as it was or a valid amount (a total cannot be cleared).
  bool _canSave(ReceiptDetail receipt) {
    final edits = _edits(receipt);
    final totalTyped = _totalController.text.trim().isNotEmpty;
    final totalValid =
        MoneyInputFormatter.parse(_totalController.text) != null ||
        (!totalTyped && receipt.extractedTotal == null);
    return totalValid &&
        (edits.vendorName != null || edits.total != null || edits.date != null);
  }

  Future<void> _save(ReceiptDetail receipt) async {
    if (_busy || !_canSave(receipt)) return;
    final loc = context.loc;
    final edits = _edits(receipt);
    await _act(() async {
      await RemoteApiHelper.instance.updateReceipt(
        receipt.id,
        version: receipt.version,
        vendorName: edits.vendorName,
        extractedTotal: edits.total,
        extractedDate: edits.date,
      );
      return (AppToastKind.success, loc.receiptDetailEdited);
    });
  }

  // ---- read again ----

  Future<void> _readAgain(ReceiptDetail receipt) async {
    if (_busy || !receipt.canRetry || !receipt.hasImage) return;
    final loc = context.loc;
    await _act(() async {
      final updated = await _scanAgainAndSend(receipt);
      return updated.status == ReceiptLifecycle.failed
          ? (AppToastKind.info, loc.receiptDetailRetryStillFailed)
          : (AppToastKind.success, loc.receiptDetailRetried);
    });
  }

  /// The photo goes to a temporary file (downloaded without the login token, it is on the image host), the AI service
  /// reads it, and what it answered is sent to core-backend. The file is removed whatever happens.
  Future<ReceiptDetail> _scanAgainAndSend(ReceiptDetail receipt) async {
    final api = RemoteApiHelper.instance;
    final path = await api.downloadToTemp(receipt.imageUrl!);
    if (path == null) throw const _PhotoUnavailable();
    try {
      final scan = await api.scanReceipt(path);
      final clientId = _retryClientId ??= _uuid.v4();
      final updated = await api.retryReceipt(
        receipt.id,
        rawReceiptData: jsonEncode(scan),
        clientId: clientId,
      );
      _retryClientId = null;
      return updated;
    } catch (e) {
      if (!_mayHaveReachedServer(e)) _retryClientId = null;
      rethrow;
    } finally {
      await _deleteQuietly(path);
    }
  }

  /// No answer at all, or a server error: the request may have been recorded, so a repeat has to carry its key.
  static bool _mayHaveReachedServer(Object error) {
    if (error is! DioException) return false;
    final status = error.response?.statusCode;
    return status == null || status >= HttpStatus.internalServerError;
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException catch (e) {
      debugPrint('Không xóa được tệp tạm $path: $e');
    }
  }

  // ---- send the right amount ----

  void _startSendAmount(ReceiptDetail receipt) {
    final total = receipt.extractedTotal;
    _totalController.text = total == null
        ? ''
        : MoneyInputFormatter.format(total, context.loc.localeName);
    _moneyFormatter = MoneyInputFormatter(context.loc.localeName);
    setState(() => _mode = _Mode.sendAmount);
  }

  Future<void> _sendAmount(ReceiptDetail receipt) async {
    final amount = MoneyInputFormatter.parse(_totalController.text);
    if (_busy || amount == null) return;
    final loc = context.loc;
    await _act(() async {
      await RemoteApiHelper.instance.submitReceiptFeedback(receipt.id, amount);
      return (AppToastKind.success, loc.receiptDetailAmountSent);
    });
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, _gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        loc.receiptDetailTitle,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: AppTextSize.title,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _busy ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: 8),
                _body(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final receipt = _receipt;
    if (receipt == null) {
      return _loading
          ? const AppStateView.loading()
          : AppStateView.error(
              title: context.loc.receiptDetailLoadFailedTitle,
              onRetry: _load,
            );
    }
    return switch (_mode) {
      _Mode.view => _view(context, receipt),
      _Mode.edit => _editForm(context, receipt),
      _Mode.sendAmount => _sendAmountForm(context, receipt),
    };
  }

  Widget _view(BuildContext context, ReceiptDetail receipt) {
    final loc = context.loc;
    final colors = Theme.of(context).colorScheme;
    final total = receipt.extractedTotal;
    final date = receipt.extractedDate;
    final rows = <(String, String)>[
      (loc.receiptDetailStatus, _statusLabel(loc, receipt.status)),
      (
        loc.receiptDetailVendor,
        _nonBlank(receipt.vendorName) ?? loc.receiptDetailNoValue,
      ),
      (
        loc.receiptDetailTotal,
        total == null
            ? loc.receiptDetailNoValue
            : CurrencyHelper.formatVND(total, loc, showSign: false),
      ),
      (
        loc.receiptDetailDate,
        date == null
            ? loc.receiptDetailNoValue
            : DateFormat(DateField.displayPattern).format(date),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: _gutter),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(_blockRadius),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colors.outlineVariant),
                _InfoRow(label: rows[i].$1, value: rows[i].$2),
              ],
            ],
          ),
        ),
        if (receipt.status == ReceiptLifecycle.failed) ...[
          const SizedBox(height: 12),
          _FailureBlock(message: receipt.errorMessage),
        ],
        ..._actions(context, receipt),
      ],
    );
  }

  List<Widget> _actions(BuildContext context, ReceiptDetail receipt) {
    final loc = context.loc;
    final buttons = <Widget>[
      if (receipt.canEdit)
        FilledButton(
          onPressed: _busy ? null : () => _startEdit(receipt),
          child: _ButtonText(loc.receiptDetailEdit),
        ),
      if (receipt.canRetry && receipt.hasImage)
        FilledButton(
          onPressed: _busy ? null : () => _readAgain(receipt),
          child: _ButtonText(loc.receiptDetailRetry),
        ),
      if (receipt.canSendAmount)
        OutlinedButton(
          onPressed: _busy ? null : () => _startSendAmount(receipt),
          child: _ButtonText(loc.receiptDetailSendAmount),
        ),
    ];
    return [
      for (final button in buttons) ...[const SizedBox(height: 12), button],
    ];
  }

  Widget _editForm(BuildContext context, ReceiptDetail receipt) {
    final loc = context.loc;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextField(
          controller: _vendorController,
          label: loc.receiptDetailVendor,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _totalController,
          label: loc.receiptDetailTotal,
          keyboardType: TextInputType.number,
          inputFormatters: [_moneyFormatter!],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        DateField(
          value: _pickedDate ?? receipt.extractedDate ?? DateTime.now(),
          lastDate: DateTime.now(),
          onChanged: (day) => setState(() => _pickedDate = day),
        ),
        const SizedBox(height: 12),
        Text(
          loc.receiptDetailEditHint,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: AppTextSize.secondary,
          ),
        ),
        const SizedBox(height: 16),
        _FormButtons(
          cancelLabel: loc.dialogCancel,
          confirmLabel: loc.commonSave,
          onCancel: _busy ? null : () => setState(() => _mode = _Mode.view),
          onConfirm: _busy || !_canSave(receipt) ? null : () => _save(receipt),
        ),
      ],
    );
  }

  Widget _sendAmountForm(BuildContext context, ReceiptDetail receipt) {
    final loc = context.loc;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          loc.receiptDetailSendAmountHint,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: AppTextSize.secondary,
          ),
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _totalController,
          label: loc.receiptDetailTotal,
          keyboardType: TextInputType.number,
          inputFormatters: [_moneyFormatter!],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _FormButtons(
          cancelLabel: loc.dialogCancel,
          confirmLabel: loc.receiptDetailSend,
          onCancel: _busy ? null : () => setState(() => _mode = _Mode.view),
          onConfirm:
              _busy || MoneyInputFormatter.parse(_totalController.text) == null
              ? null
              : () => _sendAmount(receipt),
        ),
      ],
    );
  }

  static String? _nonBlank(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _statusLabel(AppLocalizations loc, String status) =>
      switch (status) {
        ReceiptLifecycle.pending => loc.receiptDetailStatusPending,
        ReceiptLifecycle.processing => loc.receiptDetailStatusProcessing,
        ReceiptLifecycle.completedRaw => loc.receiptDetailStatusCompleted,
        ReceiptLifecycle.edited => loc.receiptDetailStatusEdited,
        ReceiptLifecycle.failed => loc.receiptDetailStatusFailed,
        ReceiptLifecycle.waitingForReview =>
          loc.receiptDetailStatusWaitingForReview,
        ReceiptLifecycle.approved => loc.receiptDetailStatusApproved,
        ReceiptLifecycle.canceled => loc.receiptDetailStatusCanceled,
        _ => loc.receiptDetailStatusUnknown,
      };
}

/// One label / value line. A Wrap, not a Row: on a narrow screen or with a large font the value drops to its own line.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
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
                color: colors.onSurfaceVariant,
                fontSize: AppTextSize.secondary,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: AppTextSize.body,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why the receipt is FAILED: the fixed text the server sends with its error code.
class _FailureBlock extends StatelessWidget {
  const _FailureBlock({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reason = message;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(_blockRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_rounded, color: colors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.loc.receiptDetailFailedTitle,
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    fontSize: AppTextSize.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (reason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    reason,
                    style: TextStyle(
                      color: colors.onErrorContainer,
                      fontSize: AppTextSize.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cancel and the main button of a form; the text of each stays on one line.
class _FormButtons extends StatelessWidget {
  const _FormButtons({
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            child: _ButtonText(cancelLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: onConfirm,
            child: _ButtonText(confirmLabel),
          ),
        ),
      ],
    );
  }
}

class _ButtonText extends StatelessWidget {
  const _ButtonText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
}
