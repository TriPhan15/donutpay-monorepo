import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';

/// The full list of [categories] in a bottom sheet, [selected] ticked. Returns the tapped category, or null when the
/// sheet is dismissed.
Future<String?> showCategoryPickerSheet(
  BuildContext context, {
  required List<String> categories,
  required String? selected,
  required bool isExpense,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _CategoryPickerSheet(
      categories: categories,
      selected: selected,
      isExpense: isExpense,
    ),
  );
}

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.selected,
    required this.isExpense,
  });

  /// The sheet never covers more than this share of the screen; a long list scrolls inside it.
  static const double _maxHeightFactor = 0.75;

  final List<String> categories;
  final String? selected;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _maxHeightFactor,
      ),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                isExpense
                    ? loc.transactionPickExpenseCategory
                    : loc.transactionPickIncomeCategory,
                style: const TextStyle(
                  fontSize: AppTextSize.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final category in categories)
              ListTile(
                leading: Icon(
                  TransactionCategories.iconFor(category),
                  color: category == selected
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                title: Text(
                  TransactionCategories.displayName(loc, category),
                  style: TextStyle(
                    color: category == selected
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                    fontWeight: category == selected
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
                trailing: category == selected
                    ? Icon(Icons.check_rounded, color: colors.primary)
                    : null,
                onTap: () => Navigator.pop(context, category),
              ),
          ],
        ),
      ),
    );
  }
}
