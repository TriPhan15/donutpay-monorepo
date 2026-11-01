import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/app_date_format.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/core/utils/money_input_formatter.dart';
import 'package:finance_ai_app/models/savings_goal.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/screens/ledger/widgets/transaction_form_fields.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/inputs/date_picker_sheet.dart';

/// Saves a goal. Returns null on success, or the message to show when it failed.
typedef SavingsGoalSubmit =
    Future<String?> Function({
      required String title,
      required double target,
      String? deadline,
    });

/// The page to create or edit a savings goal (T9 spec 3.6, mockup M2 with the R8 chips): a blue band, a "Mục tiêu" card
/// (name, target amount with 5 / 10 / 25 / 50 tr chips, the saved amount), a "Thời hạn" card with the optional target
/// date, and the save button stuck to the bottom. The saved amount is shown, not typed: the server only lets it move
/// through contributions. Pops with true once [onSubmit] succeeds; on a failure the page stays with what was typed.
class SavingsGoalFormPage extends StatefulWidget {
  const SavingsGoalFormPage({super.key, this.goal, required this.onSubmit});

  /// The goal being edited; null for a new one.
  final SavingsGoal? goal;
  final SavingsGoalSubmit onSubmit;

  static const Key nameKey = ValueKey('savings-form-name');
  static const Key amountKey = ValueKey('savings-form-amount');
  static const Key deadlineKey = ValueKey('savings-form-deadline');
  static const Key clearDeadlineKey = ValueKey('savings-form-clear-deadline');
  static const Key saveKey = ValueKey('savings-form-save');
  static Key targetChipKey(double amount) =>
      ValueKey('savings-form-chip-${amount.round()}');

  /// The quick targets under the amount: 5, 10, 25 and 50 tr.
  static const List<double> targetChips = [5e6, 10e6, 25e6, 50e6];

  /// The longest name core-backend keeps (SavingGoalDto.TITLE_MAX_LENGTH).
  static const int nameMaxLength = 255;

  /// How far ahead a target date may be picked.
  static const int maxYearsAhead = 30;

  @override
  State<SavingsGoalFormPage> createState() => _SavingsGoalFormPageState();
}

class _SavingsGoalFormPageState extends State<SavingsGoalFormPage> {
  static const double _gutter = 16;
  static const double _cardGap = 12;

  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _deadline;

  /// A stored deadline that is not in [AppDateFormat.date] (written by another client): shown and sent back as it is, until
  /// the user picks a date or removes it.
  String? _unreadDeadline;
  bool _amountShown = false;
  bool _isSaving = false;

  bool get _isEditing => widget.goal != null;

  double? get _amount => MoneyInputFormatter.parse(_amountController.text);

