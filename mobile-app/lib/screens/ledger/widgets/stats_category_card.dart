import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/category_colors.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/ledger_stats.dart';

/// The "Danh mục" view of the statistics tab (T9 spec, 3.1): a ring split by category with the total spent in the
/// middle, then one row per category with its bar, amount, share and count. No "over the limit" wording.
class StatsCategoryCard extends StatelessWidget {
  const StatsCategoryCard({
    super.key,
    required this.shares,
    required this.periodLabel,
  });

  static const double _ringSize = 110;
  static const double _ringWidth = 17;
  static const double _tileSize = 40;
  static const int _legendRows = 4;

  final List<CategoryShare> shares;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final card = BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
    );
    if (shares.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: card,
        child: Text(
          loc.statsNoSpending,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: AppTextSize.secondary,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: card,
          child: Row(
            children: [
              _ring(context),
              const SizedBox(width: 16),
              Expanded(child: _legend(context)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                loc.statsByCategory,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: AppTextSize.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              periodLabel,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: AppTextSize.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: card,
          child: Column(
            children: [
              for (var i = 0; i < shares.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colors.outlineVariant),
                _CategoryRow(share: shares[i], tileSize: _tileSize),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _ring(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final total = shares.fold<double>(0, (s, c) => s + c.amount);
    return SizedBox.square(
      dimension: _ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 0,
              centerSpaceRadius: _ringSize / 2 - _ringWidth,
              pieTouchData: PieTouchData(enabled: false),
              sections: [
                for (final share in shares)
                  PieChartSectionData(
                    value: share.amount,
                    color: CategoryColors.accentFor(share.category, colors),
                    radius: _ringWidth,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  CurrencyHelper.formatCompactVND(total, loc),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: AppTextSize.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                loc.statsSpent,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: AppTextSize.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final share in shares.take(_legendRows))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: CategoryColors.accentFor(share.category, colors),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${TransactionCategories.displayName(loc, share.category)} ${share.percent.round()}%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: AppTextSize.caption,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.share, required this.tileSize});

  final CategoryShare share;
  final double tileSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;
    final accent = CategoryColors.accentFor(share.category, colors);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              color: CategoryColors.tileFor(accent, theme.brightness),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              TransactionCategories.iconFor(share.category),
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
                  TransactionCategories.displayName(loc, share.category),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: AppTextSize.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: share.percent / 100,
                    minHeight: 6,
                    backgroundColor: colors.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyHelper.formatCompactVND(share.amount, loc),
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: AppTextSize.body,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                loc.statsCategoryLine(share.percent.round(), share.count),
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: AppTextSize.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
