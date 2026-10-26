import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show DatabaseException;
import 'package:uuid/uuid.dart';

import 'package:finance_ai_app/models/receipt_scan_result.dart';
import 'package:finance_ai_app/models/scan_queue_item.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/services/sqflite_helper.dart';

/// How far the reading of the queue has come, for the banner of the app.
@immutable
class ScanQueueProgress {
  /// Items of the current run that are read (ready or failed).
  final int done;

  /// Items of the current run: the read ones plus the ones still queued or reading. 0 when nothing is being read.
  final int total;

  /// Items of the user that wait for a confirmation.
  final int ready;

  /// Items of the user whose reading failed.
  final int failed;

  const ScanQueueProgress({
    this.done = 0,
    this.total = 0,
    this.ready = 0,
    this.failed = 0,
  });

  static const ScanQueueProgress idle = ScanQueueProgress();

  bool get isReading => total > 0;

  @override
  bool operator ==(Object other) =>
      other is ScanQueueProgress &&
      other.done == done &&
      other.total == total &&
      other.ready == ready &&
      other.failed == failed;

  @override
  int get hashCode => Object.hash(done, total, ready, failed);

  @override
  String toString() =>
      'ScanQueueProgress($done/$total, ready $ready, failed $failed)';
}

/// What one "confirm every valid receipt" did.
@immutable
class BulkConfirmResult {
  /// Saved on the server, or waiting in the outbox of this device; gone from the queue.
  final int saved;

  /// Taken by the server for receipts already saved (409); kept in the queue for a review.
  final int duplicates;

  /// Not saved for another reason (the image could not be uploaded, a refusal ...); kept in the queue.
  final int notSaved;

  const BulkConfirmResult({
    required this.saved,
    required this.duplicates,
    required this.notSaved,
  });

  static const BulkConfirmResult none = BulkConfirmResult(
    saved: 0,
    duplicates: 0,
    notSaved: 0,
  );
}

/// The receipts that the user photographed or picked to be read by DONUT on this device, one after the other, while the
/// app is open. The queue lives in SQLite, so closing the app keeps it and the next start reads on (see [resume]).
/// Every user sees and reads only their own items.
class ReceiptScanQueue {
  /// The most images queued or being read at a time.
  static const int maxBatch = 20;

  /// The folder, in the documents of the app, that keeps the copies of the queued images.
  static const String _folderName = 'receipt_queue';

  static const Uuid _uuid = Uuid();

  static final ReceiptScanQueue instance = ReceiptScanQueue._(
    SqfliteHelper.instance,
    getApplicationDocumentsDirectory,
  );

  ReceiptScanQueue._(this._store, this._baseDirectory);

  /// A queue on a database of the test and with the copies of the images under [baseDirectory].
  @visibleForTesting
  ReceiptScanQueue.forTesting({
    required SqfliteHelper store,
    required Directory baseDirectory,
  }) : this._(store, () async => baseDirectory);

  final SqfliteHelper _store;
  final Future<Directory> Function() _baseDirectory;

  final ValueNotifier<ScanQueueProgress> _progress = ValueNotifier(
    ScanQueueProgress.idle,
  );

  /// The one reading loop in flight, null when nothing is read.
  Future<void>? _reading;

  /// Set when new work arrives while the loop runs, so the loop looks once more before it ends.
  bool _wake = false;

  /// The user the current run reads for, and how many of their items it has read.
  int? _runUserId;
  int _runDone = 0;

  bool _confirming = false;

  ValueListenable<ScanQueueProgress> get progress => _progress;

  /// Queues [imagePaths], in this order, for the signed-in user and starts reading them. Each image is copied into the
  /// folder of the app first, since the scanner and the picker leave theirs in a cache the system may clear. Only as
  /// many are taken as fit under [maxBatch] queued or reading items; returns how many were taken.
  Future<int> enqueue(List<String> imagePaths) async {
    final userId = SessionService.currentUserId;
    if (userId == null || imagePaths.isEmpty) return 0;

    final room =
        maxBatch - _active(await _store.countScanQueueByStatus(userId));
    final accepted = imagePaths.take(max(0, room)).toList();
    if (accepted.isEmpty) {
      debugPrint('Hàng đợi quét đã đủ $maxBatch hóa đơn, không nhận thêm.');
      return 0;
    }

    final folder = await _queueFolder();
    for (final source in accepted) {
      await _store.insertScanQueueItem(
        userId: userId,
        imagePath: await _copyIntoQueue(source, folder),
        createdAt: DateTime.now(),
      );
    }
    debugPrint(
      'Đã thêm ${accepted.length}/${imagePaths.length} hóa đơn vào hàng đợi quét.',
    );
    _startReading();
    return accepted.length;
  }

  /// Reads on what the signed-in user left in the queue: an item left reading (the app was killed meanwhile) is read
  /// again. Completes when the loop ends; the app does not wait for it.
  Future<void> resume() {
    if (SessionService.currentUserId == null) return Future.value();
    _startReading();
    return _reading ?? Future.value();
  }

