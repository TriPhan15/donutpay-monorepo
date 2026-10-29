import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/models/transaction_filter.dart';
import 'package:finance_ai_app/widgets/common/pill_segmented.dart';

/// The "Lọc" sheet of the statistics tab (T9 spec, 3.4, R7): three small toggles stacked, "Đặt lại" and
/// "Xem n giao dịch", where n is what [countFor] counts for the draft on the device. Null when closed without applying.
Future<TransactionFilter?> showTransactionFilterSheet(
  BuildContext context, {
  required TransactionFilter initial,
  required int Function(TransactionFilter draft) countFor,
}) {
  return showModalBottomSheet<TransactionFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FilterSheet(initial: initial, countFor: countFor),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.countFor});

  final TransactionFilter initial;
  final int Function(TransactionFilter draft) countFor;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  static const double _gap = 12;

  late TransactionFilter _draft = widget.initial;

  void _update(TransactionFilter draft) => setState(() => _draft = draft);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    loc.filterTitle,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: AppTextSize.title,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: _gap),
            PillSegmented<TransactionTypeFilter>(
              options: [
                (TransactionTypeFilter.all, loc.filterAll),
                (TransactionTypeFilter.expense, loc.filterExpense),
                (TransactionTypeFilter.income, loc.filterIncome),
              ],
              selected: _draft.type,
              onChanged: (v) => _update(_draft.copyWith(type: v)),
            ),
            const SizedBox(height: _gap),
            PillSegmented<AmountRange>(
              options: [
                (AmountRange.any, loc.filterAnyAmount),
                (AmountRange.under100k, loc.filterUnder100k),
                (AmountRange.from100kTo500k, loc.filter100kTo500k),
                (AmountRange.over500k, loc.filterOver500k),
              ],
              selected: _draft.range,
              onChanged: (v) => _update(_draft.copyWith(range: v)),
            ),
            const SizedBox(height: _gap),
            PillSegmented<TransactionSort>(
              options: [
                (TransactionSort.newest, loc.filterNewest),
                (TransactionSort.oldest, loc.filterOldest),
                (TransactionSort.largest, loc.filterLargest),
              ],
              selected: _draft.sort,
              onChanged: (v) => _update(_draft.copyWith(sort: v)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _update(TransactionFilter.none),
                    child: Text(loc.filterReset),
                  ),
                ),
                const SizedBox(width: _gap),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _draft),
                    child: Text(
                      loc.filterShowCount(widget.countFor(_draft)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
