import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show DatabaseException;

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/widgets/common/pill_segmented.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/models/pending_queue_view.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/receipt_scan_result.dart';
import 'package:finance_ai_app/models/scan_queue_item.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/receipt_scanner/pending_receipts_screen.dart';
import 'package:finance_ai_app/screens/receipt_scanner/review_form_page.dart';
import 'package:finance_ai_app/services/receipt_scan_queue.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';
import '../../helpers/fake_scan_queue.dart';
import '../../helpers/fake_settings_repository.dart';

/// A real file of the project, so the review form can upload it: it stands for the copy of a queued receipt.
const String _photo = 'assets/images/logo.png';
const String _scan = '/donut/scan';
const String _upload = '/api/upload';
const String _checkout = '/api/transactions/checkout';

/// The main button of the review form ("Lưu" is also a step of its band).
final Finder _save = find.widgetWithText(FilledButton, 'Lưu');
final Finder _saveAndScan = find.widgetWithText(
  OutlinedButton,
  'Lưu & quét tiếp',
);

String _money(double amount) => CurrencyHelper.formatVND(
  amount,
  AppLanguage.vietnamese.localizations,
  showSign: false,
);

ReceiptScanResult _result({
  String storeName = 'Highlands',
  Set<String> invalidFields = const {},
}) => ReceiptScanResult(
  storeName: storeName,
  amount: 45000,
  date: DateTime(2026, 9, 20, 8, 30),
  category: TransactionCategories.food,
  raw: {
    'seller': {
      'seller_name': storeName,
      'timestamp': '20/09/2026 08:30',
      'total_cost_number': 45000,
    },
  },
  invalidFields: invalidFields,
);

ScanQueueItem _item(
  int id,
  ScanQueueStatus status, {
  ReceiptScanResult? result,
  String? error,
}) => ScanQueueItem(
  id: id,
  userId: 1,
  imagePath: _photo,
  status: status,
  result: result,
  error: error,
  createdAt: DateTime(2026, 9, 20, 9),
);

/// One item of every status: queued, reading, ready (Highlands), failed (no network).
List<ScanQueueItem> _everyStatus({String storeName = 'Highlands'}) => [
  _item(1, ScanQueueStatus.queued),
  _item(2, ScanQueueStatus.reading),
  _item(3, ScanQueueStatus.ready, result: _result(storeName: storeName)),
  _item(4, ScanQueueStatus.failed, error: ScanQueueError.network),
];

