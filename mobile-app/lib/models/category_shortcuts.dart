import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

/// The categories a transaction form offers as tiles (T9 spec, 3.3: three often used ones plus "Khác").
abstract final class CategoryShortcuts {
  static const int count = 3;

  /// Up to [count] names of [available] (server order), the ones used most often in [history] for the same type
  /// first; equal counts and unused categories keep the server order. Savings are never offered.
  static List<String> pick({
    required List<String> available,
    required Iterable<TransactionModel> history,
    required bool isExpense,
  }) {
    final offered = [
      for (final name in available)
        if (!TransactionCategories.isSavings(name)) name,
    ];
    final uses = <String, int>{};
    for (final tx in history) {
      if (tx.isExpense != isExpense || !tx.isNormal) continue;
      uses.update(tx.category, (n) => n + 1, ifAbsent: () => 1);
    }
    final order = {for (var i = 0; i < offered.length; i++) offered[i]: i};
    final ranked = [...offered]
      ..sort((a, b) {
        final byUse = (uses[b] ?? 0).compareTo(uses[a] ?? 0);
        return byUse != 0 ? byUse : order[a]!.compareTo(order[b]!);
      });
    return ranked.take(count).toList();
  }

  /// The selected category when it is not among [shortcuts]: it then takes the place of the "Khác" tile.
  static String? overflowOf(List<String> shortcuts, String? selected) =>
      selected == null || shortcuts.contains(selected) ? null : selected;
}
