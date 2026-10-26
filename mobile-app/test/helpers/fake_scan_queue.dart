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
  int resumeCalls = 0;

  /// How many images [enqueue] takes, out of those it is given.
  int Function(List<String> imagePaths) acceptedOf = _all;

  /// What [confirmAllValid] answers.
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
    resumeCalls = 0;
    acceptedOf = _all;
    bulkResult = BulkConfirmResult.none;
  }

  @override
  ValueListenable<ScanQueueProgress> get progress => progressNotifier;

  @override
  Future<int> enqueue(List<String> imagePaths) async {
    enqueued.add(imagePaths);
    return acceptedOf(imagePaths);
  }

  @override
  Future<void> resume() async => resumeCalls++;

  @override
  Future<List<ScanQueueItem>> items() async => List.of(queueItems);

  @override
  Future<void> retry(int id) async => retried.add(id);

  @override
  Future<void> remove(int id) async {
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
    return bulkResult;
  }
}
