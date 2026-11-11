import 'dart:convert';

import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

/// The ways a receipt date may come back from the scan, tried in this order. The first ones are the Vietnamese order of
/// day and month, which is what the receipts print.
const List<String> _scannedDateFormats = [
  'dd/MM/yyyy HH:mm:ss',
  'dd/MM/yyyy HH:mm',
  'dd/MM/yyyy',
  'dd-MM-yyyy HH:mm:ss',
  'dd-MM-yyyy HH:mm',
  'dd-MM-yyyy',
  'yyyy-MM-dd HH:mm:ss',
  'yyyy-MM-dd HH:mm',
  'yyyy-MM-dd',
];

/// Keys of the raw "seller" block of a /donut/scan answer.
abstract final class _RawScan {
  static const String seller = 'seller';
  static const String sellerName = 'seller_name';
  static const String address = 'address';
  static const String timestamp = 'timestamp';
  static const String totalCostNumber = 'total_cost_number';
  static const String totalCost = 'total_cost';
}

/// Keys of the "normalized" block that ai-service adds to a scan (ai-service/receipt_postprocess.py).
abstract final class _NormalizedScan {
  static const String block = 'normalized';
  static const String value = 'value';
  static const String iso = 'iso';
  static const String valid = 'valid';
}

/// What one /donut/scan answer means for a transaction: the values the review form starts with, and the draft that the
/// review form and the batch confirmation both save.
class ReceiptScanResult {
  /// The fields of the "normalized" block the review form shows; only these can be marked as needing a check, since
  /// the user could not correct any other one before saving.
  static const String sellerField = 'seller';
  static const String addressField = 'address';
  static const String timestampField = 'timestamp';
  static const String totalCostField = 'total_cost';
  static const Set<String> checkedFields = {
    sellerField,
    addressField,
    timestampField,
    totalCostField,
  };

  /// The longest location core-backend takes (TEXT_MAX_LENGTH).
  static const int maxAddressLength = 255;

  /// '' when the receipt gave no store name.
  final String storeName;

  /// '' when the receipt gave no address; at most [maxAddressLength] characters.
  final String address;

  /// Null when the total could not be read or is not above zero.
  final double? amount;

  /// Null when the receipt date could not be parsed.
  final DateTime? date;

  /// The category the review form starts with.
  final String category;

  /// The /donut/scan answer as received, sent as rawReceiptData.
  final Map<String, dynamic> raw;

  /// The keys of [checkedFields] that the "normalized" block marks with valid=false. An older ai-service sends no such
  /// block, and then nothing is marked.
  final Set<String> invalidFields;

  const ReceiptScanResult({
    required this.storeName,
    this.address = '',
    required this.amount,
    required this.date,
    required this.category,
    required this.raw,
    required this.invalidFields,
  });

  factory ReceiptScanResult.fromResponse(Map<String, dynamic> response) {
    final raw = Map<String, dynamic>.from(response);
    final seller = raw[_RawScan.seller] is Map
        ? Map<String, dynamic>.from(raw[_RawScan.seller] as Map)
        : <String, dynamic>{};
    final normalized = raw[_NormalizedScan.block] is Map
        ? Map<String, dynamic>.from(raw[_NormalizedScan.block] as Map)
        : null;

    final normalizedStore = _normalizedString(
      normalized,
      sellerField,
      _NormalizedScan.value,
    );
    final normalizedAddress = _normalizedString(
      normalized,
      addressField,
      _NormalizedScan.value,
    );
    final total = _totalOf(seller);
    return ReceiptScanResult(
      storeName: normalizedStore.isNotEmpty
          ? normalizedStore
          : seller[_RawScan.sellerName]?.toString() ?? '',
      address: _capped(
        normalizedAddress.isNotEmpty
            ? normalizedAddress
            : seller[_RawScan.address]?.toString() ?? '',
      ),
      amount: total > 0 ? total : null,
      date:
          DateTime.tryParse(
            _normalizedString(normalized, timestampField, _NormalizedScan.iso),
          ) ??
          _parseScannedDate(seller[_RawScan.timestamp]?.toString() ?? ''),
      category: TransactionCategories.food,
      raw: raw,
      invalidFields: {
        for (final field in checkedFields)
          if (_isMarkedInvalid(normalized, field)) field,
      },
    );
  }

  /// True when the receipt can be saved as it is, without a review. A doubtful or missing address does not count: it
  /// is optional.
  bool get allValid =>
      invalidFields.difference({addressField}).isEmpty &&
      amount != null &&
      date != null &&
      storeName.isNotEmpty;

  /// The answer as received, to be kept on the device and read back with [ReceiptScanResult.fromResponse].
  Map<String, dynamic> toJson() => raw;

  /// The transaction this scan stands for, by the same rule as the review form: the title is the store name, or the
  /// category when there is none. Meant for an [allValid] scan; otherwise a missing total is 0 and a missing date is now.
  TransactionModel toDraft({String? imageUrl}) => TransactionModel.draft(
    title: storeName.isEmpty ? category : storeName,
    category: category,
    amount: amount ?? 0,
    date: date ?? DateTime.now(),
    isExpense: true,
    imageUrl: imageUrl,
    rawReceiptData: jsonEncode(raw),
    location: address.isEmpty ? null : address,
  );

  /// The total of the raw seller block: the number ai-service read, else the digits of the printed total, else 0.
  static double _totalOf(Map<String, dynamic> seller) {
    final number = seller[_RawScan.totalCostNumber];
    if (number is num) return number.toDouble();
    final printed = (seller[_RawScan.totalCost] ?? '0').toString().trim();
    // Dong are whole: "." and "," group thousands ("52.000đ", "1,011,780"); only a 1-2 digit tail ("30,200.00") is cents.
    final withoutCents = printed.replaceFirst(RegExp(r'[.,]\d{1,2}\D*$'), '');
    return double.tryParse(withoutCents.replaceAll(RegExp(r'\D'), '')) ?? 0.0;
  }

  static String _capped(String text) {
    final trimmed = text.trim();
    return trimmed.length <= maxAddressLength
        ? trimmed
        : trimmed.substring(0, maxAddressLength).trim();
  }

  /// `normalized[field][key]` as text, or '' when the scan has no such value.
  static String _normalizedString(
    Map<String, dynamic>? normalized,
    String field,
    String key,
  ) {
    final entry = normalized?[field];
    return entry is Map ? (entry[key]?.toString() ?? '') : '';
  }

  /// True only when the scan says outright that [field] is not valid.
  static bool _isMarkedInvalid(Map<String, dynamic>? normalized, String field) {
    final entry = normalized?[field];
    return entry is Map && entry[_NormalizedScan.valid] == false;
  }

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
}
