import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/models/transaction_filter.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/models/transaction_source.dart';

TransactionModel _tx(
  double amount, {
  bool isExpense = true,
  DateTime? date,
  String title = 'x',
  TransactionSource source = TransactionSource.normal,
}) => TransactionModel(
  title: title,
  amount: amount,
  date: date ?? DateTime(2026, 10, 20),
  category: 'Ăn uống',
  isExpense: isExpense,
  source: source,
);

void main() {
  test('type keeps only expenses or only income', () {
    final txs = [_tx(10), _tx(20, isExpense: false)];
    expect(
      const TransactionFilter(
        type: TransactionTypeFilter.expense,
      ).apply(txs).map((t) => t.amount),
      [10],
    );
    expect(
      const TransactionFilter(
        type: TransactionTypeFilter.income,
      ).apply(txs).map((t) => t.amount),
      [20],
    );
    expect(TransactionFilter.none.apply(txs), hasLength(2));
  });

  test(
    'the refund of a savings goal is not listed under Thu, only under all',
    () {
      final txs = [
        _tx(10, isExpense: false),
        _tx(20, isExpense: false, source: TransactionSource.goalRefund),
      ];
      expect(
        const TransactionFilter(
          type: TransactionTypeFilter.income,
        ).apply(txs).map((t) => t.amount),
        [10],
      );
      expect(TransactionFilter.none.apply(txs), hasLength(2));
    },
  );

  test('a wallet transfer is listed under neither Thu nor Chi', () {
    final txs = [
      _tx(10),
      _tx(20, isExpense: false),
      _tx(30, source: TransactionSource.walletTransfer),
      _tx(40, isExpense: false, source: TransactionSource.walletTransfer),
    ];
    expect(
      const TransactionFilter(
        type: TransactionTypeFilter.expense,
      ).apply(txs).map((t) => t.amount),
      [10],
    );
    expect(
      const TransactionFilter(
        type: TransactionTypeFilter.income,
      ).apply(txs).map((t) => t.amount),
      [20],
    );
    expect(TransactionFilter.none.apply(txs), hasLength(4));
  });

  test('amount ranges meet at 100k and 500k without overlap', () {
    bool inRange(AmountRange r, double a) =>
        TransactionFilter(range: r).matches(_tx(a));
    expect(inRange(AmountRange.under100k, 99999), isTrue);
    expect(inRange(AmountRange.under100k, 100000), isFalse);
    expect(inRange(AmountRange.from100kTo500k, 100000), isTrue);
    expect(inRange(AmountRange.from100kTo500k, 500000), isTrue);
    expect(inRange(AmountRange.from100kTo500k, 500001), isFalse);
    expect(inRange(AmountRange.over500k, 500000), isFalse);
    expect(inRange(AmountRange.over500k, 500001), isTrue);
    expect(inRange(AmountRange.any, 0), isTrue);
  });

  test('newest, oldest and largest order', () {
    final a = _tx(50, date: DateTime(2026, 10, 1), title: 'a');
    final b = _tx(90, date: DateTime(2026, 10, 2), title: 'b');
    final c = _tx(90, date: DateTime(2026, 10, 3), title: 'c');
    final txs = [a, b, c];
    String order(TransactionSort s) =>
        TransactionFilter(sort: s).apply(txs).map((t) => t.title).join();
    expect(order(TransactionSort.newest), 'cba');
    expect(order(TransactionSort.oldest), 'abc');
    // Equal amounts: the newer one first.
    expect(order(TransactionSort.largest), 'cba');
  });

  test('sort alone is not an active filter', () {
    expect(TransactionFilter.none.isActive, isFalse);
    expect(
      const TransactionFilter(sort: TransactionSort.largest).isActive,
      isFalse,
    );
    expect(
      const TransactionFilter(type: TransactionTypeFilter.income).isActive,
      isTrue,
    );
    expect(
      const TransactionFilter(range: AmountRange.over500k).isActive,
      isTrue,
    );
  });

  test('apply on nothing gives an empty list', () {
    expect(TransactionFilter.none.apply(const []), isEmpty);
  });

  test('copyWith changes only what it is given', () {
    final f = TransactionFilter.none.copyWith(range: AmountRange.under100k);
    expect(f.type, TransactionTypeFilter.all);
    expect(f.range, AmountRange.under100k);
    expect(f.sort, TransactionSort.newest);
  });
}
