import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/receipt_item_model.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';

/// How the date of the transaction is shown in the form.
const String _displayDateFormat = 'dd/MM/yyyy HH:mm';

/// The ways a receipt date may come back from the scan, tried in this order. The first ones are the Vietnamese order of
/// day and month, which is what the receipts print.
const List<String> _scannedDateFormats = [
  'dd/MM/yyyy HH:mm:ss',
  _displayDateFormat,
  'dd/MM/yyyy',
  'dd-MM-yyyy HH:mm:ss',
  'dd-MM-yyyy HH:mm',
  'dd-MM-yyyy',
  'yyyy-MM-dd HH:mm:ss',
  'yyyy-MM-dd HH:mm',
  'yyyy-MM-dd',
];

const String _dateFallbackHint =
    'Không đọc được ngày trên hóa đơn, đang dùng thời điểm hiện tại. Chạm để chọn lại.';
const String _saveFailedMessage = 'Không lưu được giao dịch. Vui lòng thử lại.';
const String _notSentTitle = 'Chưa gửi được lên máy chủ';
const String _notSentMessage =
    'Giao dịch đã được lưu trên thiết bị nhưng chưa gửi được lên máy chủ. '
    'Khi có mạng, mở Sổ sách, chọn giao dịch và bấm "Gửi lại". Gửi lại sẽ không tạo giao dịch trùng.';

class ReviewFormPage extends StatefulWidget {
  final String imagePath;

  const ReviewFormPage({super.key, required this.imagePath});

  @override
  State<ReviewFormPage> createState() => _ReviewFormPageState();
}

class _ReviewFormPageState extends State<ReviewFormPage> {
  late ReceiptModel _receipt;
  bool _isProcessing = true;
  bool _isSaving = false;
  Map<String, dynamic>? _rawScan;

  /// The photo on the server, once uploaded: a second save after a failure does not upload it again.
  String? _imageUrl;

  /// The date of the transaction. [_dateIsFallback] is true while it is only the time of the scan because the receipt
  /// date could not be read, until the user picks one.
  DateTime _selectedDate = DateTime.now();
  bool _dateIsFallback = false;

  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  late final TextEditingController _dateController = TextEditingController(
    text: _formatDate(_selectedDate),
  );
  String _selectedCategory = 'Ăn uống';

