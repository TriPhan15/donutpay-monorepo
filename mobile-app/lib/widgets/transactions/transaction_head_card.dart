import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/category_colors.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

/// The head card of a transaction (T9 spec, 3.3 and 3.4): its category icon, its name and the amount in large type,
/// with an optional [footer] under the amount.
class TransactionHeadCard extends StatelessWidget {
  const TransactionHeadCard({
    super.key,
    required this.transaction,
    this.footer,
  });

  static const double _padding = 16;
  static const double _radius = 20;
  static const double _tileSize = 48;
  static const double _tileRadius = 13;
  static const double _iconSize = 24;

  final TransactionModel transaction;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;
    final tx = transaction;
    // Income is told apart by the green of the theme; spending takes the colour of its category.
    final accent = tx.isExpense
        ? CategoryColors.accentFor(tx.category, colors)
        : context.colors.successColor;
    final amount = tx.isExpense
        ? CurrencyHelper.formatVND(-tx.amount, loc)
        : CurrencyHelper.formatVND(tx.amount, loc);
    return Container(
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Row(
        children: [
          Container(
            width: _tileSize,
            height: _tileSize,
            decoration: BoxDecoration(
              color: CategoryColors.tileFor(accent, theme.brightness),
              borderRadius: BorderRadius.circular(_tileRadius),
            ),
            child: Icon(
              TransactionCategories.iconFor(tx.category),
              color: accent,
              size: _iconSize,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TransactionCategories.displayName(loc, tx.title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: AppTextSize.title,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount,
                    maxLines: 1,
                    style: TextStyle(
                      color: tx.isExpense
                          ? colors.onSurface
                          : context.colors.successColor,
                      fontSize: AppTextSize.amount,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (footer case final Widget footer) ...[
                  const SizedBox(height: 6),
                  footer,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
