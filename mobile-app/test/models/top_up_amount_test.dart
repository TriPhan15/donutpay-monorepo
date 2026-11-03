import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/models/top_up_amount.dart';

void main() {
  group('TopUpAmount.validate', () {
    test('nothing typed, or zero, is empty', () {
      expect(TopUpAmount.validate(null), TopUpAmountError.empty);
      expect(TopUpAmount.validate(0), TopUpAmountError.empty);
    });

    test('under 1.000 ₫ is below the minimum', () {
      expect(TopUpAmount.validate(1), TopUpAmountError.belowMinimum);
      expect(TopUpAmount.validate(999), TopUpAmountError.belowMinimum);
    });

    test('1.000 ₫ and more is accepted', () {
      expect(TopUpAmount.validate(1000), isNull);
      expect(TopUpAmount.validate(500000), isNull);
    });

    test('1.000.000.000 ₫ is the most core-backend takes at once', () {
      expect(TopUpAmount.validate(1000000000), isNull);
      expect(TopUpAmount.validate(1000000001), TopUpAmountError.aboveMaximum);
      expect(TopUpAmount.validate(5e12), TopUpAmountError.aboveMaximum);
    });
  });

  test('the maximum is 1.000.000.000 ₫', () {
    expect(TopUpAmount.maximum, 1000000000);
  });

  test('the minimum is 1.000 ₫', () {
    expect(TopUpAmount.minimum, 1000);
  });

  test('the quick amounts are 50k, 100k, 200k and 500k', () {
    expect(TopUpAmount.quickAmounts, [50000, 100000, 200000, 500000]);
    for (final amount in TopUpAmount.quickAmounts) {
      expect(TopUpAmount.validate(amount), isNull, reason: '$amount');
    }
  });
}
