import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/models/receipt_detail.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/common/custom_text_field.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_detail_sheet.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_settings_repository.dart';
import '../../helpers/theme_colors.dart';
import '../../helpers/vnd.dart';

const String _byTransaction = '/api/receipts/transaction/42';
const String _receiptPath = '/api/receipts/7';
const String _retryPath = '/api/receipts/7/retry';
const String _feedbackPath = '/api/receipts/feedback/7';
const String _scanPath = '/donut/scan';
const String _photoUrl = 'https://res.cloudinary.com/demo/image/upload/r7.jpg';
const String _conflict = 'Hóa đơn đã được thay đổi, hãy tải lại rồi thử lại';
const String _offline =
    'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.';
const String _failedReason = 'AI không đọc được tổng tiền trên hóa đơn này';

Map<String, dynamic> _receipt({
  String status = 'COMPLETED_RAW',
  int version = 3,
  Object? total = 45000,
  String? imageUrl = _photoUrl,
  String? errorCode,
  String? errorMessage,
}) => {
  'id': 7,
  'transactionId': 42,
  'status': status,
  'version': version,
  'vendorName': 'Highlands',
  'extractedTotal': total,
  'extractedDate': '2026-09-20',
  'imageUrl': imageUrl,
  'errorCode': errorCode,
  'errorMessage': errorMessage,
};

Map<String, dynamic> _failed({String? imageUrl = _photoUrl}) => _receipt(
  status: 'FAILED',
  total: null,
  imageUrl: imageUrl,
  errorCode: 'AI_NO_TOTAL',
  errorMessage: _failedReason,
);

