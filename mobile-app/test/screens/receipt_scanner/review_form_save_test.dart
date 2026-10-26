import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/receipt_scanner/review_form_page.dart';
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
const String _save = 'Xác nhận và lưu';
const String _dateFallbackHint =
    'Không đọc được ngày trên hóa đơn, đang dùng thời điểm hiện tại. Chạm để chọn lại.';

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

const String _needsCheck =
    'AI chưa chắc chắn ở trường này, vui lòng kiểm tra lại.';

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
    // The themes load Poppins through google_fonts once, and that fetch fails in a test (there is no network). Started
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
  /// [onOpenTransaction] is what MainScaffold hands over to show a transaction in the Ledger.
  Future<List<bool?>> openForm(
    WidgetTester tester, {
    ValueChanged<int>? onOpenTransaction,
  }) async {
    tester.view.physicalSize = const Size(600, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final result = <bool?>[];
    await tester.pumpWidget(
      withAppSettings(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result.add(
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => ReviewFormPage(
                    imagePath: _photo,
                    onOpenTransaction: onOpenTransaction,
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
    await settle(tester, () => find.text(_save).evaluate().isNotEmpty);
    expect(find.text(_save), findsOneWidget);
    return result;
  }

  Finder field(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text(_save));
    await tester.pump();
    await settle(tester, () => find.byType(Dialog).evaluate().isNotEmpty);
  }

  testWidgets(
    'the total from the AI can be corrected, and the photo is uploaded only when saving',
    (tester) async {
      final result = await openForm(tester);

      expect(
        find.descendant(
          of: field('Tổng tiền (đ)'),
          matching: find.text('45.000'),
        ),
        findsOneWidget,
      );
      expect(
        uploads(),
        0,
        reason: 'nothing is uploaded while the form is only open',
      );
      expect(find.text(_dateFallbackHint), findsNothing);

      await tester.enterText(field('Tổng tiền (đ)'), '50000');
      await tester.pump();
      expect(
        find.descendant(
          of: field('Tổng tiền (đ)'),
          matching: find.text('50.000'),
        ),
        findsOneWidget,
        reason: 'the amount is grouped while it is typed',
      );
      expect(
        find.text(
          CurrencyHelper.formatVND(
            50000,
            AppLanguage.vietnamese.localizations,
            showSign: false,
          ),
        ),
        findsNWidgets(2),
        reason: 'the totals card follows the amount field',
      );

      await tapSave(tester);
      expect(find.text('Thành công'), findsOneWidget);
      await tester.tap(find.text('OK'));
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
      expect(result, [true]);
    },
  );

  testWidgets(
    'a total the AI could not read leaves the field empty, and saving without one is refused',
    (tester) async {
      backend.on('POST', _scan, (_) => _scanned(total: 0));
      final result = await openForm(tester);

      await tapSave(tester);

      expect(find.text('Số tiền không hợp lệ'), findsOneWidget);
      await tester.tap(find.text('Đã hiểu'));
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
    'a receipt date that cannot be read falls back to now, with a warning under the field',
    (tester) async {
      backend.on('POST', _scan, (_) => _scanned(timestamp: 'ngày 20 tháng 9'));
      final before = DateTime.now().subtract(const Duration(minutes: 1));
      await openForm(tester);

      expect(find.text(_dateFallbackHint), findsOneWidget);

      await tapSave(tester);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final sent = DateTime.parse(
        sentBodies().single['transactionDate'] as String,
      );
      expect(sent.isAfter(before), isTrue);
    },
  );

  testWidgets('the date is the shared date field, which opens a date picker', (
    tester,
  ) async {
    await openForm(tester);

    final date = find.byType(DateField);
    expect(date, findsOneWidget);
    expect(tester.widget<DateField>(date).value, DateTime(2026, 9, 20, 8, 30));

    await tester.tap(find.byIcon(Icons.calendar_today_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

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
      expect(find.text(_save), findsOneWidget);
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

        await tester.tap(find.byTooltip('Đối chiếu với ảnh'));
        await tester.pumpAndSettle();

        final photo = find.byType(ZoomableReceiptImage);
        expect(photo, findsOneWidget);
        expect(field('Tên cửa hàng'), findsOneWidget);
        expect(
          tester.getTopLeft(photo).dy,
          lessThan(tester.getTopLeft(field('Tên cửa hàng')).dy),
        );
        expect(find.text(_needsCheck), findsOneWidget);

        await tester.enterText(field('Tên cửa hàng'), 'Highlands Coffee');
        await tester.pump();
        expect(find.text(_needsCheck), findsNothing);

        await tester.tap(find.byTooltip('Thoát chế độ đối chiếu'));
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
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(sentBodies().single.containsKey('imageUrl'), isFalse);
      expect(result, [true]);
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
      expect(result, [true]);
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
        expect(result, [false]);
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
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        final bodies = sentBodies();
        expect(bodies, hasLength(2));
        expect(bodies.first.containsKey('allowDuplicate'), isFalse);
        expect(bodies.last['allowDuplicate'], isTrue);
        expect(bodies.last['clientId'], bodies.first['clientId']);
        expect(uploads(), 1, reason: 'the photo is not uploaded again');
        expect(store.rows.single.syncStatus, SyncStatus.synced);
        expect(result, [true]);
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
          expect(find.text(_save), findsOneWidget);
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

    await tester.tap(find.text(_save));
    await tester.pump();
    for (var i = 0; i < 40 && sentBodies().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(sentBodies(), hasLength(1));
    final button = find.byType(ElevatedButton);
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    await tester.tap(button, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(sentBodies(), hasLength(1));

    answer.complete(okResponse({'transactionId': 5, 'finalAmount': 45000}));
    await settle(tester, () => find.text('Thành công').evaluate().isNotEmpty);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  });

  group('fields the post-processing marked as not valid', () {
    Color? outline(WidgetTester tester, String label) {
      final decorator = tester.widget<InputDecorator>(
        find.descendant(
          of: field(label),
          matching: find.byType(InputDecorator),
        ),
      );
      final border = decorator.decoration.errorText == null
          ? decorator.decoration.enabledBorder
          : decorator.decoration.errorBorder;
      return border?.borderSide.color;
    }

    testWidgets('an older ai-service without the block marks nothing', (
      tester,
    ) async {
      await openForm(tester);
      expect(find.text(_needsCheck), findsNothing);
    });

    testWidgets(
      'store and total are marked in the error colour until the user changes them',
      (tester) async {
        backend.on(
          'POST',
          _scan,
          (_) => _scanned(
            normalized: _normalized(sellerValid: false, totalValid: false),
          ),
        );
        await openForm(tester);
        final error = Theme.of(
          tester.element(field('Tên cửa hàng')),
        ).colorScheme.error;

        expect(find.text(_needsCheck), findsNWidgets(2));
        expect(outline(tester, 'Tên cửa hàng'), error);
        expect(outline(tester, 'Tổng tiền (đ)'), error);
        expect(
          tester.widget<DateField>(find.byType(DateField)).errorText,
          isNull,
        );

        await tester.enterText(field('Tên cửa hàng'), 'Highlands Coffee');
        await tester.pump();
        expect(find.text(_needsCheck), findsOneWidget);
        expect(outline(tester, 'Tên cửa hàng'), isNot(error));

        await tester.enterText(field('Tổng tiền (đ)'), '46000');
        await tester.pump();
        expect(find.text(_needsCheck), findsNothing);
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
        expect(find.text(_dateFallbackHint), findsNothing);
      },
    );

    testWidgets('an unreadable date shows only the fallback warning', (
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
      expect(find.text(_needsCheck), findsNothing);
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
}
