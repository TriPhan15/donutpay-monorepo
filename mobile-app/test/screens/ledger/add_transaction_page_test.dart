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
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

import '../../helpers/captured_logs.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';

const String _checkout = '/api/transactions/checkout';
const String _saveLabel = 'Lưu giao dịch';

/// Dio hands a request from one step to the next with zero-length timers, which only fire when the fake clock moves.
const Duration _requestStep = Duration(milliseconds: 100);

final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

final List<Map<String, Object?>> _serverCategories = [
  {'id': 10, 'name': 'Ăn uống', 'type': 'EXPENSE'},
  {'id': 11, 'name': 'Di chuyển', 'type': 'EXPENSE'},
  {'id': 6, 'name': 'Thu nhập', 'type': 'INCOME'},
];

/// Stands for the Ledger: a button that opens the form and reports what the form popped with.
class _Launcher extends StatelessWidget {
  final void Function(bool? saved) onClosed;

  const _Launcher({required this.onClosed});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final saved = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const AddTransactionPage()),
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
  }) async {
    // Tall, so that the whole form is on screen, and wide, because the test font is much wider than a real one.
    tester.view.physicalSize = const Size(600, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _Launcher(
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

  Future<void> typeAmount(WidgetTester tester, String text) =>
      tester.enterText(find.byType(TextField).at(0), text);

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
        await tapText(tester, 'OK');

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

        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, _saveLabel),
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
        await tapText(tester, 'OK');

        expect(sentBodies(), hasLength(1));
        expect(store.rows, hasLength(1));
        expect(store.rows.single.syncStatus, SyncStatus.synced);
      },
    );

    testWidgets(
      'an invalid amount is refused before anything is stored or sent',
      (tester) async {
        await openForm(tester);

        await typeAmount(tester, '');
        await tapText(tester, _saveLabel);

        expect(find.text('Số tiền không hợp lệ'), findsOneWidget);
        expect(store.rows, isEmpty);
        expect(sentBodies(), isEmpty);
      },
    );
  });

  group('amount and date fields', () {
    testWidgets('the form opens on today and the amount is grouped as typed', (
      tester,
    ) async {
      await openForm(tester);

      final today = DateTime.now();
      expect(find.text(DateFormat('dd/MM/yyyy').format(today)), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Hôm nay'))
            .selected,
        isTrue,
      );
      expect(find.byTooltip('Về hôm nay'), findsNothing);

      await typeAmount(tester, '1250000');
      expect(find.text('1.250.000'), findsOneWidget);
    });

    testWidgets(
      'yesterday is sent with the amount read back from the grouped text',
      (tester) async {
        backend.on('POST', _checkout, (_) => okResponse({'transactionId': 5}));
        await openForm(tester);

        await typeAmount(tester, '45000');
        await tapText(tester, 'Hôm qua');
        expect(find.byTooltip('Về hôm nay'), findsOneWidget);
        await tapText(tester, _saveLabel);
        await tapText(tester, 'OK');

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
        await tapText(tester, 'Save transaction');

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
}
