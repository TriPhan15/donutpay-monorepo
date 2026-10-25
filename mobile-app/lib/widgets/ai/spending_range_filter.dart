import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/spending_range.dart';

/// The time filter above the spending chart: which period the report covers, the days that period spans, and a button
/// that runs the analysis again. It only reports what the user tapped; the screen keeps the state and calls the API.
class SpendingRangeFilter extends StatelessWidget {
  static const double _optionSpacing = 8;
  static const double _refreshIconSize = 18;

  const SpendingRangeFilter({
    super.key,
    required this.range,
    required this.isRefreshing,
    required this.onPeriodSelected,
    required this.onRefresh,
  });

  /// The range on screen; its period is the selected option and its dates are shown under the options.
  final SpendingRange range;

  /// True while the analysis runs: the refresh button then shows a spinner and cannot be pressed.
  final bool isRefreshing;

  /// Called with the option the user tapped, also when it is the one already selected (the screen decides what that
  /// means: for [SpendingPeriod.custom] it opens the date picker again).
  final ValueChanged<SpendingPeriod> onPeriodSelected;

  final VoidCallback onRefresh;

  static String _labelOf(AppLocalizations loc, SpendingPeriod period) =>
      switch (period) {
        SpendingPeriod.week => loc.periodThisWeek,
        SpendingPeriod.month => loc.periodThisMonth,
        SpendingPeriod.custom => loc.periodCustom,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.locOrDefault;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: _optionSpacing,
          runSpacing: _optionSpacing,
          children: [
            for (final period in SpendingPeriod.values)
              _buildOption(colors, loc, period),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                range.label,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ),
            _buildRefreshButton(loc),
          ],
        ),
      ],
    );
  }

  /// Selected: a tonal chip framed in the primary colour. Not selected: a surface chip with a neutral border.
  Widget _buildOption(
    ColorScheme colors,
    AppLocalizations loc,
    SpendingPeriod period,
  ) {
    final selected = range.period == period;
    return ChoiceChip(
      label: Text(_labelOf(loc, period)),
      selected: selected,
      onSelected: (_) => onPeriodSelected(period),
      showCheckmark: false,
      selectedColor: colors.primaryContainer,
      backgroundColor: colors.surface,
      side: BorderSide(
        color: selected ? colors.primary : colors.outlineVariant,
      ),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// A text button: the label, the icon and the spinner take the primary colour of the theme.
  Widget _buildRefreshButton(AppLocalizations loc) {
    return TextButton(
      onPressed: isRefreshing ? null : onRefresh,
      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isRefreshing
              ? const SizedBox(
                  width: _refreshIconSize,
                  height: _refreshIconSize,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: _refreshIconSize),
          const SizedBox(width: 6),
          Text(
            loc.commonRefresh,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
