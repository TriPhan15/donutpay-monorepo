import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/models/ledger_stats.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

TransactionModel _tx(
  double amount,
  DateTime date, {
  bool isExpense = true,
  String category = 'Ăn uống',
  String title = 'x',
}) => TransactionModel(
  title: title,
  amount: amount,
  date: date,
  category: category,
  isExpense: isExpense,
);

void main() {
  test(
    'byDay adds income and spending per calendar day, savings transfers left out',
    () {
      final totals = LedgerStats.byDay([
        _tx(55000, DateTime(2026, 10, 20, 8, 15)),
        _tx(42000, DateTime(2026, 10, 20, 7, 40)),
        _tx(18500000, DateTime(2026, 10, 19, 9), isExpense: false),
        _tx(
          1000000,
          DateTime(2026, 10, 19, 10),
          category: TransactionCategories.savings,
        ),
      ]);
      expect(totals[DateTime(2026, 10, 20)]!.expense, 97000);
      expect(totals[DateTime(2026, 10, 20)]!.income, 0);
      expect(totals[DateTime(2026, 10, 19)]!.income, 18500000);
      expect(totals[DateTime(2026, 10, 19)]!.expense, 0);
      expect(totals.containsKey(DateTime(2026, 10, 18)), isFalse);
    },
  );

  test(
    'categoryShares: percent of spending, count, biggest first, ties by name',
    () {
      final day = DateTime(2026, 10, 10);
      final shares = LedgerStats.categoryShares([
        for (var i = 0; i < 38; i++) _tx(2450000 / 38, day),
        _tx(1900000, day, category: 'Mua sắm'),
        _tx(820000, day, category: 'Di chuyển'),
        _tx(425000, day, category: 'Hóa đơn'),
        _tx(425000, day, category: 'Giải trí'),
        _tx(9000000, day, isExpense: false, category: 'Lương'),
        _tx(500000, day, category: TransactionCategories.savings),
      ]);
      expect(shares.map((s) => s.category), [
        'Ăn uống',
        'Mua sắm',
        'Di chuyển',
        'Giải trí',
        'Hóa đơn',
      ]);
      expect(shares.first.count, 38);
      expect(shares.first.amount, closeTo(2450000, 0.01));
      expect(shares.first.percent, closeTo(2450000 / 6020000 * 100, 0.01));
      expect(
        shares.fold<double>(0, (s, c) => s + c.percent),
        closeTo(100, 0.01),
      );
    },
  );

  test('no spending gives an empty list, not a division by zero', () {
    expect(LedgerStats.categoryShares(const []), isEmpty);
    expect(
      LedgerStats.categoryShares([
        _tx(10, DateTime(2026, 10, 1), isExpense: false),
      ]),
      isEmpty,
    );
  });

  test('week buckets are Monday to Sunday, the day of the anchor selected', () {
    final buckets =
        LedgerStats.chartBuckets(LedgerPeriod.week, DateTime(2026, 10, 28), [
          _tx(30000, DateTime(2026, 10, 26, 12)),
          _tx(70000, DateTime(2026, 11, 1, 23)),
          _tx(5000, DateTime(2026, 11, 2)),
        ]);
    expect(buckets, hasLength(7));
    expect(buckets.first.start, DateTime(2026, 10, 26));
    expect(buckets.last.start, DateTime(2026, 11, 1));
    expect(buckets.first.expense, 30000);
    expect(buckets.last.expense, 70000);
    expect(
      buckets.where((b) => b.isSelected).single.start,
      DateTime(2026, 10, 28),
    );
  });

  test('week of 29/12/2026 runs into January 2027', () {
    final buckets = LedgerStats.chartBuckets(
      LedgerPeriod.week,
      DateTime(2026, 12, 29),
      const [],
    );
    expect(buckets, hasLength(7));
    expect(buckets.first.start, DateTime(2026, 12, 28));
    expect(buckets.last.start, DateTime(2027, 1, 3));
  });

  test('month buckets are the anchor month and the five before', () {
    final buckets = LedgerStats.chartBuckets(
      LedgerPeriod.month,
      DateTime(2026, 10, 31),
      [
        _tx(100, DateTime(2026, 5, 31)),
        _tx(200, DateTime(2026, 10, 1), isExpense: false),
      ],
    );
    expect(buckets.map((b) => b.start), [
      for (var m = 5; m <= 10; m++) DateTime(2026, m),
    ]);
    expect(buckets.first.expense, 100);
    expect(buckets.last.income, 200);
    expect(buckets.last.isSelected, isTrue);
    expect(buckets.where((b) => b.isSelected), hasLength(1));
  });

  test('year buckets are its twelve months', () {
    final buckets = LedgerStats.chartBuckets(
      LedgerPeriod.year,
      DateTime(2026, 3, 15),
      [_tx(100, DateTime(2025, 12, 31)), _tx(40, DateTime(2026, 12, 31))],
    );
    expect(buckets, hasLength(12));
    expect(buckets.first.start, DateTime(2026, 1));
    expect(buckets.last.expense, 40);
    expect(buckets.first.expense, 0);
    expect(buckets.where((b) => b.isSelected).single.start, DateTime(2026, 3));
  });

  test('groupByDay keeps the order and totals each day', () {
    final groups = LedgerStats.groupByDay([
      _tx(55000, DateTime(2026, 10, 20, 8), title: 'a'),
      _tx(42000, DateTime(2026, 10, 20, 7), title: 'b'),
      _tx(18500000, DateTime(2026, 10, 19, 9), isExpense: false, title: 'c'),
      _tx(10000, DateTime(2026, 10, 20, 6), title: 'd'),
    ]);
    expect(groups.map((g) => g.day), [
      DateTime(2026, 10, 20),
      DateTime(2026, 10, 19),
      DateTime(2026, 10, 20),
    ]);
    expect(groups.first.transactions.map((t) => t.title), ['a', 'b']);
    expect(groups.first.expense, 97000);
    expect(groups[1].income, 18500000);
  });

  test(
    'totals adds all income and all spending, savings transfers left out',
    () {
      final totals = LedgerStats.totals([
        _tx(55000, DateTime(2026, 10, 20)),
        _tx(42000, DateTime(2026, 10, 3)),
        _tx(18500000, DateTime(2026, 10, 19), isExpense: false),
        _tx(
          1000000,
          DateTime(2026, 10, 19),
          category: TransactionCategories.savings,
        ),
      ]);
      expect(totals.expense, 97000);
      expect(totals.income, 18500000);
      expect(LedgerStats.totals(const []).expense, 0);
    },
  );
}
