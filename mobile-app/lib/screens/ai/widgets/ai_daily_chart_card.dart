import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/spending_range.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/screens/ai/widgets/ai_section.dart';
import 'package:finance_ai_app/widgets/common/pill_segmented.dart';

/// "Chi tiêu theo ngày" (T9 spec 3.1): a curved area chart of what was spent each day of the range, under the
/// Tuần này / Tháng này / Tùy chọn toggle. The line stops at today; the days after it keep their place on the axis.
class AiDailyChartCard extends StatelessWidget {
  const AiDailyChartCard({
    super.key,
    required this.range,
    required this.transactions,
    required this.today,
    required this.onPeriodSelected,
  });

  @visibleForTesting
  static const Key chartKey = ValueKey('ai-daily-chart');

  static const double _chartHeight = 150;

  /// About this many day labels fit under the chart.
  static const int _maxLabels = 6;

  final SpendingRange range;
  final List<TransactionModel> transactions;
  final DateTime today;

  /// Called with the option tapped, also the one already chosen (Tùy chọn then opens the date sheets again).
  final ValueChanged<SpendingPeriod> onPeriodSelected;

  /// What was spent in each point of [buckets], income and savings contributions left out.
  static List<double> spendingPer(
    List<SpendingBucket> buckets,
    List<TransactionModel> transactions,
  ) => [
    for (final bucket in buckets)
      transactions
          .where((t) => t.countsAsSpending && bucket.contains(t.date))
          .fold(0.0, (s, t) => s + t.amount),
  ];

  /// How many points the line draws: up to the one holding [today] when the range runs past it, else all.
  static int drawnCount(List<SpendingBucket> buckets, DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    final index = buckets.indexWhere((b) => b.contains(day));
    if (index >= 0) return index + 1;
    // A range wholly in the future has nothing to draw; one in the past draws everything.
    return buckets.isNotEmpty && buckets.first.start.isAfter(day)
        ? 0
        : buckets.length;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AiSectionHeader(title: loc.aiDailyChartTitle),
        AiCard(
          padding: const EdgeInsets.all(16),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PillSegmented<SpendingPeriod>(
                  options: [
                    (SpendingPeriod.week, loc.periodThisWeek),
                    (SpendingPeriod.month, loc.periodThisMonth),
                    (SpendingPeriod.custom, loc.periodCustom),
                  ],
                  selected: range.period,
                  onChanged: onPeriodSelected,
                ),
                const SizedBox(height: 8),
                Text(
                  range.label,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: AppTextSize.caption,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: _chartHeight,
                  child: _chart(context, loc, colors),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _chart(
    BuildContext context,
    AppLocalizations loc,
    ColorScheme colors,
  ) {
    final buckets = range.dayBuckets(loc);
    final values = spendingPer(buckets, transactions);
    final drawn = drawnCount(buckets, today);
    final peak = values.isEmpty ? 0.0 : values.reduce(math.max);
    final maxY = math.max(peak * 1.2, 100.0);
    final lastX = math.max(buckets.length - 1, 1).toDouble();
    final labelEvery = buckets.length <= DateTime.daysPerWeek
        ? 1
        : (buckets.length / _maxLabels).ceil();
    final labelStyle = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: AppTextSize.caption,
    );
    final tooltipStyle = TextStyle(
      color: colors.onSurface,
      fontWeight: FontWeight.w700,
      fontSize: AppTextSize.caption,
    );
    final spots = [
      for (var i = 0; i < drawn; i++) FlSpot(i.toDouble(), values[i]),
    ];

    return LineChart(
      key: chartKey,
      LineChartData(
        minX: 0,
        maxX: lastX,
        minY: 0,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colors.onSurfaceVariant.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 24,
              getTitlesWidget: (value, _) {
                final i = value.round();
                if (i != value || i < 0 || i >= buckets.length) {
                  return const SizedBox.shrink();
                }
                if (i % labelEvery != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(buckets[i].label, style: labelStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.surfaceContainer,
            getTooltipItems: (touched) => [
              for (final spot in touched)
                LineTooltipItem(
                  '${buckets[spot.x.toInt()].label}\n'
                  '${CurrencyHelper.formatCompactVND(spot.y, loc)}',
                  tooltipStyle,
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: colors.primary,
            barWidth: 2.6,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, _) => spot.x == drawn - 1,
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 4,
                color: colors.primary,
                strokeWidth: 2,
                strokeColor: colors.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.primary.withValues(alpha: 0.35),
                  colors.primary.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
