import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/widgets/dialogs/ai_components.dart';

TransactionModel _tx(String category, double amount, {bool isExpense = true}) =>
    TransactionModel(
      title: category,
      amount: amount,
      date: DateTime(2026, 10, 1),
      category: category,
      isExpense: isExpense,
    );

void main() {
  group('AiComponents.needsTotal (50/30/20 needs)', () {
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

        expect(AiComponents.needsTotal(txs), 1023);
        expect(
          txs.map((t) => t.category).toSet(),
          TransactionCategories.essentialExpenses,
        );
      },
    );

    test('leaves wants, income and the old non-default names out', () {
      final txs = [
        _tx('Mua sắm', 1),
        _tx('Giải trí', 2),
        _tx('Du lịch', 4),
        _tx('Hiếu hỉ', 8),
        _tx('Khác', 16),
        _tx('Siêu thị', 32),
        _tx('Sinh hoạt', 64),
        _tx('Lương', 128, isExpense: false),
        _tx('Ăn uống', 256, isExpense: false),
      ];

      expect(AiComponents.needsTotal(txs), 0);
    });

    test('ignores surrounding spaces in the stored name', () {
      expect(AiComponents.needsTotal([_tx(' Siêu thị & Chợ ', 10)]), 10);
    });
  });
}