  bool get _valid => _nameController.text.trim().isNotEmpty && _amount != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    if (goal != null) {
      _nameController.text = goal.title;
      _deadline = _parse(goal.deadline);
      if (_deadline == null) _unreadDeadline = goal.deadline;
    }
  }

  /// The target of an edited goal is grouped in the language of the app, which the context only knows from here on.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final goal = widget.goal;
    if (_amountShown || goal == null) return;
    _amountShown = true;
    if (goal.target > 0) {
      _amountController.text = MoneyInputFormatter.format(
        goal.target,
        context.loc.localeName,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  static DateTime? _parse(String? text) {
    if (text == null) return null;
    try {
      return AppDateFormat.date.parseStrict(text);
    } on FormatException {
      return null;
    }
  }

  void _pickTarget(double amount) {
    setState(() {
      _amountController.text = MoneyInputFormatter.format(
        amount,
        context.loc.localeName,
      );
    });
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePickerSheet(
      context,
      initial: _deadline ?? today,
      firstDate: today,
      lastDate: DateTime(
        today.year + SavingsGoalFormPage.maxYearsAhead,
        today.month,
        today.day,
      ),
      title: context.loc.savingsDeadlineLabel,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _deadline = picked;
      _unreadDeadline = null;
    });
  }

  Future<void> _save() async {
    final amount = _amount;
    final title = _nameController.text.trim();
    if (_isSaving || amount == null || title.isEmpty) return;
    final deadline = _deadline;
    setState(() => _isSaving = true);
    final error = await widget.onSubmit(
      title: title,
      target: amount,
      deadline: deadline == null
          ? _unreadDeadline
          : AppDateFormat.date.format(deadline),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (error != null) {
      await AppDialog.error(
        context,
        title: context.loc.savingsSaveFailedTitle,
        message: error,
      );
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                PageBand(
                  title: _isEditing ? loc.savingsEditGoal : loc.savingsCreate,
                  action: PageBandAction.close,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _gutter,
                    _gutter,
                    _gutter,
                    _gutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FormCard(
                        title: loc.savingsFormGoalCard,
                        children: _goalFields(),
                      ),
                      const SizedBox(height: _cardGap),
                      _FormCard(
                        title: loc.savingsFormDeadlineCard,
                        children: [_deadlineField()],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, _gutter),
              child: FormSubmitBar(
                key: SavingsGoalFormPage.saveKey,
                label: loc.savingsSaveGoal,
                busy: _isSaving,
                onPressed: _valid ? _save : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _goalFields() {
    final loc = context.loc;
    final colors = Theme.of(context).colorScheme;
    final amount = _amount;
    final saved = widget.goal?.current ?? 0;
    return [
      TextField(
        key: SavingsGoalFormPage.nameKey,
        controller: _nameController,
        maxLength: SavingsGoalFormPage.nameMaxLength,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          label: FormFieldLabel(loc.savingsGoalName, required: true),
          counterText: '',
        ),
      ),
      const SizedBox(height: 16),
      AmountField(
        key: SavingsGoalFormPage.amountKey,
        controller: _amountController,
        label: loc.savingsTargetAmountLabel,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final chip in SavingsGoalFormPage.targetChips)
            ChoiceChip(
              key: SavingsGoalFormPage.targetChipKey(chip),
              label: Text(CurrencyHelper.formatCompactVND(chip, loc)),
              selected: amount == chip,
              showCheckmark: false,
              onSelected: (_) => _pickTarget(chip),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Text(
              loc.savingsSavedLabel,
              style: const TextStyle(fontSize: AppTextSize.body),
            ),
          ),
          Text(
            CurrencyHelper.formatVND(saved, loc, showSign: false),
            style: const TextStyle(
              fontSize: AppTextSize.body,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Text(
        loc.savingsSavedHint,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: AppTextSize.caption,
        ),
      ),
    ];
  }

  Widget _deadlineField() {
    final loc = context.loc;
    final colors = Theme.of(context).colorScheme;
    final shown = switch (_deadline) {
      final DateTime day => AppDateFormat.date.format(day),
      null => _unreadDeadline,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormFieldLabel(loc.savingsDeadlineLabel),
        const SizedBox(height: 6),
        Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: SavingsGoalFormPage.deadlineKey,
            borderRadius: BorderRadius.circular(12),
            onTap: _pickDeadline,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Icon(Icons.event_rounded, color: colors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shown ?? loc.savingsDeadlinePick,
                      style: TextStyle(
                        color: shown == null
                            ? colors.onSurfaceVariant
                            : colors.onSurface,
                        fontSize: AppTextSize.body,
                        fontWeight: shown == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (shown != null)
                    IconButton(
                      key: SavingsGoalFormPage.clearDeadlineKey,
                      tooltip: loc.savingsTargetDateClear,
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                      onPressed: () => setState(() {
                        _deadline = null;
                        _unreadDeadline = null;
                      }),
                    )
                  else
                    const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A white card of the form with its title.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.title, required this.children});

  static const double _radius = 16;

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: AppTextSize.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
