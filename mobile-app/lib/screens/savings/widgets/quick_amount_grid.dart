import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/contribution_plan.dart';

/// The quick amounts of the "Góp tiền" sheet in a 4 × 2 grid (T9 spec 3.6, mockups G1 + S1). The tile equal to
/// [selected] is outlined in the primary colour; the [suggested] one carries a small green "Gợi ý" badge.
class QuickAmountGrid extends StatelessWidget {
  const QuickAmountGrid({
    super.key,
    required this.selected,
    required this.suggested,
    required this.onSelected,
  });

  static Key tileKey(double amount) =>
      ValueKey('quick-amount-${amount.round()}');
  static const Key badgeKey = ValueKey('quick-amount-badge');

  static const int columns = 4;
  static const double _gap = 8;

  /// Room above the first row, so the badge of a top tile is not cut off.
  static const double _badgeRoom = 8;

  final double? selected;
  final double? suggested;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    const amounts = ContributionSuggestion.quickAmounts;
    return Padding(
      padding: const EdgeInsets.only(top: _badgeRoom),
      child: Column(
        children: [
          for (var row = 0; row < amounts.length; row += columns) ...[
            if (row > 0) const SizedBox(height: _gap + _badgeRoom),
            Row(
              children: [
                for (var i = row; i < row + columns; i++) ...[
                  if (i > row) const SizedBox(width: _gap),
                  Expanded(
                    child: _Tile(
                      amount: amounts[i],
                      selected: amounts[i] == selected,
                      suggested: amounts[i] == suggested,
                      onTap: () => onSelected(amounts[i]),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.amount,
    required this.selected,
    required this.suggested,
    required this.onTap,
  });

  static const double _height = 40;
  static const double _radius = 12;
  static const double _border = 1.5;

  final double amount;
  final bool selected;
  final bool suggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_radius),
      side: BorderSide(
        color: selected ? colors.primary : colors.outlineVariant,
        width: _border,
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: selected ? colors.primaryContainer : colors.surface,
          shape: shape,
          child: InkWell(
            key: QuickAmountGrid.tileKey(amount),
            customBorder: shape,
            onTap: onTap,
            child: SizedBox(
              height: _height,
              child: Center(
                child: Text(
                  CurrencyHelper.formatCompactVND(amount, loc),
                  maxLines: 1,
                  style: TextStyle(
                    color: selected ? colors.primary : colors.onSurface,
                    fontSize: AppTextSize.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (suggested)
          Positioned(
            top: -9,
            right: -4,
            child: Container(
              key: QuickAmountGrid.badgeKey,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: theme.semanticColors.successColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                loc.savingsSuggestedBadge,
                style: TextStyle(
                  color: colors.surface,
                  fontSize: AppTextSize.caption,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
