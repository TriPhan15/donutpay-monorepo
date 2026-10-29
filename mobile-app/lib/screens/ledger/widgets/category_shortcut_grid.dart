import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/category_colors.dart';
import 'package:finance_ai_app/models/category_shortcuts.dart';

/// The category tiles of a transaction form (T9 spec, 3.3): the often used [shortcuts] and a fourth tile that opens
/// the full list ([onMore]). A [selected] category that is not a shortcut takes the fourth tile, so the choice always
/// shows.
class CategoryShortcutGrid extends StatelessWidget {
  const CategoryShortcutGrid({
    super.key,
    required this.shortcuts,
    required this.selected,
    required this.onSelected,
    required this.onMore,
  });

  @visibleForTesting
  static const Key moreKey = ValueKey('category-more-tile');

  static const int _columns = CategoryShortcuts.count + 1;
  static const double _gap = 8;

  final List<String> shortcuts;
  final String? selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final overflow = CategoryShortcuts.overflowOf(shortcuts, selected);
    final tiles = <Widget>[
      for (final category in shortcuts)
        _Tile(
          category: category,
          label: TransactionCategories.displayName(context.loc, category),
          icon: TransactionCategories.iconFor(category),
          selected: category == selected,
          onTap: () => onSelected(category),
        ),
      _Tile(
        key: moreKey,
        category: overflow,
        label: overflow == null
            ? context.loc.categoryMoreTile
            : TransactionCategories.displayName(context.loc, overflow),
        icon: overflow == null
            ? Icons.grid_view_rounded
            : TransactionCategories.iconFor(overflow),
        selected: overflow != null,
        onTap: onMore,
      ),
    ];
    // One height for all tiles: a label on two lines does not leave its neighbours shorter.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _columns; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            Expanded(child: i < tiles.length ? tiles[i] : const SizedBox()),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.category,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  static const double _radius = 12;
  static const double _iconSize = 20;
  static const double _border = 1.5;

  /// Null for the plain "Khác" tile, which takes the secondary text colour.
  final String? category;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = category;
    final iconColor = name == null
        ? colors.onSurfaceVariant
        : CategoryColors.accentFor(name, colors);
    final radius = BorderRadius.circular(_radius);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: _border,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: _iconSize, color: iconColor),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                    fontSize: AppTextSize.caption,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
