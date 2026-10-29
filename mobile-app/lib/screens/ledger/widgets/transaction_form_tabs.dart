import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';

/// The underlined tabs at the top of the add form (T9 spec, 3.3): "Nhập tay" is the form itself and always selected;
/// "Quét hóa đơn" hands over to the receipt scanner through [onScan].
class EntryModeTabs extends StatelessWidget {
  const EntryModeTabs({super.key, required this.onScan});

  static const double _underline = 2.5;
  static const double _iconSize = 16;

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    Widget tab({
      required IconData icon,
      required String label,
      required bool selected,
      required VoidCallback? onTap,
    }) {
      final color = selected ? colors.primary : colors.onSurfaceVariant;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? colors.primary : Colors.transparent,
                    width: _underline,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: _iconSize, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: AppTextSize.body,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          tab(
            icon: Icons.edit_outlined,
            label: loc.addTransactionManualTab,
            selected: true,
            onTap: null,
          ),
          tab(
            icon: Icons.document_scanner_outlined,
            label: loc.addTransactionScanTab,
            selected: false,
            onTap: onScan,
          ),
        ],
      ),
    );
  }
}

/// The card tabs Chi tiêu / Thu nhập above the white form card (T9 spec, 3.3): the selected tab has the colour of the
/// card, so the two read as one piece; its text is red for spending and green for income.
class TransactionTypeTabs extends StatelessWidget {
  const TransactionTypeTabs({
    super.key,
    required this.isExpense,
    required this.onChanged,
  });

  static const double _radius = 16;
  static const double _iconSize = 15;

  final bool isExpense;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = context.colors;
    final loc = context.loc;
    Widget tab({
      required bool expense,
      required IconData icon,
      required String label,
    }) {
      final selected = expense == isExpense;
      final color = !selected
          ? colors.onSurfaceVariant
          : expense
          ? semantic.expenseColor
          : semantic.successColor;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: Material(
            color: selected ? colors.surface : colors.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(_radius),
            ),
            child: InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_radius),
              ),
              onTap: () => onChanged(expense),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: _iconSize, color: color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: AppTextSize.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(
          expense: true,
          icon: Icons.south_west_rounded,
          label: loc.transactionTabExpense,
        ),
        tab(
          expense: false,
          icon: Icons.north_east_rounded,
          label: loc.transactionTabIncome,
        ),
      ],
    );
  }
}
