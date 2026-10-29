import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' show DatabaseException;

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/pending_queue_view.dart';
import 'package:finance_ai_app/models/review_exit.dart';
import 'package:finance_ai_app/models/scan_queue_item.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/screens/receipt_scanner/review_form_page.dart';
import 'package:finance_ai_app/screens/receipt_scanner/widgets/pending_receipt_card.dart';
import 'package:finance_ai_app/services/receipt_scan_queue.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';
import 'package:finance_ai_app/widgets/common/pill_segmented.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

/// The receipts of the scan queue of the user (T9 spec, 3.1 "Chờ xác nhận"): grouped up to five, in tabs above that;
/// a quick save, a review or another reading per receipt; a swipe to drop one; a long press to select several; and the
/// count and total of the receipts that can be saved at once over "Xác nhận tất cả". The list follows the queue while
/// it reads.
class PendingReceiptsScreen extends StatefulWidget {
  /// Shows a saved transaction in the Ledger, for the review form ("View the saved one" of a duplicate).
  final ValueChanged<int>? onOpenTransaction;

  const PendingReceiptsScreen({super.key, this.onOpenTransaction});

  @override
  State<PendingReceiptsScreen> createState() => _PendingReceiptsScreenState();
}

class _PendingReceiptsScreenState extends State<PendingReceiptsScreen> {
  static const double _gutter = 16;

  final ReceiptScanQueue _queue = ReceiptScanQueue.instance;

  /// Null until the first load.
  List<ScanQueueItem>? _items;

  /// Only the answer of the latest load is shown, however the loads finish.
  int _loadSeq = 0;

  bool _confirming = false;

  /// The tab picked by the user; null follows [PendingQueueView.defaultTab].
  PendingTab? _tab;

  bool _selecting = false;
  final Set<int> _selected = {};

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
    setState(() {
      _items = items;
      // A receipt saved or dropped meanwhile cannot stay selected.
      final savable = {
        for (final item in PendingQueueView.of(items).quickSavable) item.id,
      };
      _selected.retainWhere(savable.contains);
    });
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

  /// Opens the review form; after "Lưu & quét tiếp" the next ready receipt follows, until none is left.
  Future<void> _review(ScanQueueItem item) async {
    final exit = await Navigator.push<ReviewExit>(
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
    if (!mounted || exit == null) return;
    // Picked while the saved receipt is still in the list, so "next" is the one after it.
    final next = PendingQueueView.of(_items ?? const []).nextReady(item.id);
    await _change(() => _queue.markConfirmed(item.id));
    if (!mounted || exit != ReviewExit.savedScanNext || next == null) return;
    // It may have been saved or dropped meanwhile.
    final stillReady = PendingQueueView.of(
      _items ?? const [],
    ).ready.where((candidate) => candidate.id == next.id);
    if (stillReady.isNotEmpty) await _review(stillReady.first);
  }

  /// The review form has closed itself; this list closes too, so the Ledger shows the transaction.
  void _openTransaction(int id) {
    if (mounted) Navigator.pop(context);
    widget.onOpenTransaction?.call(id);
  }

  Future<bool> _askDiscard() async {
    final loc = context.loc;
    return AppDialog.confirm(
      context,
      title: loc.pendingDiscardConfirm,
      confirmText: loc.pendingDiscard,
      danger: true,
    );
  }

  /// The card is already gone from the screen (the swipe); the queue follows.
  Future<void> _discard(ScanQueueItem item) {
    setState(() => _items = [...?_items]..remove(item));
    return _change(() => _queue.remove(item.id));
  }

  Future<void> _retry(ScanQueueItem item) =>
      _change(() => _queue.retry(item.id));

  /// Saves [ids] (null: every receipt that can be saved at once) and sums up the outcome.
  Future<void> _save(Set<int>? ids) async {
    if (_confirming) return;
    setState(() => _confirming = true);
    BulkConfirmResult? result;
    try {
      result = ids == null
          ? await _queue.confirmAllValid()
          : await _queue.confirmItems(ids);
    } on DatabaseException catch (e) {
      debugPrint('Lỗi xác nhận hóa đơn: $e');
    }
    if (!mounted) return;
    setState(() {
      _confirming = false;
      _selecting = false;
      _selected.clear();
    });
    _showConfirmOutcome(result);
    await _reload();
  }

  Future<void> _confirmAll(int count) async {
    final go = await AppDialog.confirm(
      context,
      title: context.loc.pendingConfirmAllAsk(count),
    );
    if (!mounted || !go) return;
    await _save(null);
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

  void _startSelecting(ScanQueueItem item) {
    setState(() {
      _selecting = true;
      _selected.add(item.id);
    });
  }

  void _toggle(ScanQueueItem item) {
    setState(() {
      if (!_selected.remove(item.id)) _selected.add(item.id);
    });
  }

  void _stopSelecting() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  /// The title of [item]: its store, "Đang đọc…" or "Ảnh n" by its place in the whole list.
  String _titleOf(ScanQueueItem item, List<ScanQueueItem> all) {
    final loc = context.loc;
    final store = item.result?.storeName ?? '';
    return switch (item.status) {
      ScanQueueStatus.ready when store.isNotEmpty => store,
      ScanQueueStatus.ready => loc.pendingReadingTitle,
      ScanQueueStatus.failed => loc.pendingPhotoTitle(all.indexOf(item) + 1),
      _ => loc.pendingReadingTitle,
    };
  }

  Widget _card(ScanQueueItem item, List<ScanQueueItem> all, bool savable) {
    // While a save runs nothing opens or drops a receipt it may be saving.
    final ready = item.status == ScanQueueStatus.ready && !_confirming;
    final failed = item.status == ScanQueueStatus.failed;
    final card = PendingReceiptCard(
      item: item,
      title: _titleOf(item, all),
      selecting: _selecting && savable,
      selected: _selected.contains(item.id),
      onTap: _selecting
          ? (savable ? () => _toggle(item) : null)
          : (ready ? () => _review(item) : null),
      onLongPress: savable && !_selecting ? () => _startSelecting(item) : null,
      onQuickSave: savable && !_confirming ? () => _save({item.id}) : null,
      onReview: ready && !savable ? () => _review(item) : null,
      onRetry: failed ? () => _retry(item) : null,
    );
    // A receipt being read is still the queue's: only a ready or failed one can be dropped.
    if (_selecting || _confirming || !(ready || failed)) return card;
    return Dismissible(
      key: ValueKey('pending-${item.id}'),
      direction: DismissDirection.endToStart,
      background: const _DiscardBackground(),
      confirmDismiss: (_) => _askDiscard(),
      onDismissed: (_) => _discard(item),
      child: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final items = _items;
    final view = PendingQueueView.of(items ?? const []);
    final savable = {for (final item in view.quickSavable) item.id};
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) _stopSelecting();
      },
      child: Scaffold(
        body: Column(
          children: [
            _selecting
                ? PageBand(
                    title: loc.pendingSelected(_selected.length),
                    action: PageBandAction.close,
                    onAction: _stopSelecting,
                    trailing: _BandPill(
                      label: loc.pendingSelectAll,
                      onTap: () => setState(() => _selected.addAll(savable)),
                    ),
                  )
                : PageBand(title: loc.pendingReceiptsTitle),
            ValueListenableBuilder<ScanQueueProgress>(
              valueListenable: _queue.progress,
              builder: (_, progress, _) => progress.isReading
                  ? _ReadingStrip(progress: progress)
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: items == null
                  ? const AppStateView.loading()
                  : items.isEmpty
                  ? AppStateView.empty(
                      icon: Icons.receipt_long_outlined,
                      title: loc.pendingReceiptsEmpty,
                    )
                  : _list(view, items, savable),
            ),
            if (items != null && items.isNotEmpty) _bottomBar(view),
          ],
        ),
      ),
    );
  }

