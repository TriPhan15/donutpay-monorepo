import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/category_colors.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/spending_analysis.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/screens/ai/widgets/ai_section.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';

/// "Thói quen chi tiêu" (T9 spec 3.1): the sequences that come back week after week, each with the icons of its
/// categories and how many weeks it came back in, then the expenses that return at a regular interval. A soft box
/// under the card says what usually comes next. No algorithm name or technical figure is shown (spec 5).
class AiHabitsCard extends StatelessWidget {
  const AiHabitsCard({
    super.key,
    required this.analysis,
    required this.isLoading,
    required this.hasError,
    required this.transactions,
    required this.today,
    required this.onRetry,
  });

  static const int maxPatterns = 3;
  static const int maxPeriodic = 2;
  static const int _maxStackIcons = 3;
  static const String _sequenceSeparator = ' → ';
  static const String _itemSeparator = '+';

  final SpendingAnalysis? analysis;
  final bool isLoading;

  /// True when the last analysis failed; it replaces the "not enough data" message, which would be wrong then.
  final bool hasError;
  final List<TransactionModel> transactions;
  final DateTime today;
  final VoidCallback onRetry;

  /// A pattern as the user reads it: "a+b → c", each category in the language of [loc].
  static String formatPattern(AppLocalizations loc, SpendingPattern pattern) =>
      pattern.itemsets
          .map((step) => _categories(loc, step))
          .join(_sequenceSeparator);

  static String _categories(AppLocalizations loc, List<String> names) => names
      .map((n) => TransactionCategories.displayName(loc, n.trim()))
      .join(_itemSeparator);

