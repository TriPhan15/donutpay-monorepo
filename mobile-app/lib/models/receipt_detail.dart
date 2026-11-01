import 'package:finance_ai_app/models/receipt_status.dart';

/// The names of core-backend's ReceiptStatus (Entity/ReceiptStatus.java), as `ReceiptResponseDto.status` carries them.
abstract final class ReceiptLifecycle {
  static const String pending = 'PENDING';
  static const String processing = 'PROCESSING';
  static const String completedRaw = 'COMPLETED_RAW';
  static const String edited = 'EDITED';
  static const String failed = 'FAILED';
  static const String waitingForReview = 'WAITING_FOR_REVIEW';
  static const String approved = 'APPROVED';
  static const String canceled = 'CANCELED';
}

/// A receipt as its owner sees it (core-backend ReceiptResponseDto): the final fields, where it stands in the lifecycle
/// and the [version] an edit has to be based on. What the AI answered is never part of it.
class ReceiptDetail {
  const ReceiptDetail({
    required this.id,
    required this.status,
    required this.version,
    this.transactionId,
    this.vendorName,
    this.extractedTotal,
    this.extractedDate,
    this.imageUrl,
    this.errorCode,
    this.errorMessage,
    this.createdAt,
    this.updatedAt,
  });

  factory ReceiptDetail.fromJson(Map<String, dynamic> json) {
    final image = (json['imageUrl'] as String?)?.trim();
    return ReceiptDetail(
      id: (json['id'] as num).toInt(),
      transactionId: (json['transactionId'] as num?)?.toInt(),
      status: (json['status'] as String).trim().toUpperCase(),
      version: (json['version'] as num).toInt(),
      vendorName: json['vendorName'] as String?,
      extractedTotal: (json['extractedTotal'] as num?)?.toDouble(),
      extractedDate: _parseDate(json['extractedDate']),
      imageUrl: image == null || image.isEmpty ? null : image,
      errorCode: json['errorCode'] as String?,
      errorMessage: json['errorMessage'] as String?,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  static DateTime? _parseDate(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;

  final int id;
  final int? transactionId;

  /// One of the [ReceiptLifecycle] names; a name this version of the app does not know is kept as it came.
  final String status;

  /// Sent back with an edit: an edit based on an older version is answered 409.
  final int version;
  final String? vendorName;
  final double? extractedTotal;
  final DateTime? extractedDate;
  final String? imageUrl;

  /// Why the receipt is FAILED, and the fixed text that goes with it; null in every other status.
  final String? errorCode;
  final String? errorMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasImage => imageUrl != null;

  /// The owner may correct a read receipt (PUT /api/receipts/{id}).
  bool get canEdit =>
      status == ReceiptLifecycle.completedRaw ||
      status == ReceiptLifecycle.edited;

  /// A FAILED receipt can be read again (POST /api/receipts/{id}/retry).
  bool get canRetry => status == ReceiptLifecycle.failed;

  /// The owner of a FAILED receipt can send the right amount to an administrator.
  bool get canSendAmount => status == ReceiptLifecycle.failed;

  /// The state a transaction row shows for this receipt, which is the old three-state name core-backend sends in
  /// `TransactionResponseDto.receiptStatus`; null for a withdrawn receipt or a name the app does not know.
  ReceiptStatus? get listStatus => switch (status) {
    ReceiptLifecycle.completedRaw ||
    ReceiptLifecycle.edited ||
    ReceiptLifecycle.approved => ReceiptStatus.success,
    ReceiptLifecycle.failed => ReceiptStatus.failed,
    ReceiptLifecycle.pending ||
    ReceiptLifecycle.processing ||
    ReceiptLifecycle.waitingForReview => ReceiptStatus.processing,
    _ => null,
  };
}
