/// Why an amount typed in the "Đồng bộ tiền" sheet cannot be sent yet.
enum TopUpAmountError { empty, belowMinimum }

/// The amount of a wallet sync (T9 spec 3.9): at least [minimum], with four quick amounts under the field.
abstract final class TopUpAmount {
  /// The smallest amount a wallet accepts, in VND.
  static const double minimum = 1000;

  /// 50k, 100k, 200k, 500k.
  static const List<double> quickAmounts = [5e4, 1e5, 2e5, 5e5];

  /// Null when [amount] can be sent.
  static TopUpAmountError? validate(double? amount) {
    if (amount == null || amount <= 0) return TopUpAmountError.empty;
    if (amount < minimum) return TopUpAmountError.belowMinimum;
    return null;
  }
}