  /// 00:00 on the Monday of the ISO week of [day].
  static DateTime _weekStart(DateTime day) =>
      DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));

  /// The rule to tell about: the first one under way this week (every category of its antecedent spent on in the week
  /// of [today], none of its consequent yet), else the first one the server kept. Null without rules.
  static ({SpendingRule rule, bool upcoming})? nextRule(
    List<SpendingRule> rules,
    List<TransactionModel> transactions,
    DateTime today,
  ) {
    if (rules.isEmpty) return null;
    final week = _weekStart(today);
    final spentThisWeek = transactions
        .where((t) => t.countsAsSpending && _weekStart(t.date) == week)
        .map((t) => t.category.trim())
        .toSet();
    bool underWay(SpendingRule r) =>
        r.antecedent.every((c) => spentThisWeek.contains(c.trim())) &&
        !r.consequent.any((c) => spentThisWeek.contains(c.trim()));
    for (final r in rules) {
      if (underWay(r)) return (rule: r, upcoming: true);
    }
    return (rule: rules.first, upcoming: false);
  }

  /// "dd/MM", worked out by hand: it needs no date-format locale data.
  static String _dayMonth(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AiSectionHeader(title: loc.aiHabitsTitle),
        ..._body(context, loc),
      ],
    );
  }

  List<Widget> _body(BuildContext context, AppLocalizations loc) {
    if (isLoading) {
      return const [
        AiCard(children: [AppStateView.loading()]),
      ];
    }
    if (hasError) {
      return [
        AiCard(
          children: [
            AppStateView.error(
              title: loc.aiSpadeLoadFailedTitle,
              message: loc.aiSpadeLoadFailedMessage,
              onRetry: onRetry,
            ),
          ],
        ),
      ];
    }
    final a = analysis;
    final patterns = (a?.patterns ?? const <SpendingPattern>[]).take(
      maxPatterns,
    );
    final periodic = (a?.habits ?? const <PeriodicHabit>[]).take(maxPeriodic);
    final next = nextRule(
      a?.rules ?? const <SpendingRule>[],
      transactions,
      today,
    );
    final rows = [
      for (final p in patterns) _patternRow(context, loc, p, a!.weeksWithData),
      for (final h in periodic) _periodicRow(context, loc, h),
    ];
    return [
      AiCard(children: rows.isEmpty ? [_emptyState(loc, a)] : rows),
      if (next != null)
        AiSoftBox(
          icon: Icons.lightbulb_outline_rounded,
          children: [
            Text(
              next.upcoming
                  ? loc.aiHabitUpcoming(
                      _categories(loc, next.rule.antecedent),
                      _categories(loc, next.rule.consequent),
                    )
                  : loc.aiHabitUsually(
                      _categories(loc, next.rule.antecedent),
                      _categories(loc, next.rule.consequent),
                    ),
            ),
          ],
        ),
    ];
  }

  /// Nothing to list: either the history is too short (say how short), or it is long enough and nothing repeats.
  Widget _emptyState(AppLocalizations loc, SpendingAnalysis? analysis) {
    if (analysis?.status == SpendingAnalysisStatus.ok) {
      return AppStateView.empty(
        icon: Icons.auto_graph_rounded,
        title: loc.aiSpadeNoPatternTitle,
        message: loc.aiSpadeNoPatternMessage,
      );
    }
    final weeks = analysis?.weeksWithData ?? 0;
    final minWeeks = analysis?.minWeeks ?? 0;
    return AppStateView.empty(
      icon: Icons.auto_graph_rounded,
      title: loc.aiSpadeNotEnoughTitle,
      message: minWeeks <= 0
          ? loc.aiSpadeNotEnoughUnknown
          : weeks == 0
          ? loc.aiSpadeNotEnoughNone
          : loc.aiSpadeNotEnoughWeeks(weeks, minWeeks),
    );
  }

  Widget _patternRow(
    BuildContext context,
    AppLocalizations loc,
    SpendingPattern p,
    int weeksWithData,
  ) {
    final categories = <String>{
      for (final step in p.itemsets)
        for (final c in step) c.trim(),
    }.take(_maxStackIcons).toList();
    return AiListRow(
      leading: _IconStack(categories: categories),
      title: formatPattern(loc, p),
      subtitle: weeksWithData > 0 ? loc.aiHabitRepeat(weeksWithData) : null,
      trailing: AiValuePill(
        label: loc.aiTimes(p.support),
        tone: AiPillTone.neutral,
      ),
    );
  }

  Widget _periodicRow(
    BuildContext context,
    AppLocalizations loc,
    PeriodicHabit h,
  ) {
    final day = DateTime(today.year, today.month, today.day);
    final gap = NumberFormat.decimalPatternDigits(
      locale: loc.localeName,
      decimalDigits: 1,
    );
    final late = h.nextExpectedDate.isBefore(day);
    return AiListRow(
      leading: AiIconTile(
        icon: TransactionCategories.iconFor(h.category),
        color: CategoryColors.accentFor(
          h.category,
          Theme.of(context).colorScheme,
        ),
      ),
      title: TransactionCategories.displayName(loc, h.category),
      subtitle: loc.aiHabitEvery(gap.format(h.meanGapDays)),
      trailing: AiValuePill(
        label: late
            ? loc.aiHabitLastOn(_dayMonth(h.lastDate))
            : _dayMonth(h.nextExpectedDate),
        tone: AiPillTone.neutral,
      ),
    );
  }
}

/// The icons of a sequence's categories, overlapping like a stack of avatars.
class _IconStack extends StatelessWidget {
  const _IconStack({required this.categories});

  static const double _size = 30;
  static const double _overlap = 8;

  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: _size + (categories.length - 1) * (_size - _overlap),
      height: _size,
      child: Stack(
        children: [
          for (var i = 0; i < categories.length; i++)
            Positioned(
              left: i * (_size - _overlap),
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  // An opaque base under the pale tile, so the icon below does not show through.
                  color: scheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: _tile(scheme, theme.brightness, categories[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(ColorScheme scheme, Brightness brightness, String category) {
    final accent = CategoryColors.accentFor(category, scheme);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CategoryColors.tileFor(accent, brightness),
        shape: BoxShape.circle,
      ),
      child: Icon(
        TransactionCategories.iconFor(category),
        color: accent,
        size: 14,
      ),
    );
  }
}
