import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/utils/money_input_formatter.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/custom_text_field.dart';
import 'package:finance_ai_app/widgets/common/primary_button.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/inputs/date_field.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_status_badge.dart';

/// Field names of the body of PUT /api/transactions/{id}; a field that is left out keeps its value on the server.
const String _fieldAmount = 'amount';
const String _fieldCategory = 'categoryName';
const String _fieldNote = 'note';
const String _fieldDate = 'transactionDate';

/// Form to correct the amount, category, day and note of a transaction that the server has. It sends just what the user
/// changed, which leaves the time of day, the type and the receipt alone, and pops with true once the server has saved
/// it.
class EditTransactionPage extends StatefulWidget {
  final TransactionModel transaction;

  const EditTransactionPage({super.key, required this.transaction});

  @override
  State<EditTransactionPage> createState() => _EditTransactionPageState();
}

class _EditTransactionPageState extends State<EditTransactionPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  late String _category;
  late DateTime _date;
  bool _amountShown = false;
  List<String> _categories = const [];
  bool _isLoadingCategories = true;
  bool _categoriesUnavailable = false;
  bool _isSaving = false;

  TransactionModel get _original => widget.transaction;

  /// The amount in whole dong, which is all the form can show or type. The field and the comparison both use it, so an
  /// amount with decimals that the user does not touch is never rewritten.
  double get _originalWholeAmount => _original.amount.roundToDouble();

  /// The server titles a transaction without a note with its category, so an equal title means there is no note.
  String get _originalNote {
    final title = _original.title.trim();
    return title == _original.category.trim() ? '' : title;
  }

  @override
  void initState() {
    super.initState();
    _noteController.text = _originalNote;
    _category = _original.category;
    _date = _original.date;
    _categories = [_category];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCategories();
    });
  }

  /// The amount is grouped the way the language groups it, which needs the localizations: not there in initState yet.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_amountShown) return;
    _amountShown = true;
    _amountController.text = MoneyInputFormatter.format(
      _originalWholeAmount,
      context.loc.localeName,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final isExpense = _original.isExpense;
    if (TransactionCategories.forType(isExpense: isExpense).isEmpty) {
      await TransactionCategories.loadFromApi();
      if (!mounted) return;
    }
    final loaded = TransactionCategories.forType(isExpense: isExpense);
    setState(() {
      // A copy, because the cached list is cleared whenever another screen reloads the categories. The category of the
      // transaction stays selectable even when the server list does not contain it.
      _categories = [
        if (!loaded.contains(_original.category)) _original.category,
        ...loaded,
      ];
      _categoriesUnavailable = loaded.isEmpty;
      _isLoadingCategories = false;
    });
  }

  /// The fields the user changed; empty when nothing differs from the transaction as it was opened.
  Map<String, dynamic> _changes(double amount) {
    final note = _noteController.text.trim();
    return {
      if (amount != _originalWholeAmount) _fieldAmount: amount,
      if (_category != _original.category) _fieldCategory: _category,
      if (note != _originalNote) _fieldNote: note,
      if (_date != _original.date) _fieldDate: _date.toIso8601String(),
    };
  }

  /// Sends the changes. Returns null once the server has saved them, or the message to show in the language of [loc]
  /// when it did not.
  Future<String?> _send(
    String id,
    Map<String, dynamic> changes,
    AppLocalizations loc,
  ) async {
    try {
      await RemoteApiHelper.instance.updateTransaction(id, changes);
      return null;
    } catch (e) {
      UserFacingError.log('Edit transaction', e);
      // Without a token core-backend answers 403, so a refusal with no reason means the login is gone.
      final status = e is DioException ? e.response?.statusCode : null;
      return UserFacingError.messageOf(
        e,
        loc,
        rejectedMessage: status == HttpStatus.forbidden
            ? loc.errorSessionExpired
            : loc.editTransactionRejected,
      );
    }
  }

  /// The form can be closed while the request or a dialog is awaited, so `mounted` is checked before every dialog and
  /// before the pop: here for the validation dialogs (nothing is awaited before them) and after each await below.
  Future<void> _save() async {
    if (!mounted) return;
    final loc = context.loc;
    if (SessionService.currentUserId == null) {
      await AppDialog.error(
        context,
        title: loc.commonSessionExpiredTitle,
        message: loc.accountInfoSignInAgain,
      );
      return;
    }
    final id = _original.id;
    if (id == null) {
      await AppDialog.error(
        context,
        title: loc.editTransactionNoServerIdTitle,
        message: loc.editTransactionNoServerIdMessage,
      );
      return;
    }
    final amount = MoneyInputFormatter.parse(_amountController.text);
    if (amount == null) {
      await AppDialog.error(
        context,
        title: loc.commonInvalidAmountTitle,
        message: loc.editTransactionAmountPositive,
      );
      return;
    }
    final changes = _changes(amount);
    if (changes.isEmpty) {
      await AppDialog.info(
        context,
        title: loc.editTransactionNoChangesTitle,
        message: loc.editTransactionNoChangesMessage,
      );
      return;
    }

    setState(() => _isSaving = true);
    final failure = await _send(id, changes, loc);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (failure != null) {
      await AppDialog.error(
        context,
        title: loc.editTransactionSaveFailedTitle,
        message: failure,
      );
      return;
    }
    await AppDialog.success(
      context,
      title: loc.editTransactionSavedTitle,
      message: loc.editTransactionSavedMessage,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.editTransactionTitle,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            if (!mounted) return;
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Summary(transaction: _original),
            const SizedBox(height: 24),
            CustomTextField(
              controller: _amountController,
              label: loc.editTransactionAmountLabel,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter(loc.localeName)],
            ),
            const SizedBox(height: 20),
            _SectionLabel(loc.transactionCategoryLabel),
            const SizedBox(height: 8),
            _CategoryChips(
              categories: _categories,
              selected: _category,
              isLoading: _isLoadingCategories,
              onSelected: (category) => setState(() => _category = category),
            ),
            if (_categoriesUnavailable)
              _Hint(loc.editTransactionCategoriesUnavailable),
            const SizedBox(height: 20),
            _SectionLabel(loc.transactionDateLabel),
            const SizedBox(height: 8),
            DateField(
              value: _date,
              onChanged: (date) => setState(() => _date = date),
            ),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _noteController,
              label: loc.transactionNoteOptional,
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              text: _isSaving ? loc.commonSaving : loc.commonSaveChanges,
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// What is being edited, as it was opened: the type, the moment and the state of the receipt.
class _Summary extends StatelessWidget {
  static final DateFormat _displayDate = DateFormat('dd/MM/yyyy HH:mm');

  final TransactionModel transaction;

  const _Summary({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final status = transaction.receiptStatus;
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(colors),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: transaction.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(transaction.icon, color: transaction.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.isExpense
                      ? loc.transactionExpenseKind
                      : loc.transactionIncomeKind,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _displayDate.format(transaction.date),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(height: 6),
                  ReceiptStatusBadge(status: status),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final bool isLoading;
  final ValueChanged<String> onSelected;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.isLoading,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final side = BorderSide(
      color: colors.onSurfaceVariant.withValues(alpha: 0.3),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final category in categories)
          ChoiceChip(
            label: Text(TransactionCategories.displayName(loc, category)),
            selected: category == selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(category),
            selectedColor: colors.primary,
            backgroundColor: colors.surface,
            side: side,
            labelStyle: TextStyle(
              color: category == selected ? colors.onPrimary : colors.onSurface,
            ),
          ),
        if (isLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
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

class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    );
  }
}
