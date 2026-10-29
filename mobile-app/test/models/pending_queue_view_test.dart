import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/models/pending_queue_view.dart';
import 'package:finance_ai_app/models/receipt_scan_result.dart';
import 'package:finance_ai_app/models/scan_queue_item.dart';

ReceiptScanResult _result(
  double amount, {
  Set<String> invalidFields = const {},
}) => ReceiptScanResult(
  storeName: 'Co.opmart',
  amount: amount,
  date: DateTime(2026, 10, 20, 19, 20),
  category: TransactionCategories.shopping,
  raw: const {},
  invalidFields: invalidFields,
);

ScanQueueItem _item(
  int id,
  ScanQueueStatus status, {
  ReceiptScanResult? result,
}) => ScanQueueItem(
  id: id,
  userId: 1,
  imagePath: 'a.jpg',
  status: status,
  result: result,
  error: status == ScanQueueStatus.failed ? ScanQueueError.network : null,
  createdAt: DateTime(2026, 10, 20, 9),
);

ScanQueueItem _ready(int id, [double amount = 10000]) =>
    _item(id, ScanQueueStatus.ready, result: _result(amount));

void main() {
  test('up to five receipts are grouped into ready and processing', () {
    final view = PendingQueueView.of([
      _ready(1),
      _item(2, ScanQueueStatus.reading),
      _ready(3),
      _item(4, ScanQueueStatus.failed),
      _ready(5),
    ]);

    expect(view.useTabs, isFalse);
    expect([for (final item in view.ready) item.id], [1, 3, 5]);
    expect([for (final item in view.processing) item.id], [2, 4]);
  });

  test('more than five receipts use tabs, reading includes the queued', () {
    final view = PendingQueueView.of([
      _ready(1),
      _ready(2),
      _item(3, ScanQueueStatus.queued),
      _item(4, ScanQueueStatus.reading),
      _item(5, ScanQueueStatus.failed),
      _ready(6),
    ]);

    expect(view.useTabs, isTrue);
    expect(
      [for (final item in view.inTab(PendingTab.ready)) item.id],
      [1, 2, 6],
    );
    expect(
      [for (final item in view.inTab(PendingTab.reading)) item.id],
      [3, 4],
    );
    expect([for (final item in view.inTab(PendingTab.failed)) item.id], [5]);
  });

  test('only receipts the AI read in full can be saved at once', () {
    final view = PendingQueueView.of([
      _ready(1, 386000),
      _item(
        2,
        ScanQueueStatus.ready,
        result: _result(
          99000,
          invalidFields: {ReceiptScanResult.totalCostField},
        ),
      ),
      _ready(3, 55000),
    ]);

    expect([for (final item in view.quickSavable) item.id], [1, 3]);
    expect(view.quickSavableTotal, 441000);
  });

  test('the default tab is the first one with receipts', () {
    expect(PendingQueueView.of([_ready(1)]).defaultTab, PendingTab.ready);
    expect(
      PendingQueueView.of([_item(1, ScanQueueStatus.failed)]).defaultTab,
      PendingTab.failed,
    );
    expect(
      PendingQueueView.of([
        _item(1, ScanQueueStatus.failed),
        _item(2, ScanQueueStatus.queued),
      ]).defaultTab,
      PendingTab.reading,
    );
  });

  group('nextReady', () {
    final view = PendingQueueView.of([
      _ready(1),
      _item(2, ScanQueueStatus.reading),
      _ready(3),
      _ready(5),
    ]);

    test('goes to the following ready receipt', () {
      expect(view.nextReady(1)?.id, 3);
      expect(view.nextReady(3)?.id, 5);
    });

    test('wraps around to the first one', () {
      expect(view.nextReady(5)?.id, 1);
    });

    test('a receipt already gone continues from the start', () {
      expect(view.nextReady(4)?.id, 1);
    });

    test('is null when no other receipt is ready', () {
      expect(PendingQueueView.of([_ready(1)]).nextReady(1), isNull);
      expect(
        PendingQueueView.of([_item(2, ScanQueueStatus.reading)]).nextReady(1),
        isNull,
      );
    });
  });
}
