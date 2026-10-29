import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/budget_progress.dart';
import 'package:finance_ai_app/models/home_budget_summary.dart';

/// The budget band under the blue band of the home screen (T9 spec, 3.1): a ring with the share of the total that is
/// spent, what is left for how many days and a View button. Without a running budget it invites to set one; when the
/// budgets could not be loaded it offers to try again.
class HomeBudgetBand extends StatelessWidget {
  const HomeBudgetBand({
    super.key,
    required this.summary,
    required this.loadFailed,
    required this.onOpen,
    required this.onRetry,
  });

  static const double _radius = 20;
  static const double _leadingSize = 46;

  final HomeBudgetSummary? summary;
  final bool loadFailed;

  /// Opens the budget screen: a tap anywhere on the band but the retry button.
  final VoidCallback onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final current = summary;

    final Widget leading;
    final Widget title;
    final String? subtitle;
    final Widget action;
    if (loadFailed) {
      leading = _IconTile(icon: Icons.cloud_off_rounded);
      title = _Title(loc.homeBudgetFailed);
      subtitle = null;
      action = _BandButton(label: loc.commonRetry, onPressed: onRetry);
    } else if (current == null) {
      leading = _IconTile(icon: Icons.track_changes_rounded);
      title = _Title(loc.homeBudgetEmptyTitle);
      subtitle = loc.homeBudgetEmptyHint;
      action = _BandButton(label: loc.homeBudgetSet, onPressed: onOpen);
    } else {
      final over = current.remaining < 0;
      leading = _Ring(summary: current);
      title = _Title(
        over
            ? loc.homeBudgetOver(
                CurrencyHelper.formatCompactVND(-current.remaining, loc),
              )
            : loc.homeBudgetLeft(
                CurrencyHelper.formatCompactVND(current.remaining, loc),
                current.daysLeft,
              ),
        color: over ? colors.error : null,
      );
      subtitle = _categoryLine(context, current);
      action = _BandButton(label: loc.homeBudgetView, onPressed: onOpen);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primaryContainer, colors.surface],
        ),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: loadFailed ? null : onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Row(
              children: [
                SizedBox.square(dimension: _leadingSize, child: leading),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: AppTextSize.secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                action,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The category budget worth naming: the one exceeded the most, else the one closest to its limit past 80%.
  static String? _categoryLine(
    BuildContext context,
    HomeBudgetSummary summary,
  ) {
    final loc = context.loc;
    final over = summary.overCategory;
    if (over != null) {
      return loc.homeBudgetCategoryOver(
        over.budget.categoryLabel(loc),
        CurrencyHelper.formatCompactVND(-over.remaining, loc),
      );
    }
    final near = summary.nearCategory;
    if (near != null) {
      return loc.homeBudgetCategoryNear(
        near.budget.categoryLabel(loc),
        near.percentLabel,
      );
    }
    return null;
  }
}

class _Title extends StatelessWidget {
  final String text;
  final Color? color;

  const _Title(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color ?? Theme.of(context).colorScheme.onSurface,
        fontSize: AppTextSize.body,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;

  const _IconTile({required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: colors.primary, size: 22),
    );
  }
}

class _BandButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _BandButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: const TextStyle(
          fontSize: AppTextSize.secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }
}

/// The share of the total that is spent: runs from 0 to its value when shown, in the colour of the alert level.
class _Ring extends StatelessWidget {
  static const double _stroke = 6;
  static const Duration _run = Duration(milliseconds: 600);

  final HomeBudgetSummary summary;

  const _Ring({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = switch (summary.level) {
      BudgetAlertLevel.exceeded => colors.error,
      BudgetAlertLevel.warning => theme.semanticColors.warningColor,
      BudgetAlertLevel.none => colors.primary,
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: summary.ringValue),
          duration: _run,
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => CircularProgressIndicator(
            value: value,
            strokeWidth: _stroke,
            strokeCap: StrokeCap.round,
            color: color,
            backgroundColor: colors.primary.withValues(alpha: 0.2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(_stroke + 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${summary.percentLabel}%',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: AppTextSize.caption,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
