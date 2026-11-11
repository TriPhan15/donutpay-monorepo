import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/spending_group_colors.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/spending_analysis.dart';
import 'package:finance_ai_app/models/spending_balance.dart';
import 'package:finance_ai_app/models/spending_highlights.dart';
import 'package:finance_ai_app/models/today_allowance.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/screens/ai/widgets/ai_balance_card.dart';
import 'package:finance_ai_app/screens/ai/widgets/ai_habits_card.dart';
import 'package:finance_ai_app/screens/ai/widgets/ai_highlights_card.dart';
import 'package:finance_ai_app/screens/ai/widgets/ai_section.dart';
import 'package:finance_ai_app/screens/ai/widgets/ai_today_band.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(700, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

TransactionModel _tx(DateTime date, double amount, String category) =>
    TransactionModel(
      title: category,
      amount: amount,
      date: date,
      category: category,
      isExpense: true,
    );

SpendingPattern _pattern(List<String> steps, int support) => SpendingPattern(
  itemsets: [
    for (final s in steps) [s],
  ],
  support: support,
  weightedSupport: 0.42,
  weeks: const [],
);

SpendingRule _rule(List<String> from, List<String> to) => SpendingRule(
  antecedent: from,
  consequent: to,
  support: 3,
  antecedentSupport: 4,
  confidence: 0.75,
  laplaceConfidence: 0.7,
  lift: 1.2,
  weeks: const [],
);

