import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' show DatabaseException;

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/core/utils/date_helper.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/scan_queue_item.dart';
import 'package:finance_ai_app/screens/receipt_scanner/review_form_page.dart';
import 'package:finance_ai_app/services/receipt_scan_queue.dart';
import 'package:finance_ai_app/widgets/common/primary_button.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

/// The receipts of the scan queue of the user: each one with its status, a review of the read ones, another reading of
/// the failed ones, and one button that saves every receipt needing no review. The list follows the queue while it
/// reads.
class PendingReceiptsScreen extends StatefulWidget {
  /// Shows a saved transaction in the Ledger, for the review form ("View the saved one" of a duplicate).
  final ValueChanged<int>? onOpenTransaction;

  const PendingReceiptsScreen({super.key, this.onOpenTransaction});

  @override
  State<PendingReceiptsScreen> createState() => _PendingReceiptsScreenState();
}

class _PendingReceiptsScreenState extends State<PendingReceiptsScreen> {
  final ReceiptScanQueue _queue = ReceiptScanQueue.instance;

  /// Null until the first load.
  List<ScanQueueItem>? _items;

  /// Only the answer of the latest load is shown, however the loads finish.
  int _loadSeq = 0;

  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _queue.progress.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _queue.progress.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final seq = ++_loadSeq;
    final List<ScanQueueItem> items;
    try {
      items = await _queue.items();
    } on DatabaseException catch (e) {
      debugPrint('Không đọc được hàng đợi quét: $e');
      if (!mounted) return;
      setState(() => _items ??= const []);
      AppToast.error(context, context.loc.scanQueueStorageFailed);
      return;
    }
    if (!mounted || seq != _loadSeq) return;
    setState(() => _items = items);
  }

  /// Runs [action] on the queue, then shows the queue as it is now.
  Future<void> _change(Future<void> Function() action) async {
    try {
      await action();
    } on DatabaseException catch (e) {
      debugPrint('Không cập nhật được hàng đợi quét: $e');
      if (!mounted) return;
      AppToast.error(context, context.loc.scanQueueStorageFailed);
    }
    if (!mounted) return;
    await _reload();
  }

  Future<void> _review(ScanQueueItem item) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewFormPage(
          imagePath: item.imagePath,
          initialScan: item.result,
          onOpenTransaction: widget.onOpenTransaction == null
              ? null
              : _openTransaction,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    await _change(() => _queue.markConfirmed(item.id));
  }

  /// The review form has closed itself; this list closes too, so the Ledger shows the transaction.
  void _openTransaction(int id) {
    if (mounted) Navigator.pop(context);
    widget.onOpenTransaction?.call(id);
  }

  Future<void> _discard(ScanQueueItem item) async {
    final loc = context.loc;
    final discard = await AppDialog.confirm(
      context,
      title: loc.pendingDiscardConfirm,
      confirmText: loc.pendingDiscard,
      danger: true,
    );
    if (!mounted || !discard) return;
    await _change(() => _queue.remove(item.id));
  }

  Future<void> _retry(ScanQueueItem item) =>
      _change(() => _queue.retry(item.id));

  Future<void> _confirmAll(int count) async {
    final loc = context.loc;
    final go = await AppDialog.confirm(
      context,
      title: loc.pendingConfirmAllAsk(count),
    );
    if (!mounted || !go) return;
    setState(() => _confirming = true);
    BulkConfirmResult? result;
    try {
      result = await _queue.confirmAllValid();
    } on DatabaseException catch (e) {
      debugPrint('Lỗi xác nhận hàng loạt hóa đơn: $e');
    }
    if (!mounted) return;
    setState(() => _confirming = false);
    _showConfirmOutcome(result);
    await _reload();
  }

  /// "Saved x, duplicates y, not saved z"; a success only when every receipt was saved.
  void _showConfirmOutcome(BulkConfirmResult? result) {
    final loc = context.loc;
    if (result == null) {
      AppToast.error(context, loc.scanQueueStorageFailed);
      return;
    }
    final message = loc.pendingConfirmAllResult(
      result.saved,
      result.duplicates,
      result.notSaved,
    );
    if (result.duplicates == 0 && result.notSaved == 0) {
      AppToast.success(context, message);
    } else {
      AppToast.info(context, message);
    }
  }

  static bool _isValid(ScanQueueItem item) =>
      item.status == ScanQueueStatus.ready && (item.result?.allValid ?? false);

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final items = _items;
    final validCount = items?.where(_isValid).length ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(loc.pendingReceiptsTitle)),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? _EmptyQueue(message: loc.pendingReceiptsEmpty)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return _PendingReceiptTile(
                  item: item,
                  onReview: item.status == ScanQueueStatus.ready
                      ? () => _review(item)
                      : null,
                  onRetry: item.status == ScanQueueStatus.failed
                      ? () => _retry(item)
                      : null,
                  onDiscard:
                      item.status == ScanQueueStatus.ready ||
                          item.status == ScanQueueStatus.failed
                      ? () => _discard(item)
                      : null,
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: PrimaryButton(
            text: loc.pendingConfirmAll(validCount),
            onPressed: validCount == 0 || _confirming
                ? null
                : () => _confirmAll(validCount),
          ),
        ),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  final String message;

  const _EmptyQueue({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 56,
              color: colors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// One receipt of the queue, a card like the rows of the Ledger.
class _PendingReceiptTile extends StatelessWidget {
  static const double _thumbSize = 56;
  static const double _radius = 20;

  final ScanQueueItem item;
  final VoidCallback? onReview;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  const _PendingReceiptTile({
    required this.item,
    this.onReview,
    this.onRetry,
    this.onDiscard,
  });

  static String _errorText(AppLocalizations loc, String? error) =>
      switch (error) {
        ScanQueueError.network => loc.pendingErrorNetwork,
        ScanQueueError.missingImage => loc.pendingErrorMissingImage,
        _ => loc.pendingErrorServer,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;
    final result = item.result;
    final storeName = result?.storeName ?? '';
    final amount = result?.amount;
    final dateText = DateHelper.formatTransactionDate(
      loc,
      result?.date ?? item.createdAt,
    );
    final details = [
      if (amount != null)
        CurrencyHelper.formatVND(amount, loc, showSign: false),
      if (storeName.isNotEmpty) dateText,
    ].join(' • ');

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onReview,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(path: item.imagePath, size: _thumbSize),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName.isNotEmpty ? storeName : dateText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        details,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (item.status == ScanQueueStatus.failed) ...[
                      const SizedBox(height: 2),
                      Text(
                        _errorText(loc, item.error),
                        style: TextStyle(color: colors.error, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusChip(status: item.status),
                        if (onRetry != null)
                          _TileAction(
                            label: loc.pendingRetry,
                            color: colors.primary,
                            onPressed: onRetry!,
                          ),
                        if (onDiscard != null)
                          _TileAction(
                            label: loc.pendingDiscard,
                            color: colors.error,
                            onPressed: onDiscard!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String path;
  final double size;

  const _Thumbnail({required this.path, required this.size});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.primary.withValues(alpha: 0.10),
      child: Icon(Icons.receipt_long_rounded, color: colors.primary),
    );
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: size,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: pixels,
          errorBuilder: (_, _, _) => placeholder,
          frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
              wasSynchronouslyLoaded || frame != null ? child : placeholder,
        ),
      ),
    );
  }
}

class _TileAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _TileAction({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

/// The status of a receipt of the queue, a pill like the receipt badge of the Ledger.
class _StatusChip extends StatelessWidget {
  final ScanQueueStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;
    final (color, icon, label) = switch (status) {
      ScanQueueStatus.queued => (
        theme.colorScheme.onSurfaceVariant,
        Icons.schedule_rounded,
        loc.pendingStatusQueued,
      ),
      ScanQueueStatus.reading => (
        theme.semanticColors.warningColor,
        Icons.sync_rounded,
        loc.pendingStatusReading,
      ),
      ScanQueueStatus.ready => (
        theme.semanticColors.successColor,
        Icons.check_circle_rounded,
        loc.pendingStatusReady,
      ),
      ScanQueueStatus.failed => (
        theme.colorScheme.error,
        Icons.error_rounded,
        loc.pendingStatusFailed,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
