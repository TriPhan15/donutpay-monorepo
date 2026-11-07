import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/constants/input_limits.dart';
import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/money_input_formatter.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/models/receipt_scan_result.dart';
import 'package:finance_ai_app/models/review_exit.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ledger/widgets/category_shortcut_grid.dart';
import 'package:finance_ai_app/screens/ledger/widgets/experience_rating_field.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/screens/ledger/widgets/transaction_form_fields.dart';
import 'package:finance_ai_app/screens/receipt_scanner/receipt_submitter.dart';
import 'package:finance_ai_app/screens/receipt_scanner/widgets/needs_check_field.dart';
import 'package:finance_ai_app/screens/receipt_scanner/widgets/receipt_photo_header.dart';
import 'package:finance_ai_app/screens/receipt_scanner/widgets/receipt_step_band.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';
import 'package:finance_ai_app/widgets/inputs/date_field.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_image_viewer.dart';
import 'package:finance_ai_app/widgets/transactions/category_picker_sheet.dart';

/// The day of the receipt in the note about the balance (day and month only).
const String _dayMonthFormat = 'dd/MM';

/// The receipt review form (T9 spec, 3.1): the band with the steps Ảnh → Kiểm tra → Lưu, the photo, the store, total,
/// date and category of the scan (a field the AI doubts outlined in dashes), and "Lưu & quét tiếp" / "Lưu" at the
/// bottom. Closes with a [ReviewExit] once saved, with null otherwise.
class ReviewFormPage extends StatefulWidget {
  /// The categories offered as tiles, besides the one the AI guessed (D1 of the T9 plan, batch 6).
  static const List<String> shortcutCategories = [
    TransactionCategories.food,
    TransactionCategories.shopping,
    TransactionCategories.transport,
  ];

  @visibleForTesting
  static const Key storeFieldKey = ValueKey('review-store');
  @visibleForTesting
  static const Key totalFieldKey = ValueKey('review-total');

  final String imagePath;

  /// Shows a transaction (by its server id) in the Ledger, the way a notification does; the form closes itself first.
  /// Used by "View the saved one" when the server takes the receipt for one already saved.
  final ValueChanged<int>? onOpenTransaction;

  /// A scan already read (by the scan queue): the form starts with it and does not send the photo to DONUT again.
  final ReceiptScanResult? initialScan;

  const ReviewFormPage({
    super.key,
    required this.imagePath,
    this.onOpenTransaction,
    this.initialScan,
  });

  @override
  State<ReviewFormPage> createState() => _ReviewFormPageState();
}

class _ReviewFormPageState extends State<ReviewFormPage> {
  static const double _gutter = 16;
  static const double _cardRadius = 20;

  bool _isProcessing = true;

  /// True from the tap on the save button until the answer, and again while a "save anyway" is sent: the button is
  /// disabled meanwhile, so one receipt is never sent twice.
  bool _isSaving = false;

  /// The photo in the top half and the fields under it, to check one against the other.
  bool _compareMode = false;
  Map<String, dynamic>? _rawScan;

  /// The photo on the server, once uploaded: a second save after a failure does not upload it again.
  String? _imageUrl;

  /// The date of the transaction. [_dateIsFallback] is true while it is only the time of the scan because the receipt
  /// date could not be read, until the user picks one.
  DateTime _selectedDate = DateTime.now();
  bool _dateIsFallback = false;

  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reviewNoteController = TextEditingController();
  String _selectedCategory = TransactionCategories.food;
  double? _rating;
  List<TransactionModel> _history = const [];

  /// The fields the post-processing of the scan marked as not valid: they are shown in the error colour until the user
  /// changes them. An older ai-service sends no "normalized" block, and then nothing is marked.
  bool _storeNeedsCheck = false;
  bool _totalNeedsCheck = false;
  bool _dateNeedsCheck = false;

