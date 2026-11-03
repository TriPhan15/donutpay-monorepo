import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/category_colors.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_status_badge.dart';
import 'package:finance_ai_app/widgets/sync/sync_status_badge.dart';

/// One transaction in a list card (T9 spec, 3.1): category tile, title, category, receipt and sync badges, then the
/// amount (spending in the text colour with "-", income green with "+") over its time. Shared by the home "Gần đây"
/// card and the statistics list.
class TransactionRow extends StatelessWidget {
  static const double _tileSize = 40;
  static const double _amountMaxWidth = 140;
  static const String _timePattern = 'HH:mm';

  final TransactionModel transaction;

  /// Null leaves the row inert.
  final VoidCallback? onTap;

  /// Under a day header the time alone is enough; elsewhere the day is named too ("Hôm nay 08:15", a weekday, a date).
  final bool timeOnly;

  const TransactionRow({
    super.key,
    required this.transaction,
    this.onTap,
    this.timeOnly = false,
  });

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
    // A transaction without a note is titled with its category, shown in the app language.
    final title = TransactionCategories.displayName(loc, tx.title);
    final category = TransactionCategories.displayName(loc, tx.category);
    final amount = tx.isExpense
        ? CurrencyHelper.formatVND(-tx.amount, loc)
        : CurrencyHelper.formatVND(tx.amount, loc);
    final sourceLabel = tx.source.label(loc);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: _tileSize,
              height: _tileSize,
              decoration: BoxDecoration(
                color: CategoryColors.tileFor(accent, theme.brightness),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                TransactionCategories.iconFor(tx.category),
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: AppTextSize.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (category != title) ...[
                    const SizedBox(height: 2),
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: AppTextSize.secondary,
                      ),
                    ),
                  ],
                  if (sourceLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: AppTextSize.secondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (tx.receiptStatus != null) ...[
                    const SizedBox(height: 6),
                    ReceiptStatusBadge(status: tx.receiptStatus!),
                  ],
                  if (tx.isUnsynced) ...[
                    const SizedBox(height: 6),
                    SyncStatusBadge(status: tx.syncStatus),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _amountMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      amount,
                      maxLines: 1,
                      style: TextStyle(
                        color: tx.isExpense
                            ? colors.onSurface
                            : context.colors.successColor,
                        fontSize: AppTextSize.body,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeOnly
                        ? DateFormat(_timePattern).format(tx.date)
                        : _formatTime(context, tx.date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: AppTextSize.caption,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(BuildContext context, DateTime date) {
    final loc = context.loc;
    final now = DateTime.now();
    final time = DateFormat(_timePattern).format(date);
    if (DateUtils.isSameDay(date, now)) return loc.dateTodayAt(time);
    if (DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return loc.dateYesterdayAt(time);
    }
    if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE, HH:mm', loc.localeName).format(date);
    }
    return DateFormat('dd/MM/yyyy, HH:mm').format(date);
  }
}
