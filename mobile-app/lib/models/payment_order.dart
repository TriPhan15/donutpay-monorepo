import 'package:finance_ai_app/l10n/app_localizations.dart';

/// Order states core-backend sends for a deposit or withdrawal.
const String paymentStatusSuccess = 'SUCCESS';
const String paymentStatusFailed = 'FAILED';
const String paymentStatusCancelled = 'CANCELLED';
const String paymentStatusPending = 'PENDING';

/// The order type of a sync from a wallet into the spending budget.
const String paymentTypeDeposit = 'DEPOSIT';

/// A payment gateway the app can sync from: its provider code and brand name. The demo wallet has no brand; its name
/// follows the language.
class PaymentWallet {
  const PaymentWallet(this.provider, this.brand);

  static const String demoProvider = 'MOCK';

  /// The wallets shown as linked, in their order on the page.
  static const List<PaymentWallet> linked = [
    PaymentWallet('VNPAY', 'VNPAY'),
    PaymentWallet('ZALOPAY', 'ZaloPay'),
    PaymentWallet(demoProvider, null),
  ];

  final String provider;
  final String? brand;

  /// The linked wallet with [provider]; an unknown code becomes a wallet named by that code.
  static PaymentWallet of(String provider) {
    for (final wallet in linked) {
      if (wallet.provider == provider) return wallet;
    }
    return PaymentWallet(provider, provider);
  }

  String label(AppLocalizations loc) => brand ?? loc.linkedDemoWallet;

  /// The logo image in assets/payment, named after the provider code; null for the demo wallet, which has no brand and
  /// shows the wallet icon of the theme.
  String? get logoAsset => provider == demoProvider
      ? null
      : 'assets/payment/${provider.toLowerCase()}.png';
}

/// One deposit or withdrawal of the history, read leniently: core-backend may send the amount as text.
class PaymentOrder {
  const PaymentOrder({
    required this.orderCode,
    required this.type,
    required this.status,
    required this.amount,
    required this.provider,
    this.createdAt,
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];
    return PaymentOrder(
      orderCode: '${json['orderCode'] ?? ''}',
      type: '${json['type'] ?? ''}',
      status: '${json['status'] ?? ''}',
      amount: amount is num
          ? amount.toDouble()
          : double.tryParse('$amount') ?? 0,
      provider: '${json['provider'] ?? ''}',
      // A time with a zone ("…Z") is shown in the time of the phone.
      createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal(),
    );
  }

  final String orderCode;
  final String type;
  final String status;
  final double amount;
  final String provider;
  final DateTime? createdAt;

  bool get isDeposit => type == paymentTypeDeposit;
  bool get isPending => status == paymentStatusPending;
  PaymentWallet get wallet => PaymentWallet.of(provider);
}
