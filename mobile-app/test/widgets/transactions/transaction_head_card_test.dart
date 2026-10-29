import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/widgets/transactions/transaction_head_card.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/vnd.dart';

TransactionModel _tx({required bool isExpense}) => TransactionModel(
  title: 'Cà phê',
  amount: 55000,
  date: DateTime(2026, 10, 20, 8, 30),
  category: 'Ăn uống',
  isExpense: isExpense,
);

void main() {
  Future<ThemeData> pump(WidgetTester tester, Widget card) async {
    late ThemeData theme;
    await tester.pumpWidget(
      withAppSettings(
        Scaffold(
          body: Builder(
            builder: (context) {
              theme = Theme.of(context);
              return card;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return theme;
  }

  Color? colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  testWidgets('a spending shows its title and a negative amount', (
    tester,
  ) async {
    final theme = await pump(
      tester,
      TransactionHeadCard(transaction: _tx(isExpense: true)),
    );

    expect(find.text('Cà phê'), findsOneWidget);
    expect(colorOf(tester, vnd(-55000)), theme.colorScheme.onSurface);
  });

  testWidgets('an income shows its amount in the success colour', (
    tester,
  ) async {
    final theme = await pump(
      tester,
      TransactionHeadCard(transaction: _tx(isExpense: false)),
    );

    final income = find.textContaining('55.000');
    expect(income, findsOneWidget);
    expect(
      tester.widget<Text>(income).style?.color,
      theme.semanticColors.successColor,
    );
  });

  testWidgets('shows the footer under the amount when there is one', (
    tester,
  ) async {
    await pump(
      tester,
      TransactionHeadCard(
        transaction: _tx(isExpense: true),
        footer: const Text('Khoản chi, 20/10/2026 08:30'),
      ),
    );

    expect(find.text('Khoản chi, 20/10/2026 08:30'), findsOneWidget);
  });
}
