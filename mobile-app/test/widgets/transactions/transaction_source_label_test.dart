import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/models/transaction_source.dart';
import 'package:finance_ai_app/widgets/transactions/transaction_head_card.dart';
import 'package:finance_ai_app/widgets/transactions/transaction_row.dart';

import '../../helpers/app_settings_scope.dart';

const String _refundLabel = 'Hoàn tiền mục tiêu tiết kiệm';
const String _transferLabel = 'Chuyển ví liên kết';

TransactionModel _tx(TransactionSource source, {bool isExpense = false}) =>
    TransactionModel(
      title: 'Hoàn tiền',
      amount: 500000,
      date: DateTime(2026, 10, 20, 8, 30),
      category: 'Tiết kiệm',
      isExpense: isExpense,
      source: source,
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(withAppSettings(Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  group('TransactionRow', () {
    testWidgets('names a savings goal refund', (tester) async {
      await _pump(
        tester,
        TransactionRow(transaction: _tx(TransactionSource.goalRefund)),
      );

      expect(find.text(_refundLabel), findsOneWidget);
    });

    testWidgets('names a transfer to or from a linked wallet', (tester) async {
      await _pump(
        tester,
        TransactionRow(
          transaction: _tx(TransactionSource.walletTransfer, isExpense: true),
        ),
      );

      expect(find.text(_transferLabel), findsOneWidget);
    });

    testWidgets('shows no extra label for a normal transaction', (
      tester,
    ) async {
      await _pump(
        tester,
        TransactionRow(transaction: _tx(TransactionSource.normal)),
      );

      expect(find.text(_refundLabel), findsNothing);
      expect(find.text(_transferLabel), findsNothing);
    });
  });

  group('TransactionHeadCard', () {
    testWidgets('names a savings goal refund', (tester) async {
      await _pump(
        tester,
        TransactionHeadCard(transaction: _tx(TransactionSource.goalRefund)),
      );

      expect(find.text(_refundLabel), findsOneWidget);
    });

    testWidgets('shows no extra label for a normal transaction', (
      tester,
    ) async {
      await _pump(
        tester,
        TransactionHeadCard(transaction: _tx(TransactionSource.normal)),
      );

      expect(find.text(_refundLabel), findsNothing);
    });
  });
}
