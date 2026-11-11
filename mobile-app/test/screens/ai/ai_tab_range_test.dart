import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/spending_range.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ai/ai_tab_page.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/screens/ai/widgets/ai_today_band.dart';
import 'package:finance_ai_app/widgets/common/pill_segmented.dart';

import '../../helpers/captured_logs.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';

const String _weekLabel = 'Tuần này';
const String _monthLabel = 'Tháng này';
const String _customLabel = 'Tùy chọn';
const String _todayChip = 'Hôm nay';
const String _yesterdayChip = 'Hôm qua';
const String _fromTitle = 'Từ ngày';
const String _toTitle = 'Đến ngày';
const String _dismissLabel = 'Đã hiểu';

const String _errorTitle = 'Không phân tích được thói quen chi tiêu';
const String _errorCardTitle = 'Không tải được phân tích';
const String _notEnoughDataTitle = 'Chưa đủ dữ liệu';
const String _networkMessage =
    'Không kết nối được tới máy chủ phân tích. Vui lòng kiểm tra mạng và thử lại.';
const String _serverMessage =
    'Máy chủ phân tích đang gặp sự cố. Vui lòng thử lại sau.';
const String _rejectedMessage =
    'Máy chủ phân tích chưa xử lý được yêu cầu. Vui lòng thử lại sau.';
const String _failureLog = 'Lỗi phân tích thói quen chi tiêu';

/// The patterns the fake AI service answers with, and the texts the page makes of them.
const List<String> _foodThenTransport = ['Ăn uống', 'Đi lại'];
const String _foodThenTransportShown = 'Ăn uống → Đi lại';
const List<String> _billsThenShopping = ['Hóa đơn', 'Mua sắm'];
const String _billsThenShoppingShown = 'Hóa đơn → Mua sắm';

final DateTime _now = DateTime.now();

final AppLocalizations _vi = lookupAppLocalizations(const Locale('vi'));

DateTime _at(int year, int month, int day) => DateTime(year, month, day, 12);

/// Today: in this week and in this month.
final DateTime _today = _at(_now.year, _now.month, _now.day);

/// A day (12:00) of the month of [now] outside the Monday-to-Sunday week of [now] and not after [now], which is the
/// 1st when the week starts after it. The charts draw only up to today, so a later day (the last of the month) could
/// never show a point: when the week holds the 1st there is no such day and the result is null.
DateTime? monthOnlyDayFor(DateTime now) {
  final monday = DateTime(
    now.year,
    now.month,
    now.day - (now.weekday - DateTime.monday),
  );
  final first = _at(now.year, now.month, 1);
  return first.isBefore(monday) ? first : null;
}

/// Null on the days when the week of today holds the 1st of the month: the tests then expect today's points only.
final DateTime? _monthOnlyDay = monthOnlyDayFor(_now);

/// The expenses the fake backend holds on the month-only day (none when there is no such day), as the page sends them.
final List<num> _sentAmounts = [1000, if (_monthOnlyDay != null) 2000, 4000];

/// The expenses of the month by day: today's, and the month-only day's when there is one.
final Map<DateTime, double> _monthExpenses = {
  _today: 1000,
  ?_monthOnlyDay: 2000,
};

/// A day of last month: outside this week and this month.
final DateTime _lastMonthDay = _at(_now.year, _now.month - 1, 15);

/// A transaction the way core-backend sends it.
Map<String, Object?> _tx(
  int id,
  DateTime date, {
  num amount = 1000,
  String category = 'Ăn uống',
  bool isExpense = true,
}) => {
  'id': id,
  'title': 'Giao dịch $id',
  'amount': amount,
  'date': date.toIso8601String(),
  'category': category,
  'isExpense': isExpense,
};

Map<String, Object?> _pattern(List<String> steps) => {
  'itemsets': [
    for (final step in steps) [step],
  ],
  'support': 4,
  'weight': 1.0,
  'weightedSupport': 0.125,
  'weeks': ['2026-W40'],
};

/// What the AI service answers to /spade/analyze.
ResponseBody _patternsResponse(List<Map<String, Object?>> patterns) =>
    jsonResponse(200, {'status': 'OK', 'patterns': patterns});

/// What the month chart must draw for expenses on the given days: one point per day, up to today, worked out here
/// from the days of the month so that the test does not lean on the code it checks.
List<double> _monthPoints(Map<DateTime, double> expenseOn) {
  final points = List.filled(_now.day, 0.0);
  expenseOn.forEach((day, amount) {
    if (day.day <= _now.day) points[day.day - 1] += amount;
  });
  return points;
}

