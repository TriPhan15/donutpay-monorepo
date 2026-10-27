import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/spending_analysis.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

/// Sections of the AI tab. Each builder takes the colour scheme that the calling screen read once in its build, and the
/// texts of the language on screen.
///
/// Amber marks the money-allocation advice, blue and orange the needs and wants of the 50/30/20 rule: identity
/// colours that stay the same in both themes, like chart series, and are bright enough on the dark surface.
class AiComponents {
  static const String _sequenceSeparator = ' → ';
  static const String _itemSeparator = '+';

  static String _money(AppLocalizations loc, double amount) =>
      CurrencyHelper.formatVND(amount, loc, showSign: amount < 0);

  /// A pattern of the AI service as the user reads it: "a+b → c", each category in the language of [loc].
  static String formatPattern(AppLocalizations loc, SpendingPattern pattern) =>
      pattern.itemsets
          .map(
            (step) => step
                .map(
                  (item) => TransactionCategories.displayName(loc, item.trim()),
                )
                .join(_itemSeparator),
          )
          .join(_sequenceSeparator);

  /// [hasError] is true when the last analysis failed; it replaces the "not enough data" message, which would be wrong then.
  static Widget buildSpadeSection(
    ColorScheme colors,
    AppLocalizations loc,
    SpendingAnalysis? analysis,
    bool isLoading, {
    bool hasError = false,
  }) {
    final spadePatterns = analysis?.patterns ?? const <SpendingPattern>[];
    // Made once for the whole list rather than once per pattern.
    final cardDecoration = BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
    );
    final indexDecoration = BoxDecoration(
      color: colors.primaryContainer,
      borderRadius: BorderRadius.circular(10),
    );
    final indexStyle = TextStyle(
      color: colors.onPrimaryContainer,
      fontWeight: FontWeight.bold,
      fontSize: 13,
    );
    final detailStyle = TextStyle(
      color: colors.primary,
      fontSize: 12,
      fontStyle: FontStyle.italic,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // The title wraps on a narrow phone; the badge keeps its size.
            Flexible(
              child: Text(
                loc.aiSpadeTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'WCM-SPADE',
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          loc.aiSpadeSubtitle,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (hasError)
          _buildSpadeMessageCard(
            colors,
            icon: Icons.cloud_off_rounded,
            title: loc.aiSpadeLoadFailedTitle,
            message: loc.aiSpadeLoadFailedMessage,
          )
        else if (spadePatterns.isEmpty)
          _buildSpadeEmptyCard(colors, loc, analysis)
        else
          ...List.generate(spadePatterns.length, (i) {
            final p = spadePatterns[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDecoration,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: indexDecoration,
                      child: Center(
                        child: Text('#${i + 1}', style: indexStyle),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatPattern(loc, p),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            loc.aiSpadeWeeksDetail(
                              p.support,
                              analysis?.weeksWithData ?? 0,
                            ),
                            style: detailStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  /// No pattern to list: either the history is too short (say how short), or it is long enough and nothing repeats.
  static Widget _buildSpadeEmptyCard(
    ColorScheme colors,
    AppLocalizations loc,
    SpendingAnalysis? analysis,
  ) {
    final enough = analysis?.status == SpendingAnalysisStatus.ok;
    if (enough) {
      return _buildSpadeMessageCard(
        colors,
        icon: Icons.auto_graph_rounded,
        title: loc.aiSpadeNoPatternTitle,
        message: loc.aiSpadeNoPatternMessage,
      );
    }
    final weeks = analysis?.weeksWithData ?? 0;
    final minWeeks = analysis?.minWeeks ?? 0;
    return _buildSpadeMessageCard(
      colors,
      icon: Icons.auto_graph_rounded,
      title: loc.aiSpadeNotEnoughTitle,
      message: minWeeks <= 0
          ? loc.aiSpadeNotEnoughUnknown
          : weeks == 0
          ? loc.aiSpadeNotEnoughNone
          : loc.aiSpadeNotEnoughWeeks(weeks, minWeeks),
    );
  }

  static Widget _buildSpadeMessageCard(
    ColorScheme colors, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: colors.onPrimaryContainer, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildBudgetAdviceSection(
    ColorScheme colors,
    AppLocalizations loc,
    Map<String, dynamic>? budgetAdvice,
    bool isLoading,
  ) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (budgetAdvice == null) return const SizedBox.shrink();

    final recs = (budgetAdvice['recommendations'] as List?) ?? [];
    final summary = budgetAdvice['summary']?.toString() ?? '';

    if (summary.isEmpty && recs.isEmpty) return const SizedBox.shrink();

    // A cut is shown in the error colour, a keep or a raise in the primary colour.
    final cutColor = colors.error;
    final keepColor = colors.primary;
    final amountsStyle = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: 13,
    );
    final reasonStyle = TextStyle(color: colors.onSurfaceVariant, fontSize: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // The title wraps on a narrow phone; the badge keeps its size.
            Flexible(
              child: Text(
                loc.aiAdviceTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'WCM-SPADE',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          loc.aiAdviceSubtitle,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (summary.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.tips_and_updates_rounded,
                  color: Colors.amber,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    summary,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        if (recs.isNotEmpty) const SizedBox(height: 12),
        ...recs.map((r) {
          final m = Map<String, dynamic>.from(r as Map);
          final isCut = ((m['delta'] as num?) ?? 0).toDouble() < 0;
          final accent = isCut ? cutColor : keepColor;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCut
                            ? Icons.trending_down_rounded
                            : Icons.trending_up_rounded,
                        color: accent,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${m['action']} · ${m['tag']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        CurrencyHelper.formatVND(
                          ((m['delta'] as num?) ?? 0).toDouble(),
                          loc,
                        ),
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    loc.aiAdvicePerMonth(
                      _money(loc, ((m['current'] as num?) ?? 0).toDouble()),
                      _money(loc, ((m['suggested'] as num?) ?? 0).toDouble()),
                    ),
                    style: amountsStyle,
                  ),
                  if ((m['reason']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(m['reason'].toString(), style: reasonStyle),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  static const int maxHabitAlerts = 3;
  static const int maxHabits = 5;

  /// 00:00 on the Monday of the ISO week of [day].
  static DateTime _weekStart(DateTime day) =>
      DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));

  static String _categories(AppLocalizations loc, List<String> names) => names
      .map((n) => TransactionCategories.displayName(loc, n.trim()))
      .join(_itemSeparator);

  /// "dd/MM", worked out by hand: it needs no date-format locale data.
  static String _dayMonth(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  static Widget _sectionHeader(
    ColorScheme colors,
    String title,
    String subtitle,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
      ),
      const SizedBox(height: 16),
    ],
  );

  /// The rules the server kept (enough weeks, enough confidence), at most [maxHabitAlerts]. A rule is "triggered" when
  /// every category of its antecedent was spent on in the week of [today] and none of its consequent yet; those come
  /// first. Each rule says how many weeks it held in, never "will".
  static Widget buildHabitAlertSection(
    ColorScheme colors,
    AppLocalizations loc,
    List<SpendingRule> rules,
    List<TransactionModel> transactions,
    DateTime today,
  ) {
    if (rules.isEmpty) return const SizedBox.shrink();

    final week = _weekStart(today);
    final spentThisWeek = transactions
        .where((t) => t.countsAsSpending && _weekStart(t.date) == week)
        .map((t) => t.category.trim())
        .toSet();
    bool triggered(SpendingRule r) =>
        r.antecedent.every((c) => spentThisWeek.contains(c.trim())) &&
        !r.consequent.any((c) => spentThisWeek.contains(c.trim()));

    // Two passes keep the server's order inside each group.
    final ordered = [
      ...rules.where(triggered),
      ...rules.where((r) => !triggered(r)),
    ].take(maxHabitAlerts);

    // Made once for all the cards rather than once per card.
    final decoration = BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
    );
    final headingStyle = TextStyle(
      color: colors.primary,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );
    final triggeredStyle = TextStyle(
      color: colors.primary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.4,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(colors, loc.aiGuardTitle, loc.aiGuardSubtitle),
        for (final r in ordered)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: decoration,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.psychology_alt_rounded,
                    color: colors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.aiGuardHeading, style: headingStyle),
                        const SizedBox(height: 6),
                        Text(
                          loc.aiGuardRule(
                            _categories(loc, r.antecedent),
                            _categories(loc, r.consequent),
                            r.support,
                            r.antecedentSupport,
                          ),
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                        if (triggered(r)) ...[
                          const SizedBox(height: 6),
                          Text(
                            loc.aiGuardTriggered(
                              _categories(loc, r.antecedent),
                              _categories(loc, r.consequent),
                            ),
                            style: triggeredStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// The categories that come back at a fairly regular interval (descriptive statistics, so shown even when there is too
  /// little history for sequences), at most [maxHabits]. A habit whose expected date is already past shows its last
  /// date instead of a date in the past.
  static Widget buildPeriodicHabitsSection(
    ColorScheme colors,
    AppLocalizations loc,
    List<PeriodicHabit> habits,
    DateTime today,
  ) {
    if (habits.isEmpty) return const SizedBox.shrink();

    final day = DateTime(today.year, today.month, today.day);
    final gap = NumberFormat.decimalPatternDigits(
      locale: loc.localeName,
      decimalDigits: 1,
    );
    final decoration = BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(colors, loc.aiHabitTitle, loc.aiHabitSubtitle),
        for (final h in habits.take(maxHabits))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: decoration,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.event_repeat_rounded, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      h.nextExpectedDate.isBefore(day)
                          ? loc.aiHabitLineLate(
                              TransactionCategories.displayName(
                                loc,
                                h.category,
                              ),
                              gap.format(h.meanGapDays),
                              _dayMonth(h.lastDate),
                            )
                          : loc.aiHabitLine(
                              TransactionCategories.displayName(
                                loc,
                                h.category,
                              ),
                              gap.format(h.meanGapDays),
                              _dayMonth(h.nextExpectedDate),
                            ),
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// The expenses of [txs] that the 50/30/20 card counts as needs: those in an essential default category, matched by
  /// the name core-backend stores (TransactionCategories.essentialExpenses).
  static double needsTotal(List<TransactionModel> txs) => txs
      .where(
        (t) =>
            t.countsAsSpending &&
            TransactionCategories.essentialExpenses.contains(t.category.trim()),
      )
      .fold(0, (s, t) => s + t.amount);

  /// The shares of [income], in percent, that went to needs, wants and what was kept. [spending] must already leave
  /// savings contributions out, so a contribution is neither a want nor a loss of saved money.
  static ({double needs, double wants, double save}) shares503020(
    List<TransactionModel> txs,
    double income,
    double spending,
  ) {
    final needs = needsTotal(txs);
    return (
      needs: needs / income * 100,
      wants: (spending - needs) / income * 100,
      save: (income - spending) / income * 100,
    );
  }

  static Widget build503020Card(
    ColorScheme colors,
    AppLocalizations loc,
    List<TransactionModel> monthTxs,
    double monthIncome,
    double monthExpense,
  ) {
    if (monthIncome <= 0) return const SizedBox.shrink();

    final shares = shares503020(monthTxs, monthIncome, monthExpense);
    final needsPct = shares.needs,
        wantsPct = shares.wants,
        savePct = shares.save;

    // Past its target, a share turns to the error colour; the track is the neutral container colour.
    Widget row(
      String lbl,
      double pct,
      double target,
      Color c, {
      bool atLeast = false,
    }) {
      final over = atLeast ? pct < target : pct > target;
      final color = over ? colors.error : c;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(lbl, style: const TextStyle(fontSize: 13)),
                ),
                Text(
                  '${pct.toStringAsFixed(0)}% / ${atLeast ? '≥' : '≤'}${target.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: colors.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      );
    }

    String advice = loc.ai503020OnTrack;
    if (needsPct > 50 && needsPct >= wantsPct) {
      advice = loc.ai503020NeedsHigh(needsPct.toStringAsFixed(0));
    } else if (wantsPct > 30) {
      advice = loc.ai503020WantsHigh(wantsPct.toStringAsFixed(0));
    } else if (savePct < 20) {
      advice = loc.ai503020SavingsLow(savePct.toStringAsFixed(0));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.ai503020Title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            loc.ai503020Groups,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 12),
          row(loc.ai503020Needs, needsPct, 50, Colors.blueAccent),
          row(loc.ai503020Wants, wantsPct, 30, Colors.orangeAccent),
          row(loc.ai503020Savings, savePct, 20, colors.primary, atLeast: true),
          const SizedBox(height: 2),
          Text(
            advice,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
