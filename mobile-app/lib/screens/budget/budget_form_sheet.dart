import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/utils/money_input_formatter.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/widgets/common/custom_text_field.dart';
import 'package:finance_ai_app/widgets/common/primary_button.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/inputs/date_field.dart';

/// Bottom sheet to create a budget or edit one. It only collects and checks the input: the screen that opens it
/// sends the request and reports a failure by returning its message from [onSubmit]. Pops with true once saved.
class BudgetFormSheet extends StatefulWidget {
  /// The budget being edited; null when creating a new one.
  final BudgetModel? budget;

  final Future<List<BudgetCategory>> Function() loadCategories;

  /// Saves the budget. Returns null on success, or the message to show when it failed.
  final Future<String?> Function(BudgetModel budget) onSubmit;

  const BudgetFormSheet({
    super.key,
    this.budget,
    required this.loadCategories,
    required this.onSubmit,
  });

  @override
  State<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<BudgetFormSheet> {
  /// The longest category name a user may type under "Khác" (core-backend's categories.name holds it).
  static const int customCategoryMaxLength = 50;

  final _amountController = TextEditingController();
  final _customCategoryController = TextEditingController();
  late String _periodType;

  /// The period is the week, month or year that contains this day.
  late DateTime _referenceDay;

  /// Whether the user picked [_referenceDay]: until then, changing the period type of an edited budget moves it to
  /// the current period.
  bool _dayPicked = false;
  bool _amountShown = false;
  String? _customCategoryError;

  /// Null means the budget covers every category.
  BudgetCategory? _category;
  List<BudgetCategory> _categories = [];
  bool _isLoadingCategories = true;
  bool _isSaving = false;

  bool get _isEditing => widget.budget != null;

  /// An edited budget keeps its dates while its period type is unchanged and the chosen day is inside them; otherwise
  /// the week, month or year that contains the chosen day.
  bool get _keepsDates {
    final existing = widget.budget;
    return existing != null &&
        existing.periodType == _periodType &&
        existing.coversDay(_referenceDay);
  }

  ({DateTime start, DateTime end}) get _range {
    final existing = widget.budget;
    if (existing != null && _keepsDates) {
      return (start: existing.start, end: existing.end);
    }
    return BudgetPeriodType.rangeContaining(_periodType, _referenceDay);
  }

  /// "Khác" is chosen: the budget is for a category the user names. It is sent by name, and core-backend reuses the
  /// category of that name (trimmed, ignoring case) or creates it.
  bool get _isCustomCategory =>
      _category?.name == TransactionCategories.otherExpense;

  @override
  void initState() {
    super.initState();
    final existing = widget.budget;
    _periodType = existing?.periodType ?? BudgetPeriodType.month;
    _referenceDay = existing?.start ?? DateTime.now();
    if (existing != null) {
      final categoryId = existing.categoryId;
      if (categoryId != null) {
        _category = (id: categoryId, name: existing.categoryName ?? '');
        if (_isCustomCategory) _customCategoryController.text = _category!.name;
      }
    }
    _loadCategories();
  }

  /// The amount of an edited budget is grouped in the language of the app, which the context only knows from here on.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final existing = widget.budget;
    if (_amountShown || existing == null) return;
    _amountShown = true;
    _amountController.text = MoneyInputFormatter.format(
      existing.amount,
      context.loc.localeName,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  void _selectPeriodType(String type) {
    setState(() {
      _periodType = type;
      if (!_dayPicked) {
        final existing = widget.budget;
        _referenceDay = existing != null && existing.periodType == type
            ? existing.start
            : DateTime.now();
      }
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _referenceDay = day;
      _dayPicked = true;
    });
  }

  Future<void> _loadCategories() async {
    final List<BudgetCategory> categories;
    try {
      categories = await widget.loadCategories();
    } catch (e) {
      debugPrint('Lỗi tải danh mục cho ngân sách: $e');
      if (!mounted) return;
      setState(() => _isLoadingCategories = false);
      final loc = context.loc;
      await AppDialog.error(
        context,
        title: loc.budgetCategoriesLoadFailedTitle,
        message: loc.budgetCategoriesLoadFailedMessage(
          BudgetModel.allCategoriesLabel(loc),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _categories = _withSelected(categories);
      _isLoadingCategories = false;
    });
  }

  /// Keeps the category of the edited budget selectable even when the loaded list does not contain it.
  List<BudgetCategory> _withSelected(List<BudgetCategory> loaded) {
    final selected = _category;
    if (selected == null ||
        loaded.any((category) => category.id == selected.id)) {
      return loaded;
    }
    return [selected, ...loaded];
  }

  /// The name typed under "Khác", trimmed. Null, with [_customCategoryError] set, when it is empty or too long.
  String? _validCustomCategoryName(AppLocalizations loc) {
    final typed = _customCategoryController.text.trim();
    final String? error;
    if (typed.isEmpty) {
      error = loc.budgetCustomCategoryRequired;
    } else if (typed.length > customCategoryMaxLength) {
      error = loc.budgetCustomCategoryTooLong(customCategoryMaxLength);
    } else {
      error = null;
    }
    setState(() => _customCategoryError = error);
    return error == null ? typed : null;
  }

  /// With a [customCategoryName] the budget is sent by that name and without a category id; otherwise with the
  /// chosen chip (none for every category).
  BudgetModel _buildBudget(double amount, String? customCategoryName) {
    final range = _range;
    final category = customCategoryName == null ? _category : null;
    return BudgetModel(
      id: widget.budget?.id,
      categoryId: category?.id,
      categoryName: customCategoryName ?? category?.name,
      amount: amount,
      periodType: _periodType,
      startDate: BudgetModel.formatApiDate(range.start),
      endDate: BudgetModel.formatApiDate(range.end),
      userId: widget.budget?.userId,
    );
  }

  Future<void> _save() async {
    final loc = context.loc;
    final amount = MoneyInputFormatter.parse(_amountController.text);
    if (amount == null) {
      await AppDialog.error(
        context,
        title: loc.commonInvalidAmountTitle,
        message: loc.budgetAmountPositive,
      );
      return;
    }
    String? customCategoryName;
    if (_isCustomCategory) {
      customCategoryName = _validCustomCategoryName(loc);
      if (customCategoryName == null) return;
    }

    setState(() => _isSaving = true);
    final error = await widget.onSubmit(
      _buildBudget(amount, customCategoryName),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      await AppDialog.error(
        context,
        title: context.loc.budgetSaveFailedTitle,
        message: error,
      );
      return;
    }
    await AppDialog.success(
      context,
      title: context.loc.budgetSavedTitle,
      message: context.loc.budgetSavedMessage,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? loc.budgetEditTitle : loc.budgetCreate,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _amountController,
              label: loc.budgetAmountLabel,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter(loc.localeName)],
            ),
            const SizedBox(height: 20),
            _SectionLabel(loc.budgetPeriodLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final type in BudgetPeriodType.values)
                  _OptionChip(
                    label: BudgetPeriodType.label(loc, type),
                    selected: _periodType == type,
                    onSelected: () => _selectPeriodType(type),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionLabel(loc.budgetPeriodDayLabel),
            const SizedBox(height: 8),
            DateField(value: _referenceDay, onChanged: _selectDay),
            const SizedBox(height: 12),
            _PeriodPreview(label: _previewLabel(loc), range: _range),
            const SizedBox(height: 20),
            _SectionLabel(loc.transactionCategoryLabel),
            const SizedBox(height: 8),
            _buildCategories(loc),
            if (_isCustomCategory) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customCategoryController,
                maxLength: customCategoryMaxLength,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (_customCategoryError != null) {
                    setState(() => _customCategoryError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: loc.budgetCustomCategoryLabel,
                  helperText: loc.budgetCustomCategoryHelper,
                  helperMaxLines: 2,
                  errorText: _customCategoryError,
                  errorMaxLines: 3,
                ),
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              text: _isSaving ? loc.commonSaving : loc.budgetSave,
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  /// "Applied period" for the kept dates of an edited budget or a period without today, else "this week" (month, year).
  String _previewLabel(AppLocalizations loc) {
    if (_keepsDates) return loc.budgetAppliedPeriod;
    final range = _range;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final containsToday =
        !today.isBefore(range.start) && !today.isAfter(range.end);
    return containsToday
        ? BudgetPeriodType.currentLabel(loc, _periodType)
        : loc.budgetAppliedPeriod;
  }

  Widget _buildCategories(AppLocalizations loc) {
    if (_isLoadingCategories) {
      return const SizedBox(
        height: 40,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _OptionChip(
          label: BudgetModel.allCategoriesLabel(loc),
          selected: _category == null,
          onSelected: () => setState(() => _category = null),
        ),
        for (final category in _categories)
          _OptionChip(
            label: TransactionCategories.displayName(loc, category.name),
            selected: _category?.id == category.id,
            onSelected: () => setState(() => _category = category),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 14,
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

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
      side: BorderSide(color: colors.outlineVariant),
      labelStyle: TextStyle(
        color: selected ? colors.onPrimary : colors.onSurface,
      ),
    );
  }
}

class _PeriodPreview extends StatelessWidget {
  static final DateFormat _displayDate = DateFormat('dd/MM/yyyy');

  final String label;
  final ({DateTime start, DateTime end}) range;

  const _PeriodPreview({required this.label, required this.range});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.event_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: ${_displayDate.format(range.start)} – ${_displayDate.format(range.end)}',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
