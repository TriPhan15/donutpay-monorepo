import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/spending_group_colors.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/spending_balance.dart';
import 'package:finance_ai_app/screens/ai/widgets/ai_section.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';

/// "Cân đối chi tiêu" (T9 spec 3.1, YNAB style): needs, wants and savings as shares of the month's income, each with
/// Ổn / Hơi cao / Hơi thấp, then one soft box that holds the 50/30/20 advice and the budget advisor's suggestions for
/// the savings goal. Nothing at all when there is neither income nor advice.
class AiBalanceCard extends StatelessWidget {
  const AiBalanceCard({
    super.key,
    required this.balance,
    required this.advice,
    required this.adviceLoading,
  });

  final SpendingBalance? balance;

  /// The answer of the budget advisor: a summary and a list of recommendations, either may be missing.
  final Map<String, dynamic>? advice;
  final bool adviceLoading;

  static String levelLabel(AppLocalizations loc, BalanceLevel level) =>
      switch (level) {
        BalanceLevel.ok => loc.aiLevelOk,
        BalanceLevel.high => loc.aiLevelHigh,
        BalanceLevel.low => loc.aiLevelLow,
      };

  static String adviceText(AppLocalizations loc, SpendingBalance b) {
    final percent = '${b.advicePercent}';
    return switch (b.advice) {
      BalanceAdvice.onTrack => loc.ai503020OnTrack,
      BalanceAdvice.needsHigh => loc.ai503020NeedsHigh(percent),
      BalanceAdvice.wantsHigh => loc.ai503020WantsHigh(percent),
      BalanceAdvice.savingsLow => loc.ai503020SavingsLow(percent),
    };
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final b = balance;
    final summary = advice?['summary']?.toString() ?? '';
    final recs = [
      for (final r in (advice?['recommendations'] as List?) ?? const [])
        if (r is Map) Map<String, dynamic>.from(r),
    ];
    final adviceLines = [
      if (b != null) Text(adviceText(loc, b)),
      if (adviceLoading)
        const Align(
          alignment: Alignment.centerLeft,
          child: AppStateView.loading(),
        )
      else ...[
        if (summary.isNotEmpty) Text(summary),
        for (final r in recs) Text(_recommendation(loc, r)),
      ],
    ];
    if (b == null && adviceLines.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AiSectionHeader(title: loc.aiBalanceTitle),
        if (b != null)
          AiCard(
            children: [
              _row(
                context,
                loc.ai503020Needs,
                b.needs,
                SpendingGroupColors.needs(context),
              ),
              _row(
                context,
                loc.ai503020Wants,
                b.wants,
                SpendingGroupColors.wants,
              ),
              _row(
                context,
                loc.aiBalanceSavings,
                b.savings,
                SpendingGroupColors.savings(context),
              ),
            ],
          ),
        if (adviceLines.isNotEmpty)
          AiSoftBox(icon: Icons.info_outline_rounded, children: adviceLines),
      ],
    );
  }

  static String _recommendation(AppLocalizations loc, Map<String, dynamic> r) {
    double amount(String key) => ((r[key] as num?) ?? 0).toDouble();
    return loc.aiAdviceLine(
      TransactionCategories.displayName(
        loc,
        (r['tag'] ?? '').toString().trim(),
      ),
      CurrencyHelper.formatCompactVND(amount('current'), loc),
      CurrencyHelper.formatCompactVND(amount('suggested'), loc),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    BalanceShare share,
    Color color,
  ) {
    final loc = context.loc;
    return AiListRow(
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      title: label,
      subtitle: loc.aiBalanceLine(share.percent, share.target),
      trailing: AiValuePill(
        label: levelLabel(loc, share.level),
        tone: share.level == BalanceLevel.ok
            ? AiPillTone.good
            : AiPillTone.warning,
      ),
    );
  }
}
