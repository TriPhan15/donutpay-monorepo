import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';

/// Opens the date picker sheet (T9 spec 3.3): quick choices for today, yesterday and [lastRecordedDay] above a
/// Monday-first month calendar. Returns the day picked (at midnight), or null when the sheet was closed.
///
/// Days outside [firstDate]..[lastDate] are faded and cannot be picked, and quick choices outside it are left out.
/// [lastRecordedDay] is offered only when it is neither today nor yesterday.
Future<DateTime?> showDatePickerSheet(
  BuildContext context, {
  required DateTime initial,
  required DateTime firstDate,
  required DateTime lastDate,
  required String title,
  DateTime? lastRecordedDay,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _DatePickerSheet(
      initial: _dayOf(initial),
      firstDate: _dayOf(firstDate),
      lastDate: _dayOf(lastDate),
      title: title,
      lastRecordedDay: lastRecordedDay == null ? null : _dayOf(lastRecordedDay),
    ),
  );
}

DateTime _dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.lastRecordedDay,
  });

  final DateTime initial;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final DateTime? lastRecordedDay;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  static const double cellSize = 40;
  static const double futureAlpha = 0.35;
  static const String _chipPattern = 'dd/MM';

  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

  bool _inRange(DateTime day) =>
      !day.isBefore(widget.firstDate) && !day.isAfter(widget.lastDate);

  bool get _canGoBack => DateTime(
    _month.year,
    _month.month,
  ).isAfter(DateTime(widget.firstDate.year, widget.firstDate.month));

  bool get _canGoForward => DateTime(
    _month.year,
    _month.month,
  ).isBefore(DateTime(widget.lastDate.year, widget.lastDate.month));

  void _moveMonth(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  void _pick(DateTime day) => Navigator.pop(context, day);

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final today = _dayOf(DateTime.now());
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final recorded = widget.lastRecordedDay;
    final quick = <(String, DateTime)>[
      (loc.dateFieldToday, today),
      (loc.dateFieldYesterday, yesterday),
      if (recorded != null && recorded != today && recorded != yesterday)
        (loc.datePickerLastRecorded, recorded),
    ].where((choice) => _inRange(choice.$2)).toList();

    // Scrolls when the screen is short (landscape, large text) instead of overflowing.
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: AppTextSize.title,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (quick.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, day) in quick)
                    _QuickChip(
                      label: label,
                      date: DateFormat(_chipPattern).format(day),
                      selected: day == widget.initial,
                      onTap: () => _pick(day),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _monthHeader(loc),
            const SizedBox(height: 8),
            _weekdays(loc.datePickerWeekdays.split(',')),
            _grid(today),
          ],
        ),
      ),
    );
  }

  Widget _monthHeader(AppLocalizations loc) {
    final monthName = DateFormat.MMMM(loc.localeName).format(_month);
    return Row(
      children: [
        Expanded(
          child: Text(
            loc.datePickerMonthTitle(
              '${_month.month}',
              '${_month.year}',
              monthName,
            ),
            style: const TextStyle(
              fontSize: AppTextSize.body,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: loc.datePickerPreviousMonth,
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: _canGoBack ? () => _moveMonth(-1) : null,
        ),
        IconButton(
          tooltip: loc.datePickerNextMonth,
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: _canGoForward ? () => _moveMonth(1) : null,
        ),
      ],
    );
  }

  Widget _weekdays(List<String> names) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        for (final name in names)
          Expanded(
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: AppTextSize.caption),
            ),
          ),
      ],
    );
  }

  Widget _grid(DateTime today) {
    final colors = Theme.of(context).colorScheme;
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final leading = _month.weekday - DateTime.monday;
    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++)
        _dayCell(DateTime(_month.year, _month.month, d), today, colors),
    ];
    while (cells.length % DateTime.daysPerWeek != 0) {
      cells.add(const SizedBox.shrink());
    }
    return Column(
      children: [
        for (var row = 0; row < cells.length; row += DateTime.daysPerWeek)
          Row(
            children: [
              for (final cell in cells.sublist(row, row + DateTime.daysPerWeek))
                Expanded(
                  child: SizedBox(
                    height: cellSize + 4,
                    child: Center(child: cell),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _dayCell(DateTime day, DateTime today, ColorScheme colors) {
    final enabled = _inRange(day);
    final selected = day == widget.initial;
    final isToday = day == today;
    final Color textColor = selected
        ? colors.onPrimary
        : enabled
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: futureAlpha);
    return InkWell(
      key: ValueKey('day-${day.day}'),
      customBorder: const CircleBorder(),
      onTap: enabled ? () => _pick(day) : null,
      child: Container(
        width: cellSize,
        height: cellSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? colors.primary : null,
          border: isToday && !selected
              ? Border.all(color: colors.primary, width: 1.5)
              : null,
        ),
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: textColor,
            fontSize: AppTextSize.body,
            fontWeight: selected || isToday ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// A quick choice: its name over the day it stands for.
class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.onPrimary : colors.onPrimaryContainer;
    return Material(
      color: selected ? colors.primary : colors.primaryContainer,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: AppTextSize.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                date,
                style: TextStyle(
                  color: foreground.withValues(alpha: 0.8),
                  fontSize: AppTextSize.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
