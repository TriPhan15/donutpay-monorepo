import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ledger/add_transaction_page.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/screens/main_tabs.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

import '../../helpers/captured_logs.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';

const String _checkout = '/api/transactions/checkout';
const String _saveLabel = 'Thêm giao dịch chi';
const String _mine = '/api/transactions/mine';

/// Dio hands a request from one step to the next with zero-length timers, which only fire when the fake clock moves.
const Duration _requestStep = Duration(milliseconds: 100);

final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

final List<Map<String, Object?>> _serverCategories = [
  {'id': 10, 'name': 'Ăn uống', 'type': 'EXPENSE'},
  {'id': 11, 'name': 'Di chuyển', 'type': 'EXPENSE'},
  {'id': 12, 'name': 'Mua sắm', 'type': 'EXPENSE'},
  {'id': 13, 'name': 'Hóa đơn', 'type': 'EXPENSE'},
  {'id': 14, 'name': 'Sức khỏe', 'type': 'EXPENSE'},
  {'id': 6, 'name': 'Thu nhập', 'type': 'INCOME'},
  {'id': 7, 'name': 'Lương', 'type': 'INCOME'},
];

Map<String, Object?> _serverTx(String category) => {
  'id': category.hashCode,
  'title': category,
  'amount': 10000,
  'date': '2026-10-20T08:00:00',
  'category': category,
  'isExpense': true,
};

/// Stands for the Ledger: a button that opens the form and reports what the form popped with.
class _Launcher extends StatelessWidget {
  final void Function(bool? saved) onClosed;
  final ValueChanged<DateTime>? onSaved;

  const _Launcher({required this.onClosed, this.onSaved});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final saved = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => AddTransactionPage(onSaved: onSaved),
              ),
            );
            onClosed(saved);
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}

