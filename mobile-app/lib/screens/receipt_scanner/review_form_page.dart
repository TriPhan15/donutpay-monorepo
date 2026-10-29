import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/core/utils/money_input_formatter.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/receipt_item_model.dart';
import 'package:finance_ai_app/models/receipt_scan_result.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';
import 'package:finance_ai_app/widgets/inputs/date_field.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_image_viewer.dart';

/// A day and a time, as receipts print them and as the duplicate dialog names the day of the saved one.
const String _dateTimeFormat = 'dd/MM/yyyy HH:mm';

/// The day of the receipt in the note about the balance (day and month only).
const String _dayMonthFormat = 'dd/MM';

class ReviewFormPage extends StatefulWidget {
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
  late ReceiptModel _receipt;
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
  String _selectedCategory = TransactionCategories.food;

  /// The fields the post-processing of the scan marked as not valid: they are shown in the error colour until the user
  /// changes them. An older ai-service sends no "normalized" block, and then nothing is marked.
  bool _storeNeedsCheck = false;
  bool _totalNeedsCheck = false;
  bool _dateNeedsCheck = false;

  @override
  void initState() {
    super.initState();
    _receipt = ReceiptModel(storeName: '', date: '', items: [], tax: 0);
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
    _storeNameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

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

  /// Uploads the photo of the receipt, once. Returns false when it failed and the user would rather not save without it.
  /// The save button stops spinning while the user is asked.
  Future<bool> _ensurePhotoUploaded() async {
    _imageUrl ??= await RemoteApiHelper.instance.uploadImage(widget.imagePath);
    if (_imageUrl != null || !mounted) return true;
    setState(() => _isSaving = false);
    final loc = context.loc;
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
  Future<void> _saveToDatabase() async {
    if (_isSaving) return;
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
        message: loc.reviewTotalPositive,
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
    await _submit(userId, _draftOf(amount));
  }

  TransactionModel _draftOf(double amount) {
    final storeName = _storeNameController.text.trim();
    final rawScan = _rawScan;
    return TransactionModel.draft(
      title: storeName.isEmpty ? _selectedCategory : storeName,
      category: _selectedCategory,
      amount: amount,
      date: _selectedDate,
      isExpense: true,
      imageUrl: _imageUrl,
      rawReceiptData: rawScan == null ? null : jsonEncode(rawScan),
    );
  }

  /// Sends [draft] while the save button is disabled, then tells the user how it went. A receipt the server takes for
  /// one already saved writes nothing anywhere, not even on the device: the user is asked what to do.
  Future<void> _submit(
    int userId,
    TransactionModel draft, {
    bool allowDuplicate = false,
  }) async {
    final loc = context.loc;
    SyncStatus? status;
    String? failure;
    DuplicateReceiptException? duplicate;
    try {
      status = await AppRepository.instance.createTransaction(
        userId,
        draft,
        allowDuplicate: allowDuplicate,
      );
    } on DuplicateReceiptException catch (e) {
      debugPrint('Hóa đơn trùng với giao dịch ${e.existingTransactionId}');
      duplicate = e;
    } on TransactionRefusedException catch (e) {
      failure = e.messageFor(loc);
    } catch (e) {
      debugPrint('Lỗi lưu giao dịch từ hóa đơn: $e');
      failure = loc.transactionSaveFailed;
    }
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (duplicate != null) {
      await _askAboutDuplicate(userId, draft, duplicate);
      return;
    }
    if (failure != null) {
      await AppDialog.error(
        context,
        title: loc.commonSaveFailed,
        message: failure,
      );
      return;
    }
    if (status == SyncStatus.synced) {
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
    Navigator.pop(context, true);
  }

  /// "Save anyway" sends the same draft again with allowDuplicate; "View the saved one" opens that transaction.
  /// Dismissing the question (Back, or a tap outside it) only closes it: the form stays, and nothing is sent.
  Future<void> _askAboutDuplicate(
    int userId,
    TransactionModel draft,
    DuplicateReceiptException duplicate,
  ) async {
    final loc = context.loc;
    final savedAt = duplicate.existingTransactionDate;
    final saveAnyway = await AppDialog.choose(
      context,
      title: savedAt == null
          ? loc.reviewDuplicateTitleNoDate
          : loc.reviewDuplicateTitle(
              DateFormat(_dateTimeFormat).format(savedAt),
            ),
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
    await _submit(userId, draft, allowDuplicate: true);
  }

  /// Closes the form, which saved nothing, and shows the transaction [id] in the Ledger.
  void _openSavedTransaction(int id) {
    final openTransaction = widget.onOpenTransaction;
    if (openTransaction == null) {
      AppToast.info(context, context.loc.reviewDuplicateCannotOpen);
      return;
    }
    Navigator.pop(context, false);
    openTransaction(id);
  }

  Future<void> _pickCategory() async {
    if (TransactionCategories.expenseSelectable.isEmpty) {
      await TransactionCategories.loadFromApi();
    }

    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        final loc = sheetContext.loc;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  loc.transactionPickExpenseCategory,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...TransactionCategories.expenseSelectable.map((cat) {
                final selected = cat == _selectedCategory;
                return ListTile(
                  leading: Icon(
                    TransactionCategories.iconFor(cat),
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                  title: Text(
                    TransactionCategories.displayName(loc, cat),
                    style: TextStyle(
                      color: selected
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: selected
                      ? Icon(Icons.check_rounded, color: colors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, cat),
                );
              }),
            ],
          ),
        );
      },
    );

    if (picked != null && mounted) setState(() => _selectedCategory = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.reviewTitle),
        actions: [
          if (!_isProcessing)
            IconButton(
              tooltip: _compareMode
                  ? loc.reviewCompareOff
                  : loc.reviewCompareOn,
              icon: Icon(
                _compareMode
                    ? Icons.view_agenda_outlined
                    : Icons.vertical_split_outlined,
              ),
              onPressed: () => setState(() => _compareMode = !_compareMode),
            ),
        ],
      ),
      body: _isProcessing
          ? _buildProcessingState(colors, loc)
          : _compareMode
          ? _buildCompareContent(colors, theme.semanticColors, loc)
          : _buildFormContent(colors, theme.semanticColors, loc),
    );
  }