  Widget _list(
    PendingQueueView view,
    List<ScanQueueItem> all,
    Set<int> savable,
  ) {
    final loc = context.loc;
    Widget cards(List<ScanQueueItem> group) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in group)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _card(item, all, savable.contains(item.id)),
          ),
      ],
    );
    final children = <Widget>[];
    if (view.useTabs) {
      final tab = _tab ?? view.defaultTab;
      children
        ..add(
          PillSegmented<PendingTab>(
            options: [
              (
                PendingTab.ready,
                loc.pendingGroupReady(view.inTab(PendingTab.ready).length),
              ),
              (
                PendingTab.reading,
                loc.pendingTabReading(view.inTab(PendingTab.reading).length),
              ),
              (
                PendingTab.failed,
                loc.pendingTabFailed(view.inTab(PendingTab.failed).length),
              ),
            ],
            selected: tab,
            onChanged: (picked) => setState(() => _tab = picked),
          ),
        )
        ..add(const SizedBox(height: 12))
        ..add(cards(view.inTab(tab)));
    } else {
      for (final (title, group) in [
        (loc.pendingGroupReady(view.ready.length), view.ready),
        (loc.pendingGroupProcessing(view.processing.length), view.processing),
      ]) {
        if (group.isEmpty) continue;
        children
          ..add(_GroupTitle(title))
          ..add(cards(group));
      }
    }
    return ListView(padding: const EdgeInsets.all(_gutter), children: children);
  }

  Widget _bottomBar(PendingQueueView view) {
    final loc = context.loc;
    final colors = Theme.of(context).colorScheme;
    final count = _selecting ? _selected.length : view.quickSavable.length;
    final total = _selecting
        ? view.quickSavable
              .where((item) => _selected.contains(item.id))
              .fold<double>(0, (sum, item) => sum + (item.result?.amount ?? 0))
        : view.quickSavableTotal;
    final enabled = count > 0 && !_confirming;
    return FormSubmitBar(
      label: _selecting
          ? loc.pendingSaveSelected(count)
          : loc.pendingConfirmAllShort,
      busy: _confirming,
      onPressed: !enabled
          ? null
          : _selecting
          ? () => _save(Set.of(_selected))
          : () => _confirmAll(count),
      header: Row(
        children: [
          Expanded(
            child: Text(
              loc.pendingReadyFooter(count),
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: AppTextSize.secondary,
              ),
            ),
          ),
          Text(
            CurrencyHelper.formatVND(total, loc, showSign: false),
            style: TextStyle(
              color: colors.onSurface,
              fontSize: AppTextSize.title,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: AppTextSize.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// "Đang đọc hóa đơn 2/3" and a thin bar under the band while the queue reads.
class _ReadingStrip extends StatelessWidget {
  const _ReadingStrip({required this.progress});

  final ScanQueueProgress progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final current = min(progress.done + 1, progress.total);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sync_rounded, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.loc.scanQueueReading(current, progress.total),
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: AppTextSize.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.done / progress.total,
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}

/// What a swipe to the left uncovers: "Bỏ" on the expense colour.
class _DiscardBackground extends StatelessWidget {
  const _DiscardBackground();

  @override
  Widget build(BuildContext context) {
    final color = context.colors.expenseColor;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline_rounded, color: color),
          const SizedBox(width: 6),
          Text(
            context.loc.pendingDiscard,
            style: TextStyle(
              color: color,
              fontSize: AppTextSize.body,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BandPill extends StatelessWidget {
  const _BandPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BandColors.tint,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: const TextStyle(
              color: BandColors.primary,
              fontSize: AppTextSize.caption,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
