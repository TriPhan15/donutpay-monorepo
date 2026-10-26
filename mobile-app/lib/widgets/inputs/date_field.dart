import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';

/// The day of a form: a box that opens the date picker, a "Today" and a "Yesterday" chip, and a button back to today
/// while another day is picked. Only the day changes: the value given to [onChanged] keeps the time of [value], so a
/// form that stores a moment (a transaction) keeps its hour.
///
/// [errorText] outlines the box in the error colour and is shown under it, like the error of a text field;
/// [helperText] is shown there otherwise, in [helperColor].
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.errorText,
    this.helperText,
    this.helperColor,
  });

  static const String displayPattern = 'dd/MM/yyyy';
  static const double _radius = 16;
  static const double _iconSize = 20;

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  /// The earliest and latest days the picker offers; [defaultFirstDate] and [defaultLastDate] when left out.
  final DateTime? firstDate;
  final DateTime? lastDate;

  final String? errorText;
  final String? helperText;
  final Color? helperColor;

  static final DateTime defaultFirstDate = DateTime(2000);
  static final DateTime defaultLastDate = DateTime(2100);

  static DateTime _dayOf(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// [day] with the time of [value].
  DateTime _onDay(DateTime day) => DateTime(
    day.year,
    day.month,
    day.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );

  void _select(DateTime day) {
    if (_sameDay(day, value)) return;
    onChanged(_onDay(day));
  }

  Future<void> _pick(BuildContext context) async {
    final first = firstDate ?? defaultFirstDate;
    final last = lastDate ?? defaultLastDate;
    var initial = _dayOf(value);
    if (initial.isBefore(first)) initial = _dayOf(first);
    if (initial.isAfter(last)) initial = _dayOf(last);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !context.mounted) return;
    _select(picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final today = _dayOf(DateTime.now());
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final isToday = _sameDay(value, today);
    final isYesterday = _sameDay(value, yesterday);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: loc.dateFieldPick,
          child: InkWell(
            onTap: () => _pick(context),
            borderRadius: BorderRadius.circular(_radius),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              constraints: const BoxConstraints(minHeight: 56),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(_radius),
                border: errorText == null
                    ? null
                    : Border.all(color: colors.error),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: colors.onSurfaceVariant,
                    size: _iconSize,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(DateFormat(displayPattern).format(value)),
                  ),
                  if (!isToday)
                    IconButton(
                      tooltip: loc.dateFieldBackToToday,
                      icon: Icon(
                        Icons.restart_alt_rounded,
                        color: colors.primary,
                      ),
                      onPressed: () => _select(today),
                    ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        if ((errorText ?? helperText) case final String note) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              note,
              style: TextStyle(
                color: errorText != null ? colors.error : helperColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DayChip(
              label: loc.dateFieldToday,
              selected: isToday,
              onSelected: () => _select(today),
            ),
            _DayChip(
              label: loc.dateFieldYesterday,
              selected: isYesterday,
              onSelected: () => _select(yesterday),
            ),
          ],
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      selectedColor: colors.primary,
      backgroundColor: colors.surface,
      side: BorderSide(color: colors.onSurfaceVariant.withValues(alpha: 0.3)),
      labelStyle: TextStyle(
        color: selected ? colors.onPrimary : colors.onSurface,
      ),
    );
  }
}
