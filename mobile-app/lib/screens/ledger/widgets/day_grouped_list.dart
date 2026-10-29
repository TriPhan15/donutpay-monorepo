import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/ledger_stats.dart';
import 'package:finance_ai_app/models/transaction_filter.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/widgets/transactions/transaction_row.dart';

/// The transaction list of the statistics tab (T9 spec, 3.1): one surface card, rows split by thin lines, grouped by
/// day with the totals of each day. Ordered by the largest amount it is one flat block (days cannot group then); in the
/// calendar one "Tổng thu | Tổng chi" line heads the rows of the chosen day.
class DayGroupedList extends StatelessWidget {
  const DayGroupedList({
    super.key,
    required this.transactions,
    required this.sort,
    required this.onOpen,
    required this.title,
    this.trailing,
    this.singleDaySummary = false,
    required this.empty,
  });

  static const String _dayPattern = 'dd/MM';

  /// Already filtered and in [sort] order.
  final List<TransactionModel> transactions;
  final TransactionSort sort;
  final ValueChanged<TransactionModel> onOpen;
  final String title;
  final Widget? trailing;
  final bool singleDaySummary;

  /// Shown inside the card when [transactions] is empty.
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: AppTextSize.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: transactions.isEmpty
              ? empty
              : Column(children: _children(context)),
        ),
      ],
    );
  }

  List<Widget> _children(BuildContext context) {
    final divider = Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
    final out = <Widget>[];
    void rows(List<TransactionModel> txs, {required bool timeOnly}) {
      for (final tx in txs) {
        if (out.isNotEmpty) out.add(divider);
        out.add(
          TransactionRow(
            transaction: tx,
            onTap: () => onOpen(tx),
            timeOnly: timeOnly,
          ),
        );
      }
    }

    if (singleDaySummary) {
      final group = LedgerStats.groupByDay(transactions);
      out.add(
        _header(
          context,
          null,
          income: group.fold(0.0, (s, g) => s + g.income),
          expense: group.fold(0.0, (s, g) => s + g.expense),
          totalLabels: true,
        ),
      );
      rows(transactions, timeOnly: true);
    } else if (sort == TransactionSort.largest) {
      rows(transactions, timeOnly: false);
    } else {
      for (final group in LedgerStats.groupByDay(transactions)) {
        if (out.isNotEmpty) out.add(divider);
        out.add(
          _header(
            context,
            group.day,
            income: group.income,
            expense: group.expense,
          ),
        );
        rows(group.transactions, timeOnly: true);
      }
    }
    return out;
  }

  String _dayLabel(BuildContext context, DateTime day) {
    final loc = context.loc;
    final now = DateTime.now();
    final date = DateFormat(_dayPattern).format(day);
    if (DateUtils.isSameDay(day, now)) return loc.dateFieldTodayValue(date);
    if (DateUtils.isSameDay(day, now.subtract(const Duration(days: 1)))) {
      return loc.dateFieldYesterdayValue(date);
    }
    return DateFormat('EEEE, $_dayPattern', loc.localeName).format(day);
  }

  /// A day header (its label and its non-zero totals), or with a null [day] the "Tổng thu | Tổng chi" line.
  Widget _header(
    BuildContext context,
    DateTime? day, {
    required double income,
    required double expense,
    bool totalLabels = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    String full(double v) => CurrencyHelper.formatVND(v, loc, showSign: false);
    final style = TextStyle(
      fontSize: AppTextSize.secondary,
      fontWeight: FontWeight.w600,
    );
    final amounts = [
      if (income > 0 || totalLabels)
        Text(
          totalLabels
              ? loc.statsTotalIncome(full(income))
              : loc.statsIncome(full(income)),
          style: style.copyWith(color: context.colors.successColor),
        ),
      if (expense > 0 || totalLabels)
        Text(
          totalLabels
              ? loc.statsTotalExpense(full(expense))
              : loc.statsExpense(full(expense)),
          style: style.copyWith(color: colors.error),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          if (day != null)
            Text(
              _dayLabel(context, day),
              style: style.copyWith(color: colors.onSurfaceVariant),
            ),
          Wrap(spacing: 12, runSpacing: 4, children: amounts),
        ],
      ),
    );
  }
}
