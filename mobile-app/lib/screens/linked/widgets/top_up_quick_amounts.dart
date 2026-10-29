import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/top_up_amount.dart';

/// The four quick amounts of the "Đồng bộ tiền" sheet in one row (T9 spec 3.9: 50k / 100k / 200k / 500k). The chip
/// equal to [selected] is filled with the primary container and outlined in the primary colour.
class TopUpQuickAmounts extends StatelessWidget {
  const TopUpQuickAmounts({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  static Key chipKey(double amount) => ValueKey('top-up-${amount.round()}');

  static const double _gap = 8;

  final double? selected;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    const amounts = TopUpAmount.quickAmounts;
    return Row(
      children: [
        for (var i = 0; i < amounts.length; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          Expanded(
            child: _Chip(
              key: chipKey(amounts[i]),
              amount: amounts[i],
              selected: amounts[i] == selected,
              onTap: () => onSelected(amounts[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  static const double _height = 40;
  static const double _radius = 12;
  static const double _border = 1.5;

  final double amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_radius),
      side: BorderSide(
        color: selected ? colors.primary : colors.outlineVariant,
        width: _border,
      ),
    );
    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: SizedBox(
          height: _height,
          child: Center(
            child: Text(
              CurrencyHelper.formatCompactVND(amount, context.loc),
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
    );
  }
}
