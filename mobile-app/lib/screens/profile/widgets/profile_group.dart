import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/theme/app_typography.dart';

/// One row of a [ProfileGroup]: an icon in a light blue box, a label, an optional value on the right and a chevron.
/// A [danger] row (sign out) is red and has no chevron.
class ProfileRow {
  const ProfileRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.badge,
    this.danger = false,
    this.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Shown in grey before the chevron, such as the current theme.
  final String? value;

  /// Shown right after the label, such as a demo badge.
  final Widget? badge;
  final bool danger;
  final Key? key;
}

/// An iPhone-style grouped list (T9 spec 3.1, "Cá nhân"): an optional caption outside the card, then the rows on one
/// card, split by thin lines.
class ProfileGroup extends StatelessWidget {
  const ProfileGroup({super.key, this.title, required this.rows});

  static const double _radius = 16;
  static const double _boxSize = 34;
  static const double _boxRadius = 11;
  static const double _iconSize = 18;
  static const double _dividerIndent = 62;
  static const double _dangerTint = 0.12;

  final String? title;
  final List<ProfileRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = this.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: AppTextSize.caption,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        // A Material, not a coloured Container: ListTile paints its ink on the nearest Material.
        Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(_radius),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: _dividerIndent,
                    color: colors.outlineVariant,
                  ),
                _tile(colors, rows[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(ColorScheme colors, ProfileRow row) {
    final accent = row.danger ? colors.error : colors.primary;
    final value = row.value;
    return ListTile(
      key: row.key,
      onTap: row.onTap,
      leading: Container(
        width: _boxSize,
        height: _boxSize,
        decoration: BoxDecoration(
          color: row.danger
              ? colors.error.withValues(alpha: _dangerTint)
              : colors.primaryContainer,
          borderRadius: BorderRadius.circular(_boxRadius),
        ),
        child: Icon(row.icon, color: accent, size: _iconSize),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              row.label,
              style: TextStyle(
                color: row.danger ? colors.error : colors.onSurface,
                fontSize: AppTextSize.body,
                fontWeight: row.danger ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          if (row.badge case final Widget badge) ...[
            const SizedBox(width: 8),
            badge,
          ],
        ],
      ),
      trailing: row.danger
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null)
                  Text(
                    value,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: AppTextSize.secondary,
                    ),
                  ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
    );
  }
}