/// What the week chart must draw: one point per day, Monday first, up to today.
List<double> _weekPoints(Map<DateTime, double> expenseOn) {
  final points = List.filled(_now.weekday, 0.0);
  expenseOn.forEach((day, amount) {
    if (day.weekday <= _now.weekday) points[day.weekday - 1] += amount;
  });
  return points;
}

Future<void> _showPage(WidgetTester tester, PickDateRange? pickDateRange) {
  // Tall, so that every card is built without scrolling, and wide, because the test font is much wider than a real one.
  tester.view.physicalSize = const Size(700, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: pickDateRange == null
          ? const AITabPage()
          : AITabPage(pickDateRange: pickDateRange),
    ),
  );
}

/// A few frames without waiting for the animations to stop: a test that keeps an answer of the AI service pending
/// has a spinner that never stops, so pumpAndSettle would time out.
Future<void> _pumpFrames(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

String _selectedOption(WidgetTester tester) => switch (tester
    .widget<PillSegmented<SpendingPeriod>>(
      find.byType(PillSegmented<SpendingPeriod>),
    )
    .selected) {
  SpendingPeriod.week => _weekLabel,
  SpendingPeriod.month => _monthLabel,
  SpendingPeriod.custom => _customLabel,
};

bool _isRefreshing(WidgetTester tester) =>
    find.byKey(AiTodayBand.loadingKey).evaluate().isNotEmpty;

/// Pull-to-refresh: drags the page down far enough (the test drag is damped by overscroll friction) to start the refresh.
Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, 1200));
  await tester.pumpAndSettle();
}

