import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:finance_ai_app/models/scan_queue_item.dart';
import 'package:finance_ai_app/services/receipt_scan_queue.dart';

/// Stands in for the scan queue of the app, so a widget test never opens a database. Install it with
/// `ReceiptScanQueue.instanceForTesting = ...`. It keeps [queueItems] in memory, records every call and lets the test
/// set the [progress] the banner and the pending list hear.
class FakeScanQueue implements ReceiptScanQueue {
  final ValueNotifier<ScanQueueProgress> progressNotifier = ValueNotifier(
    ScanQueueProgress.idle,
  );

  final List<ScanQueueItem> queueItems = [];

  final List<List<String>> enqueued = [];
  final List<int> retried = [];
  final List<int> removed = [];
  final List<int> confirmed = [];
  int confirmAllCalls = 0;

  /// The id sets given to [confirmItems], in call order.
  final List<Set<int>> confirmedItems = [];
  int resumeCalls = 0;

  /// How many images [enqueue] takes, out of those it is given.
  int Function(List<String> imagePaths) acceptedOf = _all;

  /// When set, [confirmAllValid] waits for it: a test can act while a bulk save runs.
  Completer<void>? confirmGate;

  /// When set, [items] takes its copy of the queue at once and answers only once this completes: a slow read.
  Completer<void>? itemsGate;

  /// When set, [remove] waits for it before it drops the item.
  Completer<void>? removeGate;

  /// When set, [remove] throws it instead of dropping the item.
  Object? removeError;

  /// When set, [enqueue] throws it instead of taking the images.
  Object? enqueueError;

  /// What [confirmAllValid] and [confirmItems] answer.
  BulkConfirmResult bulkResult = BulkConfirmResult.none;

  static int _all(List<String> imagePaths) => imagePaths.length;

  void reset() {
    progressNotifier.value = ScanQueueProgress.idle;
    queueItems.clear();
    enqueued.clear();
    retried.clear();
    removed.clear();
    confirmed.clear();
    confirmAllCalls = 0;
    confirmedItems.clear();
    confirmGate = null;
    itemsGate = null;
    removeGate = null;
    removeError = null;
    enqueueError = null;
    resumeCalls = 0;
    acceptedOf = _all;
    bulkResult = BulkConfirmResult.none;
  }

  @override
  ValueListenable<ScanQueueProgress> get progress => progressNotifier;

  @override
  Future<int> enqueue(List<String> imagePaths) async {
    enqueued.add(imagePaths);
    if (enqueueError case final Object error) throw error;
    return acceptedOf(imagePaths);
  }

  @override
  Future<void> resume() async => resumeCalls++;

  @override
  Future<List<ScanQueueItem>> items() async {
    final copy = List.of(queueItems);
    await itemsGate?.future;
    return copy;
  }

  @override
  Future<void> retry(int id) async => retried.add(id);

  @override
  Future<void> remove(int id) async {
    await removeGate?.future;
    if (removeError case final Object error) throw error;
    removed.add(id);
    queueItems.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> markConfirmed(int id) async {
    confirmed.add(id);
    queueItems.removeWhere((item) => item.id == id);
  }

  @override
  Future<BulkConfirmResult> confirmAllValid() async {
    confirmAllCalls++;
    await confirmGate?.future;
    return bulkResult;
  }

  /// Records [ids] and, like the real queue, drops them from [queueItems] when [bulkResult] says they were saved.
  @override
  Future<BulkConfirmResult> confirmItems(Set<int> ids) async {
    confirmedItems.add(Set.of(ids));
    if (bulkResult.saved > 0) {
      queueItems.removeWhere((item) => ids.contains(item.id));
    }
    return bulkResult;
  }
}