void main() {
  final backend = FakeBackend();

  setUpAll(() async {
    // The themes load Be Vietnam Pro through google_fonts once, and that fetch fails in a test (there is no network). Started
    // here, in a zone that ignores the failure, it cannot fail the first test that gives real time to I/O (runAsync).
    runZonedGuarded(() => [AppTheme.lightTheme, AppTheme.darkTheme], (_, _) {});
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});
    backend.reset();
  });

  tearDown(() {
    // The language cubit of withAppSettings sets the default locale of intl.
    Intl.defaultLocale = null;
  });

  void serve(Map<String, dynamic> receipt) =>
      backend.on('GET', _byTransaction, (_) => okResponse(receipt));

  int loads() => backend.calls.where((c) => c == 'GET $_byTransaction').length;

  List<RequestOptions> sent(String method, String path) => [
    for (final request in backend.requests)
      if (request.method == method && request.path == path) request,
  ];

  /// Opens the sheet from a page of its own, like the transaction detail does; [result] gets what it closes with and
  /// [seen] every receipt it reports.
  Future<({List<bool> result, List<ReceiptDetail> seen})> open(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
    Size size = const Size(600, 1800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final result = <bool>[];
    final seen = <ReceiptDetail>[];
    await tester.pumpWidget(
      withAppSettings(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result.add(
                await showReceiptDetailSheet(
                  context,
                  transactionId: '42',
                  onReceipt: seen.add,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        settings: FakeSettingsRepository(themeMode: mode),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (result: result, seen: seen);
  }

  /// Runs the requests that are in flight, with real time, until [done] holds, without waiting for the spinner of a
  /// busy sheet to stop (it never does while a request is held).
  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() done, {
    int tries = 40,
  }) async {
    for (var i = 0; i < tries && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Reading the photo is real file I/O, which the fake clock of the test does not run: it gets real time until
  /// [done] holds and the sheet is no longer busy (its progress bar is gone).
  Future<void> settle(WidgetTester tester, bool Function() done) async {
    await pumpUntil(tester, done);
    await pumpUntil(
      tester,
      () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
    );
    await tester.pumpAndSettle();
  }

  Finder button(String label) => find.ancestor(
    of: find.text(label),
    matching: find.bySubtype<ButtonStyleButton>(),
  );

  /// The buttons of the actions and forms, not the round close button of the sheet.
  final actionButtons = find.byWidgetPredicate(
    (widget) => widget is FilledButton || widget is OutlinedButton,
  );

  bool enabled(WidgetTester tester, String label) =>
      tester.widget<ButtonStyleButton>(button(label)).onPressed != null;

  testWidgets(
    'a read receipt shows its fields and offers only "Sửa thông tin"',
    (tester) async {
      serve(_receipt());

      await open(tester);

      expect(find.text('Hóa đơn'), findsOneWidget);
      expect(find.text('AI đã đọc'), findsOneWidget);
      expect(find.text('Highlands'), findsOneWidget);
      expect(find.text(vnd(45000)), findsOneWidget);
      expect(find.text('20/09/2026'), findsOneWidget);
      expect(button('Sửa thông tin'), findsOneWidget);
      expect(button('Đọc lại'), findsNothing);
      expect(button('Gửi số tiền đúng'), findsNothing);
      expect(find.text(_failedReason), findsNothing);
    },
  );

  testWidgets('an edited receipt can be edited again', (tester) async {
    serve(_receipt(status: 'EDITED'));

    await open(tester);

    expect(find.text('Bạn đã sửa'), findsOneWidget);
    expect(button('Sửa thông tin'), findsOneWidget);
  });

  testWidgets(
    'a FAILED receipt shows why, and offers "Đọc lại" and "Gửi số tiền đúng"',
    (tester) async {
      serve(_failed());

      await open(tester);

      expect(find.text('Chưa đọc được hóa đơn này'), findsOneWidget);
      expect(find.text(_failedReason), findsOneWidget);
      expect(button('Đọc lại'), findsOneWidget);
      expect(button('Gửi số tiền đúng'), findsOneWidget);
      expect(button('Sửa thông tin'), findsNothing);
    },
  );

  testWidgets('a FAILED receipt without a photo cannot be read again', (
    tester,
  ) async {
    serve(_failed(imageUrl: null));

    await open(tester);

    expect(button('Đọc lại'), findsNothing);
    expect(button('Gửi số tiền đúng'), findsOneWidget);
  });

  for (final status in [
    'APPROVED',
    'WAITING_FOR_REVIEW',
    'PENDING',
    'CANCELED',
  ]) {
    testWidgets('$status can only be looked at: no button', (tester) async {
      serve(_receipt(status: status));

      await open(tester);

      expect(actionButtons, findsNothing);
      expect(find.text('Highlands'), findsOneWidget);
    });
  }

  testWidgets('a receipt that cannot be loaded shows a retry that loads it', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(AppStateView), findsOneWidget);
    expect(find.text('Không tải được hóa đơn'), findsOneWidget);

    serve(_receipt());
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(loads(), 2);
    expect(find.text('Highlands'), findsOneWidget);
  });

  group('edit', () {
    Future<void> startEdit(WidgetTester tester) async {
      await tester.tap(button('Sửa thông tin'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'the form says the transaction and the balance wait for an administrator',
      (tester) async {
        serve(_receipt());
        await open(tester);

        await startEdit(tester);

        expect(
          find.text('Giao dịch và số dư chỉ đổi sau khi quản trị viên duyệt.'),
          findsOneWidget,
        );
        expect(find.byType(CustomTextField), findsNWidgets(2));
      },
    );

    testWidgets('"Lưu" waits for a change', (tester) async {
      serve(_receipt());
      await open(tester);
      await startEdit(tester);

      expect(enabled(tester, 'Lưu'), isFalse);

      await tester.enterText(find.byType(TextField).first, 'Phuc Long');
      await tester.pump();
      expect(enabled(tester, 'Lưu'), isTrue);

      await tester.enterText(find.byType(TextField).first, 'Highlands');
      await tester.pump();
      expect(enabled(tester, 'Lưu'), isFalse);
    });

    testWidgets('only the fields that changed are sent, with the version', (
      tester,
    ) async {
      serve(_receipt());
      backend.on(
        'PUT',
        _receiptPath,
        (_) => okResponse(_receipt(status: 'EDITED', version: 4)),
      );
      final opened = await open(tester);
      await startEdit(tester);

      await tester.enterText(find.byType(TextField).first, 'Phuc Long');
      await tester.pump();
      await tester.tap(button('Lưu'));
      await tester.pumpAndSettle();

      final puts = sent('PUT', _receiptPath);
      expect(puts, hasLength(1));
      expect(puts.single.data, {'version': 3, 'vendorName': 'Phuc Long'});
      expect(find.text('Đã cập nhật hóa đơn'), findsOneWidget);
      expect(loads(), 2);
      expect(opened.seen, hasLength(2));

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(opened.result, [true]);
    });

    testWidgets(
      'a changed total is sent as a number, a changed day as yyyy-MM-dd',
      (tester) async {
        serve(_receipt());
        backend.on('PUT', _receiptPath, (_) => okResponse(_receipt()));
        await open(tester);
        await startEdit(tester);

        await tester.enterText(find.byType(TextField).at(1), '52000');
        await tester.pump();
        await tester.tap(find.text('20/09/2026'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('day-5')));
        await tester.pumpAndSettle();
        await tester.tap(button('Lưu'));
        await tester.pumpAndSettle();

        expect(sent('PUT', _receiptPath).single.data, {
          'version': 3,
          'extractedTotal': 52000,
          'extractedDate': '2026-09-05',
        });
      },
    );

    testWidgets('a total of 0 cannot be saved', (tester) async {
      serve(_receipt());
      await open(tester);
      await startEdit(tester);

      await tester.enterText(find.byType(TextField).at(1), '0');
      await tester.pump();

      expect(enabled(tester, 'Lưu'), isFalse);
    });

    testWidgets(
      'a 409 shows the message of the server and loads the receipt again',
      (tester) async {
        serve(_receipt());
        backend.on(
          'PUT',
          _receiptPath,
          (_) => jsonResponse(409, {'code': 409, 'message': _conflict}),
        );
        final opened = await open(tester);
        await startEdit(tester);

        serve(_receipt(status: 'EDITED', version: 9));
        await tester.enterText(find.byType(TextField).first, 'Phuc Long');
        await tester.pump();
        await tester.tap(button('Lưu'));
        await tester.pumpAndSettle();

        expect(find.text(_conflict), findsOneWidget);
        expect(loads(), 2);
        expect(opened.seen.last.version, 9);
        // Back on the receipt as it is now, not on a form based on the old version.
        expect(find.text('Bạn đã sửa'), findsOneWidget);
        expect(button('Sửa thông tin'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(opened.result, [false]);
      },
    );

    testWidgets('a second tap while the request runs sends nothing more', (
      tester,
    ) async {
      serve(_receipt());
      final answer = Completer<ResponseBody>();
      backend.on('PUT', _receiptPath, (_) => answer.future);
      await open(tester);
      await startEdit(tester);
      await tester.enterText(find.byType(TextField).first, 'Phuc Long');
      await tester.pump();

      await tester.tap(button('Lưu'));
      await tester.tap(button('Lưu'));
      await pumpUntil(tester, () => sent('PUT', _receiptPath).length > 1);

      expect(sent('PUT', _receiptPath), hasLength(1));
      expect(enabled(tester, 'Lưu'), isFalse);
      answer.complete(okResponse(_receipt(status: 'EDITED', version: 4)));
      await tester.pumpAndSettle();
      expect(sent('PUT', _receiptPath), hasLength(1));
    });

    testWidgets('the sheet cannot be closed while the request runs', (
      tester,
    ) async {
      serve(_receipt());
      final answer = Completer<ResponseBody>();
      backend.on('PUT', _receiptPath, (_) => answer.future);
      await open(tester);
      await startEdit(tester);
      await tester.enterText(find.byType(TextField).first, 'Phuc Long');
      await tester.pump();
      await tester.tap(button('Lưu'));
      await pumpUntil(tester, () => sent('PUT', _receiptPath).isNotEmpty);

      await tester.tapAt(const Offset(300, 20));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ReceiptDetailSheet), findsOneWidget);
      answer.complete(okResponse(_receipt(status: 'EDITED', version: 4)));
      await tester.pumpAndSettle();
    });
  });

  group('read again', () {
    void serveScan() {
      backend.on(
        'GET',
        _photoUrl,
        (_) => ResponseBody.fromBytes(Uint8List.fromList([0xFF, 0xD8, 1]), 200),
      );
      backend.on(
        'POST',
        _scanPath,
        (_) => jsonResponse(200, {
          'seller': {'seller_name': 'Highlands', 'total_cost_number': 45000},
        }),
      );
    }

    testWidgets(
      'scans the photo and sends the answer as one JSON text with a clientId',
      (tester) async {
        serve(_failed());
        serveScan();
        backend.on('POST', _retryPath, (_) => okResponse(_receipt()));
        final opened = await open(tester);

        await tester.tap(button('Đọc lại'));
        await settle(tester, () => sent('POST', _retryPath).isNotEmpty);

        final body = sent('POST', _retryPath).single.data as Map;
        expect(body['rawReceiptData'], isA<String>());
        expect(body['rawReceiptData'], contains('"total_cost_number":45000'));
        expect(body['clientId'], matches(RegExp(r'^[0-9a-f-]{36}$')));
        expect(
          sent(
            'GET',
            _photoUrl,
          ).single.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('authorization')),
        );
        expect(find.text('Đã đọc lại hóa đơn'), findsOneWidget);
        expect(loads(), 2);
        expect(opened.seen, hasLength(2));
      },
    );

    testWidgets('says so when the new reading holds no total either', (
      tester,
    ) async {
      serve(_failed());
      serveScan();
      backend.on('POST', _retryPath, (_) => okResponse(_failed()));
      await open(tester);

      await tester.tap(button('Đọc lại'));
      await settle(
        tester,
        () => find.text('Vẫn chưa đọc được tổng tiền').evaluate().isNotEmpty,
      );

      expect(find.text('Vẫn chưa đọc được tổng tiền'), findsOneWidget);
    });

    testWidgets(
      'after a network failure the next tap sends the same clientId',
      (tester) async {
        serve(_failed());
        serveScan();
        var attempts = 0;
        backend.on('POST', _retryPath, (options) {
          attempts++;
          if (attempts == 1) {
            throw DioException.connectionError(
              requestOptions: options,
              reason: 'no network',
            );
          }
          return okResponse(_receipt());
        });
        await open(tester);

        await tester.tap(button('Đọc lại'));
        await settle(tester, () => find.text(_offline).evaluate().isNotEmpty);
        await tester.tap(button('Đọc lại'));
        await settle(
          tester,
          () => find.text('Đã đọc lại hóa đơn').evaluate().isNotEmpty,
        );

        final first = (sent('POST', _retryPath)[0].data as Map)['clientId'];
        final second = (sent('POST', _retryPath)[1].data as Map)['clientId'];
        expect(second, first);
      },
    );

    testWidgets(
      'a photo that cannot be downloaded is told, and nothing is sent',
      (tester) async {
        serve(_failed());
        await open(tester);

        await tester.tap(button('Đọc lại'));
        await settle(tester, () => sent('GET', _photoUrl).isNotEmpty);

        expect(
          find.text('Không tải được ảnh hóa đơn để đọc lại.'),
          findsOneWidget,
        );
        expect(sent('POST', _scanPath), isEmpty);
        expect(sent('POST', _retryPath), isEmpty);
      },
    );
  });

  group('send the right amount', () {
    testWidgets(
      'sends the amount as a query parameter and shows the new state',
      (tester) async {
        serve(_failed());
        backend.on('POST', _feedbackPath, (_) => okResponse(null));
        final opened = await open(tester);

        await tester.tap(button('Gửi số tiền đúng'));
        await tester.pumpAndSettle();
        expect(enabled(tester, 'Gửi'), isFalse);
        await tester.enterText(find.byType(TextField), '52000');
        await tester.pump();
        serve(_receipt(status: 'WAITING_FOR_REVIEW', total: 52000));
        await tester.tap(button('Gửi'));
        await tester.pumpAndSettle();

        final posts = sent('POST', _feedbackPath);
        expect(posts, hasLength(1));
        expect(posts.single.queryParameters, {'manualAmount': 52000});
        expect(find.text('Đã gửi quản trị viên duyệt'), findsOneWidget);
        expect(find.text('Chờ quản trị viên duyệt'), findsOneWidget);
        expect(actionButtons, findsNothing);
        expect(opened.seen.last.status, ReceiptLifecycle.waitingForReview);
      },
    );

    testWidgets('a 409 is told and the receipt loaded again', (tester) async {
      serve(_failed());
      backend.on(
        'POST',
        _feedbackPath,
        (_) => jsonResponse(409, {'code': 409, 'message': _conflict}),
      );
      await open(tester);
      await tester.tap(button('Gửi số tiền đúng'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '52000');
      await tester.pump();

      serve(_receipt(status: 'APPROVED'));
      await tester.tap(button('Gửi'));
      await tester.pumpAndSettle();

      expect(find.text(_conflict), findsOneWidget);
      expect(loads(), 2);
      expect(find.text('Đã được duyệt'), findsOneWidget);
    });
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('every state fits 320 px wide in the $mode theme', (
      tester,
    ) async {
      serve(_failed());
      await open(tester, mode: mode, size: const Size(320, 900));
      final colors = Theme.of(
        tester.element(find.byType(ReceiptDetailSheet)),
      ).colorScheme;

      expect(tester.takeException(), isNull);
      expect(boxColor(tester, find.text(_failedReason)), colors.errorContainer);
      expect(
        paintedColor(tester, find.text(_failedReason)),
        colors.onErrorContainer,
      );

      await tester.tap(button('Gửi số tiền đúng'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      serve(_receipt());
      await tester.tap(button('Hủy'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the edit form fits 320 px wide in the dark theme', (
    tester,
  ) async {
    serve(_receipt());
    await open(tester, mode: ThemeMode.dark, size: const Size(320, 900));

    await tester.tap(button('Sửa thông tin'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(button('Lưu'), findsOneWidget);
    expect(button('Hủy'), findsOneWidget);
  });
}
