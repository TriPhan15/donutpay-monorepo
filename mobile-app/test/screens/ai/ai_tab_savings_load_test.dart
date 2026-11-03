import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ai/ai_tab_page.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';

/// What the AI tab does with the answer of /api/savings: a goal feeds the allocation advice, a missing or broken answer
/// is no goal at all and never stops the rest of the tab.

const String _savings = '/api/savings';
const String _recommend = '/spade/recommend';
const String _patternShown = 'Ăn uống → Giải trí';
const String _noDeadlineHint = 'Mục tiêu chưa có hạn, góp lúc nào cũng được';

final DateTime _now = DateTime.now();

Map<String, Object?> _tx(
  int id, {
  required num amount,
  String category = 'Ăn uống',
  bool isExpense = true,
}) => {
  'id': id,
  'title': 'Giao dịch $id',
  'amount': amount,
  'date': DateTime(_now.year, _now.month, _now.day, 12).toIso8601String(),
  'category': category,
  'isExpense': isExpense,
};

Map<String, Object?> _goal({String? deadline}) => {
  'id': 1,
  'title': 'Mua laptop',
  'target': 20000000,
  'current': 2000000,
  'deadline': deadline,
};

void main() {
  final backend = FakeBackend();

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    AppRepository.instance.localStore = FakeLocalStore();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});

    backend.reset();
    backend.on(
      'GET',
      '/api/transactions/mine',
      (_) => okResponse([
        _tx(1, amount: 450000),
        _tx(2, amount: 9000000, category: 'Thu nhập', isExpense: false),
      ]),
    );
    backend.on(
      'POST',
      '/spade/analyze',
      (_) => jsonResponse(200, {
        'status': 'OK',
        'patterns': [
          {
            'itemsets': [
              ['Ăn uống'],
              ['Giải trí'],
            ],
            'support': 4,
            'weight': 1.0,
            'weightedSupport': 0.125,
            'weeks': ['2026-W40'],
          },
        ],
      }),
    );
    backend.on(
      'POST',
      _recommend,
      (_) => jsonResponse(200, {'recommendations': []}),
    );
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('vi'),
        home: AITabPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<Object?> recommendations() => [
    for (final r in backend.requests)
      if (r.path == _recommend) r.data,
  ];

  testWidgets('the goal the server sends feeds the allocation advice', (
    tester,
  ) async {
    backend.on('GET', _savings, (_) => okResponse([_goal()]));

    await pumpPage(tester);

    final sent = recommendations().single as Map;
    expect(sent['target'], 20000000.0);
    expect(sent['current'], 2000000.0);
    expect(sent.containsKey('months_left'), isFalse);
    expect(find.text(_noDeadlineHint), findsOneWidget);
    expect(find.text(_patternShown), findsOneWidget);
  });

  final noGoal = {
    'no goal': () => okResponse([]),
    'an answer without data': () => okResponse(null),
    'a refused request': () => jsonResponse(500, {'code': 500}),
    'data that is not a list': () => okResponse('oops'),
    'a goal that is not an object': () => okResponse([1]),
  };
  noGoal.forEach((how, answer) {
    testWidgets(
      '$how is no goal: no advice is asked, and the rest of the tab loads',
      (tester) async {
        backend.on('GET', _savings, (_) => answer());

        await pumpPage(tester);

        expect(recommendations(), isEmpty);
        expect(find.text(_noDeadlineHint), findsNothing);
        expect(find.text(_patternShown), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
