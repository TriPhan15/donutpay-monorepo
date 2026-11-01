import 'package:finance_ai_app/models/transaction_model.dart';

/// The length of the period the statistics tab shows.
enum LedgerPeriod { week, month, year }

/// Income and spending of one day. Spending leaves out money moved into savings, as every spending total does.
class DayTotals {
  final double income;
  final double expense;

  const DayTotals({required this.income, required this.expense});
}

/// The spending of one category over a period.
class CategoryShare {
  final String category;
  final double amount;
  final int count;

  /// Share of the spending of the period, 0..100.
  final double percent;

  const CategoryShare({
    required this.category,
    required this.amount,
    required this.count,
    required this.percent,
  });
}

/// One group of bars of the statistics chart: a day of the week, or a month.
class ChartBucket {
  /// The day, or the first day of the month, the bucket covers.
  final DateTime start;
  final double income;
  final double expense;

  /// True for the bucket of the day or month on screen; the others are drawn faded.
  final bool isSelected;

  const ChartBucket({
    required this.start,
    required this.income,
    required this.expense,
    required this.isSelected,
  });
}

/// Consecutive transactions of the same day, with their totals.
class DayGroup {
  final DateTime day;
  final List<TransactionModel> transactions;
  final double income;
  final double expense;

  const DayGroup({
    required this.day,
    required this.transactions,
    required this.income,
    required this.expense,
  });
}

/// The figures of the statistics tab (T9 spec, 3.1), computed on the device.
abstract final class LedgerStats {
  static const int daysPerWeek = 7;
  static const int monthsPerYear = 12;

  /// The month chart shows the selected month and this many before it.
  static const int monthsBeforeSelected = 5;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static double _income(Iterable<TransactionModel> txs) =>
      txs.where((t) => !t.isExpense).fold(0.0, (s, t) => s + t.amount);

  static double _spending(Iterable<TransactionModel> txs) =>
      txs.where((t) => t.countsAsSpending).fold(0.0, (s, t) => s + t.amount);

  /// Income and spending per calendar day; days without any transaction are left out.
  static Map<DateTime, DayTotals> byDay(Iterable<TransactionModel> txs) {
    final byDay = <DateTime, List<TransactionModel>>{};
    for (final tx in txs) {
      byDay.putIfAbsent(_dayOf(tx.date), () => []).add(tx);
    }
    return byDay.map(
      (day, list) => MapEntry(
        day,
        DayTotals(income: _income(list), expense: _spending(list)),
      ),
    );
  }

  /// Income and spending of all of [txs] together (the spending leaves out money moved into savings).
  static DayTotals totals(Iterable<TransactionModel> txs) =>
      DayTotals(income: _income(txs), expense: _spending(txs));

  /// The spending of [txs] per category, the biggest first (equal amounts by name). Empty when nothing was spent.
  static List<CategoryShare> categoryShares(Iterable<TransactionModel> txs) {
    final spending = txs.where((t) => t.countsAsSpending).toList();
    final total = _spending(spending);
    if (total <= 0) return const [];
    final byCategory = <String, List<TransactionModel>>{};
    for (final tx in spending) {
      byCategory.putIfAbsent(tx.category, () => []).add(tx);
    }
    final shares = [
      for (final entry in byCategory.entries)
        CategoryShare(
          category: entry.key,
          amount: _spending(entry.value),
          count: entry.value.length,
          percent: _spending(entry.value) / total * 100,
        ),
    ];
    shares.sort(
      (a, b) => b.amount != a.amount
          ? b.amount.compareTo(a.amount)
          : a.category.compareTo(b.category),
    );
    return shares;
  }

  /// The first day (Monday) of the week of [day].
  static DateTime weekStart(DateTime day) =>
      _dayOf(day).subtract(Duration(days: day.weekday - DateTime.monday));

  /// The bars of the chart: the 7 days of the week of [anchor], the month of [anchor] and the 5 before it, or the 12
  /// months of its year. Measured over [all] transactions, whatever the period on screen.
  static List<ChartBucket> chartBuckets(
    LedgerPeriod period,
    DateTime anchor,
    Iterable<TransactionModel> all,
  ) {
    if (period == LedgerPeriod.week) {
      final start = weekStart(anchor);
      final totals = byDay(all);
      return [
        for (var i = 0; i < daysPerWeek; i++)
          _bucket(
            DateTime(start.year, start.month, start.day + i),
            totals,
            _dayOf(anchor),
          ),
      ];
    }
    final months = period == LedgerPeriod.year
        ? [for (var m = 1; m <= monthsPerYear; m++) DateTime(anchor.year, m)]
        : [
            for (var i = monthsBeforeSelected; i >= 0; i--)
              DateTime(anchor.year, anchor.month - i),
          ];
    final selected = DateTime(anchor.year, anchor.month);
    return [
      for (final month in months)
        () {
          final inMonth = all.where(
            (t) => t.date.year == month.year && t.date.month == month.month,
          );
          return ChartBucket(
            start: month,
            income: _income(inMonth),
            expense: _spending(inMonth),
            isSelected: month == selected,
          );
        }(),
    ];
  }

  static ChartBucket _bucket(
    DateTime day,
    Map<DateTime, DayTotals> totals,
    DateTime selected,
  ) => ChartBucket(
    start: day,
    income: totals[day]?.income ?? 0,
    expense: totals[day]?.expense ?? 0,
    isSelected: day == selected,
  );

  /// Splits [ordered] into runs of the same day, keeping the order it is given.
  static List<DayGroup> groupByDay(List<TransactionModel> ordered) {
    final groups = <DayGroup>[];
    var run = <TransactionModel>[];
    DateTime? runDay;
    void close() {
      if (runDay == null) return;
      groups.add(
        DayGroup(
          day: runDay,
          transactions: run,
          income: _income(run),
          expense: _spending(run),
        ),
      );
    }

    for (final tx in ordered) {
      final day = _dayOf(tx.date);
      if (day != runDay) {
        close();
        run = [];
        runDay = day;
      }
      run.add(tx);
    }
    close();
    return groups;
  }
}
