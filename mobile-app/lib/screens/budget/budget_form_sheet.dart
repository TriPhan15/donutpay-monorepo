import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/app_date_format.dart';
import 'package:finance_ai_app/core/utils/money_input_formatter.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/category_shortcuts.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/screens/ledger/widgets/category_shortcut_grid.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/screens/ledger/widgets/transaction_form_fields.dart';
import 'package:finance_ai_app/widgets/common/pill_segmented.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/transactions/category_picker_sheet.dart';

/// Bottom sheet to create a budget or edit one (T9 spec, 3.5, mockup M1): the amount, three categories plus Khác, the
/// period toggle, the period it applies to, and Save. It only collects and checks the input: the screen that opens it
/// sends the request and reports a failure by returning its message from [onSubmit]. Pops with true once saved.
class BudgetFormSheet extends StatefulWidget {
  /// The budget being edited; null when creating a new one.
  final BudgetModel? budget;

  /// The period type a new budget starts with.
  final String initialPeriodType;

  /// The transactions that rank the category tiles, the most used first.
  final Iterable<TransactionModel> history;

  final Future<List<BudgetCategory>> Function() loadCategories;

  /// Saves the budget. Returns null on success, or the message to show when it failed.
  final Future<String?> Function(BudgetModel budget) onSubmit;

  const BudgetFormSheet({
    super.key,
    this.budget,
    this.initialPeriodType = BudgetPeriodType.month,
    this.history = const [],
    required this.loadCategories,
    required this.onSubmit,
  });

  static const Key closeKey = ValueKey('budget-form-close');
  static const Key saveKey = ValueKey('budget-form-save');

  @override
  State<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<BudgetFormSheet> {
  /// The longest category name a user may type under "Khác" (core-backend's categories.name holds it).
  static const int customCategoryMaxLength = 50;
  static const double _gutter = 20;
  static const double _topPadding = 12;
  static const double _bottomPadding = 24;
  static const double _loadingHeight = 40;
  static const double _spinnerSize = 20;

  final _amountController = TextEditingController();
  final _customCategoryController = TextEditingController();
  late String _periodType;
  bool _amountShown = false;
  String? _customCategoryError;

  /// Null means the budget covers every category.
  BudgetCategory? _category;
  List<BudgetCategory> _categories = [];
  bool _isLoadingCategories = true;
  bool _isSaving = false;

  bool get _isEditing => widget.budget != null;

  bool get _amountValid =>
      MoneyInputFormatter.parse(_amountController.text) != null;

  /// An edited budget keeps its dates while its period type is unchanged; otherwise the budget is for the week, month
  /// or year that contains today.
  bool get _keepsDates => widget.budget?.periodType == _periodType;

  ({DateTime start, DateTime end}) get _range {
    final existing = widget.budget;
    if (existing != null && _keepsDates) {
      return (start: existing.start, end: existing.end);
    }
    return BudgetPeriodType.rangeContaining(_periodType, DateTime.now());
  }

  /// "Khác" is chosen: the budget is for a category the user names. It is sent by name, and core-backend reuses the
  /// category of that name (trimmed, ignoring case) or creates it.
  bool get _isCustomCategory =>
      _category?.name == TransactionCategories.otherExpense;

  /// The chosen category as the tiles name it: [TransactionCategories.all] stands for every category.
  String get _selectedName => _category?.name ?? TransactionCategories.all;

  List<String> get _names => [for (final c in _categories) c.name];

  @override
  void initState() {
    super.initState();
    final existing = widget.budget;
    _periodType = existing?.periodType ?? widget.initialPeriodType;
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

  /// A name that is neither [TransactionCategories.all] nor a loaded category is ignored.
  void _selectName(String name) {
    final BudgetCategory? category;
    if (name == TransactionCategories.all) {
      category = null;
    } else {
      final matches = _categories.where((c) => c.name == name);
      if (matches.isEmpty) return;
      category = matches.first;
    }
    setState(() {
      _customCategoryError = null;
      _category = category;
    });
  }

  /// The full list, every category first.
  Future<void> _pickCategory() async {
    final picked = await showCategoryPickerSheet(
      context,
      categories: [TransactionCategories.all, ..._names],
      selected: _selectedName,
      isExpense: true,
    );
    if (!mounted || picked == null) return;
    _selectName(picked);
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
  /// chosen tile (none for every category).
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
    if (amount == null) return;
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
        padding: const EdgeInsets.fromLTRB(
          _gutter,
          _topPadding,
          _gutter,
          _bottomPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? loc.budgetEditTitle : loc.budgetCreate,
                    style: const TextStyle(
                      fontSize: AppTextSize.title,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: BudgetFormSheet.closeKey,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AmountField(
              controller: _amountController,
              label: loc.budgetAmountLabel,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: _gutter),
            FormFieldLabel(loc.transactionCategoryLabel),
            const SizedBox(height: 8),
            _buildCategories(),
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
            const SizedBox(height: _gutter),
            FormFieldLabel(loc.budgetPeriodLabel),
            const SizedBox(height: 8),
            PillSegmented<String>(
              options: [
                for (final type in BudgetPeriodType.values)
                  (type, BudgetPeriodType.label(loc, type)),
              ],
              selected: _periodType,
              onChanged: (type) => setState(() => _periodType = type),
            ),
            const SizedBox(height: 10),
            _PeriodPreview(
              text:
                  '${_previewLabel(loc)}: ${AppDateFormat.date.format(_range.start)} – ${AppDateFormat.date.format(_range.end)}',
            ),
            const SizedBox(height: _bottomPadding),
            FormSubmitBar(
              key: BudgetFormSheet.saveKey,
              label: loc.budgetSave,
              busy: _isSaving,
              onPressed: _amountValid ? _save : null,
            ),
          ],
        ),
      ),
    );
  }

  /// "Applied period" for the kept dates of an edited budget, else "this week" (month, year).
  String _previewLabel(AppLocalizations loc) => _keepsDates
      ? loc.budgetAppliedPeriod
      : BudgetPeriodType.currentLabel(loc, _periodType);

  Widget _buildCategories() {
    if (_isLoadingCategories) {
      return const SizedBox(
        height: _loadingHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: _spinnerSize,
            height: _spinnerSize,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return CategoryShortcutGrid(
      shortcuts: CategoryShortcuts.pick(
        available: _names,
        history: widget.history,
        isExpense: true,
      ),
      selected: _selectedName,
      onSelected: _selectName,
      onMore: _pickCategory,
    );
  }
}

class _PeriodPreview extends StatelessWidget {
  final String text;

  const _PeriodPreview({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.event_rounded, color: colors.onPrimaryContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontSize: AppTextSize.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