LineChartData _chart(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;

List<double> _points(WidgetTester tester) => [
  for (final spot in _chart(tester).lineBarsData.single.spots) spot.y,
];

/// The amounts of the transactions a request to the AI service carried, in order.
List<num> _amountsSent(RequestOptions request) {
  final sent = (request.data as Map)['transactions'] as List;
  return [for (final tx in sent) (tx as Map)['amount'] as num]..sort();
}

void main() {
  group('monthOnlyDayFor', () {
    test('is null when the week of now holds the 1st (Sunday the 1st)', () {
      expect(monthOnlyDayFor(DateTime(2026, 11, 1)), isNull);
    });

    test('is the 1st once the week starts after it', () {
      expect(monthOnlyDayFor(DateTime(2026, 11, 2)), _at(2026, 11, 1));
      expect(monthOnlyDayFor(DateTime(2026, 11, 15)), _at(2026, 11, 1));
      expect(monthOnlyDayFor(DateTime(2026, 11, 30)), _at(2026, 11, 1));
    });

    test('holds for every day of 2026', () {
      for (
        var day = DateTime(2026);
        day.year == 2026;
        day = DateTime(day.year, day.month, day.day + 1)
      ) {
        final result = monthOnlyDayFor(day);
        if (result == null) continue;
        final monday = DateTime(
          day.year,
          day.month,
          day.day - (day.weekday - 1),
        );
        expect(result.month, day.month, reason: '$day');
        expect(result.year, day.year, reason: '$day');
        expect(result.isBefore(monday), isTrue, reason: '$day');
        expect(result.isAfter(day), isFalse, reason: '$day');
      }
    });
  });

  final backend = FakeBackend();
  var transactions = <Map<String, Object?>>[];
  var patterns = <Map<String, Object?>>[];

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    // The list of transactions also reads the ones waiting to be sent; the fake keeps the test away from a real database.
    AppRepository.instance.localStore = FakeLocalStore();
  });

  setUp(() async {
    // SharedPreferences shares one Future that must be created inside the test body, which runs in fake async, so the
    // store is reset after the session is written and the body starts from scratch (see budget_display_test.dart).
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});

    backend.reset();
    transactions = [
      _tx(1, _today, amount: 1000),
      if (_monthOnlyDay case final day?) _tx(2, day, amount: 2000),
      _tx(3, _lastMonthDay, amount: 4000),
      _tx(4, _today, amount: 9000, category: 'Thu nhập', isExpense: false),
    ];
    patterns = [_pattern(_foodThenTransport)];
    backend.on(
      'GET',
      '/api/transactions/mine',
      (_) => okResponse(transactions),
    );
    backend.on('GET', '/api/savings', (_) => okResponse([]));
    backend.on('POST', '/spade/analyze', (_) => _patternsResponse(patterns));
  });

  List<RequestOptions> analyses() =>
      backend.requests.where((r) => r.path == '/spade/analyze').toList();

  Future<void> pumpPage(
    WidgetTester tester, {
    PickDateRange? pickDateRange,
  }) async {
    await _showPage(tester, pickDateRange);
    await tester.pumpAndSettle();
  }

  Future<void> pumpPageWhileLoading(WidgetTester tester) async {
    await _showPage(tester, null);
    await _pumpFrames(tester);
  }

  group('opening the tab', () {
    testWidgets(
      'opens by analysing 26 weeks of spending, not the month on screen',
      (tester) async {
        await pumpPage(tester);

        expect(_selectedOption(tester), _monthLabel);
        expect(analyses(), hasLength(1));
        // Last month is inside the 26 weeks; the income never is.
        expect(_amountsSent(analyses().single), _sentAmounts);
        expect(find.text(_foodThenTransportShown), findsOneWidget);
        expect(find.text(SpendingRange.month(_now).label), findsOneWidget);
      },
    );

    testWidgets(
      'the request keeps the shape the AI service already knows: only the transactions, each with four fields',
      (tester) async {
        await pumpPage(tester);

        final body = analyses().single.data as Map;
        expect(body.keys, ['transactions']);
        for (final tx in body['transactions'] as List) {
          expect(
            (tx as Map).keys,
            unorderedEquals(['category', 'amount', 'date', 'isExpense']),
          );
        }
      },
    );

    testWidgets(
      'the month chart has one point per day of the month and draws the expenses up to today, no income',
      (tester) async {
        await pumpPage(tester);

        expect(_points(tester), _monthPoints(_monthExpenses));
        expect(
          _chart(tester).maxX,
          DateTime(_now.year, _now.month + 1, 0).day - 1,
        );
      },
    );

    testWidgets(
      'without any transaction there is no filter and the AI service is not called',
      (tester) async {
        transactions = [];

        await pumpPage(tester);

        expect(find.byType(PillSegmented<SpendingPeriod>), findsNothing);
        expect(analyses(), isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a history older than 26 weeks says there is not enough data and does not call the AI service',
      (tester) async {
        transactions = [_tx(3, _at(_now.year - 2, 1, 15), amount: 4000)];

        await pumpPage(tester);

        expect(analyses(), isEmpty);
        expect(find.text(_notEnoughDataTitle), findsOneWidget);
        expect(find.text(_errorCardTitle), findsNothing);
      },
    );
  });

  group('time filter', () {
    testWidgets(
      'choosing this week redraws the chart without asking the AI service again',
      (tester) async {
        await pumpPage(tester);

        await _tap(tester, _weekLabel);

        expect(_selectedOption(tester), _weekLabel);
        expect(analyses(), hasLength(1));
        expect(_points(tester), _weekPoints({_today: 1000}));
        for (final label in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']) {
          expect(
            find.descendant(
              of: find.byType(LineChart),
              matching: find.text(label),
            ),
            findsOneWidget,
            reason: label,
          );
        }
        expect(find.text(SpendingRange.week(_now).label), findsOneWidget);
      },
    );

    testWidgets(
      'choosing this month again goes back to the days of the month, still with one analysis',
      (tester) async {
        await pumpPage(tester);

        await _tap(tester, _weekLabel);
        await _tap(tester, _monthLabel);

        expect(_selectedOption(tester), _monthLabel);
        expect(analyses(), hasLength(1));
        expect(_points(tester), _monthPoints(_monthExpenses));
      },
    );

    testWidgets('the patterns stay when the filter changes', (tester) async {
      await pumpPage(tester);
      expect(find.text(_foodThenTransportShown), findsOneWidget);

      await _tap(tester, _weekLabel);

      expect(find.text(_foodThenTransportShown), findsOneWidget);
    });

    testWidgets(
      'tapping the period that is already on screen does not call the AI service again',
      (tester) async {
        await pumpPage(tester);

        await _tap(tester, _monthLabel);

        expect(analyses(), hasLength(1));
      },
    );

    testWidgets(
      'the top week row keeps comparing the weeks of the month, whatever the chart shows',
      (tester) async {
        await pumpPage(tester);
        final weeks = List.filled(4, 0.0);
        for (final MapEntry(key: day, value: amount)
            in _monthExpenses.entries) {
          weeks[math.min((day.day - 1) ~/ 7, 3)] += amount;
        }
        var best = 0;
        for (var i = 1; i < weeks.length; i++) {
          if (weeks[i] > weeks[best]) best = i;
        }
        final card = 'Tuần ${best + 1} của tháng này';
        expect(find.textContaining(card), findsOneWidget);

        await _tap(tester, _weekLabel);

        expect(find.textContaining(card), findsOneWidget);
      },
    );

    testWidgets('a change of the data keeps the period the user chose', (
      tester,
    ) async {
      await pumpPage(tester);
      await _tap(tester, _weekLabel);

      RemoteApiHelper.instance.dataChangedNotifier.value++;
      await tester.pumpAndSettle();

      expect(_selectedOption(tester), _weekLabel);
      expect(analyses(), hasLength(2));
      expect(_amountsSent(analyses().last), _sentAmounts);
    });
  });

  group('custom range', () {
    testWidgets(
      'draws one point per picked day and is marked on screen, without a new analysis',
      (tester) async {
        final firstOfLastMonth = _at(_now.year, _now.month - 1, 1);
        DateTimeRange? offered;
        await pumpPage(
          tester,
          pickDateRange: (_, initial) async {
            offered = initial;
            return DateTimeRange(start: firstOfLastMonth, end: _lastMonthDay);
          },
        );

        await _tap(tester, _customLabel);

        expect(
          offered,
          DateTimeRange(
            start: DateTime(_now.year, _now.month, 1),
            end: DateTime(_now.year, _now.month + 1, 0),
          ),
          reason: 'the picker starts from the days on screen',
        );
        expect(_selectedOption(tester), _customLabel);
        expect(analyses(), hasLength(1));
        expect(
          find.text(
            SpendingRange.custom(firstOfLastMonth, _lastMonthDay).label,
          ),
          findsOneWidget,
        );
        expect(_points(tester), [
          ...List.filled(14, 0.0),
          4000.0,
        ], reason: 'fifteen days in the past, all drawn');
      },
    );

    testWidgets('a picker that is closed without a choice changes nothing', (
      tester,
    ) async {
      await pumpPage(tester, pickDateRange: (_, _) async => null);

      await _tap(tester, _customLabel);

      expect(_selectedOption(tester), _monthLabel);
      expect(analyses(), hasLength(1));
    });

    testWidgets('a preset chosen after a custom range replaces it', (
      tester,
    ) async {
      await pumpPage(
        tester,
        pickDateRange: (_, _) async =>
            DateTimeRange(start: _lastMonthDay, end: _lastMonthDay),
      );

      await _tap(tester, _customLabel);
      await _tap(tester, _weekLabel);

      expect(_selectedOption(tester), _weekLabel);
      expect(analyses(), hasLength(1));
    });

    testWidgets(
      'Tùy chọn asks for the first day, then the last one, in the date sheets of the app',
      (tester) async {
        await pumpPage(tester);

        await _tap(tester, _customLabel);
        expect(find.text(_fromTitle), findsOneWidget);
        await _tap(tester, _yesterdayChip);
        expect(find.text(_toTitle), findsOneWidget);
        await _tap(tester, _todayChip);

        expect(find.text(_toTitle), findsNothing);
        expect(_selectedOption(tester), _customLabel);
        expect(analyses(), hasLength(1));
        expect(
          find.text(
            SpendingRange.custom(
              _now.subtract(const Duration(days: 1)),
              _now,
            ).label,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('closing a date sheet changes nothing', (tester) async {
      await pumpPage(tester);

      await _tap(tester, _customLabel);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text(_fromTitle), findsNothing);
      expect(_selectedOption(tester), _monthLabel);
      expect(analyses(), hasLength(1));
    });

    testWidgets('closing the second sheet changes nothing either', (
      tester,
    ) async {
      await pumpPage(tester);

      await _tap(tester, _customLabel);
      await _tap(tester, _todayChip);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text(_toTitle), findsNothing);
      expect(_selectedOption(tester), _monthLabel);
    });
  });

  group('pull to refresh', () {
    testWidgets('analyses the same 26 weeks again and shows the new patterns', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.text(_foodThenTransportShown), findsOneWidget);

      patterns = [_pattern(_billsThenShopping)];
      await _pullToRefresh(tester);

      expect(analyses(), hasLength(2));
      expect(_amountsSent(analyses().last), _sentAmounts);
      expect(find.text(_billsThenShoppingShown), findsOneWidget);
      expect(find.text(_foodThenTransportShown), findsNothing);
    });

    testWidgets('keeps the period the user chose', (tester) async {
      await pumpPage(tester);
      await _tap(tester, _weekLabel);

      await _pullToRefresh(tester);

      expect(_selectedOption(tester), _weekLabel);
      expect(analyses(), hasLength(2));
      expect(_amountsSent(analyses().last), _sentAmounts);
    });

    testWidgets(
      'shows the spinner while the analysis runs and hides it once it is over',
      (tester) async {
        final answer = Completer<ResponseBody>();
        backend.on('POST', '/spade/analyze', (_) => answer.future);

        await pumpPageWhileLoading(tester);

        expect(_isRefreshing(tester), isTrue);
        expect(
          find.descendant(
            of: find.byType(AiTodayBand),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );

        answer.complete(_patternsResponse(patterns));
        await tester.pumpAndSettle();

        expect(_isRefreshing(tester), isFalse);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(analyses(), hasLength(1));
      },
    );
  });

  group('answers out of order', () {
    late List<Completer<ResponseBody>> gates;

    /// Opens the tab and then changes the data, both answers of the AI service still pending.
    Future<void> openThenChangeData(WidgetTester tester) async {
      gates = [];
      backend.on('POST', '/spade/analyze', (_) {
        final gate = Completer<ResponseBody>();
        gates.add(gate);
        return gate.future;
      });
      await pumpPageWhileLoading(tester);
      expect(gates, hasLength(1), reason: 'the first analysis');

      RemoteApiHelper.instance.dataChangedNotifier.value++;
      await _pumpFrames(tester);
      expect(gates, hasLength(2), reason: 'the analysis after the change');
    }

    testWidgets(
      'a reload that comes back after a newer one does not bring back the old transactions',
      (tester) async {
        await pumpPage(tester);
        final oldList = Completer<ResponseBody>();
        final staleTransactions = [_tx(9, _today, amount: 7000)];
        var calls = 0;
        backend.on('GET', '/api/transactions/mine', (_) {
          calls++;
          // The first reload is slow and carries what the server had before the second change.
          return calls == 1 ? oldList.future : okResponse(transactions);
        });

        RemoteApiHelper.instance.dataChangedNotifier.value++;
        await _pumpFrames(tester);
        RemoteApiHelper.instance.dataChangedNotifier.value++;
        await tester.pumpAndSettle();
        expect(_amountsSent(analyses().last), _sentAmounts);
        final analysesBefore = analyses().length;

        oldList.complete(okResponse(staleTransactions));
        await tester.pumpAndSettle();

        expect(analyses(), hasLength(analysesBefore));
        expect(_points(tester), _monthPoints(_monthExpenses));
      },
    );

    testWidgets(
      'an answer that comes after a newer analysis was started is dropped',
      (tester) async {
        await openThenChangeData(tester);

        gates[1].complete(_patternsResponse([_pattern(_billsThenShopping)]));
        await _pumpFrames(tester);
        expect(find.text(_billsThenShoppingShown), findsOneWidget);
        expect(_isRefreshing(tester), isFalse);

        gates[0].complete(_patternsResponse([_pattern(_foodThenTransport)]));
        await _pumpFrames(tester);

        expect(find.text(_billsThenShoppingShown), findsOneWidget);
        expect(find.text(_foodThenTransportShown), findsNothing);
      },
    );

    testWidgets(
      'an old answer neither shows its patterns nor stops the spinner of the newer analysis',
      (tester) async {
        await openThenChangeData(tester);

        gates[0].complete(_patternsResponse([_pattern(_foodThenTransport)]));
        await _pumpFrames(tester);

        expect(find.text(_foodThenTransportShown), findsNothing);
        expect(
          _isRefreshing(tester),
          isTrue,
          reason: 'the newer analysis is still running',
        );

        gates[1].complete(_patternsResponse([_pattern(_billsThenShopping)]));
        await tester.pumpAndSettle();

        expect(find.text(_billsThenShoppingShown), findsOneWidget);
        expect(_isRefreshing(tester), isFalse);
      },
    );

    testWidgets('an answer that arrives after the page is gone does nothing', (
      tester,
    ) async {
      final answer = Completer<ResponseBody>();
      backend.on('POST', '/spade/analyze', (_) => answer.future);
      await pumpPageWhileLoading(tester);

      await tester.pumpWidget(const SizedBox());
      answer.complete(_patternsResponse(patterns));
      await _pumpFrames(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a failure that arrives after the page is gone opens no dialog',
      (tester) async {
        final answer = Completer<ResponseBody>();
        backend.on('POST', '/spade/analyze', (_) => answer.future);
        await pumpPageWhileLoading(tester);
        RemoteApiHelper.instance.dataChangedNotifier.value++;
        await _pumpFrames(tester);

        await tester.pumpWidget(const SizedBox());
        answer.completeError(
          DioException(
            requestOptions: RequestOptions(path: '/spade/analyze'),
            type: DioExceptionType.connectionError,
          ),
        );
        await _pumpFrames(tester);

        expect(tester.takeException(), isNull);
        expect(find.text(_errorTitle), findsNothing);
      },
    );
  });

  group('errors', () {
    testWidgets(
      'a failed background load is shown on the card without a dialog; Làm mới then reports it and can recover',
      (tester) async {
        await withCapturedLogs((logs) async {
          backend.on(
            'POST',
            '/spade/analyze',
            (o) => throw DioException(
              requestOptions: o,
              type: DioExceptionType.connectionError,
            ),
          );

          await pumpPage(tester);

          expect(find.text(_errorCardTitle), findsOneWidget);
          expect(
            find.text(_notEnoughDataTitle),
            findsNothing,
            reason: 'a failure is not a lack of data',
          );
          expect(
            find.text(_dismissLabel),
            findsNothing,
            reason: 'nothing the user asked for failed, so no dialog',
          );
          expect(logs.where((l) => l.contains(_failureLog)), hasLength(1));

          await _pullToRefresh(tester);

          expect(find.text(_errorTitle), findsOneWidget);
          expect(find.text(_networkMessage), findsOneWidget);
          await _tap(tester, _dismissLabel);
          expect(find.text(_errorTitle), findsNothing);
          expect(find.text(_errorCardTitle), findsOneWidget);
          expect(logs.where((l) => l.contains(_failureLog)), hasLength(2));

          backend.on(
            'POST',
            '/spade/analyze',
            (_) => _patternsResponse(patterns),
          );
          await _pullToRefresh(tester);

          expect(find.text(_errorCardTitle), findsNothing);
          expect(find.text(_foodThenTransportShown), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      },
    );

    testWidgets(
      'a server error on Làm mới is reported as a problem of the server, and the old patterns go',
      (tester) async {
        await withCapturedLogs((logs) async {
          await pumpPage(tester);
          expect(find.text(_foodThenTransportShown), findsOneWidget);

          backend.on(
            'POST',
            '/spade/analyze',
            (_) => jsonResponse(503, {'detail': 'down'}),
          );
          await _pullToRefresh(tester);

          expect(find.text(_errorTitle), findsOneWidget);
          expect(find.text(_serverMessage), findsOneWidget);
          expect(
            find.text(_foodThenTransportShown),
            findsNothing,
            reason: 'a failed analysis shows the error card, not the old list',
          );
          await _tap(tester, _dismissLabel);
          expect(find.text(_errorCardTitle), findsOneWidget);
          expect(logs.where((l) => l.contains(_failureLog)), hasLength(1));
        });
      },
    );

    testWidgets('a request the server refuses is reported as not processed', (
      tester,
    ) async {
      await withCapturedLogs((logs) async {
        await pumpPage(tester);

        backend.on(
          'POST',
          '/spade/analyze',
          (_) => jsonResponse(422, {'detail': 'bad'}),
        );
        await _pullToRefresh(tester);

        expect(find.text(_errorTitle), findsOneWidget);
        expect(find.text(_rejectedMessage), findsOneWidget);
        await _tap(tester, _dismissLabel);
      });
    });

    testWidgets('changing the period never opens an error dialog', (
      tester,
    ) async {
      await withCapturedLogs((logs) async {
        await pumpPage(
          tester,
          pickDateRange: (_, _) async =>
              DateTimeRange(start: _lastMonthDay, end: _lastMonthDay),
        );

        backend.on(
          'POST',
          '/spade/analyze',
          (o) => throw DioException(
            requestOptions: o,
            type: DioExceptionType.receiveTimeout,
          ),
        );
        await _tap(tester, _weekLabel);
        await _tap(tester, _customLabel);

        expect(analyses(), hasLength(1));
        expect(find.text(_errorTitle), findsNothing);
        expect(_selectedOption(tester), _customLabel);
      });
    });
  });

  group('budget advice', () {
    const adviceText = 'Gợi ý thử nghiệm';

    void withGoal() {
      backend.on(
        'GET',
        '/api/savings',
        (_) => okResponse([
          {
            'id': 1,
            'title': 'Mục tiêu',
            'target': 5e6,
            'current': 1e6,
            'deadline': null,
          },
        ]),
      );
    }

    testWidgets('failed advice clears the previous advice', (tester) async {
      await withCapturedLogs((logs) async {
        withGoal();
        backend.on(
          'POST',
          '/spade/recommend',
          (_) =>
              jsonResponse(200, {'summary': adviceText, 'recommendations': []}),
        );
        await pumpPage(tester);
        expect(find.text(adviceText), findsOneWidget);

        backend.on(
          'POST',
          '/spade/recommend',
          (_) => jsonResponse(503, {'detail': 'down'}),
        );
        RemoteApiHelper.instance.dataChangedNotifier.value++;
        await tester.pumpAndSettle();

        expect(find.text(adviceText), findsNothing);
        expect(find.text(_dismissLabel), findsNothing);
      });
    });

    testWidgets(
      'a 422 for a history that is too short clears the advice and opens no dialog',
      (tester) async {
        await withCapturedLogs((logs) async {
          withGoal();
          backend.on(
            'POST',
            '/spade/recommend',
            (_) => jsonResponse(200, {
              'summary': adviceText,
              'recommendations': [],
            }),
          );
          await pumpPage(tester);
          expect(find.text(adviceText), findsOneWidget);

          backend.on(
            'POST',
            '/spade/recommend',
            (_) => jsonResponse(422, {'detail': 'Chưa đủ lịch sử chi tiêu'}),
          );
          RemoteApiHelper.instance.dataChangedNotifier.value++;
          await tester.pumpAndSettle();

          expect(find.text(adviceText), findsNothing);
          expect(find.text(_dismissLabel), findsNothing);
          expect(tester.takeException(), isNull);
        });
      },
    );

    testWidgets(
      'the advice gets the history from the 1st day 7 months back, without savings',
      (tester) async {
        withGoal();
        transactions = [
          _tx(1, _today, amount: 1000),
          _tx(2, DateTime(_now.year, _now.month - 7, 1), amount: 2000),
          _tx(3, DateTime(_now.year, _now.month - 7, 0, 23, 59), amount: 4000),
          _tx(4, _today, amount: 700, category: 'Tiết kiệm'),
        ];
        backend.on(
          'POST',
          '/spade/recommend',
          (_) => jsonResponse(200, {'recommendations': []}),
        );

        await pumpPage(tester);

        final sent = backend.requests
            .where((r) => r.path == '/spade/recommend')
            .single;
        expect(_amountsSent(sent), [1000, 2000]);
      },
    );

    group('answers out of order', () {
      late List<Completer<ResponseBody>> gates;

      /// Opens the tab and changes the data, both advice requests still pending.
      Future<void> openThenChangeData(WidgetTester tester) async {
        withGoal();
        gates = [];
        backend.on('POST', '/spade/recommend', (_) {
          final gate = Completer<ResponseBody>();
          gates.add(gate);
          return gate.future;
        });
        await pumpPageWhileLoading(tester);
        expect(gates, hasLength(1), reason: 'the first advice request');

        RemoteApiHelper.instance.dataChangedNotifier.value++;
        await _pumpFrames(tester);
        expect(gates, hasLength(2), reason: 'the request after the change');

        gates[1].complete(
          jsonResponse(200, {'summary': adviceText, 'recommendations': []}),
        );
        await _pumpFrames(tester);
        expect(find.text(adviceText), findsOneWidget);
      }

      testWidgets('a late 422 does not clear the newer advice', (tester) async {
        await withCapturedLogs((logs) async {
          await openThenChangeData(tester);

          gates[0].complete(
            jsonResponse(422, {'detail': 'Chưa đủ lịch sử chi tiêu'}),
          );
          await _pumpFrames(tester);

          expect(find.text(adviceText), findsOneWidget);
        });
      });

      testWidgets('a late answer does not overwrite the newer advice', (
        tester,
      ) async {
        await openThenChangeData(tester);

        gates[0].complete(
          jsonResponse(200, {'summary': 'Gợi ý cũ', 'recommendations': []}),
        );
        await _pumpFrames(tester);

        expect(find.text(adviceText), findsOneWidget);
        expect(find.text('Gợi ý cũ'), findsNothing);
      });
    });

    testWidgets('savings contributions are not sent to /spade/analyze', (
      tester,
    ) async {
      transactions = [
        _tx(1, _today, amount: 1000),
        _tx(2, _today, amount: 700, category: 'Tiết kiệm'),
      ];

      await pumpPage(tester);

      expect(_amountsSent(analyses().single), [1000]);
    });
  });

  group('savings goal', () {
    const onTrackText = 'Đúng lộ trình tiết kiệm';
    const needMoreText = 'Cần góp thêm cho mục tiêu';

    String two(int n) => n.toString().padLeft(2, '0');

    /// A goal the way core-backend sends it; a deadline of today makes the monthly need the whole rest.
    Map<String, Object?> goal({
      required num target,
      String? deadline,
      num current = 0,
    }) => {
      'id': 1,
      'title': 'Mục tiêu',
      'target': target,
      'current': current,
      'deadline': deadline,
    };

    testWidgets(
      'a goal without deadline sends no months_left and no savings contribution',
      (tester) async {
        transactions = [
          _tx(1, _today, amount: 5000),
          _tx(2, _today, amount: 9000, category: 'Thu nhập', isExpense: false),
          _tx(3, _today, amount: 700, category: 'Tiết kiệm'),
        ];
        backend.on(
          'GET',
          '/api/savings',
          (_) => okResponse([goal(target: 5e6, current: 1e6)]),
        );
        backend.on(
          'POST',
          '/spade/recommend',
          (_) => jsonResponse(200, {'recommendations': []}),
        );

        await pumpPage(tester);

        final sent = backend.requests
            .where((r) => r.path == '/spade/recommend')
            .toList();
        expect(sent, hasLength(1));
        final body = sent.single.data as Map;
        expect(body.containsKey('months_left'), isFalse);
        final categories = [
          for (final t in body['transactions'] as List) (t as Map)['category'],
        ];
        expect(categories, isNot(contains('Tiết kiệm')));
        expect(categories, hasLength(2));
        expect(
          find.text('Mục tiêu chưa có hạn, góp lúc nào cũng được'),
          findsOneWidget,
        );
      },
    );

    testWidgets('on track is shown only when the month covers the goal', (
      tester,
    ) async {
      final deadline = '${two(_now.day)}/${two(_now.month)}/${_now.year}';
      backend.on(
        'GET',
        '/api/savings',
        (_) => okResponse([goal(target: 2e6, deadline: deadline)]),
      );
      backend.on(
        'POST',
        '/spade/recommend',
        (_) => jsonResponse(200, {'recommendations': []}),
      );

      transactions = [
        _tx(1, _today, amount: 3e6),
        _tx(2, _today, amount: 10e6, category: 'Thu nhập', isExpense: false),
      ];
      await pumpPage(tester);
      expect(find.textContaining(onTrackText), findsOneWidget);
      expect(find.textContaining(needMoreText), findsNothing);

      transactions = [
        _tx(1, _today, amount: 2.5e6),
        _tx(2, _today, amount: 3e6, category: 'Thu nhập', isExpense: false),
      ];
      RemoteApiHelper.instance.dataChangedNotifier.value++;
      await tester.pumpAndSettle();
      expect(find.textContaining(needMoreText), findsOneWidget);
      expect(find.textContaining(onTrackText), findsNothing);
    });

    testWidgets('an overdue goal says it is past its deadline', (tester) async {
      backend.on(
        'GET',
        '/api/savings',
        (_) => okResponse([goal(target: 5e6, deadline: '01/01/2020')]),
      );
      backend.on(
        'POST',
        '/spade/recommend',
        (_) => jsonResponse(200, {'recommendations': []}),
      );

      await pumpPage(tester);

      expect(
        find.text(
          'Mục tiêu đã quá hạn, hãy cập nhật hạn mới hoặc tiếp tục góp',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Mục tiêu chưa có hạn, góp lúc nào cũng được'),
        findsNothing,
      );
    });

    /// What the page shows for [amount]: grouped the Vietnamese way, then the currency.
    String money(double amount) =>
        '${NumberFormat.decimalPattern('vi').format(amount.round())} đ';

    final noUnfinishedGoal = {
      'reached this month': [goal(target: 2e6, current: 2e6)],
      'deleted this month': <Map<String, Object?>>[],
    };
    noUnfinishedGoal.forEach((how, goals) {
      testWidgets(
        'a goal $how after contributing: safe-to-spend and the surplus leave out what was contributed',
        (tester) async {
          const contributed = 2e6;
          transactions = [
            _tx(1, _today, amount: 3e6),
            _tx(
              2,
              _today,
              amount: 10e6,
              category: 'Thu nhập',
              isExpense: false,
            ),
            _tx(3, _today, amount: contributed, category: 'Tiết kiệm'),
          ];
          backend.on('GET', '/api/savings', (_) => okResponse(goals));

          await pumpPage(tester);

          // Today's allowance: income 10M − the 2M that left the wallet for the goal, over the days left; the 3M
          // spent today shows on the bar instead of shrinking it.
          final daysLeft =
              DateTime(_now.year, _now.month + 1, 0).day - _now.day + 1;
          expect(
            find.text(money((10e6 - contributed) / daysLeft)),
            findsOneWidget,
          );
          expect(find.text('Đã tiêu ${money(3e6)}'), findsOneWidget);
          // The surplus: income 10M − spending 3M − the 2M contributed.
          const left = 10e6 - 3e6 - contributed;
          expect(
            find.text('Tháng này còn dư, hãy lập mục tiêu'),
            findsOneWidget,
          );
          expect(
            find.text('+${CurrencyHelper.formatCompactVND(left, _vi)}'),
            findsOneWidget,
          );
        },
      );
    });

    testWidgets(
      'without a goal, contributions that eat the whole surplus ask for a goal instead',
      (tester) async {
        transactions = [
          _tx(1, _today, amount: 3e6),
          _tx(2, _today, amount: 5e6, category: 'Thu nhập', isExpense: false),
          _tx(3, _today, amount: 2e6, category: 'Tiết kiệm'),
        ];

        await pumpPage(tester);

        expect(
          find.text('Thêm mục tiêu tiết kiệm để AI phân tích.'),
          findsOneWidget,
        );
        expect(find.text('Tháng này còn dư, hãy lập mục tiêu'), findsNothing);
      },
    );
  });
}
