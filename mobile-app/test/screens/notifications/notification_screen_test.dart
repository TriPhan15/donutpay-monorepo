import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/screens/budget/budget_screen.dart';
import 'package:finance_ai_app/screens/main_tabs.dart';
import 'package:finance_ai_app/l10n/app_localizations_vi.dart';
import 'package:finance_ai_app/screens/notifications/notification_screen.dart';
import 'package:finance_ai_app/screens/notifications/widgets/notification_row.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/captured_logs.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_settings_repository.dart';
import '../../helpers/theme_colors.dart';

const String _list = '/api/notifications';
const String _readAll = '/api/notifications/read-all';
const String _markAll = 'Đọc tất cả';
const String _unreadLabel = 'Chưa đọc';
const String _markReadFailed =
    'Không đánh dấu được thông báo là đã đọc. Vui lòng thử lại.';
const String _markAllFailed =
    'Không đánh dấu được các thông báo là đã đọc. Vui lòng thử lại.';
const String _loadFailed = 'Không tải được thông báo.';
const String _loadMoreFailed = 'Không tải thêm được thông báo.';
const String _retry = 'Thử lại';
const String _empty = 'Chưa có thông báo nào.';

/// Notification [id] as core-backend sends it; its message is "Thông báo [id]".
Map<String, Object?> _notification(
  int id, {
  String type = 'BUDGET_WARNING',
  bool isRead = false,
  int? transactionId = 500,
  int? budgetId = 100,
  int? receiptId,
}) => {
  'id': id,
  'type': type,
  'message': 'Thông báo $id',
  'isRead': isRead,
  'createdAt': '2026-09-21T10:15:30',
  'transactionId': transactionId,
  'budgetId': budgetId,
  'receiptId': receiptId,
};

/// Ids [from] down to [to]: the newest first, as the server lists them.
List<Map<String, Object?>> _newestFirst(int from, int to) => [
  for (var id = from; id >= to; id--) _notification(id),
];

/// [all] served the way the server pages it.
ResponseBody _pageOf(List<Map<String, Object?>> all, RequestOptions request) {
  final page = int.parse('${request.queryParameters['page']}');
  final size = int.parse('${request.queryParameters['size']}');
  return okResponse({
    'content': all.skip(page * size).take(size).toList(),
    'page': page,
    'size': size,
    'totalElements': all.length,
    'totalPages': (all.length + size - 1) ~/ size,
    'hasNext': (page + 1) * size < all.length,
  });
}

String _message(int id) => 'Thông báo $id';

/// The row that shows notification [id].
Finder _tile(int id) => find.ancestor(
  of: find.text(_message(id)),
  matching: find.byType(NotificationRow),
);

/// The "Đọc tất cả" pill of the band.
Finder _markAllPill() => find.byKey(NotificationScreen.markAllKey);

/// Whether the pill can be tapped, and how opaque it is.
(bool, double) _pillState(WidgetTester tester) => (
  tester.widget<InkWell>(_markAllPill()).onTap != null,
  tester
      .widget<Opacity>(
        find.ancestor(of: _markAllPill(), matching: find.byType(Opacity)),
      )
      .opacity,
);

/// The unread dot of notification [id]: found when the row shows the notification as unread.
Finder _unreadDot(int id) => find.descendant(
  of: _tile(id),
  matching: find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == _unreadLabel,
  ),
);

/// Nothing that identifies the user may travel in a notification request: the server reads the owner from the token.
void _expectNoUserId(RequestOptions request) {
  expect(request.uri.toString(), isNot(contains('userId')));
  final body = request.data;
  if (body is Map) expect(body.keys, isNot(contains('userId')));
}

