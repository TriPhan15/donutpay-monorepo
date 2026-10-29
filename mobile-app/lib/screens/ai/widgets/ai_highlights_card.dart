import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/spending_highlights.dart';
import 'package:finance_ai_app/screens/ai/widgets/ai_section.dart';

/// "Điểm nổi bật" (T9 spec 3.1): four remarks and the top week of the month, one row each, the value in a pill on
/// the right.
class AiHighlightsCard extends StatelessWidget {
  const AiHighlightsCard({super.key, required this.highlights});

  final SpendingHighlights highlights;

  static AiPillTone toneOf(HighlightTone tone) => switch (tone) {
    HighlightTone.good => AiPillTone.good,
    HighlightTone.attention => AiPillTone.attention,
    HighlightTone.neutral => AiPillTone.neutral,
  };

  /// [amount] shortened ("2,45 tr"), with a + in front when above zero.
  static String signedCompact(AppLocalizations loc, double amount) {
    final text = CurrencyHelper.formatCompactVND(amount, loc);
    return amount > 0 ? '+$text' : text;
  }

  static String signedPercent(double percent) {
    final rounded = percent.round();
    return rounded > 0 ? '+$rounded%' : '$rounded%';
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final h = highlights;
    String compact(double v) => CurrencyHelper.formatCompactVND(v, loc);
    Widget pill(String label, HighlightTone tone) =>
        AiValuePill(label: label, tone: toneOf(tone));

    final trendPercent = h.trend.percent;
    final top = h.topCategory;
    final week = h.week;
    final weekEmpty = week.thisWeek == 0 && week.lastWeek == 0;
    final topWeek = h.topWeek;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AiSectionHeader(title: loc.aiHighlightsTitle),
        AiCard(
          children: [
            AiListRow(
              leading: AiIconTile(
                icon: (trendPercent ?? 0) > 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
              ),
              title: loc.aiTrendTitle,
              subtitle: trendPercent == null
                  ? loc.aiSpentThisMonth(compact(h.trend.thisMonth))
                  : loc.aiTrendVsLastMonth,
              trailing: trendPercent == null
                  ? null
                  : pill(signedPercent(trendPercent), h.trend.tone),
            ),
            AiListRow(
              leading: const AiIconTile(
                icon: Icons.local_fire_department_rounded,
              ),
              title: loc.aiTopCategoryTitle,
              subtitle: top == null
                  ? loc.aiNoSpendingThisMonth
                  : loc.aiTopCategoryLine(
                      TransactionCategories.displayName(loc, top.category),
                      compact(top.amount),
                    ),
              trailing: top == null
                  ? null
                  : pill('${top.share.round()}%', top.tone),
            ),
            AiListRow(
              leading: const AiIconTile(icon: Icons.lightbulb_outline_rounded),
              title: loc.aiSavingTipTitle,
              subtitle: _tipText(loc, h.tip),
              trailing: _tipPill(loc, h.tip),
            ),
            AiListRow(
              leading: const AiIconTile(icon: Icons.balance_rounded),
              title: loc.aiWeekCompareTitle,
              subtitle: weekEmpty
                  ? loc.aiWeekCompareNone
                  : loc.aiWeekCompareLine(
                      compact(week.thisWeek),
                      compact(week.lastWeek),
                    ),
              trailing: weekEmpty
                  ? null
                  : pill(signedCompact(loc, week.difference), week.tone),
            ),
            AiListRow(
              leading: const AiIconTile(icon: Icons.date_range_rounded),
              title: loc.aiTopWeekTitle,
              subtitle: topWeek == null
                  ? loc.aiNoSpendingThisMonth
                  : loc.aiTopWeekLine(topWeek.week),
              trailing: topWeek == null
                  ? null
                  : pill(compact(topWeek.amount), HighlightTone.neutral),
            ),
          ],
        ),
      ],
    );
  }

  static String _tipText(AppLocalizations loc, SavingTip tip) =>
      switch (tip.kind) {
        SavingTipKind.surplus => loc.aiTipSurplus,
        SavingTipKind.addGoal => loc.aiAddGoal,
        SavingTipKind.onTrack => loc.aiTipOnTrack,
        SavingTipKind.needMore => loc.aiTipNeedMore,
        SavingTipKind.overspent => loc.aiTipOverspent,
        SavingTipKind.noDeadline => loc.aiGoalNoDeadline,
        SavingTipKind.overdue => loc.aiGoalOverdue,
      };

  static Widget? _tipPill(AppLocalizations loc, SavingTip tip) {
    final tone = tip.tone;
    if (tone == null) return null;
    final label = switch (tip.kind) {
      SavingTipKind.surplus => signedCompact(loc, tip.amount),
      SavingTipKind.needMore => CurrencyHelper.formatCompactVND(
        tip.amount,
        loc,
      ),
      _ => loc.aiLevelOk,
    };
    return AiValuePill(label: label, tone: toneOf(tone));
  }
}
