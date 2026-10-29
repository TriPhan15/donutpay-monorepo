import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/models/app_language.dart';
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
const String _save = 'Xác nhận và lưu';

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

  ElevatedButton confirmAllButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  testWidgets('every status shows its chip, and a failure its reason', (
    tester,
  ) async {
    queue.queueItems.addAll(_everyStatus());
    await openScreen(tester);

    for (final chip in ['Đang chờ', 'Đang đọc', 'Sẵn sàng', 'Lỗi']) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
    expect(find.text('Highlands'), findsOneWidget);
    expect(find.text('Không kết nối được dịch vụ AI.'), findsOneWidget);
    expect(find.text('Đọc lại'), findsOneWidget, reason: 'only the failed one');
    expect(
      find.text('Bỏ'),
      findsNWidgets(2),
      reason: 'the ready and the failed one',
    );
  });

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
  });

  testWidgets('an empty queue says so', (tester) async {
    await openScreen(tester);

    expect(find.text('Không có hóa đơn nào đang chờ.'), findsOneWidget);
    expect(find.text('Xác nhận tất cả hợp lệ (0)'), findsOneWidget);
  });

  testWidgets('"Đọc lại" queues the failed receipt again', (tester) async {
    queue.queueItems.addAll(_everyStatus());
    await openScreen(tester);

    await tester.tap(find.text('Đọc lại'));
    await tester.pumpAndSettle();

    expect(queue.retried, [4]);
  });

  testWidgets('"Bỏ" asks first, and removes the receipt only once confirmed', (
    tester,
  ) async {
    queue.queueItems.addAll([
      _item(3, ScanQueueStatus.ready, result: _result()),
    ]);
    await openScreen(tester);

    await tester.tap(find.text('Bỏ'));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ hóa đơn này khỏi danh sách?'), findsOneWidget);
    expect(queue.removed, isEmpty, reason: 'nothing goes before the answer');

    await tester.tap(inDialog('Hủy'));
    await tester.pumpAndSettle();
    expect(queue.removed, isEmpty);
    expect(find.text('Highlands'), findsOneWidget);

    await tester.tap(find.text('Bỏ'));
    await tester.pumpAndSettle();
    await tester.tap(inDialog('Bỏ'));
    await tester.pumpAndSettle();

    expect(queue.removed, [3]);
    expect(find.text('Highlands'), findsNothing);
    expect(find.text('Không có hóa đơn nào đang chờ.'), findsOneWidget);
  });

  testWidgets(
    'a ready receipt opens the review form with its scan, without a new /donut/scan, and leaves the list once saved',
    (tester) async {
      queue.queueItems.addAll([
        _item(3, ScanQueueStatus.ready, result: _result()),
      ]);
      await openScreen(tester);

      await tester.tap(find.text('Highlands'));
      await tester.pump();
      await settle(tester, () => find.text(_save).evaluate().isNotEmpty);

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

      await tester.tap(find.text(_save));
      await tester.pump();
      await settle(tester, () => find.byType(Dialog).evaluate().isNotEmpty);
      expect(find.text('Thành công'), findsOneWidget);
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

      expect(find.byType(ReviewFormPage), findsNothing);
      expect(queue.confirmed, [3]);
      expect(find.text('Highlands'), findsNothing);
      expect(find.text('Không có hóa đơn nào đang chờ.'), findsOneWidget);
      expect(backend.calls, isNot(contains('POST $_scan')));
    },
  );

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

  testWidgets(
    '"Xác nhận tất cả hợp lệ" is disabled while no receipt is valid',
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

      expect(find.text('Xác nhận tất cả hợp lệ (0)'), findsOneWidget);
      expect(confirmAllButton(tester).onPressed, isNull);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(queue.confirmAllCalls, 0);
    },
  );

  testWidgets(
    '"Xác nhận tất cả hợp lệ" asks, saves the valid receipts and sums up the outcome',
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

      expect(find.text('Xác nhận tất cả hợp lệ (2)'), findsOneWidget);
      expect(confirmAllButton(tester).onPressed, isNotNull);

      await tester.tap(find.text('Xác nhận tất cả hợp lệ (2)'));
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
}
