import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ai/ai_tab_page.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/screens/ai/widgets/ai_daily_chart_card.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';

/// Phone widths in logical pixels: a common Android phone and the narrowest still in use.
const List<double> _phoneWidths = [360, 320];

/// Tall enough for the ListView to build every card at once, so that each row is laid out.
const double _tallHeight = 6000;

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

String _ddMMyyyy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// The AI tab with every section on screen: income this month (the "safe to spend" card and the 50/30/20 card), a
/// spending pattern, and a savings goal with the allocation advice of the AI service.
///
/// The test font draws each letter as wide as it is tall, much wider than a real font: a row that fits with it fits on
/// a phone too.
void main() {
  final backend = FakeBackend();

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    // The list of transactions also reads the ones waiting to be sent; the fake keeps the test away from a real database.
    AppRepository.instance.localStore = FakeLocalStore();
  });

  setUp(() async {
    // SharedPreferences shares one Future that must be created inside the test body (see budget_display_test.dart).
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
        _tx(2, amount: 120000, category: 'Giải trí'),
        _tx(3, amount: 9000000, category: 'Thu nhập', isExpense: false),
      ]),
    );
    backend.on(
      'GET',
      '/api/savings',
      (_) => okResponse([
        {
          'id': 1,
          'name': 'Mua laptop',
          'target': 20000000,
          'current': 2000000,
          'deadline': _ddMMyyyy(_now.add(const Duration(days: 120))),
        },
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
        'rules': [
          for (final cat in const [
            'Siêu thị & Chợ',
            'Internet & Điện thoại',
            'Gia đình & Con cái',
          ])
            {
              'antecedent': ['Ăn uống', 'Giải trí'],
              'consequent': [cat],
              'support': 6,
              'antecedentSupport': 8,
              'confidence': 0.75,
              'laplaceConfidence': 0.7,
              'lift': 1.4,
              'weeks': ['2026-W40'],
            },
        ],
        'habits': [
          for (final cat in const [
            'Siêu thị & Chợ',
            'Internet & Điện thoại',
            'Gia đình & Con cái',
            'Một danh mục tự đặt có cái tên rất dài để thử tràn dòng',
            'Giải trí',
          ])
            {
              'category': cat,
              'occurrences': 6,
              'meanGapDays': 6.8,
              'lastDate': '2026-10-20',
              'nextExpectedDate': '2099-01-01',
            },
        ],
        'meta': {'weeksWithData': 12, 'minWeeks': 8},
      }),
    );
    backend.on(
      'POST',
      '/spade/recommend',
      (_) => jsonResponse(200, {
        'summary': 'Cắt bớt giải trí để kịp mục tiêu.',
        'recommendations': [
          {
            'action': 'Giảm',
            'tag': 'Giải trí',
            'delta': -100000,
            'current': 120000,
            'suggested': 20000,
            'reason': 'Khoản dễ cắt nhất.',
          },
        ],
      }),
    );
  });

  for (final locale in const [Locale('vi'), Locale('en')]) {
    for (final width in _phoneWidths) {
      testWidgets(
        '${locale.languageCode}, ${width.toInt()} dp wide: no row runs past the screen',
        (tester) async {
          tester.view.physicalSize = Size(width, _tallHeight);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: locale,
              home: const AITabPage(),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          final loc = lookupAppLocalizations(locale);
          // Every section is on screen, so each of their rows was laid out at this width.
          expect(find.text(loc.aiTodayLabel), findsOneWidget);
          expect(find.text(loc.aiHighlightsTitle), findsOneWidget);
          expect(find.byKey(AiDailyChartCard.chartKey), findsOneWidget);
          expect(find.text(loc.aiHabitsTitle), findsOneWidget);
          expect(find.text(loc.aiBalanceTitle), findsOneWidget);
          // The advice of the budget advisor is in the balance box.
          expect(find.textContaining('Cắt bớt giải trí'), findsOneWidget);
        },
      );
    }
  }
}