  @override
  void initState() {
    super.initState();
    _storeNameController.addListener(_onStoreTextChanged);
    final scan = widget.initialScan;
    if (scan == null) {
      _callDonutApi();
    } else {
      // The amount is formatted for the locale of the context, which initState cannot read yet.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyScan(scan);
      });
    }
  }

  @override
  void dispose() {
    _storeNameController.removeListener(_onStoreTextChanged);
    _storeNameController.dispose();
    _amountController.dispose();
    _reviewNoteController.dispose();
    super.dispose();
  }

  void _onStoreTextChanged() => setState(() {});

  Future<void> _loadHistory() async {
    final userId = SessionService.currentUserId;
    if (userId == null) return;
    try {
      final txs = await RemoteApiHelper.instance.fetchTransactions();
      if (!mounted) return;
      setState(() => _history = txs);
    } catch (_) {
      // Past store rating hint is optional; ignore network errors here.
    }
  }

  /// Computes average rating and count for the currently typed store name from [_history].
  ({double avg, int count})? get _pastStoreRating {
    final store = _storeNameController.text.trim().toLowerCase();
    if (store.isEmpty) return null;
    var sum = 0.0;
    var count = 0;
    for (final tx in _history) {
      if (tx.isExpense &&
          tx.rating != null &&
          tx.title.trim().toLowerCase() == store) {
        sum += tx.rating!;
        count++;
      }
    }
    if (count == 0) return null;
    return (avg: sum / count, count: count);
  }

  /// The buttons follow the total: faded while it is not a positive amount.
  bool get _canSave =>
      MoneyInputFormatter.parse(_amountController.text) != null;

  /// Reads the photo with DONUT, unless the form was opened with a scan already read (the scan queue).
  Future<void> _callDonutApi() async {
    try {
      final result = await RemoteApiHelper.instance.scanReceipt(
        widget.imagePath,
      );
      if (!mounted) return;
      _applyScan(ReceiptScanResult.fromResponse(result));
    } catch (e) {
      debugPrint('Lỗi quét hóa đơn: $e');
      if (!mounted) return;
      setState(() {
        _setDate(DateTime.now(), isFallback: true);
        _isProcessing = false;
      });
      AppToast.error(context, context.loc.reviewScanFailed);
    }
  }

  /// Fills the form with [scan]: the fields it marks as not valid are outlined, and a date it could not read falls back
  /// to now with a warning.
  void _applyScan(ReceiptScanResult scan) {
    final amount = scan.amount;
    final date = scan.date;
    setState(() {
      _rawScan = scan.raw;
      _selectedCategory = scan.category;
      if (scan.storeName.isNotEmpty) _storeNameController.text = scan.storeName;
      _setDate(date ?? DateTime.now(), isFallback: date == null);
      if (amount != null) {
        _amountController.text = MoneyInputFormatter.format(
          amount,
          context.loc.localeName,
        );
      }
      _storeNeedsCheck = scan.invalidFields.contains(
        ReceiptScanResult.sellerField,
      );
      _totalNeedsCheck = scan.invalidFields.contains(
        ReceiptScanResult.totalCostField,
      );
      _dateNeedsCheck = scan.invalidFields.contains(
        ReceiptScanResult.timestampField,
      );
      _isProcessing = false;
    });

    _loadHistory();
    if (amount == null) AppToast.info(context, context.loc.reviewNoTotal);
  }

  /// To be called inside setState.
  void _setDate(DateTime date, {required bool isFallback}) {
    _selectedDate = date;
    _dateIsFallback = isFallback;
    _dateNeedsCheck = false;
  }

  /// A day picked in the date field; it keeps the time read from the receipt.
  void _onDatePicked(DateTime date) =>
      setState(() => _setDate(date, isFallback: false));

  /// True when the receipt is from another month than this one: it still changes today's balance, which may surprise.
  bool get _isOutsideCurrentMonth {
    final now = DateTime.now();
    return _selectedDate.year != now.year || _selectedDate.month != now.month;
  }

  void _openImageViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ReceiptImageViewerPage(imagePath: widget.imagePath),
      ),
    );
  }

  /// Uploads the photo of the receipt, once. A failure is told in a toast with its reason, then the user is asked; false
  /// when the user would rather not save without the photo. The save button stops spinning while the user is asked.
  Future<bool> _ensurePhotoUploaded() async {
    if (_imageUrl != null) return true;
    Object? failure;
    try {
      _imageUrl = await RemoteApiHelper.instance.uploadImage(widget.imagePath);
    } catch (e) {
      UserFacingError.log('Upload receipt photo', e);
      failure = e;
    }
    if (failure == null || !mounted) return true;
    setState(() => _isSaving = false);
    final loc = context.loc;
    AppToast.error(
      context,
      loc.reviewPhotoUploadFailedToast(
        UserFacingError.messageOf(
          failure,
          loc,
          rejectedMessage: loc.reviewPhotoRejected,
        ),
      ),
    );
    final withoutPhoto = await AppDialog.confirm(
      context,
      title: loc.reviewPhotoUploadFailedTitle,
      message: loc.reviewPhotoUploadFailedMessage,
      confirmText: loc.reviewSaveWithoutPhoto,
      cancelText: loc.reviewLater,
    );
    if (withoutPhoto && mounted) setState(() => _isSaving = true);
    return withoutPhoto;
  }

  /// Saves through AppRepository like the manual form: the transaction carries a clientId and waits on the device
  /// when it cannot be sent, so a lost answer never makes the user save (and pay) it twice.
  Future<void> _saveToDatabase(ReviewExit exit) async {
    final amount = MoneyInputFormatter.parse(_amountController.text);
    if (_isSaving || amount == null) return;
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

    setState(() => _isSaving = true);
    final keepGoing = await _ensurePhotoUploaded();
    if (!mounted) return;
    if (!keepGoing) {
      setState(() => _isSaving = false);
      return;
    }
    await _submit(userId, _draftOf(amount), exit);
  }

  TransactionModel _draftOf(double amount) {
    final storeName = _storeNameController.text.trim();
    final reviewNote = _reviewNoteController.text.trim();
    final rawScan = _rawScan;
    return TransactionModel.draft(
      title: storeName.isEmpty ? _selectedCategory : storeName,
      category: _selectedCategory,
      amount: amount,
      date: _selectedDate,
      isExpense: true,
      imageUrl: _imageUrl,
      rawReceiptData: rawScan == null ? null : jsonEncode(rawScan),
      rating: _rating,
      reviewNote: reviewNote.isEmpty ? null : reviewNote,
    );
  }

  /// Sends [draft] while the save button is disabled, then tells the user how it went. A receipt the server takes for
  /// one already saved writes nothing anywhere, not even on the device: the user is asked what to do.
  Future<void> _submit(
    int userId,
    TransactionModel draft,
    ReviewExit exit, {
    bool allowDuplicate = false,
  }) async {
    final loc = context.loc;
    final result = await ReceiptSubmitter.send(
      userId,
      draft,
      loc,
      allowDuplicate: allowDuplicate,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    final duplicate = result.duplicate;
    if (duplicate != null) {
      await _askAboutDuplicate(userId, draft, duplicate, exit);
      return;
    }
    final failure = result.failure;
    if (failure != null) {
      await AppDialog.error(
        context,
        title: loc.commonSaveFailed,
        message: failure,
      );
      return;
    }
    if (result.status == SyncStatus.synced) {
      await AppDialog.success(
        context,
        title: loc.commonSuccess,
        message: loc.reviewSaved,
      );
    } else {
      await AppDialog.warning(
        context,
        title: loc.transactionNotSentTitle,
        message: loc.transactionNotSentMessage,
      );
    }
    if (!mounted) return;
    Navigator.pop(context, exit);
  }

  /// "Save anyway" sends the same draft again with allowDuplicate; "View the saved one" opens that transaction.
  /// Dismissing the question (Back, or a tap outside it) only closes it: the form stays, and nothing is sent.
  Future<void> _askAboutDuplicate(
    int userId,
    TransactionModel draft,
    DuplicateReceiptException duplicate,
    ReviewExit exit,
  ) async {
    final loc = context.loc;
    final saveAnyway = await AppDialog.choose(
      context,
      title: ReceiptSubmitter.duplicateTitle(loc, duplicate),
      message: loc.reviewDuplicateMessage,
      confirmText: loc.reviewDuplicateSaveAnyway,
      cancelText: loc.reviewDuplicateView,
    );
    if (!mounted || saveAnyway == null) return;
    if (!saveAnyway) {
      _openSavedTransaction(duplicate.existingTransactionId);
      return;
    }
    setState(() => _isSaving = true);
    await _submit(userId, draft, exit, allowDuplicate: true);
  }

  /// Closes the form, which saved nothing, and shows the transaction [id] in the Ledger.
  void _openSavedTransaction(int id) {
    final openTransaction = widget.onOpenTransaction;
    if (openTransaction == null) {
      AppToast.info(context, context.loc.reviewDuplicateCannotOpen);
      return;
    }
    Navigator.pop(context);
    openTransaction(id);
  }

  Future<void> _pickCategory() async {
    if (TransactionCategories.expenseSelectable.isEmpty) {
      await TransactionCategories.loadFromApi();
      if (!mounted) return;
    }
    final picked = await showCategoryPickerSheet(
      context,
      categories: TransactionCategories.expenseSelectable,
      selected: _selectedCategory,
      isExpense: true,
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedCategory = picked);
  }

  /// The fixed tiles the server offers; all three while its list is not loaded.
  List<String> get _shortcuts {
    final offered = TransactionCategories.expenseSelectable;
    return [
      for (final category in ReviewFormPage.shortcutCategories)
        if (offered.isEmpty || offered.contains(category)) category,
    ];
  }

  String? get _dateHint {
    if (_dateIsFallback) return context.loc.reviewDateHint;
    return _dateNeedsCheck ? context.loc.reviewDateDoubtHint : null;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final pastRating = _pastStoreRating;
    final fields = _ReviewFields(
      storeController: _storeNameController,
      amountController: _amountController,
      storeNeedsCheck: _storeNeedsCheck,
      totalNeedsCheck: _totalNeedsCheck,
      onStoreChanged: _storeNeedsCheck
          ? (_) => setState(() => _storeNeedsCheck = false)
          : null,
      onTotalChanged: _totalNeedsCheck
          ? (_) => setState(() => _totalNeedsCheck = false)
          : null,
      pastStoreRating: pastRating,
      date: _selectedDate,
      dateHint: _dateHint,
      onDatePicked: _onDatePicked,
      outsideCurrentMonth: _isOutsideCurrentMonth,
      shortcuts: _shortcuts,
      category: _selectedCategory,
      onCategory: (category) => setState(() => _selectedCategory = category),
      onMoreCategories: _pickCategory,
      rating: _rating,
      onRatingChanged: (value) => setState(() => _rating = value),
      reviewNoteController: _reviewNoteController,
    );
    return Scaffold(
      body: Column(
        children: [
          ReceiptStepBand(
            compareOn: _compareMode,
            onToggleCompare: _isProcessing
                ? null
                : () => setState(() => _compareMode = !_compareMode),
          ),
          Expanded(
            child: _isProcessing
                ? const _Analyzing()
                : _compareMode
                // The zoomable photo in the top half, the fields under it: each field is checked against the photo.
                ? Column(
                    children: [
                      Expanded(
                        child: ZoomableReceiptImage(
                          imagePath: widget.imagePath,
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(_gutter),
                          child: fields,
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(_gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ReceiptPhotoHeader(
                          imagePath: widget.imagePath,
                          onOpen: _openImageViewer,
                        ),
                        const SizedBox(height: _gutter),
                        Container(
                          padding: const EdgeInsets.all(_gutter),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(_cardRadius),
                          ),
                          child: fields,
                        ),
                      ],
                    ),
                  ),
          ),
          if (!_isProcessing)
            // Only the buttons follow the total as it is typed: the rest of the form is not rebuilt.
            ListenableBuilder(
              listenable: _amountController,
              builder: (context, _) => FormSubmitBar(
                label: loc.reviewSave,
                busy: _isSaving,
                onPressed: _canSave
                    ? () => _saveToDatabase(ReviewExit.saved)
                    : null,
                secondaryLabel: loc.reviewSaveAndScan,
                onSecondary: () => _saveToDatabase(ReviewExit.savedScanNext),
              ),
            ),
        ],
      ),
    );
  }
}

/// The fields of the scan the user checks: store, total, date, category, and optional experience rating.
class _ReviewFields extends StatelessWidget {
  const _ReviewFields({
    required this.storeController,
    required this.amountController,
    required this.storeNeedsCheck,
    required this.totalNeedsCheck,
    required this.onStoreChanged,
    required this.onTotalChanged,
    required this.pastStoreRating,
    required this.date,
    required this.dateHint,
    required this.onDatePicked,
    required this.outsideCurrentMonth,
    required this.shortcuts,
    required this.category,
    required this.onCategory,
    required this.onMoreCategories,
    required this.rating,
    required this.onRatingChanged,
    required this.reviewNoteController,
  });

  static const double _gap = 16;

  final TextEditingController storeController;
  final TextEditingController amountController;
  final bool storeNeedsCheck;
  final bool totalNeedsCheck;
  final ValueChanged<String>? onStoreChanged;
  final ValueChanged<String>? onTotalChanged;
  final ({double avg, int count})? pastStoreRating;
  final DateTime date;
  final String? dateHint;
  final ValueChanged<DateTime> onDatePicked;
  final bool outsideCurrentMonth;
  final List<String> shortcuts;
  final String category;
  final ValueChanged<String> onCategory;
  final VoidCallback onMoreCategories;
  final double? rating;
  final ValueChanged<double?> onRatingChanged;
  final TextEditingController reviewNoteController;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final past = pastStoreRating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeedsCheckField(
          needsCheck: storeNeedsCheck,
          hint: loc.reviewStoreHint,
          child: TextField(
            key: ReviewFormPage.storeFieldKey,
            controller: storeController,
            onChanged: onStoreChanged,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [
              LengthLimitingTextInputFormatter(InputLimits.noteMaxLength),
            ],
            style: const TextStyle(fontSize: AppTextSize.body),
            decoration: InputDecoration(
              labelText: loc.reviewStoreName,
              prefixIcon: const Icon(Icons.storefront_outlined),
            ),
          ),
        ),
        if (past != null) ...[
          const SizedBox(height: 8),
          _PastStoreRatingBanner(
            storeName: storeController.text.trim(),
            avg: past.avg,
            count: past.count,
          ),
        ],
        const SizedBox(height: _gap),
        NeedsCheckField(
          needsCheck: totalNeedsCheck,
          hint: loc.reviewTotalHint,
          child: AmountField(
            key: ReviewFormPage.totalFieldKey,
            controller: amountController,
            label: loc.reviewTotal,
            onChanged: onTotalChanged,
          ),
        ),
        const SizedBox(height: _gap),
        NeedsCheckField(
          label: loc.transactionDateLabel,
          required: true,
          needsCheck: dateHint != null,
          hint: dateHint,
          child: DateField(
            forTransaction: true,
            value: date,
            onChanged: onDatePicked,
          ),
        ),
        if (outsideCurrentMonth) ...[
          const SizedBox(height: 8),
          _BalanceNote(date: date),
        ],
        const SizedBox(height: _gap),
        FormFieldLabel(loc.transactionCategoryLabel, required: true),
        const SizedBox(height: 8),
        CategoryShortcutGrid(
          shortcuts: shortcuts,
          selected: category,
          onSelected: onCategory,
          onMore: onMoreCategories,
        ),
        const SizedBox(height: _gap),
        ExperienceRatingField(
          rating: rating,
          onRatingChanged: onRatingChanged,
          reviewNoteController: reviewNoteController,
        ),
      ],
    );
  }
}