  /// The queue of the signed-in user, oldest first.
  Future<List<ScanQueueItem>> items() async {
    final userId = SessionService.currentUserId;
    if (userId == null) return const [];
    return _store.getScanQueueItems(userId);
  }

  /// Queues a failed item again and starts reading it.
  Future<void> retry(int id) async {
    final userId = SessionService.currentUserId;
    if (userId == null) return;
    final changed = await _store.requeueScanQueueItems(
      userId,
      ScanQueueStatus.failed,
      id: id,
    );
    if (changed == 0) return;
    _startReading();
  }

  /// Takes an item out of the queue, together with the copy of its image.
  Future<void> remove(int id) async {
    final userId = SessionService.currentUserId;
    if (userId == null) return;
    final item = await _store.getScanQueueItem(userId, id);
    if (item == null) return;
    await _store.deleteScanQueueItem(userId, id);
    await _deleteCopy(item.imagePath);
    await _publish(userId);
  }

  /// Takes out an item that the review form has just saved.
  Future<void> markConfirmed(int id) => remove(id);

  /// Saves, one after the other, every ready item whose scan needs no review ([ReceiptScanResult.allValid]): the image is
  /// uploaded first, then the transaction goes through [AppRepository.createTransaction]. A saved item (also one that
  /// waits in the outbox) leaves the queue; a duplicate or a failure keeps it. A call while one runs does nothing.
  Future<BulkConfirmResult> confirmAllValid() async {
    final userId = SessionService.currentUserId;
    if (userId == null || _confirming) return BulkConfirmResult.none;
    _confirming = true;
    var saved = 0;
    var duplicates = 0;
    var notSaved = 0;
    try {
      final valid = [
        for (final item in await _store.getScanQueueItems(userId))
          if (item.status == ScanQueueStatus.ready &&
              (item.result?.allValid ?? false))
            item,
      ];
      for (final item in valid) {
        switch (await _confirmOne(userId, item)) {
          case _ConfirmOutcome.saved:
            saved++;
          case _ConfirmOutcome.duplicate:
            duplicates++;
          case _ConfirmOutcome.notSaved:
            notSaved++;
        }
      }
    } finally {
      _confirming = false;
    }
    debugPrint(
      'Xác nhận hàng loạt: lưu $saved, trùng $duplicates, chưa lưu $notSaved.',
    );
    RemoteApiHelper.instance.dataChangedNotifier.value++;
    await _publish(userId);
    return BulkConfirmResult(
      saved: saved,
      duplicates: duplicates,
      notSaved: notSaved,
    );
  }

  Future<_ConfirmOutcome> _confirmOne(int userId, ScanQueueItem item) async {
    final imageUrl = await RemoteApiHelper.instance.uploadImage(item.imagePath);
    if (imageUrl == null) {
      debugPrint('Không tải được ảnh của hóa đơn ${item.id}, giữ lại.');
      return _ConfirmOutcome.notSaved;
    }
    try {
      await AppRepository.instance.createTransaction(
        userId,
        item.result!.toDraft(imageUrl: imageUrl),
        allowDuplicate: false,
      );
    } on DuplicateReceiptException catch (e) {
      debugPrint(
        'Hóa đơn ${item.id} trùng giao dịch ${e.existingTransactionId}.',
      );
      return _ConfirmOutcome.duplicate;
    } on TransactionRefusedException catch (e) {
      debugPrint('Máy chủ từ chối hóa đơn ${item.id}: ${e.message}');
      return _ConfirmOutcome.notSaved;
    } on DatabaseException catch (e) {
      debugPrint('Lỗi lưu hóa đơn ${item.id} trên máy: $e');
      return _ConfirmOutcome.notSaved;
    }
    await remove(item.id);
    return _ConfirmOutcome.saved;
  }

  /// Starts the reading loop, or tells the running one to look again: there is never a second loop.
  void _startReading() {
    if (_reading != null) {
      _wake = true;
      return;
    }
    _reading = _readAll();
  }

  Future<void> _readAll() async {
    do {
      _wake = false;
      await _readWhileQueued();
      await _publishIdle();
    } while (_wake && SessionService.currentUserId != null);
    // Nothing is awaited between the last look at _wake and here, so no new work can slip in unseen.
    _reading = null;
  }

  /// Reads the queued items of the signed-in user, oldest first, until none is left or the session ends.
  Future<void> _readWhileQueued() async {
    try {
      while (true) {
        final userId = SessionService.currentUserId;
        if (userId == null) return;
        if (userId != _runUserId) await _startRun(userId);
        final next = await _store.nextQueuedScan(userId);
        if (next == null) return;
        await _publish(userId);
        if (!await _readOne(next)) return;
        _runDone++;
        await _publish(userId);
      }
    } on DatabaseException catch (e) {
      debugPrint('Lỗi cơ sở dữ liệu của hàng đợi quét: $e');
    }
  }

