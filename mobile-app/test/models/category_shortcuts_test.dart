import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/models/category_shortcuts.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/models/transaction_source.dart';

TransactionModel _tx(
  String category, {
  bool isExpense = true,
  TransactionSource source = TransactionSource.normal,
}) => TransactionModel(
  title: category,
  amount: 10000,
  date: DateTime(2026, 10, 20),
  category: category,
  isExpense: isExpense,
  source: source,
);

void main() {
  const available = ['Ăn uống', 'Mua sắm', 'Di chuyển', 'Hóa đơn', 'Khác'];

  group('pick', () {
    test('without history the first categories of the server are offered', () {
      expect(
        CategoryShortcuts.pick(
          available: available,
          history: const [],
          isExpense: true,
        ),
        ['Ăn uống', 'Mua sắm', 'Di chuyển'],
      );
    });

    test(
      'a transfer to a linked wallet does not count as a use of its category',
      () {
        final history = [
          for (var i = 0; i < 3; i++)
            _tx('Hóa đơn', source: TransactionSource.walletTransfer),
          _tx('Di chuyển'),
        ];
        expect(
          CategoryShortcuts.pick(
            available: available,
            history: history,
            isExpense: true,
          ).first,
          'Di chuyển',
        );
      },
    );

    test('the most used categories come first', () {
      final history = [
        _tx('Hóa đơn'),
        _tx('Hóa đơn'),
        _tx('Hóa đơn'),
        _tx('Di chuyển'),
        _tx('Di chuyển'),
        _tx('Mua sắm'),
      ];
      expect(
        CategoryShortcuts.pick(
          available: available,
          history: history,
          isExpense: true,
        ),
        ['Hóa đơn', 'Di chuyển', 'Mua sắm'],
      );
    });

    test('only transactions of the same type are counted', () {
      final history = [
        for (var i = 0; i < 5; i++) _tx('Khác', isExpense: false),
        _tx('Hóa đơn'),
      ];
      expect(
        CategoryShortcuts.pick(
          available: available,
          history: history,
          isExpense: true,
        ),
        ['Hóa đơn', 'Ăn uống', 'Mua sắm'],
      );
    });

    test('equal counts keep the order of the server', () {
      final history = [_tx('Khác'), _tx('Di chuyển')];
      expect(
        CategoryShortcuts.pick(
          available: available,
          history: history,
          isExpense: true,
        ),
        ['Di chuyển', 'Khác', 'Ăn uống'],
      );
    });

    test('savings and categories the server does not offer are left out', () {
      final history = [
        _tx(TransactionCategories.savings),
        _tx(TransactionCategories.savings),
        _tx('Cũ đã xóa'),
        _tx('Cũ đã xóa'),
      ];
      expect(
        CategoryShortcuts.pick(
          available: available,
          history: history,
          isExpense: true,
        ),
        ['Ăn uống', 'Mua sắm', 'Di chuyển'],
      );
    });

    test('fewer categories than shortcuts gives all of them', () {
      expect(
        CategoryShortcuts.pick(
          available: const ['Lương', 'Thưởng'],
          history: const [],
          isExpense: false,
        ),
        ['Lương', 'Thưởng'],
      );
      expect(
        CategoryShortcuts.pick(
          available: const [],
          history: [_tx('Ăn uống')],
          isExpense: true,
        ),
        isEmpty,
      );
    });
  });

  group('overflowOf', () {
    const shortcuts = ['A', 'B', 'C'];

    test('a selection outside the shortcuts takes the fourth tile', () {
      expect(CategoryShortcuts.overflowOf(shortcuts, 'D'), 'D');
    });

    test('a selection among the shortcuts or no selection gives null', () {
      expect(CategoryShortcuts.overflowOf(shortcuts, 'B'), isNull);
      expect(CategoryShortcuts.overflowOf(shortcuts, null), isNull);
    });
  });
}