void main() {
  final backend = FakeBackend();
  late FakeLocalStore store;
  var closed = false;
  bool? result;

  setUpAll(() {
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    // The session is written here, outside the fake async of the test body, and the store is reset again afterwards.
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});

    // The category lists are static, so a test that loads them would otherwise feed the next one.
    TransactionCategories.expenseSelectable.clear();
    TransactionCategories.incomeSelectable.clear();

    store = FakeLocalStore();
    AppRepository.instance.localStore = store;
    closed = false;
    result = null;
    backend.reset();
    backend.on('GET', '/api/categories', (_) => okResponse(_serverCategories));
  });

  Future<void> openForm(
    WidgetTester tester, {
    Locale locale = const Locale('vi'),
    ValueChanged<DateTime>? onSaved,
    Size size = const Size(600, 2000),
  }) async {
    // Tall, so that the whole form is on screen, and wide, because the test font is much wider than a real one.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _Launcher(
          onSaved: onSaved,
          onClosed: (saved) {
            closed = true;
            result = saved;
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  /// Gives a request that was just started time to reach the backend, without settling: pump() alone does not move the
  /// clock, so the request would still be inside Dio, and pumpAndSettle would wait for an answer that a test holds back.
  Future<void> pumpForRequest(WidgetTester tester) => tester.pump(_requestStep);

  /// The button follows the amount, so a frame is pumped before the next tap.
  Future<void> typeAmount(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).at(0), text);
    await tester.pump();
  }

  List<Map<String, dynamic>> sentBodies() => [
    for (final request in backend.requests)
      if (request.method == 'POST' && request.path == _checkout)
        Map<String, dynamic>.from(request.data as Map),
  ];

  group('saving in full mode', () {
    testWidgets(
      'the request carries a UUID v4 clientId, the local copy ends synced and the form closes with true',
      (tester) async {
        backend.on('POST', _checkout, (_) => okResponse({'transactionId': 5}));
        await openForm(tester);

        await typeAmount(tester, '45000');
        await tester.enterText(find.byType(TextField).at(1), 'Cà phê');
        await tapText(tester, _saveLabel);

        expect(find.text('Đã thêm giao dịch mới.'), findsOneWidget);
        await tapText(tester, 'Xong');

        final body = sentBodies().single;
        expect(body['clientId'], matches(_uuidV4));
        expect(body['amount'], 45000.0);
        expect(body['note'], 'Cà phê');
        expect(body['categoryName'], 'Ăn uống');
        expect(store.rows.single.clientId, body['clientId']);
        expect(store.rows.single.syncStatus, SyncStatus.synced);
        expect(closed, isTrue);
        expect(result, isTrue);
      },
    );

    testWidgets(
      'without a network the transaction is kept flagged error, the user is told, and the form closes with true',
      (tester) {
        return withCapturedLogs((logs) async {
          backend.on(
            'POST',
            _checkout,
            (options) => throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ),
          );
          await openForm(tester);

          await typeAmount(tester, '45000');
          await tapText(tester, _saveLabel);

          expect(find.text('Chưa gửi được lên máy chủ'), findsOneWidget);
          expect(
            find.textContaining('Gửi lại'),
            findsOneWidget,
            reason: 'the message says where to resend it',
          );
          await tapText(tester, 'Đã hiểu');

          expect(store.rows.single.syncStatus, SyncStatus.error);
          expect(store.rows.single.clientId, sentBodies().single['clientId']);
          expect(closed, isTrue);
          expect(
            result,
            isTrue,
            reason: 'the Ledger reloads and shows the flagged transaction',
          );
          expect(
            logs.where((line) => line.contains('Lỗi gửi giao dịch')),
            isNotEmpty,
          );
        });
      },
    );

    testWidgets(
      'a refusal of the server shows its reason, keeps nothing and leaves the form open',
      (tester) {
        return withCapturedLogs((logs) async {
          backend.on(
            'POST',
            _checkout,
            (_) => jsonResponse(400, {
              'code': 400,
              'message': 'Số dư ví không đủ',
            }),
          );
          await openForm(tester);

          await typeAmount(tester, '45000');
          await tapText(tester, _saveLabel);

          expect(find.text('Lưu thất bại'), findsOneWidget);
          expect(find.text('Số dư ví không đủ'), findsOneWidget);
          await tapText(tester, 'Đã hiểu');

          expect(store.rows, isEmpty);
          expect(closed, isFalse);
          expect(
            find.text(_saveLabel),
            findsOneWidget,
            reason: 'still on the form, so the user can correct it',
          );
        });
      },
    );

    testWidgets(
      'while a save runs the button is off, so a second tap cannot send a second transaction',
      (tester) async {
        final answer = Completer<ResponseBody>();
        backend.on('POST', _checkout, (_) => answer.future);
        await openForm(tester);
        await typeAmount(tester, '45000');

        await tester.tap(find.text(_saveLabel));
        await pumpForRequest(tester);

        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, _saveLabel),
        );
        expect(button.onPressed, isNull);
        expect(
          sentBodies(),
          hasLength(1),
          reason:
              'the first tap started the request, which waits for its answer',
        );
        await tester.tap(find.text(_saveLabel), warnIfMissed: false);
        await pumpForRequest(tester);
        expect(
          sentBodies(),
          hasLength(1),
          reason: 'the second tap sent nothing',
        );

        answer.complete(okResponse({'transactionId': 5}));
        await tester.pumpAndSettle();
        await tapText(tester, 'Xong');

        expect(sentBodies(), hasLength(1));
        expect(store.rows, hasLength(1));
        expect(store.rows.single.syncStatus, SyncStatus.synced);
      },
    );

    testWidgets('onSaved is told the date of the saved transaction', (
      tester,
    ) async {
      backend.on('POST', _checkout, (_) => okResponse({'transactionId': 5}));
      DateTime? saved;
      await openForm(tester, onSaved: (date) => saved = date);

      await typeAmount(tester, '45000');
      await tapText(tester, _saveLabel);
      await tapText(tester, 'Xong');

      final now = DateTime.now();
      expect(saved, isNotNull);
      expect(
        DateTime(saved!.year, saved!.month, saved!.day),
        DateTime(now.year, now.month, now.day),
      );
    });
  });

  group('valid form', () {
    double opacityOfSave(WidgetTester tester) => tester
        .widget<Opacity>(
          find.ancestor(
            of: find.text(_saveLabel),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;

    testWidgets('the button is faded until a positive amount is typed', (
      tester,
    ) async {
      await openForm(tester);
      expect(opacityOfSave(tester), FormSubmitBar.disabledOpacity);

      await typeAmount(tester, '55000');
      await tester.pump();
      expect(opacityOfSave(tester), 1);

      await typeAmount(tester, '0');
      await tester.pump();
      expect(opacityOfSave(tester), FormSubmitBar.disabledOpacity);

      await tester.tap(find.text(_saveLabel), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(store.rows, isEmpty);
      expect(sentBodies(), isEmpty);
    });

    testWidgets(
      'the form can be saved before the categories arrive, as "Khác"',
      (tester) async {
        final categories = Completer<ResponseBody>();
        backend.on('GET', '/api/categories', (_) => categories.future);
        backend.on('POST', _checkout, (_) => okResponse({'transactionId': 5}));
        await openForm(tester);

        await typeAmount(tester, '45000');
        expect(opacityOfSave(tester), 1);
        await tapText(tester, _saveLabel);
        await tapText(tester, 'Xong');

        expect(sentBodies().single['categoryName'], 'Khác');
        categories.complete(okResponse(_serverCategories));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'switching to income keeps the amount and picks the first income category',
      (tester) async {
        backend.on('POST', _checkout, (_) => okResponse({'transactionId': 5}));
        await openForm(tester);
        await typeAmount(tester, '45000');

        await tapText(tester, 'Thu nhập');

        expect(find.text('Thêm giao dịch thu'), findsOneWidget);
        expect(find.text('45.000'), findsOneWidget);
        await tapText(tester, 'Thêm giao dịch thu');
        await tapText(tester, 'Xong');
        final body = sentBodies().single;
        expect(body['categoryName'], 'Thu nhập');
        expect(body['isExpense'], isFalse);
      },
    );
  });

  group('category tiles', () {
    testWidgets('the most used category comes first and is selected', (
      tester,
    ) async {
      backend.on(
        'GET',
        _mine,
        (_) => okResponse([
          _serverTx('Mua sắm'),
          _serverTx('Mua sắm'),
          _serverTx('Mua sắm'),
          _serverTx('Ăn uống'),
        ]),
      );
      backend.on('POST', _checkout, (_) => okResponse({'transactionId': 5}));
      await openForm(tester);

      final shopping = tester.getTopLeft(find.text('Mua sắm')).dx;
      final food = tester.getTopLeft(find.text('Ăn uống')).dx;
      expect(shopping, lessThan(food));

      await typeAmount(tester, '45000');
      await tapText(tester, _saveLabel);
      await tapText(tester, 'Xong');
      expect(sentBodies().single['categoryName'], 'Mua sắm');
    });

    testWidgets(
      'without a transaction list the first categories of the server are offered, without a dialog',
      (tester) {
        return withCapturedLogs((_) async {
          backend.on(
            'GET',
            _mine,
            (_) => jsonResponse(500, {'code': 500, 'message': 'down'}),
          );
          await openForm(tester);

          expect(find.text('Ăn uống'), findsOneWidget);
          expect(find.text('Di chuyển'), findsOneWidget);
          expect(find.text('Mua sắm'), findsOneWidget);
          expect(find.text('Khác'), findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byType(Dialog), findsNothing);
        });
      },
    );

    testWidgets(
      '"Khác" opens the full list and the picked category takes the fourth tile',
      (tester) async {
        backend.on('POST', _checkout, (_) => okResponse({'transactionId': 5}));
        await openForm(tester);

        await tapText(tester, 'Khác');
        expect(find.text('Chọn danh mục chi'), findsOneWidget);
        await tapText(tester, 'Sức khỏe');

        expect(find.text('Khác'), findsNothing);
        expect(find.text('Sức khỏe'), findsOneWidget);
        await typeAmount(tester, '45000');
        await tapText(tester, _saveLabel);
        await tapText(tester, 'Xong');
        expect(sentBodies().single['categoryName'], 'Sức khỏe');
      },
    );
  });

  group('scan tab', () {
    var scans = 0;
    void scanSpy() => scans++;

    setUp(() {
      scans = 0;
      MainTabs.attachScanner(scanSpy);
    });
    tearDown(() => MainTabs.detachScanner(scanSpy));

    testWidgets('an empty form closes and the scanner opens', (tester) async {
      await openForm(tester);

      await tapText(tester, 'Quét hóa đơn');

      expect(closed, isTrue);
      expect(result, isNot(isTrue));
      expect(scans, 1);
    });

    testWidgets('a typed amount is not dropped without asking', (tester) async {
      await openForm(tester);
      await typeAmount(tester, '45000');

      await tapText(tester, 'Quét hóa đơn');
      expect(find.text('Bỏ giao dịch đang nhập?'), findsOneWidget);
      await tapText(tester, 'Hủy');

      expect(closed, isFalse);
      expect(scans, 0);
      expect(find.text('45.000'), findsOneWidget);

      await tapText(tester, 'Quét hóa đơn');
      await tapText(tester, 'Bỏ và quét');
      expect(closed, isTrue);
      expect(scans, 1);
    });
  });

  group('small screen', () {
    testWidgets(
      'with the keyboard open on 320 x 568 the button stays above it and nothing overflows',
      (tester) async {
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetViewInsets);
        await openForm(tester, size: const Size(320, 568));

        expect(tester.takeException(), isNull);
        expect(find.text(_saveLabel).hitTestable(), findsOneWidget);
        final button = tester.getBottomLeft(find.byType(FilledButton)).dy;
        expect(button, lessThanOrEqualTo(568 - 260));
      },
    );
  });

  group('amount and date fields', () {
    testWidgets('the form opens on today and the amount is grouped as typed', (
      tester,
    ) async {
      await openForm(tester);

      final today = DateTime.now();
      expect(
        find.text('Hôm nay, ${DateFormat('dd/MM/yyyy').format(today)}'),
        findsOneWidget,
      );

      await typeAmount(tester, '1250000');
      expect(find.text('1.250.000'), findsOneWidget);
    });

    testWidgets(
      'yesterday is sent with the amount read back from the grouped text',
      (tester) async {
        backend.on('POST', _checkout, (_) => okResponse({'transactionId': 5}));
        await openForm(tester);

        await typeAmount(tester, '45000');
        await tester.tap(find.byIcon(Icons.calendar_today_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Chọn ngày giao dịch'), findsOneWidget);
        await tapText(tester, 'Hôm qua');
        expect(find.textContaining('Hôm qua, '), findsOneWidget);
        await tapText(tester, _saveLabel);
        await tapText(tester, 'Xong');

        final body = sentBodies().single;
        expect(body['amount'], 45000.0);
        final sent = DateTime.parse(body['transactionDate'] as String);
        final now = DateTime.now();
        final yesterday = DateTime(now.year, now.month, now.day - 1);
        expect(DateTime(sent.year, sent.month, sent.day), yesterday);
      },
    );

    testWidgets('English groups the amount with commas', (tester) async {
      await openForm(tester, locale: const Locale('en'));

      await typeAmount(tester, '1250000');
      expect(find.text('1,250,000'), findsOneWidget);
    });
  });

  group('in English', () {
    testWidgets(
      'the form speaks English and a refusal shows the app text instead of the Vietnamese server message',
      (tester) async {
        backend.on(
          'POST',
          _checkout,
          (_) =>
              jsonResponse(400, {'code': 400, 'message': 'Số dư ví không đủ'}),
        );
        await openForm(tester, locale: const Locale('en'));

        expect(find.text('Add transaction'), findsOneWidget);
        expect(find.text('Ăn uống'), findsNothing);
        await typeAmount(tester, '45000');
        await tapText(tester, 'Add expense');

        expect(find.text('Could not save'), findsOneWidget);
        expect(
          find.text(
            'The server refused this transaction. Please check the details.',
          ),
          findsOneWidget,
        );
        expect(find.text('Số dư ví không đủ'), findsNothing);
      },
    );
  });

  testWidgets('the close button waits while a save runs', (tester) async {
    final answer = Completer<ResponseBody>();
    backend.on('POST', _checkout, (_) => answer.future);
    await openForm(tester);
    await typeAmount(tester, '45000');

    await tester.tap(find.text(_saveLabel));
    await pumpForRequest(tester);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await pumpForRequest(tester);
    expect(
      find.text(_saveLabel),
      findsOneWidget,
      reason: 'the form stays until the save is over',
    );
    expect(closed, isFalse);

    answer.complete(okResponse({'transactionId': 5}));
    await tester.pumpAndSettle();
    await tapText(tester, 'Xong');
    expect(closed, isTrue);
    expect(result, isTrue);
  });

  testWidgets('Chi → Thu → Chi keeps the category picked for the expense', (
    tester,
  ) async {
    backend.on('POST', _checkout, (_) => okResponse({'transactionId': 5}));
    await openForm(tester);

    await tapText(tester, 'Di chuyển');
    await tapText(tester, 'Thu nhập');
    await tapText(tester, 'Chi tiêu');
    await typeAmount(tester, '45000');
    await tapText(tester, _saveLabel);
    await tapText(tester, 'Xong');

    expect(sentBodies().single['categoryName'], 'Di chuyển');
  });

  testWidgets(
    'on a 320 x 568 phone with the keyboard up the form keeps room to scroll',
    (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await openForm(tester, size: const Size(320, 568));

      final scroll = find.descendant(
        of: find.byType(AddTransactionPage),
        matching: find.byType(Scrollable),
      );
      final height = tester.getSize(scroll.first).height;
      expect(height, greaterThanOrEqualTo(150));
    },
  );
}
