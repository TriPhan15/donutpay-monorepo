import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/models/receipt_scan_result.dart';
import 'package:finance_ai_app/core/constants/input_limits.dart';
import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/receipt_scanner/review_form_page.dart';
import 'package:finance_ai_app/screens/receipt_scanner/widgets/receipt_step_band.dart';
import 'package:finance_ai_app/screens/receipt_scanner/widgets/needs_check_field.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/screens/ledger/widgets/category_shortcut_grid.dart';
import 'package:finance_ai_app/models/review_exit.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/inputs/date_field.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_image_viewer.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';

/// A real file of the project, so that the scan and the upload can read it: it stands for the photo of the receipt.
const String _photo = 'assets/images/logo.png';
const String _scan = '/donut/scan';
const String _upload = '/api/upload';
const String _checkout = '/api/transactions/checkout';
const String _photoUrl = 'https://example.com/receipt.png';

/// "Lưu" is also the last step of the band, so the buttons are found by their type.
final Finder _save = find.widgetWithText(FilledButton, 'Lưu');
final Finder _saveAndScan = find.widgetWithText(
  OutlinedButton,
  'Lưu & quét tiếp',
);
const String _dateFallbackHint =
    'Chưa đọc được ngày, hãy chọn lại nếu không phải hôm nay.';
const String _dateDoubtHint = 'Chưa chắc ngày, hãy so với ảnh.';
const String _storeHint = 'Chưa chắc tên cửa hàng, hãy sửa nếu sai.';
const String _totalHint = 'Chưa chắc tổng tiền, hãy so với ảnh.';

const String _duplicateMessage = 'Hóa đơn này có vẻ đã được lưu trước đó';
const String _duplicateTitle = 'Hóa đơn này có vẻ đã lưu ngày 27/05/2026 10:30';
const String _viewSaved = 'Xem bản đã lưu';
const String _saveAnyway = 'Vẫn lưu';

/// What core-backend answers when the scanned receipt looks like transaction 123 of the user (T10-BE).
ResponseBody _duplicateAnswer() => jsonResponse(409, {
  'code': 409,
  'message': _duplicateMessage,
  'data': {
    'existingTransactionId': 123,
    'existingTransactionDate': '2026-05-27T10:30:00',
  },
});

const String _needsCheck = 'Cần kiểm tra';

final Finder _store = find.byKey(ReviewFormPage.storeFieldKey);
final Finder _total = find.byKey(ReviewFormPage.totalFieldKey);

/// Whether the field found by [field] is outlined in dashes (the AI doubts it).
bool _dashed(Finder field) => find
    .ancestor(
      of: field,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.foregroundPainter is DashedOutlinePainter,
      ),
    )
    .evaluate()
    .isNotEmpty;

/// What ai-service answers for a receipt of Highlands; [normalized] is the block of its Regex post-processing.
ResponseBody _scanned({
  Object total = 45000,
  String timestamp = '20/09/2026 08:30',
  String sellerName = 'Highlands',
  Map<String, dynamic>? normalized,
}) => jsonResponse(200, {
  'seller': {
    'seller_name': sellerName,
    'timestamp': timestamp,
    'total_cost_number': total,
  },
  'normalized': ?normalized,
});

/// The "normalized" block of ai-service/receipt_postprocess.py.
Map<String, dynamic> _normalized({
  String seller = 'Highlands',
  bool sellerValid = true,
  String? iso = '2026-09-20T08:30:00',
  bool timestampValid = true,
  int? total = 45000,
  bool totalValid = true,
}) => {
  'seller': {'raw': seller, 'value': seller, 'valid': sellerValid},
  'address': {'raw': '', 'value': '', 'valid': false},
  'timestamp': {'raw': '', 'value': '', 'iso': iso, 'valid': timestampValid},
  'total_cost': {'raw': '$total', 'value': total, 'valid': totalValid},
  'invalid_fields': <String>[],
};