class _PastStoreRatingBanner extends StatelessWidget {
  const _PastStoreRatingBanner({
    required this.storeName,
    required this.avg,
    required this.count,
  });

  final String storeName;
  final double avg;
  final int count;

  @override
  Widget build(BuildContext context) {
    final semantic = context.colors;
    final tone = avg <= 2.0
        ? semantic.expenseColor
        : (avg <= 3.5 ? semantic.warningColor : semantic.successColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 16, color: tone),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.loc.reviewPastStoreRating(
                storeName,
                avg.toStringAsFixed(1),
                count,
              ),
              style: TextStyle(
                color: tone,
                fontSize: AppTextSize.caption,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A receipt of another month still counts in today's balance: only the monthly reports place it in its own month.
class _BalanceNote extends StatelessWidget {
  const _BalanceNote({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 16, color: colors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            context.loc.reviewOtherMonthBalanceNote(
              DateFormat(_dayMonthFormat).format(date),
            ),
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: AppTextSize.caption,
            ),
          ),
        ),
      ],
    );
  }
}

/// While DONUT reads the photo: the spinner of the theme and what is going on.
class _Analyzing extends StatelessWidget {
  const _Analyzing();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              loc.reviewAnalyzing,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: AppTextSize.title,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              loc.reviewPleaseWait,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: AppTextSize.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