  Widget _buildProcessingState(ColorScheme colors, AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            loc.reviewAnalyzing,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            loc.reviewPleaseWait,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// The zoomable photo in the top half, the fields of the scan in the bottom half: each field is checked against the
  /// photo and corrected on the spot.
  Widget _buildCompareContent(
    ColorScheme colors,
    SemanticColors semantic,
    AppLocalizations loc,
  ) {
    return Column(
      children: [
        Expanded(child: ZoomableReceiptImage(imagePath: widget.imagePath)),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._buildEditableFields(colors, semantic, loc),
                const SizedBox(height: 24),
                _buildSaveButton(loc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent(
    ColorScheme colors,
    SemanticColors semantic,
    AppLocalizations loc,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(colors, loc),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.reviewExtracted,
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.reviewCheckDetails,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          _buildSectionTitle(loc.reviewGeneralInfo),
          ..._buildEditableFields(colors, semantic, loc),

          const SizedBox(height: 24),
          _buildSectionTitle(loc.commonSummary),
          // Only the card follows the amount field as it is typed in, not the whole form.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _amountController,
            builder: (_, value, _) => _buildTotalsCard(
              colors,
              semantic,
              loc,
              MoneyInputFormatter.parse(value.text) ?? 0,
            ),
          ),

          const SizedBox(height: 40),
          _buildSaveButton(loc),
        ],
      ),
    );
  }

  /// The photo of the receipt, small; a tap opens it over the whole screen. The original photo keeps its own colours
  /// in both themes: no filter over it.
  Widget _buildThumbnail(ColorScheme colors, AppLocalizations loc) {
    const width = 80.0;
    const height = 120.0;
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      label: loc.reviewOpenImage,
      child: InkWell(
        onTap: _openImageViewer,
        borderRadius: radius,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: radius,
              child: Image.file(
                File(widget.imagePath),
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: radius,
                  ),
                  child: Icon(
                    Icons.image_not_supported,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.zoom_in_rounded,
                    size: 18,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The fields of the scan the user checks: store, total, date and category. A field the scan marked as not valid
  /// keeps its error outline until the user changes it, in both layouts.
  List<Widget> _buildEditableFields(
    ColorScheme colors,
    SemanticColors semantic,
    AppLocalizations loc,
  ) {
    return [
      _buildTextField(
        colors,
        loc.reviewStoreName,
        _storeNameController,
        Icons.storefront,
        error: _storeNeedsCheck ? loc.reviewFieldNeedsCheck : null,
        onChanged: _storeNeedsCheck
            ? (_) => setState(() => _storeNeedsCheck = false)
            : null,
      ),
      const SizedBox(height: 16),
      _buildTextField(
        colors,
        loc.reviewTotalLabel,
        _amountController,
        Icons.payments_outlined,
        keyboardType: TextInputType.number,
        inputFormatters: [MoneyInputFormatter(loc.localeName)],
        error: _totalNeedsCheck ? loc.reviewFieldNeedsCheck : null,
        onChanged: _totalNeedsCheck
            ? (_) => setState(() => _totalNeedsCheck = false)
            : null,
      ),
      const SizedBox(height: 16),
      _buildFieldLabel(colors, loc.transactionDateLabel),
      DateField(
        forTransaction: true,
        value: _selectedDate,
        onChanged: _onDatePicked,
        helperText: _dateIsFallback ? loc.reviewDateFallback : null,
        helperColor: semantic.warningColor,
        // A date that is only the time of the scan already shows its own warning.
        errorText: _dateNeedsCheck && !_dateIsFallback
            ? loc.reviewFieldNeedsCheck
            : null,
      ),
      if (_isOutsideCurrentMonth) ...[
        const SizedBox(height: 8),
        _buildBalanceNote(colors, loc),
      ],
      const SizedBox(height: 16),
      _buildFieldLabel(colors, loc.transactionCategoryLabel),
      InkWell(
        onTap: _pickCategory,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                TransactionCategories.iconFor(_selectedCategory),
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  TransactionCategories.displayName(loc, _selectedCategory),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildFieldLabel(ColorScheme colors, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
      ),
    );
  }

  /// A receipt of another month still counts in today's balance: only the monthly reports place it in its own month.
  Widget _buildBalanceNote(ColorScheme colors, AppLocalizations loc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 16, color: colors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            loc.reviewOtherMonthBalanceNote(
              DateFormat(_dayMonthFormat).format(_selectedDate),
            ),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(AppLocalizations loc) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _isSaving ? null : _saveToDatabase,
        // While saving the button is disabled, so its background is the disabled grey: the spinner takes the
        // primary colour to show on it.
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                loc.reviewSubmit,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildTotalsCard(
    ColorScheme colors,
    SemanticColors semantic,
    AppLocalizations loc,
    double amount,
  ) {
    String money(double value) =>
        CurrencyHelper.formatVND(value, loc, showSign: false);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTotalRow(colors, semantic, loc.reviewSubtotal, money(amount)),
            const SizedBox(height: 8),
            _buildTotalRow(
              colors,
              semantic,
              loc.reviewTax,
              money(_receipt.tax),
            ),
            // The theme divider: the white 10% line of the old dark design did not show on the light card.
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            _buildTotalRow(
              colors,
              semantic,
              loc.reviewGrandTotal,
              money(amount),
              isGrandTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  /// Text, fill, cursor and prefix icon come from the input theme; the label keeps the secondary text colour. An
  /// [error] (a field the scan could not read for sure) is shown under it and turns the outline to the error colour.
  Widget _buildTextField(
    ColorScheme colors,
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? error,
    ValueChanged<String>? onChanged,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.error),
    );
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.onSurfaceVariant),
        errorText: error,
        errorMaxLines: 3,
        errorBorder: errorBorder,
        focusedErrorBorder: errorBorder,
        prefixIcon: Icon(icon),
        filled: true,
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary),
        ),
      ),
    );
  }

  /// The grand total is the amount spent, so it takes the expense colour.
  Widget _buildTotalRow(
    ColorScheme colors,
    SemanticColors semantic,
    String label,
    String value, {
    bool isGrandTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isGrandTotal ? colors.onSurface : colors.onSurfaceVariant,
            fontSize: isGrandTotal ? 16 : 14,
            fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isGrandTotal ? semantic.expenseColor : colors.onSurface,
            fontSize: isGrandTotal ? 20 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
