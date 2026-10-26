import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/utils/money_input_formatter.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/inputs/date_field.dart';

/// Always opens on the current moment, whatever period the screen that opened it shows: a new transaction is most
/// often about today, and the date field gets to another day in one tap.
class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  bool _isExpense = true;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _selectedCategory = TransactionCategories.otherExpense;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initCategories();
  }

  Future<void> _initCategories() async {
    if (TransactionCategories.expenseSelectable.isEmpty) {
      await TransactionCategories.loadFromApi();
    }
    if (mounted && TransactionCategories.expenseSelectable.isNotEmpty) {
      setState(() {
        _selectedCategory = TransactionCategories.expenseSelectable.first;
      });
    }
  }

  void _setIsExpense(bool isExpense) {
    if (_isExpense == isExpense) return;
    setState(() {
      _isExpense = isExpense;
      final categories = TransactionCategories.forType(isExpense: _isExpense);
      if (!categories.contains(_selectedCategory)) {
        _selectedCategory = categories.isNotEmpty
            ? categories.first
            : TransactionCategories.otherExpense;
      }
    });
  }

  Future<void> _pickCategory() async {
    if (TransactionCategories.forType(isExpense: _isExpense).isEmpty) {
      await TransactionCategories.loadFromApi();
    }

    if (!mounted) return;
    final categories = TransactionCategories.forType(isExpense: _isExpense);

    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final loc = context.loc;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  _isExpense
                      ? loc.transactionPickExpenseCategory
                      : loc.transactionPickIncomeCategory,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...categories.map((category) {
                final selected = category == _selectedCategory;
                return ListTile(
                  leading: Icon(
                    TransactionCategories.iconFor(category),
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                  title: Text(
                    TransactionCategories.displayName(loc, category),
                    style: TextStyle(
                      color: selected
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: selected
                      ? Icon(Icons.check_rounded, color: colors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, category),
                );
              }),
            ],
          ),
        );
      },
    );

    if (!mounted || picked == null) return;
    setState(() {
      _selectedCategory = picked;
    });
  }

  Future<void> _saveTransaction() async {
    if (_isSaving || !mounted) return;
    final loc = context.loc;
    final userId = SessionService.currentUserId;
    if (userId == null) {
      await AppDialog.error(
        context,
        title: loc.commonSessionExpiredTitle,
        message: loc.accountInfoSignInAgain,
      );
      return;
    }

    final amount = MoneyInputFormatter.parse(_amountController.text);
    if (amount == null) {
      await AppDialog.error(
        context,
        title: loc.commonInvalidAmountTitle,
        message: loc.addTransactionInvalidAmount,
      );
      return;
    }

    final title = _noteController.text.trim().isEmpty
        ? _selectedCategory
        : _noteController.text.trim();

    final transaction = TransactionModel.draft(
      title: title,
      category: _selectedCategory,
      amount: amount,
      date: _selectedDate,
      isExpense: _isExpense,
    );

    setState(() => _isSaving = true);
    SyncStatus? status;
    String? failure;
    try {
      status = await AppRepository.instance.createTransaction(
        userId,
        transaction,
      );
    } on TransactionRefusedException catch (e) {
      failure = e.messageFor(loc);
    } catch (e) {
      debugPrint('Lỗi lưu giao dịch: $e');
      failure = loc.transactionSaveFailed;
    }
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (failure != null) {
      await AppDialog.error(
        context,
        title: loc.commonSaveFailed,
        message: failure,
      );
      return;
    }
    // The transaction is on the device in either case; when the server does not have it yet, the Ledger shows it flagged
    // and offers to send it again, so the form closes instead of inviting a second, different save of the same thing.
    if (status == SyncStatus.synced) {
      await AppDialog.success(
        context,
        title: loc.commonSuccess,
        message: loc.addTransactionSaved,
      );
    } else {
      await AppDialog.warning(
        context,
        title: loc.transactionNotSentTitle,
        message: loc.transactionNotSentMessage,
      );
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final semantic = theme.semanticColors;
    final labelStyle = TextStyle(color: colors.onSurfaceVariant, fontSize: 14);
    final loc = context.loc;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.addTransactionTitle,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTypeToggle(colors, loc),
            const SizedBox(height: 32),
            Text(loc.addTransactionAmountLabel, style: labelStyle),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter(loc.localeName)],
              style: TextStyle(
                color: _isExpense ? semantic.expenseColor : colors.primary,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                  fontSize: 40,
                ),
                suffixText: loc.currencySymbol,
                suffixStyle: TextStyle(color: colors.onSurface, fontSize: 24),
                border: InputBorder.none,
              ),
            ),
            Divider(color: colors.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 24),
            Text(loc.transactionCategoryLabel, style: labelStyle),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickCategory,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        TransactionCategories.iconFor(_selectedCategory),
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        TransactionCategories.displayName(
                          loc,
                          _selectedCategory,
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(loc.transactionDateLabel, style: labelStyle),
            const SizedBox(height: 8),
            DateField(
              value: _selectedDate,
              onChanged: (date) => setState(() => _selectedDate = date),
            ),
            const SizedBox(height: 24),
            Text(loc.transactionNoteOptional, style: labelStyle),
            const SizedBox(height: 8),
            // Text, hint and fill come from the theme: onSurface, onSurfaceVariant and the surface colour.
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: loc.addTransactionNoteHint,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isSaving ? null : _saveTransaction,
                child: Text(
                  loc.addTransactionSubmit,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle(ColorScheme colors, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _setIsExpense(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isExpense ? colors.error : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    loc.transactionExpenseMoney,
                    style: TextStyle(
                      color: _isExpense
                          ? colors.onError
                          : colors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _setIsExpense(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isExpense ? colors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    loc.transactionIncomeMoney,
                    style: TextStyle(
                      color: !_isExpense
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
