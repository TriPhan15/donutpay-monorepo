import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

/// Where a share of the month stands against its target (T9 spec 3.1, "Cân đối chi tiêu").
enum BalanceLevel { ok, high, low }

/// The one advice sentence of the old 50/30/20 card.
enum BalanceAdvice { onTrack, needsHigh, wantsHigh, savingsLow }

/// One row: a share of the month's income in whole percent, as shown, with its target.
class BalanceShare {
  const BalanceShare({
    required this.percent,
    required this.target,
    required this.level,
  });

  final int percent;
  final int target;
  final BalanceLevel level;
}

/// The month's income split into needs, wants and what was kept (the 50/30/20 rule). Levels are taken on the rounded
/// percent the user reads: needs above 50 and wants above 30 are a bit high, savings under 20 a bit low.
class SpendingBalance {
  static const int needsTarget = 50;
  static const int wantsTarget = 30;
  static const int savingsTarget = 20;

  const SpendingBalance({
    required this.needs,
    required this.wants,
    required this.savings,
    required this.advice,
    required this.advicePercent,
  });

  final BalanceShare needs;
  final BalanceShare wants;
  final BalanceShare savings;
  final BalanceAdvice advice;

  /// The percent the advice sentence quotes; 0 when on track.
  final int advicePercent;

  /// The expenses of [txs] counted as needs: those in an essential default category, matched by the name core-backend
  /// stores (TransactionCategories.essentialExpenses). Savings contributions never count.
  static double needsTotal(List<TransactionModel> txs) => txs
      .where(
        (t) =>
            t.countsAsSpending &&
            TransactionCategories.essentialExpenses.contains(t.category.trim()),
      )
      .fold(0, (s, t) => s + t.amount);

  /// Null when nothing came in. [spending] must already leave savings contributions out, so a contribution is neither
  /// a want nor a loss of saved money.
  static SpendingBalance? of(
    List<TransactionModel> monthTxs,
    double income,
    double spending,
  ) {
    if (income <= 0) return null;
    final needsRaw = needsTotal(monthTxs);
    final wantsRaw = spending - needsRaw;
    final needs = (needsRaw / income * 100).round();
    final wants = (wantsRaw / income * 100).round();
    final saved = ((income - spending) / income * 100).round();
    final needsLevel = needs > needsTarget
        ? BalanceLevel.high
        : BalanceLevel.ok;
    final wantsLevel = wants > wantsTarget
        ? BalanceLevel.high
        : BalanceLevel.ok;
    final savingsLevel = saved < savingsTarget
        ? BalanceLevel.low
        : BalanceLevel.ok;

    var advice = BalanceAdvice.onTrack;
    var percent = 0;
    if (needsLevel == BalanceLevel.high && needsRaw >= wantsRaw) {
      (advice, percent) = (BalanceAdvice.needsHigh, needs);
    } else if (wantsLevel == BalanceLevel.high) {
      (advice, percent) = (BalanceAdvice.wantsHigh, wants);
    } else if (savingsLevel == BalanceLevel.low) {
      (advice, percent) = (BalanceAdvice.savingsLow, saved);
    }
    return SpendingBalance(
      needs: BalanceShare(
        percent: needs,
        target: needsTarget,
        level: needsLevel,
      ),
      wants: BalanceShare(
        percent: wants,
        target: wantsTarget,
        level: wantsLevel,
      ),
      savings: BalanceShare(
        percent: saved,
        target: savingsTarget,
        level: savingsLevel,
      ),
      advice: advice,
      advicePercent: percent,
    );
  }
}