Color? _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  final today = DateTime(2026, 10, 21);

  group('value pills follow the theme', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: good, attention, warning, neutral', (
        tester,
      ) async {
        await _pump(
          tester,
          const Column(
            children: [
              AiValuePill(label: 'g', tone: AiPillTone.good),
              AiValuePill(label: 'a', tone: AiPillTone.attention),
              AiValuePill(label: 'w', tone: AiPillTone.warning),
              AiValuePill(label: 'n', tone: AiPillTone.neutral),
            ],
          ),
          brightness: brightness,
        );
        final context = tester.element(find.text('g'));
        final semantic = context.colors;

        expect(_textColor(tester, 'g'), semantic.incomeColor);
        expect(_textColor(tester, 'a'), semantic.expenseColor);
        expect(_textColor(tester, 'w'), semantic.warningColor);
        expect(_textColor(tester, 'n'), Theme.of(context).colorScheme.primary);
      });
    }
  });

  group('AiTodayBand', () {
    Widget band(TodayAllowance a, {bool refreshing = false}) =>
        AiTodayBand(allowance: a, isRefreshing: refreshing);

    testWidgets('shows the allowance, the days left and today\'s bar', (
      tester,
    ) async {
      await _pump(
        tester,
        band(
          const TodayAllowance(
            hasIncome: true,
            perDay: 180000,
            spentToday: 97000,
            daysLeft: 11,
          ),
        ),
      );

      expect(find.text('Hôm nay tiêu được'), findsOneWidget);
      expect(find.text('180.000 đ'), findsOneWidget);
      expect(find.text('còn 11 ngày'), findsOneWidget);
      expect(find.text('Đã tiêu 97.000 đ'), findsOneWidget);
      expect(find.text('Còn 83.000 đ hôm nay'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(AiTodayBand.barKey),
      );
      expect(bar.value, closeTo(97 / 180, 1e-9));
    });

    testWidgets('spending past today\'s share says by how much', (
      tester,
    ) async {
      await _pump(
        tester,
        band(
          const TodayAllowance(
            hasIncome: true,
            perDay: 100000,
            spentToday: 150000,
            daysLeft: 5,
          ),
        ),
      );

      expect(find.text('Vượt 50.000 đ hôm nay'), findsOneWidget);
    });

    testWidgets('without income it asks for one and has no bar', (
      tester,
    ) async {
      await _pump(
        tester,
        band(
          const TodayAllowance(
            hasIncome: false,
            perDay: 0,
            spentToday: 0,
            daysLeft: 5,
          ),
        ),
      );

      expect(
        find.text('Thêm khoản thu tháng này để tính số tiền an toàn.'),
        findsOneWidget,
      );
      expect(find.byKey(AiTodayBand.barKey), findsNothing);
    });

    testWidgets(
      'a month already overspent says so with the amount, and has no bar',
      (tester) async {
        await _pump(
          tester,
          band(
            const TodayAllowance(
              hasIncome: true,
              perDay: -100,
              spentToday: 0,
              daysLeft: 5,
            ),
          ),
        );

        expect(
          find.text('Bạn đã chi vượt phần an toàn của tháng.'),
          findsOneWidget,
        );
        expect(find.text('-100 đ'), findsOneWidget);
        expect(find.text('còn 5 ngày'), findsOneWidget);
        expect(find.byKey(AiTodayBand.barKey), findsNothing);
      },
    );

    testWidgets('shows a spinner only while refreshing, never a button', (
      tester,
    ) async {
      const a = TodayAllowance(
        hasIncome: true,
        perDay: 1,
        spentToday: 0,
        daysLeft: 1,
      );
      await _pump(tester, band(a));
      expect(find.byKey(AiTodayBand.loadingKey), findsNothing);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);

      await _pump(tester, band(a, refreshing: true));
      expect(find.byKey(AiTodayBand.loadingKey), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('AiHighlightsCard', () {
    testWidgets('five rows with their values in pills', (tester) async {
      final highlights = SpendingHighlights.of(
        transactions: [
          _tx(DateTime(2026, 9, 10), 1000000, 'Ăn uống'),
          _tx(DateTime(2026, 10, 19), 600000, 'Ăn uống'),
          _tx(DateTime(2026, 10, 2), 280000, 'Mua sắm'),
          _tx(DateTime(2026, 10, 12), 900000, 'Mua sắm'),
        ],
        savingsGoals: const [],
        today: today,
      );
      await _pump(tester, AiHighlightsCard(highlights: highlights));

      for (final title in [
        'Điểm nổi bật',
        'Xu hướng chi tiêu',
        'Chi nhiều nhất',
        'Mẹo tiết kiệm',
        'So sánh tuần',
        'Tuần chi nhiều nhất',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      // 1,78 tr this month against 1 tr last month.
      expect(find.text('+78%'), findsOneWidget);
      expect(find.text('So với cùng kỳ tháng trước'), findsOneWidget);
      // Mua sắm 1,18 tr of 1,78 tr: 66 %, which needs attention.
      expect(find.text('66%'), findsOneWidget);
      // This week 600k against 900k on the same days of last week.
      expect(find.text('-300k'), findsOneWidget);
      expect(find.text('Tuần 2 của tháng này'), findsOneWidget);
      final context = tester.element(find.text('66%'));
      expect(_textColor(tester, '66%'), context.colors.expenseColor);
      expect(_textColor(tester, '-300k'), context.colors.incomeColor);
    });
  });

  group('AiHabitsCard', () {
    Future<void> pumpHabits(
      WidgetTester tester,
      SpendingAnalysis analysis, {
      List<TransactionModel> transactions = const [],
    }) => _pump(
      tester,
      AiHabitsCard(
        analysis: analysis,
        isLoading: false,
        hasError: false,
        transactions: transactions,
        today: today,
        onRetry: () {},
      ),
    );

    SpendingAnalysis analysis({
      List<SpendingPattern> patterns = const [],
      List<SpendingRule> rules = const [],
      List<PeriodicHabit> habits = const [],
    }) => SpendingAnalysis(
      status: SpendingAnalysisStatus.ok,
      patterns: patterns,
      rules: rules,
      habits: habits,
      weeksWithData: 12,
      minWeeks: 4,
    );

    testWidgets(
      'at most three sequences, each with how often it came back and no technical figure',
      (tester) async {
        await pumpHabits(
          tester,
          analysis(
            patterns: [
              _pattern(['Ăn uống', 'Di chuyển'], 9),
              _pattern(['Mua sắm'], 6),
              _pattern(['Điện nước', 'Ăn uống'], 4),
              _pattern(['Giải trí'], 3),
            ],
          ),
        );

        expect(find.text('Ăn uống → Di chuyển'), findsOneWidget);
        expect(find.text('9 lần'), findsOneWidget);
        expect(find.text('3 lần'), findsNothing);
        expect(find.text('Lặp lại trong 12 tuần qua'), findsNWidgets(3));
        expect(find.textContaining('SPADE'), findsNothing);
        expect(find.textContaining('W-Sup'), findsNothing);
        expect(find.textContaining('0,42'), findsNothing);
      },
    );

    testWidgets('the rule under way this week comes first, as "Sắp tới"', (
      tester,
    ) async {
      await pumpHabits(
        tester,
        analysis(
          patterns: [
            _pattern(['Ăn uống'], 5),
          ],
          rules: [
            _rule(['Mua sắm'], ['Giải trí']),
            _rule(['Ăn uống'], ['Di chuyển']),
          ],
        ),
        transactions: [_tx(DateTime(2026, 10, 20), 1, 'Ăn uống')],
      );

      expect(
        find.text('Sắp tới: sau Ăn uống bạn hay chi Di chuyển.'),
        findsOneWidget,
      );
    });

    testWidgets('without a rule under way it tells the first one as usual', (
      tester,
    ) async {
      await pumpHabits(
        tester,
        analysis(
          patterns: [
            _pattern(['Ăn uống'], 5),
          ],
          rules: [
            _rule(['Mua sắm'], ['Giải trí']),
          ],
        ),
      );

      expect(
        find.text('Thường thì sau Mua sắm bạn hay chi Giải trí.'),
        findsOneWidget,
      );
    });

    testWidgets('periodic expenses show their gap and next or last date', (
      tester,
    ) async {
      await pumpHabits(
        tester,
        analysis(
          habits: [
            PeriodicHabit(
              category: 'Điện nước',
              occurrences: 5,
              meanGapDays: 30,
              lastDate: DateTime(2026, 10, 5),
              nextExpectedDate: DateTime(2026, 11, 4),
            ),
            PeriodicHabit(
              category: 'Ăn uống',
              occurrences: 5,
              meanGapDays: 3.5,
              lastDate: DateTime(2026, 10, 10),
              nextExpectedDate: DateTime(2026, 10, 13),
            ),
            PeriodicHabit(
              category: 'Mua sắm',
              occurrences: 5,
              meanGapDays: 7,
              lastDate: DateTime(2026, 10, 10),
              nextExpectedDate: DateTime(2026, 10, 17),
            ),
          ],
        ),
      );

      expect(find.text('Khoảng 30,0 ngày một lần'), findsOneWidget);
      expect(find.text('04/11'), findsOneWidget);
      expect(find.text('Lần cuối 10/10'), findsOneWidget);
      // Two periodic rows at most.
      expect(find.text('Khoảng 7,0 ngày một lần'), findsNothing);
    });

    testWidgets('too little history says how much is missing', (tester) async {
      await pumpHabits(
        tester,
        const SpendingAnalysis(
          status: SpendingAnalysisStatus.insufficientData,
          patterns: [],
          rules: [],
          habits: [],
          weeksWithData: 2,
          minWeeks: 4,
        ),
      );

      expect(find.text('Chưa đủ dữ liệu'), findsOneWidget);
    });
  });

  group('AiBalanceCard', () {
    testWidgets('three rows with their level, and one advice box', (
      tester,
    ) async {
      final balance = SpendingBalance.of(
        [
          _tx(DateTime(2026, 10, 2), 460, 'Ăn uống'),
          _tx(DateTime(2026, 10, 3), 380, 'Giải trí'),
        ],
        1000,
        840,
      );
      await _pump(
        tester,
        AiBalanceCard(
          balance: balance,
          advice: const {
            'summary': 'Cắt bớt giải trí để kịp mục tiêu.',
            'recommendations': [
              {'tag': 'Giải trí', 'current': 600000, 'suggested': 450000},
            ],
          },
          adviceLoading: false,
        ),
      );

      expect(find.text('Cân đối chi tiêu'), findsOneWidget);
      expect(find.text('46% thu nhập, nên khoảng 50%'), findsOneWidget);
      expect(find.text('38% thu nhập, nên khoảng 30%'), findsOneWidget);
      expect(find.text('16% thu nhập, nên khoảng 20%'), findsOneWidget);
      expect(find.text('Ổn'), findsOneWidget);
      expect(find.text('Hơi cao'), findsOneWidget);
      expect(find.text('Hơi thấp'), findsOneWidget);
      expect(find.textContaining('Nhóm mong muốn'), findsOneWidget);
      expect(find.text('Cắt bớt giải trí để kịp mục tiêu.'), findsOneWidget);
      expect(find.text('Giải trí: 600k → 450k / tháng'), findsOneWidget);

      final context = tester.element(find.text('Ổn'));
      expect(_textColor(tester, 'Ổn'), context.colors.incomeColor);
      expect(_textColor(tester, 'Hơi cao'), context.colors.warningColor);
      final swatches = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .toSet();
      expect(swatches, contains(SpendingGroupColors.wants));
      expect(swatches, contains(Theme.of(context).colorScheme.primary));
    });

    testWidgets('neither income nor advice: nothing at all', (tester) async {
      await _pump(
        tester,
        const AiBalanceCard(balance: null, advice: null, adviceLoading: false),
      );

      expect(find.text('Cân đối chi tiêu'), findsNothing);
    });
  });
}
