import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/models/savings_goal.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/screens/savings/contribute_sheet.dart';
import 'package:finance_ai_app/screens/savings/widgets/contribute_goal_card.dart';
import 'package:finance_ai_app/screens/savings/widgets/quick_amount_grid.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/captured_logs.dart';

SavingsGoal _goal({String? deadline}) => SavingsGoal.fromJson({
  'id': 7,
  'title': 'Mua laptop',
  'target': 25000000,
  'current': 15000000,
  'deadline': deadline,
});

final DateTime _today = DateTime(2026, 10, 29);

void main() {
  tearDown(() => Intl.defaultLocale = null);

  Future<ThemeData> open(
    WidgetTester tester, {
    String? deadline,
    Future<double?> Function()? loadBalance,
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    late ThemeData theme;
    await tester.pumpWidget(
      withAppSettings(
        Scaffold(
          body: Builder(
            builder: (context) {
              theme = Theme.of(context);
              return ContributeSheet(
                goal: _goal(deadline: deadline),
                today: _today,
                onSubmit: (_) async => SavingsGoal.fromJson({}),
                loadBalance: loadBalance,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return theme;
  }

  Finder amountField() => find.descendant(
    of: find.byKey(ContributeSheet.amountKey),
    matching: find.byType(TextField),
  );

  FilledButton button(WidgetTester tester) => tester.widget<FilledButton>(
    find.descendant(
      of: find.byType(FormSubmitBar),
      matching: find.byType(FilledButton),
    ),
  );

  testWidgets(
    'with a deadline the suggested chip is badged, preselected and explained',
    (tester) async {
      // 29/10/2026 to 28/03/2027: 150 days, 5 months; 10 tr missing → 2 tr a month.
      await open(tester, deadline: '28/03/2027');

      expect(
        tester.widget<TextField>(amountField()).controller!.text,
        '2.000.000',
      );
      final badge = find.byKey(QuickAmountGrid.badgeKey);
      expect(badge, findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(of: badge, matching: find.byType(Stack)).first,
          matching: find.text('2 tr'),
        ),
        findsOneWidget,
      );
      expect(find.text('Gợi ý'), findsOneWidget);
      expect(
        find.text('Gợi ý: góp 2 tr mỗi tháng để kịp hạn 28/03/2027.'),
        findsOneWidget,
      );
      expect(find.text('Góp 2.000.000 đ'), findsOneWidget);
      expect(find.text('60% → '), findsNothing, reason: 'one Text.rich');
      expect(
        find.textContaining('60% → 68%', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('15 tr + 2 tr = 17 tr / 25 tr', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets('without a deadline: no badge, no hint, button disabled', (
    tester,
  ) async {
    await open(tester);

    expect(find.byKey(QuickAmountGrid.badgeKey), findsNothing);
    expect(find.byKey(ContributeSheet.hintKey), findsNothing);
    expect(tester.widget<TextField>(amountField()).controller!.text, '');
    expect(button(tester).onPressed, isNull);
    expect(find.textContaining('60%', findRichText: true), findsOneWidget);
    expect(find.textContaining('→', findRichText: true), findsNothing);
  });

  testWidgets('typing or picking an amount updates the card and the button', (
    tester,
  ) async {
    final theme = await open(tester);

    await tester.enterText(amountField(), '5000000');
    await tester.pump();
    expect(
      find.textContaining('60% → 80%', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Góp 5.000.000 đ'), findsOneWidget);

    await tester.tap(find.byKey(QuickAmountGrid.tileKey(5e5)));
    await tester.pump();
    expect(tester.widget<TextField>(amountField()).controller!.text, '500.000');
    expect(
      find.textContaining('60% → 62%', findRichText: true),
      findsOneWidget,
    );

    final added = tester.widget<FractionallySizedBox>(
      find.byKey(ContributeGoalCard.addedSegmentKey),
    );
    expect(added.widthFactor, closeTo(0.62, 1e-9));
    expect(
      (added.child! as ColoredBox).color,
      theme.semanticColors.pendingProgressColor,
    );
    final saved = tester.widget<FractionallySizedBox>(
      find.byKey(ContributeGoalCard.savedSegmentKey),
    );
    expect(saved.widthFactor, closeTo(0.6, 1e-9));
    expect((saved.child! as ColoredBox).color, theme.colorScheme.primary);
  });

  testWidgets('more than missing: 100% and a full bar', (tester) async {
    await open(tester);

    await tester.enterText(amountField(), '90000000');
    await tester.pump();

    expect(
      find.textContaining('60% → 100%', findRichText: true),
      findsOneWidget,
    );
    final added = tester.widget<FractionallySizedBox>(
      find.byKey(ContributeGoalCard.addedSegmentKey),
    );
    expect(added.widthFactor, closeTo(1, 1e-9));
  });

  testWidgets('the wallet line names the balance once it loads', (
    tester,
  ) async {
    await open(tester, loadBalance: () async => 12400000);

    expect(
      find.text(
        'Trừ từ ví (số dư 12.400.000 đ) và ghi thành khoản chi "Tiết kiệm".',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a balance that fails to load leaves the number out', (
    tester,
  ) async {
    await withCapturedLogs((logs) async {
      await open(tester, loadBalance: () async => throw StateError('offline'));
      expect(logs.single, contains('offline'));
    });

    expect(
      find.text('Trừ từ ví và ghi thành khoản chi "Tiết kiệm".'),
      findsOneWidget,
    );
  });

  testWidgets('an amount above what is missing says the rest also goes in', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(ContributeSheet.overfillKey), findsNothing);

    await tester.enterText(amountField(), '10000000');
    await tester.pump();
    expect(find.byKey(ContributeSheet.overfillKey), findsNothing);

    await tester.enterText(amountField(), '12000000');
    await tester.pump();
    expect(
      find.text(
        'Mục tiêu chỉ còn thiếu 10 tr. Phần dư vẫn được góp vào mục tiêu.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a narrow screen does not overflow', (tester) async {
    await open(tester, deadline: '28/03/2027', width: 320);
    expect(tester.takeException(), isNull);
  });
}