void main() {
  final backend = FakeBackend();
  late FakeLocalStore store;

  setUpAll(() async {
    // The themes load Be Vietnam Pro through google_fonts once, and that fetch fails in a test (there is no network). Started
    // here, in a zone that ignores the failure, it cannot fail the first test that gives real time to I/O (runAsync).
    runZonedGuarded(() => [AppTheme.lightTheme, AppTheme.darkTheme], (_, _) {});
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    // SharedPreferences shares one Future that must be created inside the test body (see budget_display_test.dart).
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});
    TransactionCategories.expenseSelectable.clear();
    TransactionCategories.incomeSelectable.clear();
    store = FakeLocalStore();
    AppRepository.instance.localStore = store;

    backend.reset();
    backend.on('POST', _scan, (_) => _scanned());
    backend.on('POST', _upload, (_) => jsonResponse(200, {'url': _photoUrl}));
    backend.on(
      'POST',
      _checkout,
      (_) => okResponse({'transactionId': 5, 'finalAmount': 50000}),
    );
  });

  tearDown(() {
    // The language cubit of withAppSettings sets the default locale of intl.
    Intl.defaultLocale = null;
  });

  List<Map<String, dynamic>> sentBodies() => [
    for (final request in backend.requests)
      if (request.path == _checkout)
        Map<String, dynamic>.from(request.data as Map),
  ];

  int uploads() => backend.calls.where((c) => c == 'POST $_upload').length;

  /// Reading the photo is real file I/O, which the fake clock of the test does not run: it gets real time until
  /// [done] holds, and the pumps run the requests and the rebuilds.
  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 40 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  /// Opens the review form from a page of its own, like MainScaffold does; [result] gets what the form closes with.
  /// [onOpenTransaction] is what MainScaffold hands over to show a transaction in the Ledger; [initialScan] is a scan
  /// the scan queue already read.
  Future<List<ReviewExit?>> openForm(
    WidgetTester tester, {
    ValueChanged<int>? onOpenTransaction,
    ReceiptScanResult? initialScan,
  }) async {
    tester.view.physicalSize = const Size(600, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final result = <ReviewExit?>[];
    await tester.pumpWidget(
      withAppSettings(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result.add(
              await Navigator.push<ReviewExit>(
                context,
                MaterialPageRoute(
                  builder: (_) => ReviewFormPage(
                    imagePath: _photo,
                    onOpenTransaction: onOpenTransaction,
                    initialScan: initialScan,
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await settle(tester, () => _save.evaluate().isNotEmpty);
    expect(_save, findsOneWidget);
    return result;
  }

  Future<void> tapSave(WidgetTester tester, {Finder? button}) async {
    await tester.tap(button ?? _save);
    await tester.pump();
    await settle(tester, () => find.byType(Dialog).evaluate().isNotEmpty);
  }

  testWidgets(
    'the total from the AI can be corrected, and the photo is uploaded only when saving',
    (tester) async {
      final result = await openForm(tester);

      expect(
        find.descendant(of: _total, matching: find.text('45.000')),
        findsOneWidget,
      );
      expect(
        uploads(),
        0,
        reason: 'nothing is uploaded while the form is only open',
      );
      expect(find.text(_dateFallbackHint), findsNothing);

      await tester.enterText(_total, '50000');
      await tester.pump();
      expect(
        find.descendant(of: _total, matching: find.text('50.000')),
        findsOneWidget,
        reason: 'the amount is grouped while it is typed',
      );

      await tapSave(tester);
      expect(find.text('Thành công'), findsOneWidget);
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

      expect(uploads(), 1);
      final body = sentBodies().single;
      expect(body['amount'], 50000);
      expect(body['clientId'], isNotNull);
      expect(body['imageUrl'], _photoUrl);
      expect(
        body['transactionDate'],
        DateTime(2026, 9, 20, 8, 30).toIso8601String(),
      );
      expect(body['note'], 'Highlands');
      expect(
        jsonDecode(body['rawReceiptData'] as String)['seller']['seller_name'],
        'Highlands',
      );
      expect(store.rows.single.syncStatus, SyncStatus.synced);
      expect(result, [ReviewExit.saved]);
    },
  );

  testWidgets(
    'a total the AI could not read leaves the field empty, and both buttons stay faded',
    (tester) async {
      backend.on('POST', _scan, (_) => _scanned(total: 0));
      final result = await openForm(tester);

      final bar = tester.widget<Opacity>(
        find.ancestor(of: _save, matching: find.byType(Opacity)),
      );
      expect(bar.opacity, FormSubmitBar.disabledOpacity);
      await tester.tap(_save, warnIfMissed: false);
      await tester.tap(_saveAndScan, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(sentBodies(), isEmpty);
      expect(uploads(), 0);
      expect(
        result,
        isEmpty,
        reason: 'the form stays open to type the total in',
      );
    },
  );

  testWidgets(
    '"Lưu & quét tiếp" saves the same way and closes with savedScanNext',
    (tester) async {
      final result = await openForm(tester);

      await tapSave(tester, button: _saveAndScan);
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

      expect(sentBodies().single['amount'], 45000);
      expect(result, [ReviewExit.savedScanNext]);
    },
  );

  testWidgets('the totals card of the old form is gone', (tester) async {
    await openForm(tester);
    expect(find.text('Tạm tính'), findsNothing);
    expect(find.textContaining('VAT'), findsNothing);
  });

  group('category tiles', () {
    testWidgets(
      'a guess outside the fixed tiles takes the fourth one, selected',
      (tester) async {
        await openForm(
          tester,
          initialScan: ReceiptScanResult(
            storeName: 'Pharmacity',
            amount: 120000,
            date: DateTime(2026, 9, 20, 8, 30),
            category: TransactionCategories.health,
            raw: const {},
            invalidFields: const {},
          ),
        );

        final grid = find.byType(CategoryShortcutGrid);
        expect(
          find.descendant(of: grid, matching: find.text('Sức khỏe')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: grid, matching: find.text('Khác')),
          findsNothing,
        );
      },
    );

    testWidgets('a guess among them selects it and keeps "Khác"', (
      tester,
    ) async {
      await openForm(
        tester,
        initialScan: ReceiptScanResult(
          storeName: 'Co.opmart',
          amount: 386000,
          date: DateTime(2026, 9, 20, 8, 30),
          category: TransactionCategories.shopping,
          raw: const {},
          invalidFields: const {},
        ),
      );

      final grid = find.byType(CategoryShortcutGrid);
      expect(
        tester.widget<CategoryShortcutGrid>(grid).selected,
        TransactionCategories.shopping,
      );
      expect(
        find.descendant(of: grid, matching: find.text('Khác')),
        findsOneWidget,
      );
    });
  });

  testWidgets(
    'a receipt date that cannot be read falls back to now, with a warning under the field',
    (tester) async {
      backend.on('POST', _scan, (_) => _scanned(timestamp: 'ngày 20 tháng 9'));
      final before = DateTime.now().subtract(const Duration(minutes: 1));
      await openForm(tester);

      expect(find.text(_dateFallbackHint), findsOneWidget);

      await tapSave(tester);
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();
      final sent = DateTime.parse(
        sentBodies().single['transactionDate'] as String,
      );
      expect(sent.isAfter(before), isTrue);
    },
  );

  testWidgets(
    'the date is the shared date field, which opens the transaction date sheet',
    (tester) async {
      await openForm(tester);

      final date = find.byType(DateField);
      expect(date, findsOneWidget);
      expect(
        tester.widget<DateField>(date).value,
        DateTime(2026, 9, 20, 8, 30),
      );

      await tester.tap(find.byIcon(Icons.calendar_today_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Chọn ngày giao dịch'), findsOneWidget);
      expect(tester.widget<DateField>(date).forTransaction, isTrue);
    },
  );

  testWidgets(
    'a receipt of another month says it still counts in the current balance',
    (tester) async {
      await openForm(tester);
      expect(
        find.text('Giao dịch ngày 20/09 vẫn được tính vào số dư hiện tại'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a receipt of this month shows no such note', (tester) async {
    backend.on(
      'POST',
      _scan,
      (_) => _scanned(
        timestamp: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
      ),
    );
    await openForm(tester);
    expect(find.textContaining('vẫn được tính vào số dư'), findsNothing);
  });

  group('the photo', () {
    testWidgets('a tap on it opens it over the whole screen, zoomable', (
      tester,
    ) async {
      await openForm(tester);

      await tester.tap(find.bySemanticsLabel('Xem ảnh hóa đơn'));
      await tester.pumpAndSettle();

      expect(find.byType(ReceiptImageViewerPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ReceiptImageViewerPage),
          matching: find.byType(InteractiveViewer),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(ReceiptImageViewerPage), findsNothing);
      expect(_save, findsOneWidget);
    });

    testWidgets('a double tap zooms in, and a second one zooms back out', (
      tester,
    ) async {
      await openForm(tester);
      await tester.tap(find.bySemanticsLabel('Xem ảnh hóa đơn'));
      await tester.pumpAndSettle();

      double scale() => tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!
          .value
          .getMaxScaleOnAxis();
      final photo = find.byType(ZoomableReceiptImage);

      expect(scale(), 1);
      await tester.tap(photo);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(photo);
      await tester.pumpAndSettle();
      expect(scale(), ZoomableReceiptImage.doubleTapScale);

      await tester.tap(photo);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(photo);
      await tester.pumpAndSettle();
      expect(scale(), 1);
    });

    testWidgets(
      'compare mode: the photo on top, the fields under it, still marked and editable',
      (tester) async {
        backend.on(
          'POST',
          _scan,
          (_) => _scanned(normalized: _normalized(sellerValid: false)),
        );
        await openForm(tester);

        await tester.tap(find.byKey(ReceiptStepBand.compareKey));
        await tester.pumpAndSettle();

        final photo = find.byType(ZoomableReceiptImage);
        expect(photo, findsOneWidget);
        expect(_store, findsOneWidget);
        expect(
          tester.getTopLeft(photo).dy,
          lessThan(tester.getTopLeft(_store).dy),
        );
        expect(find.text(_needsCheck), findsOneWidget);

        await tester.enterText(_store, 'Highlands Coffee');
        await tester.pump();
        expect(find.text(_needsCheck), findsNothing);

        await tester.tap(find.byKey(ReceiptStepBand.compareKey));
        await tester.pumpAndSettle();
        expect(photo, findsNothing);
        expect(find.text('Highlands Coffee'), findsOneWidget);
      },
    );
  });

  testWidgets(
    'a failed upload asks first: "Để sau" sends nothing, "Lưu không kèm ảnh" saves without the photo',
    (tester) async {
      backend.on(
        'POST',
        _upload,
        (_) => jsonResponse(500, {'message': 'Cloudinary'}),
      );
      final result = await openForm(tester);

      await tapSave(tester);
      expect(find.text('Không tải được ảnh hóa đơn'), findsOneWidget);
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      expect(sentBodies(), isEmpty);
      expect(result, isEmpty);

      await tapSave(tester);
      expect(uploads(), 2, reason: 'the second save tries the upload again');
      await tester.tap(find.text('Lưu không kèm ảnh'));
      await tester.pump();
      await settle(tester, () => find.text('Thành công').evaluate().isNotEmpty);
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

      expect(sentBodies().single.containsKey('imageUrl'), isFalse);
      expect(result, [ReviewExit.saved]);
    },
  );

  testWidgets(
    'a failed upload says why in a toast, whatever the answer was; the dialog still asks what to do',
    (tester) async {
      final reasons = {
        413: 'Ảnh quá lớn hoặc không đúng định dạng.',
        400: 'Ảnh không hợp lệ',
        503: 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.',
      };
      var status = 413;
      backend.on(
        'POST',
        _upload,
        (_) => jsonResponse(
          status,
          status == 400 ? {'code': 400, 'message': 'Ảnh không hợp lệ'} : {},
        ),
      );
      await openForm(tester);

      for (final entry in reasons.entries) {
        status = entry.key;
        await tapSave(tester);
        expect(
          find.text('Không tải được ảnh: ${entry.value}'),
          findsOneWidget,
          reason: 'status ${entry.key}',
        );
        expect(find.text('Không tải được ảnh hóa đơn'), findsOneWidget);
        await tester.tap(find.text('Để sau'));
        await tester.pumpAndSettle();
      }
      expect(sentBodies(), isEmpty, reason: 'nothing is saved until asked');
    },
  );

  testWidgets(
    'a store name longer than core-backend takes is cut at 255 characters and saved so',
    (tester) async {
      await openForm(tester);

      await tester.enterText(_store, 'S' * 300);
      await tester.pump();
      expect(
        tester.widget<TextField>(_store).controller!.text,
        'S' * InputLimits.noteMaxLength,
      );

      await tapSave(tester);
      expect(
        (sentBodies().single['note'] as String).length,
        InputLimits.noteMaxLength,
      );
    },
  );

  testWidgets(
    'without network the transaction waits on the device with its receipt, instead of failing',
    (tester) async {
      backend.on(
        'POST',
        _checkout,
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'no network',
        ),
      );
      final result = await openForm(tester);

      await tapSave(tester);

      expect(find.text('Chưa gửi được lên máy chủ'), findsOneWidget);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      final waiting = store.rows.single;
      expect(waiting.syncStatus, SyncStatus.error);
      expect(waiting.imageUrl, _photoUrl);
      expect(waiting.rawReceiptData, isNotNull);
      expect(result, [ReviewExit.saved]);
    },
  );

  testWidgets(
    'a refusal of the server shows its reason and keeps the form open',
    (tester) async {
      backend.on(
        'POST',
        _checkout,
        (_) => jsonResponse(400, {
          'code': 400,
          'message': 'Danh mục không tồn tại',
        }),
      );
      final result = await openForm(tester);

      await tapSave(tester);

      expect(find.text('Lưu thất bại'), findsOneWidget);
      expect(find.text('Danh mục không tồn tại'), findsOneWidget);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      expect(store.rows, isEmpty);
      expect(result, isEmpty);
    },
  );
  group('a receipt the server takes for one already saved (409)', () {
    testWidgets(
      'nothing waits on the device, and "Xem bản đã lưu" opens the saved transaction',
      (tester) async {
        backend.on('POST', _checkout, (_) => _duplicateAnswer());
        final opened = <int>[];
        final result = await openForm(tester, onOpenTransaction: opened.add);

        await tapSave(tester);

        expect(find.text(_duplicateTitle), findsOneWidget);
        expect(find.text(_viewSaved), findsOneWidget);
        expect(find.text(_saveAnyway), findsOneWidget);
        expect(store.rows, isEmpty, reason: 'a 409 is never queued');
        expect(sentBodies().single.containsKey('allowDuplicate'), isFalse);

        await tester.tap(find.text(_viewSaved));
        await tester.pumpAndSettle();

        expect(opened, [123]);
        expect(result, [null]);
        expect(find.byType(ReviewFormPage), findsNothing);
        expect(sentBodies(), hasLength(1));
      },
    );

    testWidgets(
      '"Vẫn lưu" sends the same receipt again with allowDuplicate and saves it',
      (tester) async {
        var sends = 0;
        backend.on(
          'POST',
          _checkout,
          (_) => ++sends == 1
              ? _duplicateAnswer()
              : okResponse({'transactionId': 6, 'finalAmount': 45000}),
        );
        final result = await openForm(tester, onOpenTransaction: (_) {});

        await tapSave(tester);
        await tester.tap(find.text(_saveAnyway));
        await tester.pump();
        await settle(
          tester,
          () => find.text('Thành công').evaluate().isNotEmpty,
        );
        await tester.tap(find.text('Xong'));
        await tester.pumpAndSettle();

        final bodies = sentBodies();
        expect(bodies, hasLength(2));
        expect(bodies.first.containsKey('allowDuplicate'), isFalse);
        expect(bodies.last['allowDuplicate'], isTrue);
        expect(bodies.last['clientId'], bodies.first['clientId']);
        expect(uploads(), 1, reason: 'the photo is not uploaded again');
        expect(store.rows.single.syncStatus, SyncStatus.synced);
        expect(result, [ReviewExit.saved]);
      },
    );

    /// Back, or a tap on the barrier outside the dialog, answers neither "Vẫn lưu" nor "Xem bản đã lưu".
    final dismissals = <String, Future<void> Function(WidgetTester)>{
      'Back': (tester) async {
        await tester.binding.handlePopRoute();
      },
      'a tap outside the dialog': (tester) async {
        await tester.tapAt(const Offset(5, 5));
      },
    };
    for (final dismissal in dismissals.entries) {
      testWidgets(
        '${dismissal.key} only closes the question: the form stays and nothing is sent or opened',
        (tester) async {
          backend.on('POST', _checkout, (_) => _duplicateAnswer());
          final opened = <int>[];
          final result = await openForm(tester, onOpenTransaction: opened.add);

          await tapSave(tester);
          expect(find.text(_duplicateTitle), findsOneWidget);

          await dismissal.value(tester);
          await tester.pumpAndSettle();

          expect(find.text(_duplicateTitle), findsNothing);
          expect(find.byType(Dialog), findsNothing);
          expect(find.byType(ReviewFormPage), findsOneWidget);
          expect(_save, findsOneWidget);
          expect(opened, isEmpty, reason: 'not "Xem bản đã lưu"');
          expect(result, isEmpty, reason: 'the form did not close');
          expect(sentBodies(), hasLength(1), reason: 'not "Vẫn lưu"');
          expect(store.rows, isEmpty);
          expect(
            find.textContaining('Không mở được bản đã lưu từ đây'),
            findsNothing,
          );
        },
      );
    }

    testWidgets(
      'without a way to open the saved one, the form stays open and says where to find it',
      (tester) async {
        backend.on('POST', _checkout, (_) => _duplicateAnswer());
        final result = await openForm(tester);

        await tapSave(tester);
        await tester.tap(find.text(_viewSaved));
        await tester.pumpAndSettle();

        expect(find.byType(ReviewFormPage), findsOneWidget);
        expect(
          find.textContaining('Không mở được bản đã lưu từ đây'),
          findsOneWidget,
        );
        expect(result, isEmpty);
        expect(store.rows, isEmpty);
      },
    );

    testWidgets('a 409 without the id of a transaction is a plain refusal', (
      tester,
    ) async {
      backend.on(
        'POST',
        _checkout,
        (_) => jsonResponse(409, {'code': 409, 'message': 'Xung đột dữ liệu'}),
      );
      await openForm(tester);

      await tapSave(tester);

      expect(find.text('Lưu thất bại'), findsOneWidget);
      expect(find.text('Xung đột dữ liệu'), findsOneWidget);
      expect(find.text(_saveAnyway), findsNothing);
      expect(store.rows, isEmpty);
    });
  });

  testWidgets('the save button is disabled while the request is in flight', (
    tester,
  ) async {
    final answer = Completer<ResponseBody>();
    backend.on('POST', _checkout, (_) => answer.future);
    await openForm(tester);

    await tester.tap(_save);
    await tester.pump();
    for (var i = 0; i < 40 && sentBodies().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(sentBodies(), hasLength(1));
    final button = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(button, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(sentBodies(), hasLength(1));

    answer.complete(okResponse({'transactionId': 5, 'finalAmount': 45000}));
    await settle(tester, () => find.text('Thành công').evaluate().isNotEmpty);
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
  });

  group('fields the post-processing marked as not valid', () {
    testWidgets('an older ai-service without the block marks nothing', (
      tester,
    ) async {
      await openForm(tester);
      expect(find.text(_needsCheck), findsNothing);
    });

    testWidgets(
      'store and total are outlined in dashes with a hint until the user changes them',
      (tester) async {
        backend.on(
          'POST',
          _scan,
          (_) => _scanned(
            normalized: _normalized(sellerValid: false, totalValid: false),
          ),
        );
        await openForm(tester);

        expect(find.text(_needsCheck), findsNWidgets(2));
        expect(find.text(_storeHint), findsOneWidget);
        expect(find.text(_totalHint), findsOneWidget);
        expect(_dashed(_store), isTrue);
        expect(_dashed(_total), isTrue);
        expect(_dashed(find.byType(DateField)), isFalse);

        await tester.enterText(_store, 'Highlands Coffee');
        await tester.pump();
        expect(find.text(_needsCheck), findsOneWidget);
        expect(_dashed(_store), isFalse);

        await tester.enterText(_total, '46000');
        await tester.pump();
        expect(find.text(_needsCheck), findsNothing);
      },
    );

    testWidgets(
      'typing in a doubted field keeps that field (and its keyboard) instead of rebuilding it',
      (tester) async {
        backend.on(
          'POST',
          _scan,
          (_) => _scanned(normalized: _normalized(sellerValid: false)),
        );
        await openForm(tester);
        final editable = find.descendant(
          of: _store,
          matching: find.byType(EditableText),
        );
        await tester.tap(_store);
        await tester.pump();
        final before = tester.state<EditableTextState>(editable);
        expect(before.widget.focusNode.hasFocus, isTrue);

        await tester.enterText(_store, 'H');
        await tester.pump();

        expect(find.text(_needsCheck), findsNothing);
        expect(
          identical(tester.state<EditableTextState>(editable), before),
          isTrue,
        );
        expect(before.widget.focusNode.hasFocus, isTrue);
      },
    );

    testWidgets(
      'a readable date the scan doubts is marked instead of the fallback warning',
      (tester) async {
        backend.on(
          'POST',
          _scan,
          (_) => _scanned(normalized: _normalized(timestampValid: false)),
        );
        await openForm(tester);
        expect(find.text(_needsCheck), findsOneWidget);
        expect(find.text(_dateDoubtHint), findsOneWidget);
        expect(find.text(_dateFallbackHint), findsNothing);
      },
    );

    testWidgets('an unreadable date is marked with the fallback hint only', (
      tester,
    ) async {
      backend.on(
        'POST',
        _scan,
        (_) => _scanned(
          timestamp: '15:29:03',
          normalized: _normalized(iso: null, timestampValid: false),
        ),
      );
      await openForm(tester);
      expect(find.text(_dateFallbackHint), findsOneWidget);
      expect(find.text(_dateDoubtHint), findsNothing);
      expect(find.text(_needsCheck), findsOneWidget);
    });

    testWidgets(
      'the cleaned store name and the ISO date of the block fill the form',
      (tester) async {
        backend.on(
          'POST',
          _scan,
          (_) => _scanned(
            sellerName: '**Highlands**',
            timestamp: '20 / 09 / 2026 - 08 : 30',
            normalized: _normalized(),
          ),
        );
        await openForm(tester);
        expect(find.text('Highlands'), findsOneWidget);
        expect(find.text('20/09/2026'), findsOneWidget);
        expect(find.text(_dateFallbackHint), findsNothing);
        expect(find.text(_needsCheck), findsNothing);
      },
    );
  });

  group('a scan already read by the queue (initialScan)', () {
    int scans() => backend.calls.where((c) => c == 'POST $_scan').length;

    /// A scan of another receipt than the one the fake DONUT answers, so the form can only show it from [initialScan].
    ReceiptScanResult queued({
      String? iso = '2026-09-15T12:00:00',
    }) => ReceiptScanResult.fromResponse({
      'seller': {
        'seller_name': 'Phúc Long',
        'timestamp': '',
        'total_cost_number': 60000,
      },
      'normalized': {
        'seller': {'raw': 'Phúc Long', 'value': 'Phúc Long', 'valid': false},
        'timestamp': {'raw': '', 'value': '', 'iso': iso, 'valid': iso != null},
        'total_cost': {'raw': '60000', 'value': 60000, 'valid': true},
      },
    });

    testWidgets(
      'fills the form with it, marks its invalid fields, and sends nothing to DONUT',
      (tester) async {
        await openForm(tester, initialScan: queued());

        expect(scans(), 0);
        expect(
          find.descendant(of: _store, matching: find.text('Phúc Long')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: _total, matching: find.text('60.000')),
          findsOneWidget,
        );
        expect(find.text('15/09/2026'), findsOneWidget);
        expect(find.text(_needsCheck), findsOneWidget);
        expect(_dashed(_store), isTrue);
        expect(_dashed(_total), isFalse);
        expect(find.text(_dateFallbackHint), findsNothing);
      },
    );

    testWidgets('a scan without a date shows the fallback warning', (
      tester,
    ) async {
      await openForm(tester, initialScan: queued(iso: null));

      expect(scans(), 0);
      expect(find.text(_dateFallbackHint), findsOneWidget);
    });

    testWidgets('saving sends the scan as rawReceiptData', (tester) async {
      final scan = queued();
      await openForm(tester, initialScan: scan);

      await tapSave(tester);

      expect(scans(), 0);
      expect(sentBodies(), hasLength(1));
      expect(sentBodies().single['rawReceiptData'], jsonEncode(scan.raw));
    });
  });
}
