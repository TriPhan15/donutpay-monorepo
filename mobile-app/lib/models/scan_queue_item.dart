import 'dart:convert';

import 'package:finance_ai_app/models/receipt_scan_result.dart';

/// Where a receipt of the scan queue stands; stored by [name].
enum ScanQueueStatus {
  queued,
  reading,
  ready,
  failed;

  /// The status stored as [stored]; an unknown value (a newer app wrote it) reads as queued, so it is read again.
  static ScanQueueStatus fromName(String stored) => values.firstWhere(
    (status) => status.name == stored,
    orElse: () => ScanQueueStatus.queued,
  );
}

/// Why the reading of a receipt failed, stored in [ScanQueueItem.error]; the screens turn each code into a text.
abstract final class ScanQueueError {
  /// The AI service could not be reached (no network, timeout).
  static const String network = 'network';

  /// The AI service answered with an error, or with something that is not a scan.
  static const String server = 'server';

  /// The copy of the image on this device is gone.
  static const String missingImage = 'missing_image';
}

/// One receipt image of the scan queue of a user, a row of the receipt_scan_queue table.
class ScanQueueItem {
  static const String columnId = 'id';
  static const String columnUserId = 'user_id';
  static const String columnImagePath = 'image_path';
  static const String columnStatus = 'status';
  static const String columnResultJson = 'result_json';
  static const String columnError = 'error';
  static const String columnCreatedAt = 'created_at';

  final int id;
  final int userId;

  /// The copy of the image in the folder of the app.
  final String imagePath;
  final ScanQueueStatus status;

  /// What the scan read; only a [ScanQueueStatus.ready] item has one.
  final ReceiptScanResult? result;

  /// One of [ScanQueueError]; only a [ScanQueueStatus.failed] item has one.
  final String? error;
  final DateTime createdAt;

  const ScanQueueItem({
    required this.id,
    required this.userId,
    required this.imagePath,
    required this.status,
    required this.result,
    required this.error,
    required this.createdAt,
  });

  factory ScanQueueItem.fromDbMap(Map<String, Object?> row) {
    final resultJson = row[columnResultJson] as String?;
    return ScanQueueItem(
      id: row[columnId] as int,
      userId: row[columnUserId] as int,
      imagePath: row[columnImagePath] as String,
      status: ScanQueueStatus.fromName(row[columnStatus] as String),
      result: resultJson == null
          ? null
          : ReceiptScanResult.fromResponse(
              Map<String, dynamic>.from(jsonDecode(resultJson) as Map),
            ),
      error: row[columnError] as String?,
      createdAt: DateTime.parse(row[columnCreatedAt] as String),
    );
  }
}