  @override
  void initState() {
    super.initState();
    _receipt = ReceiptModel(storeName: '', date: '', items: [], tax: 0);
    _callDonutApi();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _callDonutApi() async {
    try {
      final result = await RemoteApiHelper.instance.scanReceipt(
        widget.imagePath,
      );

      final seller = result['seller'] is Map
          ? Map<String, dynamic>.from(result['seller'])
          : <String, dynamic>{};

      final storeName = seller['seller_name']?.toString() ?? '';
      final timestamp = seller['timestamp']?.toString() ?? '';
      final n = seller['total_cost_number'];
      final total = n is num
          ? n.toDouble()
          : (double.tryParse(
                  (seller['total_cost'] ?? '0').toString().replaceAll(
                    RegExp(r'[^\d.]'),
                    '',
                  ),
                ) ??
                0.0);
      final scannedDate = _parseScannedDate(timestamp);

      if (!mounted) return;
      setState(() {
        _rawScan = result;
        if (storeName.isNotEmpty) _storeNameController.text = storeName;
        _setDate(
          scannedDate ?? DateTime.now(),
          isFallback: scannedDate == null,
        );
        if (total > 0) _amountController.text = total.round().toString();
        _receipt = ReceiptModel(
          storeName: storeName,
          date: timestamp,
          items: [],
          tax: 0,
        );
        _isProcessing = false;
      });

      if (total == 0 && mounted) {
        _showSnack('Donut chưa đọc được tổng tiền từ ảnh — vui lòng nhập tay.');
      }
    } catch (e) {
      debugPrint('Lỗi quét hóa đơn: $e');
      if (!mounted) return;
      setState(() {
        _setDate(DateTime.now(), isFallback: true);
        _isProcessing = false;
      });
      _showSnack(
        'Quét hóa đơn thất bại (Kiểm tra AI service). Vui lòng nhập tay.',
      );
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _formatDate(DateTime date) =>
      DateFormat(_displayDateFormat).format(date);

  /// The receipt date read by the scan, or null when there is none or it is in none of [_scannedDateFormats].
  static DateTime? _parseScannedDate(String timestamp) {
    final text = timestamp.trim();
    if (text.isEmpty) return null;
    for (final pattern in _scannedDateFormats) {
      try {
        return DateFormat(pattern).parseStrict(text);
      } on FormatException {
        // Not this one; the next pattern may fit.
      }
    }
    return DateTime.tryParse(text);
  }

  /// To be called inside setState.
  void _setDate(DateTime date, {required bool isFallback}) {
    _selectedDate = date;
    _dateIsFallback = isFallback;
    _dateController.text = _formatDate(date);
  }

  Future<void> _pickDate() async {
    final pickedDay = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || pickedDay == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (!mounted) return;

    final time = pickedTime ?? TimeOfDay.fromDateTime(_selectedDate);
    setState(
      () => _setDate(
        DateTime(
          pickedDay.year,
          pickedDay.month,
          pickedDay.day,
          time.hour,
          time.minute,
        ),
        isFallback: false,
      ),
    );
  }

  /// Uploads the photo of the receipt, once. Returns false when it failed and the user would rather not save without it.
  /// The save button stops spinning while the user is asked.
  Future<bool> _ensurePhotoUploaded() async {
    _imageUrl ??= await RemoteApiHelper.instance.uploadImage(widget.imagePath);
    if (_imageUrl != null || !mounted) return true;
    setState(() => _isSaving = false);
    final withoutPhoto = await AppDialog.confirm(
      context,
      title: 'Không tải được ảnh hóa đơn',
      message:
          'Ảnh hóa đơn chưa được tải lên máy chủ. Bạn có muốn lưu giao dịch mà không kèm ảnh không?',
      confirmText: 'Lưu không kèm ảnh',
      cancelText: 'Để sau',
    );
    if (withoutPhoto && mounted) setState(() => _isSaving = true);
    return withoutPhoto;
  }

  /// Saves through AppRepository like the manual form: the transaction carries a clientId and waits on the device
  /// when it cannot be sent, so a lost answer never makes the user save (and pay) it twice.
  Future<void> _saveToDatabase() async {
    if (_isSaving) return;
    final userId = SessionService.currentUserId;
    if (userId == null) {
      await AppDialog.error(
        context,
        title: 'Phiên đăng nhập hết hạn',
        message: 'Vui lòng đăng nhập lại.',
      );
      return;
    }

    final amount = CurrencyHelper.parseAmount(_amountController.text);
    if (amount == null) {
      await AppDialog.error(
        context,
        title: 'Số tiền không hợp lệ',
        message: 'Vui lòng nhập tổng tiền lớn hơn 0.',
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

    final storeName = _storeNameController.text.trim();
    final rawScan = _rawScan;
    final transaction = TransactionModel.draft(
      title: storeName.isEmpty ? _selectedCategory : storeName,
      category: _selectedCategory,
      amount: amount,
      date: _selectedDate,
      isExpense: true,
      imageUrl: _imageUrl,
      rawReceiptData: rawScan == null ? null : jsonEncode(rawScan),
    );

    SyncStatus? status;
    String? failure;
    try {
      status = await AppRepository.instance.createTransaction(
        userId,
        transaction,
      );
    } on TransactionRefusedException catch (e) {
      failure = e.message;
    } catch (e) {
      debugPrint('Lỗi lưu giao dịch từ hóa đơn: $e');
      failure = _saveFailedMessage;
    }
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (failure != null) {
      await AppDialog.error(context, title: 'Lưu thất bại', message: failure);
      return;
    }
    if (status == SyncStatus.synced) {
      await AppDialog.success(
        context,
        title: 'Thành công',
        message: 'Đã lưu giao dịch từ hóa đơn.',
      );
    } else {
      await AppDialog.warning(
        context,
        title: _notSentTitle,
        message: _notSentMessage,
      );
    }
    if (!mounted) return;
    Navigator.pop(context, true);
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
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  'Chọn danh mục chi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    cat,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận hóa đơn')),
      body: _isProcessing
          ? _buildProcessingState(colors)
          : _buildFormContent(colors, theme.semanticColors),
    );
  }

  Widget _buildProcessingState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          const Text(
            'Đang phân tích hóa đơn...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Vui lòng đợi trong giây lát',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent(ColorScheme colors, SemanticColors semantic) {
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The original photo of the receipt keeps its own colours in both themes: no filter over it.
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(widget.imagePath),
                  width: 80,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 80,
                    height: 120,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.image_not_supported,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trích xuất thành công',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vui lòng kiểm tra lại thông tin bên dưới và đối chiếu với ảnh gốc trước khi lưu.',
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

          _buildSectionTitle('Thông tin chung'),
          _buildTextField(
            colors,
            'Tên cửa hàng',
            _storeNameController,
            Icons.storefront,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            colors,
            'Tổng tiền (đ)',
            _amountController,
            Icons.payments_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            colors,
            'Ngày giao dịch',
            _dateController,
            Icons.calendar_today,
            onTap: _pickDate,
            warning: _dateIsFallback ? _dateFallbackHint : null,
            warningColor: semantic.warningColor,
          ),
          const SizedBox(height: 16),

          Text(
            'Danh mục',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 8),
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
                      _selectedCategory,
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
          _buildSectionTitle('Tổng kết'),
          // Only the card follows the amount field as it is typed in, not the whole form.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _amountController,
            builder: (_, value, _) => _buildTotalsCard(
              colors,
              semantic,
              fmt,
              CurrencyHelper.parseAmount(value.text) ?? 0,
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
              onPressed: _isSaving ? null : _saveToDatabase,
              // While saving the button is disabled, so its background is the disabled grey: the spinner takes the
              // primary colour to show on it.
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Xác nhận & Lưu CSDL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(
    ColorScheme colors,
    SemanticColors semantic,
    NumberFormat fmt,
    double amount,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTotalRow(colors, semantic, 'Tạm tính:', fmt.format(amount)),
            const SizedBox(height: 8),
            _buildTotalRow(
              colors,
              semantic,
              'Thuế VAT/Khác:',
              fmt.format(_receipt.tax),
            ),
            // The theme divider: the white 10% line of the old dark design did not show on the light card.
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            _buildTotalRow(
              colors,
              semantic,
              'TỔNG TIỀN:',
              fmt.format(amount),
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

  /// Text, fill, cursor and prefix icon come from the input theme; the label keeps the secondary text colour. With
  /// [onTap] the field is not typed into: the tap opens a picker. [warning] is shown under it in [warningColor].
  Widget _buildTextField(
    ColorScheme colors,
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    VoidCallback? onTap,
    String? warning,
    Color? warningColor,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      readOnly: onTap != null,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.onSurfaceVariant),
        helperText: warning,
        helperMaxLines: 3,
        helperStyle: TextStyle(color: warningColor),
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
