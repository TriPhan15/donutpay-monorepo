import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/models/savings_goal.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/screens/savings/savings_goal_form_page.dart';

import '../../helpers/app_settings_scope.dart';

/// What the form sent, one map per submit.
typedef _Sent = List<Map<String, Object?>>;

void main() {
  late _Sent sent;
  late String? failWith;
  bool? popped;

  setUp(() {
    sent = [];
    failWith = null;
    popped = null;
  });

  tearDown(() => Intl.defaultLocale = null);

  /// Opens the form from a button, so that its pop result is seen.
  Future<void> open(WidgetTester tester, {SavingsGoal? goal}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  popped = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SavingsGoalFormPage(
                        goal: goal,
                        onSubmit:
                            ({
                              required title,
                              required target,
                              deadline,
                            }) async {
                              sent.add({
                                'title': title,
                                'target': target,
                                'deadline': deadline,
                              });
                              return failWith;
                            },
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.descendant(
      of: find.byType(FormSubmitBar),
      matching: find.byType(FilledButton),
    ),
  );

  Finder amountField() => find.descendant(
    of: find.byKey(SavingsGoalFormPage.amountKey),
    matching: find.byType(TextField),
  );

  testWidgets('a new goal: band, two cards, saved 0 and save disabled', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Thêm mục tiêu'), findsOneWidget);
    expect(find.text('Mục tiêu'), findsOneWidget);
    expect(find.text('Thời hạn'), findsOneWidget);
    expect(find.text('Đã tiết kiệm'), findsOneWidget);
    expect(find.text('0 đ'), findsOneWidget);
    expect(find.text('Chọn ngày'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('a chip fills the target, and saving sends name and target', (
    tester,
  ) async {
    await open(tester);

    await tester.enterText(
      find.byKey(SavingsGoalFormPage.nameKey),
      '  Mua xe ',
    );
    await tester.tap(find.byKey(SavingsGoalFormPage.targetChipKey(25e6)));
    await tester.pump();
    expect(
      tester.widget<TextField>(amountField()).controller!.text,
      '25.000.000',
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(SavingsGoalFormPage.targetChipKey(25e6)),
          )
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(SavingsGoalFormPage.saveKey));
    await tester.pumpAndSettle();

    expect(sent, [
      {'title': 'Mua xe', 'target': 25e6, 'deadline': null},
    ]);
    expect(popped, isTrue);
  });

  testWidgets('an empty name keeps save disabled', (tester) async {
    await open(tester);

    await tester.enterText(amountField(), '5000000');
    await tester.enterText(find.byKey(SavingsGoalFormPage.nameKey), '   ');
    await tester.pump();

    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('a picked date is sent as dd/MM/yyyy and can be removed', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateFormat('dd/MM/yyyy').format(now);
    await open(tester);
    await tester.enterText(find.byKey(SavingsGoalFormPage.nameKey), 'Mua xe');
    await tester.enterText(amountField(), '5000000');

    await tester.tap(find.byKey(SavingsGoalFormPage.deadlineKey));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Hôm nay'));
    await tester.pumpAndSettle();
    expect(find.text(today), findsOneWidget);

    await tester.tap(find.byKey(SavingsGoalFormPage.clearDeadlineKey));
    await tester.pump();
    expect(find.text('Chọn ngày'), findsOneWidget);

    await tester.tap(find.byKey(SavingsGoalFormPage.deadlineKey));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Hôm nay'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SavingsGoalFormPage.saveKey));
    await tester.pumpAndSettle();

    expect(sent.single['deadline'], today);
  });

  testWidgets('editing starts from the goal and shows its saved amount', (
    tester,
  ) async {
    await open(
      tester,
      goal: SavingsGoal.fromJson({
        'id': 7,
        'title': 'Du lịch',
        'target': 10000000,
        'current': 2500000,
        'deadline': '31/12/2026',
      }),
    );

    expect(find.text('Sửa mục tiêu'), findsOneWidget);
    expect(find.text('Du lịch'), findsOneWidget);
    expect(
      tester.widget<TextField>(amountField()).controller!.text,
      '10.000.000',
    );
    expect(find.text('2.500.000 đ'), findsOneWidget);
    expect(find.text('31/12/2026'), findsOneWidget);

    await tester.tap(find.byKey(SavingsGoalFormPage.clearDeadlineKey));
    await tester.pump();
    await tester.tap(find.byKey(SavingsGoalFormPage.saveKey));
    await tester.pumpAndSettle();

    expect(sent, [
      {'title': 'Du lịch', 'target': 10e6, 'deadline': null},
    ]);
  });

  testWidgets('a stored date in another format is kept unless changed', (
    tester,
  ) async {
    await open(
      tester,
      goal: SavingsGoal.fromJson({
        'id': 7,
        'title': 'Du lịch',
        'target': 10000000,
        'current': 0,
        'deadline': '2026-12-31',
      }),
    );

    expect(find.text('2026-12-31'), findsOneWidget);
    await tester.tap(find.byKey(SavingsGoalFormPage.saveKey));
    await tester.pumpAndSettle();
    expect(sent.single['deadline'], '2026-12-31');
  });

  testWidgets('a stored date in another format can still be removed', (
    tester,
  ) async {
    await open(
      tester,
      goal: SavingsGoal.fromJson({
        'id': 7,
        'title': 'Du lịch',
        'target': 10000000,
        'current': 0,
        'deadline': '2026-12-31',
      }),
    );

    await tester.tap(find.byKey(SavingsGoalFormPage.clearDeadlineKey));
    await tester.pump();
    expect(find.text('Chọn ngày'), findsOneWidget);
    await tester.tap(find.byKey(SavingsGoalFormPage.saveKey));
    await tester.pumpAndSettle();
    expect(sent.single['deadline'], isNull);
  });

  testWidgets('a failure keeps the page and what was typed', (tester) async {
    failWith = 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';
    await open(tester);
    await tester.enterText(find.byKey(SavingsGoalFormPage.nameKey), 'Mua xe');
    await tester.enterText(amountField(), '5000000');
    await tester.pump();

    await tester.tap(find.byKey(SavingsGoalFormPage.saveKey));
    await tester.pumpAndSettle();

    expect(find.text('Không lưu được mục tiêu'), findsOneWidget);
    expect(find.text(failWith!), findsOneWidget);
    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();

    expect(find.byType(SavingsGoalFormPage), findsOneWidget);
    expect(find.text('Mua xe'), findsOneWidget);
    expect(popped, isNull);
  });
}
