import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/utils/money_input_formatter.dart';
import 'package:finance_ai_app/models/category_shortcuts.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ledger/widgets/category_shortcut_grid.dart';
import 'package:finance_ai_app/screens/ledger/widgets/experience_rating_field.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/screens/ledger/widgets/transaction_form_fields.dart';
import 'package:finance_ai_app/screens/ledger/widgets/transaction_form_tabs.dart';
import 'package:finance_ai_app/screens/main_tabs.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/inputs/date_field.dart';
import 'package:finance_ai_app/widgets/transactions/category_picker_sheet.dart';

/// The add form (T9 spec, 3.3, layout 2): the band with a close button, the tabs Nhập tay / Quét hóa đơn, the card
/// tabs Chi tiêu / Thu nhập over a white card (amount, category tiles, day, note, optional experience rating) and the
/// button held at the bottom, faded until the form is valid.
///
/// Always opens on the current moment, whatever period the screen that opened it shows: a new transaction is most
/// often about today, and the date field gets to another day in one tap.
class AddTransactionPage extends StatefulWidget {
  /// Told the date of the transaction once it is saved (on the server or in the outbox), before the form closes.
  final ValueChanged<DateTime>? onSaved;

  const AddTransactionPage({super.key, this.onSaved});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  static const double _gutter = 16;
  static const double _cardRadius = 20;

  bool _isExpense = true;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _reviewNoteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  double? _rating;
  bool _isSaving = false;

  /// The transactions the often used categories are counted from; empty until (and unless) they are read.
  List<TransactionModel> _history = const [];
  List<String> _shortcuts = const [];

  /// "Khác" until the categories of the server are known, so the form can be saved at once, even offline.
  String _selectedCategory = TransactionCategories.otherExpense;

  /// The category the user picked for each type (true: expense). Switching Chi → Thu → Chi brings the pick back, and
  /// once there is one a late answer of the server neither changes the choice nor moves the tiles.
  final Map<bool, String> _picked = {};

  bool get _categoryTouched => _picked.containsKey(_isExpense);

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
    // Categories cached by an earlier screen give the tiles at once; otherwise _load fetches them.
    _offerDefaultCategories();
    _load();
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _noteController.dispose();
    _reviewNoteController.dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  Future<void> _load() async {
    if (TransactionCategories.forType(isExpense: _isExpense).isEmpty) {
      await TransactionCategories.loadFromApi();
      if (!mounted) return;
      setState(() {
        if (!_categoryTouched) _offerDefaultCategories();
      });
    }
    final userId = SessionService.currentUserId;
    if (userId == null) return;
    try {
      final history = await AppRepository.instance.getTransactions(userId);
      if (!mounted) return;
      setState(() {
        _history = history;
        if (!_categoryTouched) _offerDefaultCategories();
      });
    } catch (e) {
      // The tiles keep the order of the server; nothing to tell the user.
      debugPrint('Lỗi tải giao dịch để gợi ý danh mục: $e');
    }
  }

  /// The often used categories of the current type, with the one the user picked for it selected, else the first.
  /// Without any category from the server the form falls back to "Khác", so a transaction can still be recorded.
  void _offerDefaultCategories() {
    _shortcuts = CategoryShortcuts.pick(
      available: TransactionCategories.forType(isExpense: _isExpense),
      history: _history,
      isExpense: _isExpense,
    );
    _selectedCategory =
        _picked[_isExpense] ??
        (_shortcuts.isNotEmpty
            ? _shortcuts.first
            : TransactionCategories.otherExpense);
  }

  void _setIsExpense(bool isExpense) {
    if (_isExpense == isExpense) return;
    setState(() {
      _isExpense = isExpense;
      _offerDefaultCategories();
    });
  }

  void _selectCategory(String category) {
    setState(() {
      _picked[_isExpense] = category;
      _selectedCategory = category;
    });
  }

