import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/ledger_stats.dart';

/// The "Lịch" view of the statistics tab (T9 spec, 3.1): a Monday-first month grid, each day with its income (green,
/// no "+") and spending (red) in compact amounts. The selected day is filled, today only outlined, future days faded.
/// Cells grow with their text, so two amounts never overflow.
class StatsCalendarCard extends StatelessWidget {
  const StatsCalendarCard({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.today,
    required this.totals,
    required this.onDaySelected,
  });

  @visibleForTesting
  static Key dayKey(int day) => ValueKey('stats-day-$day');

  static const int _daysPerWeek = 7;
  static const double _futureOpacity = 0.35;
  static const double _cellRadius = 10;
  static const double _todayBorder = 1.5;

  /// Any day of the month shown.
  final DateTime month;
  final DateTime selectedDay;
  final DateTime today;

  /// Income and spending per day (date-only keys), as [LedgerStats.byDay] gives them.
  final Map<DateTime, DayTotals> totals;
  final ValueChanged<DateTime> onDaySelected;

  static List<String> _weekdays(AppLocalizations loc) => [
    loc.weekdayShortMon,
    loc.weekdayShortTue,
    loc.weekdayShortWed,
    loc.weekdayShortThu,
    loc.weekdayShortFri,
    loc.weekdayShortSat,
    loc.weekdayShortSun,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final blanks = first.weekday - DateTime.monday;
    final cells = <Widget>[
      for (var i = 0; i < blanks; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _cell(context, DateTime(month.year, month.month, d)),
    ];
    while (cells.length % _daysPerWeek != 0) {
      cells.add(const SizedBox.shrink());
    }
    final caption = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: AppTextSize.caption,
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final name in _weekdays(loc))
                Expanded(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: caption,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var row = 0; row < cells.length; row += _daysPerWeek)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final cell in cells.sublist(row, row + _daysPerWeek))
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: cell,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, DateTime day) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final selected = DateUtils.isSameDay(day, selectedDay);
    final isToday = DateUtils.isSameDay(day, today);
    final future = day.isAfter(today);
    final dayTotals = totals[day];
    TextStyle line(Color color) => TextStyle(
      color: selected ? colors.onPrimary : color,
      fontSize: AppTextSize.caption,
      height: 1.2,
    );
    Widget cell = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onDaySelected(day),
      child: Container(
        key: dayKey(day.day),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 1),
        decoration: BoxDecoration(
          color: selected ? colors.primary : null,
          borderRadius: BorderRadius.circular(_cellRadius),
          border: isToday && !selected
              ? Border.all(color: colors.primary, width: _todayBorder)
              : null,
        ),
        child: Column(
          children: [
            Text(
              '${day.day}',
              style: line(
                colors.onSurface,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            if ((dayTotals?.income ?? 0) > 0)
              Text(
                CurrencyHelper.formatCompactVND(dayTotals!.income, loc),
                textAlign: TextAlign.center,
                style: line(context.colors.successColor),
              ),
            if ((dayTotals?.expense ?? 0) > 0)
              Text(
                CurrencyHelper.formatCompactVND(dayTotals!.expense, loc),
                textAlign: TextAlign.center,
                style: line(colors.error),
              ),
          ],
        ),
      ),
    );
    if (future) cell = Opacity(opacity: _futureOpacity, child: cell);
    return cell;
  }
}
