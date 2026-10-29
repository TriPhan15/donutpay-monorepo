import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/category_colors.dart';

/// The building blocks shared by the cards of the AI tab (T9 spec 3.1): a section title over a white card whose rows
/// are split by thin lines, a value pill on the right of a row, and a soft box for advice.

/// What a value pill says: green is good, red needs attention (spec 3.1), amber is a warning, the primary colour is a
/// plain value.
enum AiPillTone { good, attention, warning, neutral }

class AiSectionHeader extends StatelessWidget {
  const AiSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: AppTextSize.title,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A white card (radius 20, no shadow, like the home "Gần đây" card) holding [children] one under the other, split by
/// 1 px lines.
class AiCard extends StatelessWidget {
  const AiCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
  });

  static const double radius = 20;

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.outlineVariant),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One row of a card: [leading], a title over an optional second line, and [trailing] on the right.
class AiListRow extends StatelessWidget {
  const AiListRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppTextSize.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle case final String subtitle) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppTextSize.caption,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing case final Widget trailing) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }
}

/// An icon on a pale tile of its colour, as category icons are drawn (spec 2.1).
class AiIconTile extends StatelessWidget {
  const AiIconTile({super.key, required this.icon, this.color});

  static const double size = 36;

  final IconData icon;

  /// The primary colour of the theme when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: CategoryColors.tileFor(accent, theme.brightness),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: accent, size: 20),
    );
  }
}

/// A short value in a rounded pill, coloured by [tone].
class AiValuePill extends StatelessWidget {
  const AiValuePill({super.key, required this.label, required this.tone});

  final String label;
  final AiPillTone tone;

  /// The text colour of [tone]; the pill is a pale tile of it.
  static Color colorOf(BuildContext context, AiPillTone tone) => switch (tone) {
    AiPillTone.good => context.colors.incomeColor,
    AiPillTone.attention => context.colors.expenseColor,
    AiPillTone.warning => context.colors.warningColor,
    AiPillTone.neutral => Theme.of(context).colorScheme.primary,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CategoryColors.tileFor(color, Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: AppTextSize.caption,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A box on a soft primary tint with an icon and some lines of text: the prediction under the habits, the advice under
/// the balance.
class AiSoftBox extends StatelessWidget {
  const AiSoftBox({super.key, required this.icon, required this.children});

  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CategoryColors.tileFor(primary, theme.brightness),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  DefaultTextStyle.merge(
                    style: const TextStyle(
                      fontSize: AppTextSize.secondary,
                      height: 1.45,
                    ),
                    child: children[i],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
