import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/models/receipt_detail.dart';
import 'package:finance_ai_app/models/receipt_status.dart';

Map<String, dynamic> _json({String status = 'COMPLETED_RAW'}) => {
  'id': 7,
  'transactionId': 42,
  'status': status,
  'version': 3,
  'vendorName': 'Highlands',
  'extractedTotal': 45000.0,
  'extractedDate': '2026-09-20',
  'imageUrl': 'https://res.cloudinary.com/demo/r7.jpg',
  'errorCode': 'AI_NO_TOTAL',
  'errorMessage': 'Khong doc duoc tong tien',
  'createdAt': '2026-09-20T08:30:00',
  'updatedAt': '2026-09-21T09:00:00',
};

ReceiptDetail _of(String status) =>
    ReceiptDetail.fromJson(_json(status: status));

void main() {
  test('fromJson reads every field', () {
    final receipt = ReceiptDetail.fromJson(_json());

    expect(receipt.id, 7);
    expect(receipt.transactionId, 42);
    expect(receipt.status, ReceiptLifecycle.completedRaw);
    expect(receipt.version, 3);
    expect(receipt.vendorName, 'Highlands');
    expect(receipt.extractedTotal, 45000);
    expect(receipt.extractedDate, DateTime(2026, 9, 20));
    expect(receipt.imageUrl, 'https://res.cloudinary.com/demo/r7.jpg');
    expect(receipt.errorCode, 'AI_NO_TOTAL');
    expect(receipt.errorMessage, 'Khong doc duoc tong tien');
    expect(receipt.createdAt, DateTime(2026, 9, 20, 8, 30));
    expect(receipt.updatedAt, DateTime(2026, 9, 21, 9));
  });

  test('fromJson accepts the optional fields as null or missing', () {
    final receipt = ReceiptDetail.fromJson({
      'id': 7,
      'transactionId': null,
      'status': 'FAILED',
      'version': 0,
      'vendorName': null,
      'extractedTotal': null,
      'extractedDate': null,
      'imageUrl': null,
      'errorCode': null,
      'errorMessage': null,
    });

    expect(receipt.transactionId, isNull);
    expect(receipt.vendorName, isNull);
    expect(receipt.extractedTotal, isNull);
    expect(receipt.extractedDate, isNull);
    expect(receipt.imageUrl, isNull);
    expect(receipt.errorCode, isNull);
    expect(receipt.errorMessage, isNull);
    expect(receipt.createdAt, isNull);
    expect(receipt.updatedAt, isNull);
  });

  test('an integer total and a blank image url are read sensibly', () {
    final receipt = ReceiptDetail.fromJson({
      ..._json(),
      'extractedTotal': 45000,
      'imageUrl': '  ',
    });

    expect(receipt.extractedTotal, 45000.0);
    expect(receipt.imageUrl, isNull);
    expect(receipt.hasImage, isFalse);
  });

  test('the status is upper-cased and trimmed', () {
    expect(_of(' failed ').status, ReceiptLifecycle.failed);
  });

  test('the actions follow the table of the backend lifecycle', () {
    // status: (edit, retry, send the amount)
    const expected = <String, (bool, bool, bool)>{
      ReceiptLifecycle.completedRaw: (true, false, false),
      ReceiptLifecycle.edited: (true, false, false),
      ReceiptLifecycle.failed: (false, true, true),
      ReceiptLifecycle.pending: (false, false, false),
      ReceiptLifecycle.processing: (false, false, false),
      ReceiptLifecycle.waitingForReview: (false, false, false),
      ReceiptLifecycle.approved: (false, false, false),
      ReceiptLifecycle.canceled: (false, false, false),
      'SOMETHING_NEW': (false, false, false),
    };
    for (final entry in expected.entries) {
      final receipt = _of(entry.key);
      expect(receipt.canEdit, entry.value.$1, reason: '${entry.key} canEdit');
      expect(receipt.canRetry, entry.value.$2, reason: '${entry.key} canRetry');
      expect(
        receipt.canSendAmount,
        entry.value.$3,
        reason: '${entry.key} canSendAmount',
      );
    }
  });

  test('a transaction row shows the old three-state name of the lifecycle', () {
    const expected = <String, ReceiptStatus?>{
      ReceiptLifecycle.completedRaw: ReceiptStatus.success,
      ReceiptLifecycle.edited: ReceiptStatus.success,
      ReceiptLifecycle.approved: ReceiptStatus.success,
      ReceiptLifecycle.failed: ReceiptStatus.failed,
      ReceiptLifecycle.pending: ReceiptStatus.processing,
      ReceiptLifecycle.processing: ReceiptStatus.processing,
      ReceiptLifecycle.waitingForReview: ReceiptStatus.processing,
      ReceiptLifecycle.canceled: null,
      'SOMETHING_NEW': null,
    };
    for (final entry in expected.entries) {
      expect(_of(entry.key).listStatus, entry.value, reason: entry.key);
    }
  });
}