  /// A run for [userId] begins: nothing of theirs is being read now, so an item still marked reading was left by a
  /// killed app and is read again.
  Future<void> _startRun(int userId) async {
    _runUserId = userId;
    _runDone = 0;
    final requeued = await _store.requeueScanQueueItems(
      userId,
      ScanQueueStatus.reading,
    );
    if (requeued > 0) {
      debugPrint('Đọc lại $requeued hóa đơn bị dừng giữa chừng.');
    }
  }

  /// Reads one item and stores the outcome. False when the session ended: the item is queued again and the loop stops.
  Future<bool> _readOne(ScanQueueItem item) async {
    await _store.updateScanQueueItem(item.id, ScanQueueStatus.reading);
    if (!await File(item.imagePath).exists()) {
      await _fail(item, ScanQueueError.missingImage);
      return true;
    }
    final ReceiptScanResult result;
    try {
      result = ReceiptScanResult.fromResponse(
        await RemoteApiHelper.instance.scanReceipt(item.imagePath),
      );
    } on DioException catch (e) {
      if (_endsSession(e) || SessionService.currentUserId != item.userId) {
        debugPrint('Phiên đăng nhập kết thúc, dừng đọc hóa đơn ${item.id}.');
        await _store.updateScanQueueItem(item.id, ScanQueueStatus.queued);
        return false;
      }
      await _fail(
        item,
        e.response == null ? ScanQueueError.network : ScanQueueError.server,
      );
      return true;
    } on FileSystemException {
      await _fail(item, ScanQueueError.missingImage);
      return true;
    } on TypeError {
      // The answer is not a JSON object, so it is no scan.
      await _fail(item, ScanQueueError.server);
      return true;
    }
    await _store.updateScanQueueItem(
      item.id,
      ScanQueueStatus.ready,
      resultJson: jsonEncode(result.toJson()),
    );
    return true;
  }

  Future<void> _fail(ScanQueueItem item, String error) async {
    debugPrint('Đọc hóa đơn ${item.id} thất bại: $error');
    await _store.updateScanQueueItem(
      item.id,
      ScanQueueStatus.failed,
      error: error,
    );
  }

  /// 401 (the session could not be renewed) or 403: no reading can succeed until the user signs in again.
  static bool _endsSession(DioException e) {
    final status = e.response?.statusCode;
    return status == HttpStatus.unauthorized || status == HttpStatus.forbidden;
  }

  static int _active(Map<ScanQueueStatus, int> counts) =>
      (counts[ScanQueueStatus.queued] ?? 0) +
      (counts[ScanQueueStatus.reading] ?? 0);

  /// The progress of the running loop, or the idle one when no loop runs.
  Future<void> _publish(int userId) async {
    final counts = await _store.countScanQueueByStatus(userId);
    final running = _reading != null && _runUserId == userId;
    final done = running ? _runDone : 0;
    _progress.value = ScanQueueProgress(
      done: done,
      total: running ? done + _active(counts) : 0,
      ready: counts[ScanQueueStatus.ready] ?? 0,
      failed: counts[ScanQueueStatus.failed] ?? 0,
    );
  }

  /// The run is over: total back to 0, and what is left ready or failed for the signed-in user.
  Future<void> _publishIdle() async {
    _runUserId = null;
    _runDone = 0;
    final userId = SessionService.currentUserId;
    if (userId == null) {
      _progress.value = ScanQueueProgress.idle;
      return;
    }
    try {
      final counts = await _store.countScanQueueByStatus(userId);
      _progress.value = ScanQueueProgress(
        ready: counts[ScanQueueStatus.ready] ?? 0,
        failed: counts[ScanQueueStatus.failed] ?? 0,
      );
    } on DatabaseException catch (e) {
      debugPrint('Lỗi cơ sở dữ liệu của hàng đợi quét: $e');
      _progress.value = ScanQueueProgress.idle;
    }
  }

  Future<Directory> _queueFolder() async {
    final folder = Directory(
      p.join((await _baseDirectory()).path, _folderName),
    );
    return folder.create(recursive: true);
  }

  /// Copies [source] into [folder] under a new name and returns the path of the copy. When the source is already gone
  /// the path is returned all the same: the item then fails with [ScanQueueError.missingImage].
  Future<String> _copyIntoQueue(String source, Directory folder) async {
    final target = p.join(folder.path, '${_uuid.v4()}${p.extension(source)}');
    try {
      await File(source).copy(target);
    } on FileSystemException catch (e) {
      debugPrint('Không chép được ảnh hóa đơn $source: $e');
    }
    return target;
  }

  Future<void> _deleteCopy(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (e) {
      debugPrint('Không xóa được ảnh hóa đơn $path: $e');
    }
  }
}

enum _ConfirmOutcome { saved, duplicate, notSaved }
