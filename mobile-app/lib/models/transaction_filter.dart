import 'package:finance_ai_app/models/transaction_model.dart';

/// Which direction of money the statistics list keeps.
enum TransactionTypeFilter { all, expense, income }

/// The amount ranges of the filter sheet (T9 spec, 3.4). They meet at [TransactionFilter.lowLimit] and
/// [TransactionFilter.highLimit] without overlapping.
enum AmountRange { any, under100k, from100kTo500k, over500k }

/// The orders of the filter sheet.
enum TransactionSort { newest, oldest, largest }

/// What the "Lọc" sheet chose: a direction, an amount range and an order. Applies only to the transaction list of the
/// statistics tab, never to its totals.
class TransactionFilter {
  /// Below this amount a transaction is "<100k".
  static const double lowLimit = 100000;

  /// Above this amount a transaction is ">500k".
  static const double highLimit = 500000;

  static const TransactionFilter none = TransactionFilter();

  final TransactionTypeFilter type;
  final AmountRange range;
  final TransactionSort sort;

  const TransactionFilter({
    this.type = TransactionTypeFilter.all,
    this.range = AmountRange.any,
    this.sort = TransactionSort.newest,
  });

  /// True when the filter hides something; the order alone hides nothing.
  bool get isActive =>
      type != TransactionTypeFilter.all || range != AmountRange.any;

  bool matches(TransactionModel tx) => _matchesType(tx) && _matchesRange(tx);

  bool _matchesType(TransactionModel tx) => switch (type) {
    TransactionTypeFilter.all => true,
    TransactionTypeFilter.expense => tx.isExpense,
    TransactionTypeFilter.income => !tx.isExpense,
  };

  bool _matchesRange(TransactionModel tx) => switch (range) {
    AmountRange.any => true,
    AmountRange.under100k => tx.amount < lowLimit,
    AmountRange.from100kTo500k =>
      tx.amount >= lowLimit && tx.amount <= highLimit,
    AmountRange.over500k => tx.amount > highLimit,
  };

  /// The transactions of [txs] that match, in the chosen order, as a new list.
  List<TransactionModel> apply(Iterable<TransactionModel> txs) {
    final list = txs.where(matches).toList();
    list.sort(_compare);
    return list;
  }

  int _compare(TransactionModel a, TransactionModel b) => switch (sort) {
    TransactionSort.newest => b.date.compareTo(a.date),
    TransactionSort.oldest => a.date.compareTo(b.date),
    // Equal amounts: the newer one first.
    TransactionSort.largest =>
      b.amount != a.amount
          ? b.amount.compareTo(a.amount)
          : b.date.compareTo(a.date),
  };

  TransactionFilter copyWith({
    TransactionTypeFilter? type,
    AmountRange? range,
    TransactionSort? sort,
  }) => TransactionFilter(
    type: type ?? this.type,
    range: range ?? this.range,
    sort: sort ?? this.sort,
  );

  @override
  bool operator ==(Object other) =>
      other is TransactionFilter &&
      other.type == type &&
      other.range == range &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(type, range, sort);
}
