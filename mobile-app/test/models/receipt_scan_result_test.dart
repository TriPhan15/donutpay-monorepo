import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/models/receipt_scan_result.dart';

/// A /donut/scan answer for a receipt of Highlands; [normalized] is the block of the Regex post-processing.
Map<String, dynamic> _response({
  Object? total = 45000,
  String timestamp = '20/09/2026 08:30',
  String sellerName = 'Highlands',
  Map<String, dynamic>? normalized,
}) => {
  'seller': {
    'seller_name': sellerName,
    'timestamp': timestamp,
    'total_cost_number': ?total,
  },
  'normalized': ?normalized,
};

/// The "normalized" block of ai-service/receipt_postprocess.py; the address is never shown by the form.
Map<String, dynamic> _normalized({
  String seller = 'Highlands',
  bool sellerValid = true,
  String? iso = '2026-09-20T08:30:00',
  bool timestampValid = true,
  bool totalValid = true,
  String address = '',
  bool addressValid = true,
}) => {
  'seller': {'raw': seller, 'value': seller, 'valid': sellerValid},
  'address': {'raw': address, 'value': address, 'valid': addressValid},
  'timestamp': {'raw': '', 'value': '', 'iso': iso, 'valid': timestampValid},
  'total_cost': {'raw': '45000', 'value': 45000, 'valid': totalValid},
  'invalid_fields': <String>[],
};

void main() {
  test('a full normalized block with every shown field valid is allValid', () {
    final scan = ReceiptScanResult.fromResponse(
      _response(sellerName: '**Highlands**', normalized: _normalized()),
    );

    expect(scan.allValid, isTrue);
    expect(scan.invalidFields, isEmpty);
    expect(scan.storeName, 'Highlands');
    expect(scan.amount, 45000);
    expect(scan.date, DateTime(2026, 9, 20, 8, 30));
    expect(scan.category, TransactionCategories.food);
  });

  test(
    'a field marked valid:false is in invalidFields and blocks allValid',
    () {
      final scan = ReceiptScanResult.fromResponse(
        _response(normalized: _normalized(totalValid: false)),
      );

      expect(scan.invalidFields, {ReceiptScanResult.totalCostField});
      expect(scan.allValid, isFalse);
    },
  );

  test(
    'an older ai-service without the block marks nothing and uses the raw fields',
    () {
      final scan = ReceiptScanResult.fromResponse(_response());

      expect(scan.invalidFields, isEmpty);
      expect(scan.storeName, 'Highlands');
      expect(scan.amount, 45000);
      expect(scan.date, DateTime(2026, 9, 20, 8, 30));
      expect(scan.allValid, isTrue);
    },
  );

  test('a printed total is read from its digits when there is no number', () {
    final response = _response(total: null);
    (response['seller'] as Map)['total_cost'] = '52.000đ';

    expect(ReceiptScanResult.fromResponse(response).amount, 52000);

    for (final (printed, dong) in [
      ('1,011,780', 1011780),
      ('30,200.00', 30200),
      ('105 000 VND', 105000),
    ]) {
      (response['seller'] as Map)['total_cost'] = printed;
      expect(ReceiptScanResult.fromResponse(response).amount, dong, reason: printed);
    }
  });

  test('a total of 0 is no amount, and the scan is not allValid', () {
    final scan = ReceiptScanResult.fromResponse(_response(total: 0));

    expect(scan.amount, isNull);
    expect(scan.allValid, isFalse);
  });

  test('a date that cannot be parsed is null', () {
    final scan = ReceiptScanResult.fromResponse(
      _response(
        timestamp: '15:29:03',
        normalized: _normalized(iso: null, timestampValid: false),
      ),
    );

    expect(scan.date, isNull);
    expect(scan.allValid, isFalse);
  });

  test(
    'no store name leaves it empty, and the draft is titled by the category',
    () {
      final scan = ReceiptScanResult.fromResponse(_response(sellerName: ''));

      expect(scan.storeName, isEmpty);
      expect(scan.allValid, isFalse);
      expect(scan.toDraft().title, TransactionCategories.food);
    },
  );

  test('toDraft carries the raw answer, the photo and the scanned values', () {
    final response = _response(normalized: _normalized());
    final scan = ReceiptScanResult.fromResponse(response);

    final draft = scan.toDraft(imageUrl: 'u');

    expect(draft.rawReceiptData, jsonEncode(scan.raw));
    expect(draft.imageUrl, 'u');
    expect(draft.isExpense, isTrue);
    expect(draft.title, 'Highlands');
    expect(draft.category, TransactionCategories.food);
    expect(draft.amount, 45000);
    expect(draft.date, DateTime(2026, 9, 20, 8, 30));
  });

  group('address', () {
    Map<String, dynamic> withRawAddress(
      String address, {
      Map<String, dynamic>? normalized,
    }) {
      final response = _response(normalized: normalized);
      (response['seller'] as Map<String, dynamic>)['address'] = address;
      return response;
    }

    test('is read from the normalized block, trimmed', () {
      final scan = ReceiptScanResult.fromResponse(
        _response(
          normalized: _normalized(
            address: '  12 Lê Lợi, Q1 ',
            addressValid: true,
          ),
        ),
      );

      expect(scan.address, '12 Lê Lợi, Q1');
    });

    test('falls back to the raw seller address without a normalized value', () {
      final scan = ReceiptScanResult.fromResponse(
        withRawAddress(' 5 Hai Bà Trưng ', normalized: _normalized()),
      );

      expect(scan.address, '5 Hai Bà Trưng');
    });

    test('is empty when the receipt gave none', () {
      final scan = ReceiptScanResult.fromResponse(_response());

      expect(scan.address, isEmpty);
      expect(scan.toDraft().location, isNull);
    });

    test('is cut to 255 characters', () {
      final scan = ReceiptScanResult.fromResponse(
        _response(
          normalized: _normalized(address: 'a' * 300, addressValid: true),
        ),
      );

      expect(scan.address, hasLength(ReceiptScanResult.maxAddressLength));
    });

    test('is marked invalid when the scan says so, without blocking allValid', () {
      final scan = ReceiptScanResult.fromResponse(
        _response(normalized: _normalized(addressValid: false)),
      );

      expect(scan.invalidFields, {ReceiptScanResult.addressField});
      expect(scan.allValid, isTrue);
    });

    test('becomes the location of the draft', () {
      final scan = ReceiptScanResult.fromResponse(
        _response(
          normalized: _normalized(address: '12 Lê Lợi', addressValid: true),
        ),
      );

      expect(scan.toDraft().location, '12 Lê Lợi');
    });
  });

  test(
    'toJson is the raw answer, and reading it back gives the same values',
    () {
      final scan = ReceiptScanResult.fromResponse(
        _response(normalized: _normalized(sellerValid: false)),
      );

      final again = ReceiptScanResult.fromResponse(
        jsonDecode(jsonEncode(scan.toJson())) as Map<String, dynamic>,
      );

      expect(scan.toJson(), scan.raw);
      expect(again.storeName, scan.storeName);
      expect(again.amount, scan.amount);
      expect(again.date, scan.date);
      expect(again.invalidFields, scan.invalidFields);
    },
  );
}
