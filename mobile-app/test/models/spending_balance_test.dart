import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/models/spending_balance.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

TransactionModel _tx(String category, double amount, {bool isExpense = true}) =>
    TransactionModel(
      title: category,
      amount: amount,
      date: DateTime(2026, 10, 1),
      category: category,
      isExpense: isExpense,
    );

void main() {
  group('SpendingBalance.needsTotal', () {
    test(
      'counts every essential default category by the name the server stores',
      () {
        final txs = [
          _tx('Ăn uống', 1),
          _tx('Siêu thị & Chợ', 2),
          _tx('Di chuyển', 4),
          _tx('Nhà ở', 8),
          _tx('Điện nước', 16),
          _tx('Internet & Điện thoại', 32),
          _tx('Sức khỏe', 64),
          _tx('Giáo dục', 128),
          _tx('Gia đình & Con cái', 256),
          _tx('Bảo hiểm', 512),
        ];

        expect(SpendingBalance.needsTotal(txs), 1023);
        expect(
          txs.map((t) => t.category).toSet(),
          TransactionCategories.essentialExpenses,
        );
      },
    );

    test('leaves wants, income and the old non-default names out', () {
      final txs = [
        _tx('Giải trí', 100),
        _tx('Khác', 200),
        _tx('Ăn uống', 300, isExpense: false),
        _tx('Sinh hoạt', 400),
        _tx('Siêu thị', 500),
      ];

      expect(SpendingBalance.needsTotal(txs), 0);
    });

    test('does not count a savings contribution as a need', () {
      expect(SpendingBalance.needsTotal([_tx('Tiết kiệm', 500)]), 0);
    });

    test('ignores surrounding spaces in the stored name', () {
      expect(SpendingBalance.needsTotal([_tx(' Ăn uống ', 300)]), 300);
    });
  });

  group('SpendingBalance.of', () {
    test('no income, no balance', () {
      expect(SpendingBalance.of([_tx('Ăn uống', 10)], 0, 10), isNull);
    });

    test('46 / 38 / 16 is on track, a bit high and a bit low', () {
      final txs = [_tx('Ăn uống', 460), _tx('Giải trí', 380)];
      final b = SpendingBalance.of(txs, 1000, 840)!;

      expect(b.needs.percent, 46);
      expect(b.needs.target, 50);
      expect(b.needs.level, BalanceLevel.ok);
      expect(b.wants.percent, 38);
      expect(b.wants.target, 30);
      expect(b.wants.level, BalanceLevel.high);
      expect(b.savings.percent, 16);
      expect(b.savings.target, 20);
      expect(b.savings.level, BalanceLevel.low);
    });

    test('the level follows the rounded percent on screen', () {
      // 50.4 % shows as 50 %, which is the target, not above it.
      final b = SpendingBalance.of([_tx('Ăn uống', 504)], 1000, 504)!;

      expect(b.needs.percent, 50);
      expect(b.needs.level, BalanceLevel.ok);
      final over = SpendingBalance.of([_tx('Ăn uống', 506)], 1000, 506)!;
      expect(over.needs.percent, 51);
      expect(over.needs.level, BalanceLevel.high);
    });

    test('spending more than the income leaves a negative, low saving', () {
      final b = SpendingBalance.of([_tx('Giải trí', 1500)], 1000, 1500)!;

      expect(b.savings.percent, -50);
      expect(b.savings.level, BalanceLevel.low);
    });

    test('a contribution is not a want and does not lower the saved share', () {
      // The caller leaves the contribution out of spending, as the page does.
      final txs = [_tx('Ăn uống', 400), _tx('Tiết kiệm', 300)];
      final b = SpendingBalance.of(txs, 1000, 400)!;

      expect(b.wants.percent, 0);
      expect(b.savings.percent, 60);
    });

    group('advice keeps the order of the old 50/30/20 card', () {
      test('needs over 50 and not below wants come first', () {
        final b = SpendingBalance.of(
          [_tx('Ăn uống', 600), _tx('Giải trí', 350)],
          1000,
          950,
        )!;
        expect(b.advice, BalanceAdvice.needsHigh);
        expect(b.advicePercent, 60);
      });

      test('then wants over 30', () {
        final b = SpendingBalance.of([_tx('Giải trí', 400)], 1000, 400)!;
        expect(b.advice, BalanceAdvice.wantsHigh);
        expect(b.advicePercent, 40);
      });

      test('then savings under 20, on the rounded percents', () {
        // 50.4 / 30.4 / 19.2 shows as 50 / 30 / 19: only the saving is off.
        final b = SpendingBalance.of(
          [_tx('Ăn uống', 504), _tx('Giải trí', 304)],
          1000,
          808,
        )!;
        expect(b.advice, BalanceAdvice.savingsLow);
        expect(b.advicePercent, 19);
      });

      test('else on track', () {
        final b = SpendingBalance.of([_tx('Ăn uống', 400)], 1000, 400)!;
        expect(b.advice, BalanceAdvice.onTrack);
      });
    });
  });
}
