import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/money_input_formatter.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/category_shortcuts.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/screens/ledger/widgets/category_shortcut_grid.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/screens/ledger/widgets/transaction_form_fields.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/inputs/date_field.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_status_badge.dart';
import 'package:finance_ai_app/widgets/transactions/category_picker_sheet.dart';
import 'package:finance_ai_app/widgets/transactions/transaction_head_card.dart';

/// Field names of the body of PUT /api/transactions/{id}; a field that is left out keeps its value on the server.
const String _fieldAmount = 'amount';
const String _fieldCategory = 'categoryName';
const String _fieldNote = 'note';
const String _fieldDate = 'transactionDate';

/// Form to correct the amount, category, day and note of a transaction that the server has (T9 spec, 3.3: the add form's
/// layout with a summary card on top and "Lưu thay đổi", faded until something changed). It sends just what the user
/// changed, which leaves the time of day, the type and the receipt alone, and pops with true once the server has saved
/// it.
class EditTransactionPage extends StatefulWidget {
  final TransactionModel transaction;

  const EditTransactionPage({super.key, required this.transaction});

  @override
  State<EditTransactionPage> createState() => _EditTransactionPageState();
}

class _EditTransactionPageState extends State<EditTransactionPage> {
  static const double _gutter = 16;
  static const double _cardRadius = 20;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  late String _category;
  late DateTime _date;
  bool _amountShown = false;

  /// The categories of the server for the type of the transaction; the tiles and the full list are drawn from it.
  List<String> _serverCategories = const [];
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
    _amountController.addListener(_onFieldChanged);
    _noteController.addListener(_onFieldChanged);
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
    _amountController.removeListener(_onFieldChanged);
    _noteController.removeListener(_onFieldChanged);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onFieldChanged() => setState(() {});

  Future<void> _loadCategories() async {
    final isExpense = _original.isExpense;
    if (TransactionCategories.forType(isExpense: isExpense).isEmpty) {
      await TransactionCategories.loadFromApi();
      if (!mounted) return;
    }
    final loaded = TransactionCategories.forType(isExpense: isExpense);
    setState(() {
      // A copy, because the cached list is cleared whenever another screen reloads the categories.
      _serverCategories = List.of(loaded);
      _categoriesUnavailable = loaded.isEmpty;
    });
  }

  /// The full list for the "Khác" tile. The category of the transaction stays selectable even when the server list does
  /// not contain it.
  List<String> get _pickableCategories => [
    if (!_serverCategories.contains(_original.category)) _original.category,
    ..._serverCategories,
  ];

  Future<void> _pickCategory() async {
    final picked = await showCategoryPickerSheet(
      context,
      categories: _pickableCategories,
      selected: _category,
      isExpense: _original.isExpense,
    );
    if (!mounted || picked == null) return;
    setState(() => _category = picked);
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

  /// A valid amount and at least one change.
  bool get _canSave {
    final amount = MoneyInputFormatter.parse(_amountController.text);
    return amount != null && _changes(amount).isNotEmpty;
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
    final amount = MoneyInputFormatter.parse(_amountController.text);
    if (_isSaving || !mounted || amount == null) return;
    final changes = _changes(amount);
    if (changes.isEmpty) return;
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
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    return Scaffold(
      body: Column(
        children: [
          PageBand(
            title: loc.editTransactionTitle,
            action: PageBandAction.close,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(_gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TransactionHeadCard(
                    transaction: _original,
                    footer: _SummaryFooter(transaction: _original),
                  ),
                  const SizedBox(height: _gutter),
                  Container(
                    padding: const EdgeInsets.all(_gutter),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(_cardRadius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AmountField(controller: _amountController),
                        const SizedBox(height: _gutter),
                        FormFieldLabel(
                          loc.transactionCategoryLabel,
                          required: true,
                        ),
                        const SizedBox(height: 8),
                        CategoryShortcutGrid(
                          shortcuts: CategoryShortcuts.pick(
                            available: _serverCategories,
                            history: const [],
                            isExpense: _original.isExpense,
                          ),
                          selected: _category,
                          onSelected: (category) =>
                              setState(() => _category = category),
                          onMore: _pickCategory,
                        ),
                        if (_categoriesUnavailable)
                          _Hint(loc.editTransactionCategoriesUnavailable),
                        const SizedBox(height: _gutter),
                        FormFieldLabel(loc.transactionDateLabel),
                        const SizedBox(height: 8),
                        DateField(
                          forTransaction: true,
                          value: _date,
                          onChanged: (date) => setState(() => _date = date),
                        ),
                        const SizedBox(height: _gutter),
                        NoteField(controller: _noteController),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          FormSubmitBar(
            label: _isSaving ? loc.commonSaving : loc.commonSaveChanges,
            busy: _isSaving,
            onPressed: _canSave ? _save : null,
          ),
        ],
      ),
    );
  }
}

/// "Khoản chi, 20/09/2026 08:30" and the state of the receipt: what the form does not change.
class _SummaryFooter extends StatelessWidget {
  static final DateFormat _displayDate = DateFormat('dd/MM/yyyy HH:mm');

  final TransactionModel transaction;

  const _SummaryFooter({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final status = transaction.receiptStatus;
    final loc = context.loc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.editTransactionSummaryLine(
            transaction.isExpense
                ? loc.transactionExpenseKind
                : loc.transactionIncomeKind,
            _displayDate.format(transaction.date),
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: AppTextSize.caption,
          ),
        ),
        if (status != null) ...[
          const SizedBox(height: 6),
          ReceiptStatusBadge(status: status),
        ],
      ],
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
          fontSize: AppTextSize.caption,
        ),
      ),
    );
  }
}