  Future<void> _pickCategory() async {
    if (TransactionCategories.forType(isExpense: _isExpense).isEmpty) {
      await TransactionCategories.loadFromApi();
      if (!mounted) return;
    }
    final picked = await showCategoryPickerSheet(
      context,
      categories: TransactionCategories.forType(isExpense: _isExpense),
      selected: _selectedCategory,
      isExpense: _isExpense,
    );
    if (!mounted || picked == null) return;
    _selectCategory(picked);
  }

  double? get _amount => MoneyInputFormatter.parse(_amountController.text);

  bool get _isValid => _amount != null;

  bool get _hasTypedData =>
      _amountController.text.trim().isNotEmpty ||
      _noteController.text.trim().isNotEmpty ||
      (_isExpense &&
          (_rating != null ||
              _reviewNoteController.text.trim().isNotEmpty));

  /// Hands over to the scan sheet of MainScaffold: the form closes first, so the review form the scan leads to is not
  /// stacked on top of it. Typed data is not dropped without asking.
  Future<void> _openScanner() async {
    final scanner = MainTabs.scanner;
    if (scanner == null) return;
    if (_hasTypedData) {
      final loc = context.loc;
      final confirmed = await AppDialog.confirm(
        context,
        title: loc.addTransactionDiscardTitle,
        message: loc.addTransactionDiscardMessage,
        confirmText: loc.addTransactionDiscardConfirm,
      );
      if (!confirmed) return;
    }
    if (!mounted) return;
    Navigator.pop(context);
    scanner();
  }

  Future<void> _saveTransaction() async {
    final amount = _amount;
    final category = _selectedCategory;
    if (_isSaving || !mounted || amount == null) return;
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

    final note = _noteController.text.trim();
    final reviewNote = _reviewNoteController.text.trim();
    final transaction = TransactionModel.draft(
      title: note.isEmpty ? category : note,
      category: category,
      amount: amount,
      date: _selectedDate,
      isExpense: _isExpense,
      rating: _isExpense ? _rating : null,
      reviewNote: !_isExpense || reviewNote.isEmpty ? null : reviewNote,
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
    widget.onSaved?.call(transaction.date);
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    // Closing while a save runs would drop its outcome: the dialog, and the Ledger moving to the saved day.
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        body: Column(
          children: [
            PageBand(
              title: loc.addTransactionTitle,
              action: PageBandAction.close,
            ),
            Expanded(
              // The mode tabs scroll with the form: on a small phone with the keyboard up, the fields keep the room.
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  _gutter,
                  0,
                  _gutter,
                  _gutter,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EntryModeTabs(onScan: _openScanner),
                    const SizedBox(height: 12),
                    TransactionTypeTabs(
                      isExpense: _isExpense,
                      onChanged: _setIsExpense,
                    ),
                    Container(
                      padding: const EdgeInsets.all(_gutter),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(_cardRadius),
                        ),
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
                            shortcuts: _shortcuts,
                            selected: _selectedCategory,
                            onSelected: _selectCategory,
                            onMore: _pickCategory,
                          ),
                          const SizedBox(height: _gutter),
                          FormFieldLabel(loc.transactionDateLabel),
                          const SizedBox(height: 8),
                          DateField(
                            forTransaction: true,
                            value: _selectedDate,
                            onChanged: (date) =>
                                setState(() => _selectedDate = date),
                          ),
                          const SizedBox(height: _gutter),
                          NoteField(
                            controller: _noteController,
                            hintText: loc.addTransactionNoteHint,
                          ),
                          if (_isExpense) ...[
                            const SizedBox(height: _gutter),
                            ExperienceRatingField(
                              rating: _rating,
                              onRatingChanged: (value) =>
                                  setState(() => _rating = value),
                              reviewNoteController: _reviewNoteController,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            FormSubmitBar(
              label: _isExpense
                  ? loc.addTransactionSubmitExpense
                  : loc.addTransactionSubmitIncome,
              busy: _isSaving,
              onPressed: _isValid ? _saveTransaction : null,
            ),
          ],
        ),
      ),
    );
  }
}