void main() {
  final backend = FakeBackend();
  var notifications = <Map<String, Object?>>[];

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
  });

  setUp(() async {
    // SharedPreferences shares one Future, which must be created inside the test body (see budget_display_test.dart).
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    await SessionService.setTokens('access-token', 'refresh-token');
    SharedPreferences.setMockInitialValues({});

    backend.reset();
    notifications = _newestFirst(3, 1);
    backend.on('GET', _list, (request) => _pageOf(notifications, request));
  });

  tearDown(() {
    // The language cubit of withAppSettings sets the default locale of intl.
    Intl.defaultLocale = null;
  });

  Future<void> open(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await tester.pumpWidget(
      withAppSettings(
        const NotificationScreen(),
        settings: FakeSettingsRepository(themeMode: themeMode),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// "page/size" of every list request, in order.
  List<String> listRequests() => backend.requests
      .where((request) => request.method == 'GET' && request.path == _list)
      .map(
        (request) =>
            '${request.queryParameters['page']}/${request.queryParameters['size']}',
      )
      .toList();

  Finder scrollable() => find.byType(Scrollable).first;

  /// Lets Dio send a request that a tap started, without waiting for an answer the test holds back.
  Future<void> letTheRequestGo(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 100));

  group('the list', () {
    testWidgets(
      'shows the first page newest first, marks the unread ones, and asks for page 0 of 20 only',
      (tester) async {
        notifications = [
          _notification(3),
          _notification(2, type: 'BUDGET_EXCEEDED', isRead: true),
          _notification(
            1,
            type: 'RECEIPT_PROCESSED',
            budgetId: null,
            receiptId: 900,
          ),
        ];

        await open(tester);

        expect(
          find.descendant(
            of: find.byType(PageBand),
            matching: find.text('Thông báo'),
          ),
          findsOneWidget,
          reason: 'the title, in the band',
        );
        expect(
          tester.getTopLeft(find.text(_message(3))).dy,
          lessThan(tester.getTopLeft(find.text(_message(2))).dy),
        );
        expect(
          tester.getTopLeft(find.text(_message(2))).dy,
          lessThan(tester.getTopLeft(find.text(_message(1))).dy),
        );
        expect(find.text('Sắp chạm hạn mức ngân sách'), findsOneWidget);
        expect(find.text('Đã vượt ngân sách'), findsOneWidget);
        expect(find.text('Hóa đơn đã được xử lý'), findsOneWidget);
        expect(_unreadDot(3), findsOneWidget);
        expect(_unreadDot(2), findsNothing);
        expect(_unreadDot(1), findsOneWidget);
        expect(
          find.text(
            notificationListTime(
              DateTime(2026, 9, 21, 10, 15),
              now: DateTime.now(),
              locale: 'vi',
              loc: AppLocalizationsVi(),
            ),
          ),
          findsNWidgets(3),
        );
        expect(listRequests(), ['0/${NotificationScreen.pageSize}']);
        backend.requests.forEach(_expectNoUserId);
      },
    );

    testWidgets(
      'asks for the next page near the end of the list, and for none after the last one',
      (tester) async {
        notifications = _newestFirst(45, 1);

        await open(tester);
        expect(listRequests(), ['0/20']);

        await tester.scrollUntilVisible(
          find.text(_message(26)),
          300,
          scrollable: scrollable(),
        );
        await tester.pumpAndSettle();
        expect(listRequests(), ['0/20', '1/20']);

        await tester.scrollUntilVisible(
          find.text(_message(6)),
          300,
          scrollable: scrollable(),
        );
        await tester.pumpAndSettle();
        expect(listRequests(), ['0/20', '1/20', '2/20']);

        await tester.scrollUntilVisible(
          find.text(_message(1)),
          300,
          scrollable: scrollable(),
        );
        await tester.drag(scrollable(), const Offset(0, -600));
        await tester.pumpAndSettle();

        expect(find.text(_message(1)), findsOneWidget);
        expect(listRequests(), [
          '0/20',
          '1/20',
          '2/20',
        ], reason: 'the last page said there is no next one');
      },
    );

    testWidgets(
      'fills a tall screen by itself and lists a notification repeated by the next page only once',
      (tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        // A notification raised between the two requests pushed 21 from the end of page 0 onto page 1.
        final firstPage = _newestFirst(40, 21);
        final secondPage = _newestFirst(21, 19);
        backend.on('GET', _list, (request) {
          final first = request.queryParameters['page'] == 0;
          return okResponse({
            'content': first ? firstPage : secondPage,
            'page': request.queryParameters['page'],
            'size': 20,
            'totalElements': 41,
            'totalPages': 3,
            'hasNext': first,
          });
        });

        await open(tester);

        expect(listRequests(), [
          '0/20',
          '1/20',
        ], reason: 'nothing to scroll, so the next page is asked for at once');
        expect(find.byType(NotificationRow), findsNWidgets(22));
        expect(find.text(_message(21)), findsOneWidget);
        expect(find.text(_message(19)), findsOneWidget);
      },
    );

    testWidgets('pulling the list down loads the first page again', (
      tester,
    ) async {
      notifications = _newestFirst(2, 1);
      await open(tester);
      expect(find.text(_message(3)), findsNothing);

      notifications = _newestFirst(3, 1);
      await tester.fling(find.text(_message(2)), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(listRequests(), ['0/20', '0/20']);
      expect(find.text(_message(3)), findsOneWidget);
    });

    testWidgets('an empty list says so, and nothing can be marked', (
      tester,
    ) async {
      notifications = [];

      await open(tester);

      expect(find.text(_empty), findsOneWidget);
      expect(
        find.text('Cảnh báo ngân sách, giao dịch và hóa đơn sẽ hiện ở đây.'),
        findsOneWidget,
      );
      expect(_markAllPill(), findsNothing);
    });

    testWidgets(
      'when the first page cannot be loaded it says so, and "Thử lại" loads it again',
      (tester) async {
        backend.on('GET', _list, (_) => jsonResponse(500, {'code': 500}));

        await withCapturedLogs((logs) async {
          await open(tester);

          expect(
            logs.where(
              (log) => log.startsWith(
                'Notifications: the first page could not be loaded',
              ),
            ),
            hasLength(1),
          );
        });
        expect(find.text(_loadFailed), findsOneWidget);

        backend.on('GET', _list, (request) => _pageOf(notifications, request));
        await tester.tap(find.text(_retry));
        await tester.pumpAndSettle();

        expect(find.text(_loadFailed), findsNothing);
        expect(find.text(_message(3)), findsOneWidget);
      },
    );

    testWidgets(
      'a next page that fails shows "Thử lại" at the end: scrolling does not ask again, the button does',
      (tester) async {
        final all = _newestFirst(45, 1);
        var failSecondPage = true;
        backend.on('GET', _list, (request) {
          if (request.queryParameters['page'] == 1 && failSecondPage) {
            return jsonResponse(500, {'code': 500});
          }
          return _pageOf(all, request);
        });

        await withCapturedLogs((logs) async {
          await open(tester);
          await tester.scrollUntilVisible(
            find.text(_message(26)),
            300,
            scrollable: scrollable(),
          );
          await tester.pumpAndSettle();
          await tester.drag(scrollable(), const Offset(0, -600));
          await tester.pumpAndSettle();

          expect(
            logs.where(
              (log) =>
                  log.startsWith('Notifications: page 1 could not be loaded'),
            ),
            hasLength(1),
          );
        });
        expect(find.text(_loadMoreFailed), findsOneWidget);
        expect(listRequests(), ['0/20', '1/20']);

        failSecondPage = false;
        await tester.tap(find.text(_retry));
        await tester.pumpAndSettle();

        expect(listRequests(), ['0/20', '1/20', '1/20']);
        expect(find.text(_loadMoreFailed), findsNothing);
      },
    );
  });

  group('marking one as read', () {
    testWidgets(
      'a tap shows it as read before the server answers, and it stays read',
      (tester) async {
        notifications = [_notification(7, type: 'TRANSACTION_ALERT')];
        final answer = Completer<ResponseBody>();
        backend.on('PATCH', '$_list/7/read', (_) => answer.future);
        await open(tester);
        expect(_unreadDot(7), findsOneWidget);

        await tester.tap(find.text(_message(7)));
        await letTheRequestGo(tester);

        expect(
          _unreadDot(7),
          findsNothing,
          reason: 'shown as read before the server answered',
        );
        final patch = backend.requests.singleWhere(
          (request) => request.method == 'PATCH',
        );
        expect(patch.path, '$_list/7/read');
        expect(patch.data, isNull);
        _expectNoUserId(patch);

        answer.complete(
          okResponse(_notification(7, type: 'TRANSACTION_ALERT', isRead: true)),
        );
        await tester.pumpAndSettle();

        expect(_unreadDot(7), findsNothing);
        expect(find.text(_markReadFailed), findsNothing);
      },
    );

    testWidgets(
      'when the server does not confirm, it shows as unread again and the user is told',
      (tester) async {
        notifications = [_notification(7, type: 'RECEIPT_PROCESSED')];
        final answer = Completer<ResponseBody>();
        backend.on('PATCH', '$_list/7/read', (_) => answer.future);
        await open(tester);

        await tester.tap(find.text(_message(7)));
        await letTheRequestGo(tester);
        expect(_unreadDot(7), findsNothing);

        await withCapturedLogs((logs) async {
          answer.complete(jsonResponse(500, {'code': 500}));
          await tester.pumpAndSettle();

          expect(
            logs.where((log) => log.contains('7 could not be marked as read')),
            hasLength(1),
          );
        });
        expect(_unreadDot(7), findsOneWidget);
        expect(find.text(_markReadFailed), findsOneWidget);
      },
    );

    testWidgets(
      'a second tap while the first one is being saved sends no second request',
      (tester) async {
        notifications = [_notification(7, type: 'TRANSACTION_ALERT')];
        final answer = Completer<ResponseBody>();
        backend.on('PATCH', '$_list/7/read', (_) => answer.future);
        await open(tester);

        await tester.tap(find.text(_message(7)));
        await letTheRequestGo(tester);
        // The first tap also opened the content of the notification on top of the list: tap the list row again.
        await tester.tap(find.text(_message(7)).first, warnIfMissed: false);
        await letTheRequestGo(tester);

        expect(
          backend.requests.where((request) => request.method == 'PATCH'),
          hasLength(1),
        );
        answer.complete(
          okResponse(_notification(7, type: 'TRANSACTION_ALERT', isRead: true)),
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets('a notification that is already read sends nothing', (
      tester,
    ) async {
      notifications = [
        _notification(7, type: 'TRANSACTION_ALERT', isRead: true),
      ];
      await open(tester);

      await tester.tap(find.text(_message(7)));
      await tester.pumpAndSettle();

      expect(
        backend.requests.where((request) => request.method == 'PATCH'),
        isEmpty,
      );
    });
  });

  group('marking all as read', () {
    testWidgets(
      'a second tap while the request runs sends nothing, and the pill fades meanwhile',
      (tester) async {
        final answer = Completer<ResponseBody>();
        backend.on('PATCH', _readAll, (_) => answer.future);
        await open(tester);
        expect(_pillState(tester), (true, 1.0));

        await tester.tap(_markAllPill());
        await letTheRequestGo(tester);
        expect(_pillState(tester), (false, 0.45));
        await tester.tap(_markAllPill(), warnIfMissed: false);
        await letTheRequestGo(tester);

        expect(
          backend.requests.where((request) => request.method == 'PATCH'),
          hasLength(1),
        );
        answer.complete(okResponse(3));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'shows every notification as read at once and asks the server once',
      (tester) async {
        final answer = Completer<ResponseBody>();
        backend.on('PATCH', _readAll, (_) => answer.future);
        await open(tester);

        await tester.tap(find.text(_markAll));
        await letTheRequestGo(tester);

        for (final id in [3, 2, 1]) {
          expect(_unreadDot(id), findsNothing, reason: '$id');
        }
        final patch = backend.requests.singleWhere(
          (request) => request.method == 'PATCH',
        );
        expect(patch.path, _readAll);
        expect(patch.data, isNull);
        _expectNoUserId(patch);

        answer.complete(okResponse(3));
        await tester.pumpAndSettle();

        expect(_unreadDot(3), findsNothing);
        expect(_pillState(tester), (
          false,
          0.45,
        ), reason: 'nothing unread is left');
      },
    );

    testWidgets(
      'when it fails, the ones that were unread show as unread again and the user is told',
      (tester) async {
        notifications = [
          _notification(3),
          _notification(2, isRead: true),
          _notification(1),
        ];
        backend.on('PATCH', _readAll, (_) => jsonResponse(500, {'code': 500}));
        await open(tester);

        await withCapturedLogs((logs) async {
          await tester.tap(find.text(_markAll));
          await tester.pumpAndSettle();

          expect(
            logs.where((log) => log.startsWith('Notifications: marking all')),
            hasLength(1),
          );
        });

        expect(_unreadDot(3), findsOneWidget);
        expect(_unreadDot(2), findsNothing, reason: 'it was read before');
        expect(_unreadDot(1), findsOneWidget);
        expect(find.text(_markAllFailed), findsOneWidget);
      },
    );
  });

  group('opening a notification', () {
    for (final type in ['BUDGET_WARNING', 'BUDGET_EXCEEDED']) {
      testWidgets('$type opens the budget screen', (tester) async {
        backend.on('GET', '/api/budgets', (_) => okResponse([]));
        notifications = [_notification(7, type: type)];
        backend.on(
          'PATCH',
          '$_list/7/read',
          (_) => okResponse(_notification(7, type: type, isRead: true)),
        );
        await open(tester);

        await tester.tap(find.text(_message(7)));
        await tester.pumpAndSettle();

        expect(find.byType(BudgetScreen), findsOneWidget);
      });
    }

    testWidgets(
      'a type the app does not know shows its whole content in a sheet, and is marked read',
      (tester) async {
        notifications = [
          _notification(
            7,
            type: 'SAVING_GOAL_REACHED',
            transactionId: null,
            budgetId: null,
          ),
        ];
        backend.on(
          'PATCH',
          '$_list/7/read',
          (_) => okResponse(
            _notification(
              7,
              type: 'SAVING_GOAL_REACHED',
              isRead: true,
              budgetId: null,
            ),
          ),
        );
        await open(tester);

        await tester.tap(find.text(_message(7)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        expect(
          find.descendant(of: sheet, matching: find.text(_message(7))),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheet, matching: find.text('Chi tiết thông báo')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheet, matching: find.text('Thông báo')),
          findsOneWidget,
          reason: 'the type row',
        );
        expect(find.byType(NotificationScreen), findsOneWidget);
        expect(_unreadDot(7), findsNothing);
        expect(backend.calls, contains('PATCH $_list/7/read'));
      },
    );
  });

  group('opening a transaction', () {
    for (final type in ['TRANSACTION_ALERT', 'RECEIPT_PROCESSED']) {
      testWidgets(
        '$type with a transaction id closes the screen and hands the id on',
        (tester) async {
          final opened = <int>[];
          notifications = [_notification(7, type: type, transactionId: 500)];
          backend.on(
            'PATCH',
            '$_list/7/read',
            (_) => okResponse(_notification(7, type: type, isRead: true)),
          );
          await tester.pumpWidget(
            withAppSettings(
              Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          NotificationScreen(onOpenTransaction: opened.add),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();

          await tester.tap(find.text(_message(7)));
          await tester.pumpAndSettle();

          expect(opened, [500]);
          expect(find.byType(NotificationScreen), findsNothing);
          expect(find.byType(BottomSheet), findsNothing);
          expect(backend.calls, contains('PATCH $_list/7/read'));
        },
      );
    }

    for (final type in ['TRANSACTION_ALERT', 'RECEIPT_PROCESSED']) {
      testWidgets(
        '$type without a transaction id closes the screen and opens the Ledger',
        (tester) async {
          final opened = <int>[];
          var ledgerOpened = 0;
          notifications = [
            _notification(
              7,
              type: type,
              transactionId: null,
              budgetId: null,
              receiptId: 3,
            ),
          ];
          backend.on(
            'PATCH',
            '$_list/7/read',
            (_) => okResponse(
              _notification(7, type: type, isRead: true, transactionId: null),
            ),
          );
          await tester.pumpWidget(
            withAppSettings(
              Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationScreen(
                        onOpenTransaction: opened.add,
                        onOpenLedger: () => ledgerOpened++,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();

          await tester.tap(find.text(_message(7)));
          await tester.pumpAndSettle();

          expect(ledgerOpened, 1);
          expect(opened, isEmpty);
          expect(find.byType(NotificationScreen), findsNothing);
          expect(backend.calls, contains('PATCH $_list/7/read'));
        },
      );
    }

    testWidgets(
      'without a callback, the Ledger tab of MainScaffold is brought to the front',
      (tester) async {
        final shown = <MainTab>[];
        void show(MainTab tab) => shown.add(tab);
        MainTabs.attach(show);
        addTearDown(() => MainTabs.detach(show));
        notifications = [
          _notification(
            7,
            type: 'RECEIPT_PROCESSED',
            transactionId: null,
            budgetId: null,
          ),
        ];
        backend.on(
          'PATCH',
          '$_list/7/read',
          (_) => okResponse(
            _notification(
              7,
              type: 'RECEIPT_PROCESSED',
              isRead: true,
              transactionId: null,
            ),
          ),
        );
        await tester.pumpWidget(
          withAppSettings(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text(_message(7)));
        await tester.pumpAndSettle();

        expect(shown, [MainTab.ledger]);
        expect(find.byType(NotificationScreen), findsNothing);
      },
    );

    testWidgets(
      'with nowhere to open the Ledger, a receipt notification shows its content instead',
      (tester) async {
        notifications = [
          _notification(
            7,
            type: 'RECEIPT_PROCESSED',
            transactionId: null,
            budgetId: null,
          ),
        ];
        backend.on(
          'PATCH',
          '$_list/7/read',
          (_) => okResponse(
            _notification(
              7,
              type: 'RECEIPT_PROCESSED',
              isRead: true,
              transactionId: null,
            ),
          ),
        );
        await open(tester);

        await tester.tap(find.text(_message(7)));
        await tester.pumpAndSettle();

        expect(find.byType(NotificationScreen), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(_message(7)),
          ),
          findsOneWidget,
        );
        expect(_unreadDot(7), findsNothing);
      },
    );
  });

  testWidgets('the back button of the band closes the screen', (tester) async {
    await tester.pumpWidget(
      withAppSettings(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationScreen(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationScreen), findsOneWidget);

    await tester.tap(find.byKey(NotificationScreen.backKey));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationScreen), findsNothing);
  });

  group('lifecycle', () {
    testWidgets(
      'leaving while the first page is on its way touches nothing and asks for nothing more',
      (tester) async {
        final pending = Completer<ResponseBody>();
        backend.on('GET', _list, (_) => pending.future);

        await tester.pumpWidget(withAppSettings(const NotificationScreen()));
        await letTheRequestGo(tester);
        await tester.pumpWidget(const SizedBox());
        final requestsWhenLeft = backend.requests.length;
        pending.complete(okResponse({'content': [], 'hasNext': true}));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(backend.requests, hasLength(requestsWhenLeft));
      },
    );

    testWidgets(
      'leaving while a notification is being marked touches nothing when the answer comes',
      (tester) async {
        notifications = [_notification(7, type: 'TRANSACTION_ALERT')];
        final answer = Completer<ResponseBody>();
        backend.on('PATCH', '$_list/7/read', (_) => answer.future);
        await open(tester);
        await tester.tap(find.text(_message(7)));
        await letTheRequestGo(tester);

        await tester.pumpWidget(const SizedBox());
        await withCapturedLogs((logs) async {
          answer.complete(jsonResponse(500, {'code': 500}));
          await tester.pumpAndSettle();
        });

        expect(tester.takeException(), isNull);
      },
    );
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      '${mode.name} theme: the rows take their colours from the theme',
      (tester) async {
        notifications = [
          _notification(2),
          _notification(1, type: 'BUDGET_EXCEEDED', isRead: true),
        ];

        await open(tester, themeMode: mode);
        final context = tester.element(find.byType(ListView));
        final theme = Theme.of(context);
        final colors = theme.colorScheme;

        expect(
          theme.brightness,
          mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        expect(find.byType(PageBand), findsOneWidget);
        expect(
          paintedColor(tester, find.text(_message(2))),
          colors.onSurface,
          reason: 'unread',
        );
        expect(
          paintedColor(tester, find.text(_message(1))),
          colors.onSurfaceVariant,
          reason: 'read',
        );
        expect(
          paintedColor(tester, find.text('Sắp chạm hạn mức ngân sách')),
          colors.onSurface,
        );
        expect(
          paintedColor(tester, find.text('Đã vượt ngân sách')),
          colors.onSurfaceVariant,
        );
        expect(
          paintedColor(tester, find.byIcon(Icons.warning_amber_rounded)),
          context.colors.warningColor,
        );
        expect(
          paintedColor(tester, find.byIcon(Icons.error_outline_rounded)),
          colors.error,
        );
        final dot = tester.widget<Container>(
          find.descendant(of: _unreadDot(2), matching: find.byType(Container)),
        );
        expect((dot.decoration! as BoxDecoration).color, colors.primary);
      },
    );
  }
}
