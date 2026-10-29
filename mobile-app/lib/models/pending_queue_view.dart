import 'package:finance_ai_app/models/scan_queue_item.dart';

/// The tabs of the pending receipts screen once it holds more than [PendingQueueView.tabsAbove] receipts.
enum PendingTab { ready, reading, failed }

/// How the pending receipts screen arranges the scan queue (T9 spec, 3.1 "Chờ xác nhận"): groups up to
/// [tabsAbove] receipts, tabs above that, and the receipts that can be saved without a review.
class PendingQueueView {
  /// Spec, 7: the list switches to tabs above this many receipts.
  static const int tabsAbove = 5;

  PendingQueueView._(this._all);

  /// Keeps the order of [items] inside every group.
  factory PendingQueueView.of(List<ScanQueueItem> items) =>
      PendingQueueView._(List.unmodifiable(items));

  final List<ScanQueueItem> _all;

  List<ScanQueueItem> _where(bool Function(ScanQueueStatus status) test) => [
    for (final item in _all)
      if (test(item.status)) item,
  ];

  List<ScanQueueItem> get ready => _where((s) => s == ScanQueueStatus.ready);

  /// Everything not ready yet: waiting, being read or failed (the second group of the short list).
  List<ScanQueueItem> get processing =>
      _where((s) => s != ScanQueueStatus.ready);

  /// Waiting to be read or being read (the "Đang đọc" tab).
  List<ScanQueueItem> get reading => _where(
    (s) => s == ScanQueueStatus.queued || s == ScanQueueStatus.reading,
  );

  List<ScanQueueItem> get failed => _where((s) => s == ScanQueueStatus.failed);

  bool get useTabs => _all.length > tabsAbove;

  /// Ready receipts the AI read in full: saved by the quick button, "Xác nhận tất cả" and the selection mode.
  List<ScanQueueItem> get quickSavable => [
    for (final item in ready)
      if (item.result?.allValid ?? false) item,
  ];

  double get quickSavableTotal =>
      quickSavable.fold(0, (sum, item) => sum + (item.result?.amount ?? 0));

  /// Ready when there is any, otherwise the first tab with receipts.
  PendingTab get defaultTab {
    for (final tab in PendingTab.values) {
      if (inTab(tab).isNotEmpty) return tab;
    }
    return PendingTab.ready;
  }

  List<ScanQueueItem> inTab(PendingTab tab) => switch (tab) {
    PendingTab.ready => ready,
    PendingTab.reading => reading,
    PendingTab.failed => failed,
  };

  /// The ready receipt after [currentId] in list order, wrapping around; from the first one when [currentId] is gone.
  /// Null when no other receipt is ready.
  ScanQueueItem? nextReady(int currentId) {
    final candidates = ready;
    final index = candidates.indexWhere((item) => item.id == currentId);
    for (var step = 1; step <= candidates.length; step++) {
      final next = candidates[(index + step) % candidates.length];
      if (next.id != currentId) return next;
    }
    return null;
  }
}
