import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/ledger_stats.dart';

/// The "Biểu đồ" view of the statistics tab (T9 spec, 3.1): a green income bar and a red spending bar per day of the
/// week, per month of the last six, or per month of the year. The bucket on screen is lit, the others faded; a tap on
/// a bar shows its amounts in full.
class StatsChartCard extends StatefulWidget {
  const StatsChartCard({
    super.key,
    required this.period,
    required this.buckets,
  });

  /// The tap area over the bars of bucket [index].
  @visibleForTesting
  static Key barKey(int index) => ValueKey('stats-bar-$index');

  final LedgerPeriod period;
  final List<ChartBucket> buckets;

  @override
  State<StatsChartCard> createState() => _StatsChartCardState();
}

class _StatsChartCardState extends State<StatsChartCard> {
  static const double _chartHeight = 180;
  static const double _axisHeight = 24;
  static const double _fadedAlpha = 0.4;
  static const double _headroom = 1.2;

  /// The bucket the user tapped; null shows the hint.
  int? _touched;

  @override
  void didUpdateWidget(StatsChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another period or other figures: the old tap no longer points at the same bucket.
    if (oldWidget.period != widget.period ||
        oldWidget.buckets.length != widget.buckets.length ||
        oldWidget.buckets.firstOrNull?.start !=
            widget.buckets.firstOrNull?.start) {
      _touched = null;
    }
  }

  String _label(
    ChartBucket bucket,
    AppLocalizations loc,
  ) => switch (widget.period) {
    LedgerPeriod.week => _weekday(bucket.start, loc),
    LedgerPeriod.month => loc.ledgerChartMonth('${bucket.start.month}'),
    // Twelve labels must fit a phone at the 12 px floor: the month number alone.
    LedgerPeriod.year => '${bucket.start.month}',
  };

  static String _weekday(DateTime d, AppLocalizations loc) => [
    loc.weekdayShortMon,
    loc.weekdayShortTue,
    loc.weekdayShortWed,
    loc.weekdayShortThu,
    loc.weekdayShortFri,
    loc.weekdayShortSat,
    loc.weekdayShortSun,
  ][d.weekday - 1];

  bool _lit(int i) =>
      _touched == null ? widget.buckets[i].isSelected : _touched == i;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          const SizedBox(height: 12),
          SizedBox(
            height: _chartHeight,
            child: Stack(
              children: [
                Positioned.fill(child: BarChart(_data(context))),
                // One tap area per bucket, laid out like the groups (spaceAround gives each an equal slot).
                Positioned.fill(
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.buckets.length; i++)
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: _label(widget.buckets[i], loc),
                            child: GestureDetector(
                              key: StatsChartCard.barKey(i),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _touched = i),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final success = context.colors.successColor;
    final small = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: AppTextSize.caption,
    );
    final touched = _touched;
    final Widget right;
    if (touched == null) {
      right = Text(
        loc.statsTapBarHint,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: small,
      );
    } else {
      final bucket = widget.buckets[touched];
      String full(double v) =>
          CurrencyHelper.formatVND(v, loc, showSign: false);
      right = Wrap(
        alignment: WrapAlignment.end,
        spacing: 10,
        runSpacing: 2,
        children: [
          Text(
            loc.statsIncome(full(bucket.income)),
            style: small.copyWith(color: success, fontWeight: FontWeight.w600),
          ),
          Text(
            loc.statsExpense(full(bucket.expense)),
            style: small.copyWith(
              color: colors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        _legend(success, loc.ledgerLegendIncome, small),
        const SizedBox(width: 12),
        _legend(colors.error, loc.ledgerLegendExpense, small),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  Widget _legend(Color color, String label, TextStyle style) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: style),
    ],
  );

  BarChartData _data(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final success = context.colors.successColor;
    final isYear = widget.period == LedgerPeriod.year;
    final rodWidth = isYear ? 6.0 : 12.0;
    var maxValue = 1.0;
    for (final b in widget.buckets) {
      if (b.income > maxValue) maxValue = b.income;
      if (b.expense > maxValue) maxValue = b.expense;
    }
    final axisStyle = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: AppTextSize.caption,
    );
    Color shade(Color c, int i) =>
        _lit(i) ? c : c.withValues(alpha: _fadedAlpha);
    return BarChartData(
      maxY: maxValue * _headroom,
      alignment: BarChartAlignment.spaceAround,
      barTouchData: BarTouchData(enabled: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxValue * _headroom / 2,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: colors.outlineVariant, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: _axisHeight,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= widget.buckets.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _label(widget.buckets[i], loc),
                  style: axisStyle,
                  maxLines: 1,
                  softWrap: false,
                ),
              );
            },
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < widget.buckets.length; i++)
          BarChartGroupData(
            x: i,
            barsSpace: isYear ? 2 : 4,
            barRods: [
              BarChartRodData(
                toY: widget.buckets[i].income,
                color: shade(success, i),
                width: rodWidth,
                borderRadius: BorderRadius.circular(4),
              ),
              BarChartRodData(
                toY: widget.buckets[i].expense,
                color: shade(colors.error, i),
                width: rodWidth,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
      ],
    );
  }
}
