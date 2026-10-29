import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/transactions/transaction_row.dart';

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

  /// A row opens by its server id; one still waiting to be sent has none and does not open.
  Widget _row(TransactionModel tx) {
    final serverId = int.tryParse(tx.id ?? '');
    final open = onOpenTransaction;
    return TransactionRow(
      transaction: tx,
      onTap: serverId == null || open == null ? null : () => open(serverId),
    );
  }

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
                      _row(transactions[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
