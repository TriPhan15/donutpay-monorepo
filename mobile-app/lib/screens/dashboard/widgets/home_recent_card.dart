import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/category_colors.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_status_badge.dart';
import 'package:finance_ai_app/widgets/sync/sync_status_badge.dart';

/// The "Gần đây" section of the home screen (T9 spec, 3.1): a title with "Xem tất cả", then the latest transactions
/// in one surface block, split by thin lines. An empty list offers to add a transaction.
class HomeRecentCard extends StatelessWidget {
  const HomeRecentCard({
    super.key,
    required this.transactions,
    this.onOpenTransaction,
    this.onSeeAll,
    required this.onAddTransaction,
  });

  static const double _radius = 20;

  final List<TransactionModel> transactions;

  /// Shows a transaction by its server id; a row still waiting to be sent has none and does not open.
  final ValueChanged<int>? onOpenTransaction;

  /// Opens the statistics tab; the link is left out when null.
  final VoidCallback? onSeeAll;
  final VoidCallback onAddTransaction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final seeAll = onSeeAll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                loc.dashboardRecent,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: AppTextSize.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (seeAll != null)
              TextButton(
                onPressed: seeAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: AppTextSize.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(loc.dashboardSeeAll),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(_radius),
          ),
          child: transactions.isEmpty
              ? AppStateView.empty(
                  icon: Icons.receipt_long_outlined,
                  title: loc.dashboardNoTransactions,
                  actionLabel: loc.addTransactionTitle,
                  onAction: onAddTransaction,
                )
              : Column(
                  children: [
                    for (var i = 0; i < transactions.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, color: colors.outlineVariant),
                      _RecentRow(
                        transaction: transactions[i],
                        onOpenTransaction: onOpenTransaction,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  static const double _tileSize = 40;
  static const double _amountMaxWidth = 140;

  final TransactionModel transaction;
  final ValueChanged<int>? onOpenTransaction;

  const _RecentRow({required this.transaction, this.onOpenTransaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;
    final tx = transaction;
    final serverId = int.tryParse(tx.id ?? '');
    final open = onOpenTransaction;

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

    return InkWell(
      onTap: serverId == null || open == null ? null : () => open(serverId),
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
                    _formatTime(context, tx.date),
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
    final time = DateFormat('HH:mm').format(date);
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
