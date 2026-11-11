import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/utils/app_date_format.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/di/injection_container.dart';
import 'package:finance_ai_app/repositories/settings_repository.dart';
import 'package:finance_ai_app/widgets/inputs/date_picker_sheet.dart';

/// The day of a form: a box that reads "Today, 27/10/2026", "Yesterday, ..." or the date, and opens the date picker
/// sheet ([showDatePickerSheet]), which holds the quick choices. Only the day changes: the value given to [onChanged]
/// keeps the time of [value], so a form that stores a moment (a transaction) keeps its hour.
///
/// With [withTime] the box also shows the hour (`dd/MM/yyyy HH:mm`) and, after the day, a time picker opens, so the
/// value given to [onChanged] carries the time chosen there; cancelling the time picker keeps the old time.
///
/// [forTransaction] titles the sheet for a transaction and offers the day of the transaction recorded last.
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
    this.forTransaction = false,
    this.withTime = false,
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
  final bool forTransaction;
  final bool withTime;

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
    final loc = context.loc;
    final picked = await showDatePickerSheet(
      context,
      initial: initial,
      firstDate: first,
      lastDate: last,
      title: forTransaction
          ? loc.datePickerTransactionTitle
          : loc.datePickerTitle,
      lastRecordedDay: forTransaction && sl.isRegistered<SettingsRepository>()
          ? sl<SettingsRepository>().lastRecordedDay
          : null,
    );
    if (picked == null || !context.mounted) return;
    if (!withTime) return _select(picked);
    await _pickTime(context, picked);
  }

  /// Opens the time picker for [day]; without an answer the day keeps the time of [value].
  Future<void> _pickTime(BuildContext context, DateTime day) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (time == null) return _select(day);
    final moment = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    if (moment != value) onChanged(moment);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final today = _dayOf(DateTime.now());
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final shown =
        (withTime ? AppDateFormat.dateTime : DateFormat(displayPattern)).format(
          value,
        );
    final label = _sameDay(value, today)
        ? loc.dateFieldTodayValue(shown)
        : _sameDay(value, yesterday)
        ? loc.dateFieldYesterdayValue(shown)
        : shown;

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
                  Expanded(child: Text(label)),
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
                fontSize: AppTextSize.caption,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