void main() {
  final backend = FakeBackend();
  final queue = FakeScanQueue();

  setUpAll(() async {
    // See review_form_save_test.dart: the font fetch of the themes must not fail the first test that uses runAsync.
    runZonedGuarded(() => [AppTheme.lightTheme, AppTheme.darkTheme], (_, _) {});
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    ReceiptScanQueue.instanceForTesting = queue;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    // SharedPreferences shares one Future that must be created inside the test body.
    SharedPreferences.setMockInitialValues({});
    TransactionCategories.expenseSelectable.clear();
    TransactionCategories.incomeSelectable.clear();
    AppRepository.instance.localStore = FakeLocalStore();
    queue.reset();
    backend.reset();
    backend.on(
      'POST',
      _upload,
      (_) => jsonResponse(200, {'url': 'https://example.com/r.png'}),
    );
    backend.on(
      'POST',
      _checkout,
      (_) => okResponse({'transactionId': 5, 'finalAmount': 45000}),
    );
  });

  tearDown(() {
    // The language cubit of withAppSettings sets the default locale of intl.
    Intl.defaultLocale = null;
  });

  Future<void> openScreen(
    WidgetTester tester, {
    Size size = const Size(600, 2200),
    AppLanguage language = AppLanguage.vietnamese,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        const PendingReceiptsScreen(),
        settings: FakeSettingsRepository(language: language),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The review form uploads the real photo, file I/O that the fake clock does not run: real time until [done] holds.
  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 40 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(Dialog), matching: find.text(text));

  double bottomOpacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.ancestor(
          of: find.widgetWithText(FilledButton, 'Xác nhận tất cả'),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;

  Future<void> swipeAway(WidgetTester tester, String title) async {
    await tester.drag(find.text(title), const Offset(-500, 0));
    await tester.pumpAndSettle();
  }

  /// Opens the review form of a card and waits until it shows its buttons.
  Future<void> openReview(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pump();
    await settle(tester, () => _save.evaluate().isNotEmpty);
  }

  /// Taps a button of the review form and closes the success dialog.
  Future<void> saveReview(WidgetTester tester, Finder button) async {
    await tester.tap(button);
    await tester.pump();
    await settle(tester, () => find.byType(Dialog).evaluate().isNotEmpty);
    await tester.tap(find.text('Xong'));
    await tester.pump();
    await settle(tester, () => true);
  }

  testWidgets(
    'up to five receipts are grouped, each status labelled and a failure gives its reason',
    (tester) async {
      queue.queueItems.addAll(_everyStatus());
      await openScreen(tester);

      expect(find.text('Sẵn sàng 1'), findsOneWidget);
      expect(find.text('Đang xử lý 3'), findsOneWidget);
      expect(find.byType(PillSegmented<PendingTab>), findsNothing);
      for (final label in ['Đang chờ', 'Đang đọc', 'Lỗi']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Highlands'), findsOneWidget);
      expect(find.text('Không kết nối được dịch vụ AI.'), findsOneWidget);
      expect(find.text('Đọc lại'), findsOneWidget, reason: 'the failed one');
      expect(find.text('Lưu'), findsOneWidget, reason: 'the ready one');
    },
  );

  testWidgets('the reason of each failure code comes from the texts', (
    tester,
  ) async {
    queue.queueItems.addAll([
      _item(1, ScanQueueStatus.failed, error: ScanQueueError.server),
      _item(2, ScanQueueStatus.failed, error: ScanQueueError.missingImage),
    ]);
    await openScreen(tester);

    expect(find.text('Dịch vụ AI không đọc được hóa đơn này.'), findsOneWidget);
    expect(find.text('Ảnh không còn trên máy.'), findsOneWidget);
    expect(find.text('Ảnh 1'), findsOneWidget);
    expect(find.text('Ảnh 2'), findsOneWidget);
  });

  testWidgets('an empty queue says so, without the bottom button', (
    tester,
  ) async {
    await openScreen(tester);

    expect(find.text('Không có hóa đơn nào đang chờ.'), findsOneWidget);
    expect(find.text('Xác nhận tất cả'), findsNothing);
  });

  testWidgets('"Đọc lại" queues the failed receipt again', (tester) async {
    queue.queueItems.addAll(_everyStatus());
    await openScreen(tester);

    await tester.tap(find.text('Đọc lại'));
    await tester.pumpAndSettle();

    expect(queue.retried, [4]);
  });

  testWidgets(
    'a swipe to the left asks first, and removes the receipt only once confirmed',
    (tester) async {
      queue.queueItems.addAll([
        _item(3, ScanQueueStatus.ready, result: _result()),
      ]);
      await openScreen(tester);

      await swipeAway(tester, 'Highlands');
      expect(find.text('Bỏ hóa đơn này khỏi danh sách?'), findsOneWidget);
      expect(queue.removed, isEmpty, reason: 'nothing goes before the answer');

      await tester.tap(inDialog('Hủy'));
      await tester.pumpAndSettle();
      expect(queue.removed, isEmpty);
      expect(find.text('Highlands'), findsOneWidget);

      await swipeAway(tester, 'Highlands');
      await tester.tap(inDialog('Bỏ'));
      await tester.pumpAndSettle();

      expect(queue.removed, [3]);
      expect(find.text('Highlands'), findsNothing);
      expect(find.text('Không có hóa đơn nào đang chờ.'), findsOneWidget);
    },
  );

  testWidgets('a receipt being read cannot be swiped away', (tester) async {
    queue.queueItems.add(_item(2, ScanQueueStatus.reading));
    await openScreen(tester);

    await swipeAway(tester, 'Đang đọc…');

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Đang đọc…'), findsOneWidget);
  });

  testWidgets(
    'a ready receipt opens the review form with its scan, without a new /donut/scan, and leaves the list once saved',
    (tester) async {
      queue.queueItems.addAll([
        _item(3, ScanQueueStatus.ready, result: _result()),
      ]);
      await openScreen(tester);

      await openReview(tester, 'Highlands');

      expect(find.byType(ReviewFormPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ReviewFormPage),
          matching: find.text('45.000'),
        ),
        findsOneWidget,
        reason: 'the form starts with what the queue read',
      );
      expect(backend.calls, isNot(contains('POST $_scan')));

      await saveReview(tester, _save);

      expect(find.byType(ReviewFormPage), findsNothing);
      expect(queue.confirmed, [3]);
      expect(find.text('Highlands'), findsNothing);
      expect(find.text('Không có hóa đơn nào đang chờ.'), findsOneWidget);
      expect(backend.calls, isNot(contains('POST $_scan')));
    },
  );

  testWidgets(
    '"Lưu & quét tiếp" opens the next ready receipt, and the last one goes back to the list',
    (tester) async {
      queue.queueItems.addAll([
        _item(3, ScanQueueStatus.ready, result: _result()),
        _item(4, ScanQueueStatus.ready, result: _result(storeName: 'Circle K')),
      ]);
      await openScreen(tester);

      await openReview(tester, 'Highlands');
      await saveReview(tester, _saveAndScan);

      expect(queue.confirmed, [3]);
      expect(find.byType(ReviewFormPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ReviewFormPage),
          matching: find.text('Circle K'),
        ),
        findsOneWidget,
      );

      await saveReview(tester, _saveAndScan);

      expect(queue.confirmed, [3, 4]);
      expect(find.byType(ReviewFormPage), findsNothing);
      expect(find.text('Không có hóa đơn nào đang chờ.'), findsOneWidget);
    },
  );

  testWidgets(
    '"Lưu & quét tiếp" goes to the receipt after the saved one, not back to the first',
    (tester) async {
      queue.queueItems.addAll([
        _item(3, ScanQueueStatus.ready, result: _result(storeName: 'A')),
        _item(4, ScanQueueStatus.ready, result: _result(storeName: 'B')),
        _item(5, ScanQueueStatus.ready, result: _result(storeName: 'C')),
      ]);
      await openScreen(tester);

      await openReview(tester, 'B');
      await saveReview(tester, _saveAndScan);

      expect(queue.confirmed, [4]);
      expect(
        find.descendant(
          of: find.byType(ReviewFormPage),
          matching: find.text('C'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('while "Xác nhận tất cả" runs, a card does not open the form', (
    tester,
  ) async {
    queue.queueItems.addAll([
      _item(3, ScanQueueStatus.ready, result: _result()),
    ]);
    queue.confirmGate = Completer<void>();
    await openScreen(tester);

    await tester.tap(find.text('Xác nhận tất cả'));
    await tester.pumpAndSettle();
    await tester.tap(inDialog('Đồng ý'));
    // Past the closing animation of the question, so the tap reaches the card.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.text('Highlands'));
    // The busy spinner never settles: give the tap time to push a page, if it did.
    await tester.pump(const Duration(milliseconds: 500));

    // Counted also while a pushed page would still be sliding in.
    expect(find.byType(ReviewFormPage, skipOffstage: false), findsNothing);
    queue.confirmGate!.complete();
    await tester.pump();
    await tester.pump(
      AppToast.displayDuration + AppToast.transitionDuration * 2,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('the list loads again when the progress of the queue changes', (
    tester,
  ) async {
    await openScreen(tester);
    expect(find.text('Highlands'), findsNothing);

    queue.queueItems.add(_item(3, ScanQueueStatus.ready, result: _result()));
    queue.progressNotifier.value = const ScanQueueProgress(ready: 1);
    await tester.pumpAndSettle();

    expect(find.text('Highlands'), findsOneWidget);
  });

  testWidgets('while the queue reads, a strip shows how far it is', (
    tester,
  ) async {
    queue.queueItems.addAll(_everyStatus());
    queue.progressNotifier.value = const ScanQueueProgress(done: 1, total: 3);
    await openScreen(tester);

    expect(find.text('Đang đọc hóa đơn 2/3'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets(
    'a ready receipt with a doubted field offers "Kiểm tra", which opens the form',
    (tester) async {
      queue.queueItems.add(
        _item(
          3,
          ScanQueueStatus.ready,
          result: _result(invalidFields: {ReceiptScanResult.totalCostField}),
        ),
      );
      await openScreen(tester);

      expect(find.text('Lưu'), findsNothing);
      await tester.tap(find.text('Kiểm tra'));
      await tester.pump();
      await settle(tester, () => _save.evaluate().isNotEmpty);

      expect(find.byType(ReviewFormPage), findsOneWidget);
      expect(queue.confirmedItems, isEmpty);
    },
  );

  testWidgets('the quick "Lưu" saves that receipt alone', (tester) async {
    queue.queueItems.addAll([
      _item(3, ScanQueueStatus.ready, result: _result()),
      _item(5, ScanQueueStatus.queued),
    ]);
    queue.bulkResult = const BulkConfirmResult(
      saved: 1,
      duplicates: 0,
      notSaved: 0,
    );
    await openScreen(tester);

    await tester.tap(find.text('Lưu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(queue.confirmedItems, [
      {3},
    ]);
    expect(find.text('Highlands'), findsNothing);
    await tester.pump(
      AppToast.displayDuration + AppToast.transitionDuration * 2,
    );
    await tester.pumpAndSettle();
  });

  testWidgets(
    '"Xác nhận tất cả" is faded while no receipt can be saved at once',
    (tester) async {
      queue.queueItems.addAll([
        _item(
          3,
          ScanQueueStatus.ready,
          result: _result(invalidFields: {ReceiptScanResult.totalCostField}),
        ),
        _item(4, ScanQueueStatus.failed, error: ScanQueueError.server),
        _item(5, ScanQueueStatus.queued),
      ]);
      await openScreen(tester);

      expect(find.text('0 hóa đơn sẵn sàng'), findsOneWidget);
      expect(bottomOpacity(tester), FormSubmitBar.disabledOpacity);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Xác nhận tất cả'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(queue.confirmAllCalls, 0);
    },
  );

  testWidgets(
    '"Xác nhận tất cả" shows count and total, asks, saves and sums up the outcome',
    (tester) async {
      queue.queueItems.addAll([
        _item(3, ScanQueueStatus.ready, result: _result()),
        _item(4, ScanQueueStatus.ready, result: _result(storeName: 'Circle K')),
        _item(
          5,
          ScanQueueStatus.ready,
          result: _result(invalidFields: {ReceiptScanResult.sellerField}),
        ),
      ]);
      queue.bulkResult = const BulkConfirmResult(
        saved: 1,
        duplicates: 1,
        notSaved: 0,
      );
      await openScreen(tester);

      expect(find.text('2 hóa đơn sẵn sàng'), findsOneWidget);
      expect(find.text(_money(90000)), findsOneWidget);
      expect(bottomOpacity(tester), 1);

      await tester.tap(find.text('Xác nhận tất cả'));
      await tester.pumpAndSettle();
      expect(
        find.text('Lưu 2 hóa đơn hợp lệ thành giao dịch?'),
        findsOneWidget,
      );
      expect(queue.confirmAllCalls, 0, reason: 'nothing is saved before');

      await tester.tap(inDialog('Đồng ý'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(queue.confirmAllCalls, 1);
      expect(find.text('Đã lưu 1, trùng 1, chưa lưu 0'), findsOneWidget);

      // The toast goes away by itself.
      await tester.pump(
        AppToast.displayDuration + AppToast.transitionDuration * 2,
      );
      await tester.pumpAndSettle();
    },
  );

  group('more than five receipts', () {
    List<ScanQueueItem> six() => [
      _item(1, ScanQueueStatus.ready, result: _result(storeName: 'A')),
      _item(2, ScanQueueStatus.ready, result: _result(storeName: 'B')),
      _item(3, ScanQueueStatus.ready, result: _result(storeName: 'C')),
      _item(4, ScanQueueStatus.queued),
      _item(5, ScanQueueStatus.reading),
      _item(6, ScanQueueStatus.failed, error: ScanQueueError.server),
    ];

    testWidgets('tabs, ready first; another tab shows only its receipts', (
      tester,
    ) async {
      queue.queueItems.addAll(six());
      await openScreen(tester);

      expect(find.byType(PillSegmented<PendingTab>), findsOneWidget);
      expect(find.text('Sẵn sàng 3'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('Ảnh 6'), findsNothing);

      await tester.tap(find.text('Lỗi 1'));
      await tester.pumpAndSettle();

      expect(find.text('A'), findsNothing);
      expect(find.text('Ảnh 6'), findsOneWidget);
    });
  });

  group('selection mode', () {
    List<ScanQueueItem> twoReady() => [
      _item(3, ScanQueueStatus.ready, result: _result()),
      _item(4, ScanQueueStatus.ready, result: _result(storeName: 'Circle K')),
      _item(5, ScanQueueStatus.queued),
    ];

    testWidgets(
      'a long press selects, "Chọn tất cả" takes every savable one, and the bottom saves them',
      (tester) async {
        queue.queueItems.addAll(twoReady());
        queue.bulkResult = const BulkConfirmResult(
          saved: 2,
          duplicates: 0,
          notSaved: 0,
        );
        await openScreen(tester);

        await tester.longPress(find.text('Highlands'));
        await tester.pumpAndSettle();
        expect(find.text('Đã chọn 1'), findsOneWidget);
        expect(find.text('Lưu 1 hóa đơn đã chọn'), findsOneWidget);
        expect(find.byType(Checkbox), findsNWidgets(2));

        await tester.tap(find.text('Chọn tất cả'));
        await tester.pumpAndSettle();
        expect(find.text('Đã chọn 2'), findsOneWidget);

        await tester.tap(find.text('Lưu 2 hóa đơn đã chọn'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(queue.confirmedItems, [
          {3, 4},
        ]);
        expect(find.text('Đã chọn 2'), findsNothing);
        await tester.pump(
          AppToast.displayDuration + AppToast.transitionDuration * 2,
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets('the Back key leaves the selection, not the screen', (
      tester,
    ) async {
      queue.queueItems.addAll(twoReady());
      await openScreen(tester);

      await tester.longPress(find.text('Highlands'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Đã chọn 1'), findsNothing);
      expect(find.text('Chờ xác nhận'), findsOneWidget);
      expect(find.byType(PendingReceiptsScreen), findsOneWidget);
    });

    testWidgets('a tap in the selection ticks instead of opening the form', (
      tester,
    ) async {
      queue.queueItems.addAll(twoReady());
      await openScreen(tester);

      await tester.longPress(find.text('Highlands'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Circle K'));
      await tester.pumpAndSettle();

      expect(find.byType(ReviewFormPage), findsNothing);
      expect(find.text('Đã chọn 2'), findsOneWidget);
    });
  });

  for (final language in AppLanguage.values) {
    testWidgets('nothing overflows at 320 dp in ${language.name}', (
      tester,
    ) async {
      queue.queueItems.addAll(
        _everyStatus(storeName: 'Siêu thị Co.opmart Nguyễn Đình Chiểu Quận 3'),
      );
      await openScreen(tester, size: const Size(320, 640), language: language);

      expect(tester.takeException(), isNull);
      expect(find.byType(PendingReceiptsScreen), findsOneWidget);
    });
  }

  testWidgets(
    'after "Xác nhận tất cả" empties the picked tab, the screen moves to a tab that has receipts',
    (tester) async {
      queue.queueItems.addAll([
        _item(1, ScanQueueStatus.ready, result: _result(storeName: 'A')),
        _item(2, ScanQueueStatus.ready, result: _result(storeName: 'B')),
        _item(3, ScanQueueStatus.ready, result: _result(storeName: 'C')),
        _item(4, ScanQueueStatus.queued),
        _item(5, ScanQueueStatus.reading),
        _item(6, ScanQueueStatus.queued),
        _item(7, ScanQueueStatus.failed, error: ScanQueueError.server),
        _item(8, ScanQueueStatus.failed, error: ScanQueueError.server),
        _item(9, ScanQueueStatus.failed, error: ScanQueueError.server),
      ]);
      queue.bulkResult = const BulkConfirmResult(
        saved: 3,
        duplicates: 0,
        notSaved: 0,
      );
      await openScreen(tester);
      await tester.tap(find.text('Lỗi 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sẵn sàng 3'));
      await tester.pumpAndSettle();

      // The real queue drops what it saved.
      queue.queueItems.removeWhere((item) => item.id <= 3);
      await tester.tap(find.text('Xác nhận tất cả'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Đồng ý'));
      await tester.pumpAndSettle();

      expect(find.text('Đang đọc…'), findsWidgets);
      await tester.pump(
        AppToast.displayDuration + AppToast.transitionDuration * 2,
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a swiped card does not come back from a reload that started before it was dropped',
    (tester) async {
      queue.queueItems.add(_item(3, ScanQueueStatus.ready, result: _result()));
      await openScreen(tester);

      // A reload reads the queue while the card is still in it, and answers late.
      queue.itemsGate = Completer<void>();
      queue.progressNotifier.value = const ScanQueueProgress(ready: 1);
      await tester.pump();
      queue.removeGate = Completer<void>();

      await swipeAway(tester, 'Highlands');
      await tester.tap(inDialog('Bỏ'));
      await tester.pumpAndSettle();
      expect(find.text('Highlands'), findsNothing);

      queue.itemsGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Highlands'), findsNothing);

      queue.removeGate!.complete();
      await tester.pumpAndSettle();
      expect(queue.removed, [3]);
      expect(find.text('Highlands'), findsNothing);
    },
  );

  testWidgets('a card whose removal failed comes back with the error toast', (
    tester,
  ) async {
    queue.queueItems.add(_item(3, ScanQueueStatus.ready, result: _result()));
    queue.removeError = _DiskFull();
    await openScreen(tester);

    await swipeAway(tester, 'Highlands');
    await tester.tap(inDialog('Bỏ'));
    await tester.pumpAndSettle();

    expect(find.text('Highlands'), findsOneWidget);
    await tester.pump(
      AppToast.displayDuration + AppToast.transitionDuration * 2,
    );
    await tester.pumpAndSettle();
  });
}

/// A storage failure of the queue.
class _DiskFull implements DatabaseException {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
