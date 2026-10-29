import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/models/payment_order.dart';

void main() {
  final vi = AppLanguage.vietnamese.localizations;
  final en = AppLanguage.english.localizations;

  group('PaymentWallet', () {
    test('the linked wallets are VNPAY, ZaloPay and the demo wallet', () {
      expect(PaymentWallet.linked.map((w) => w.provider), [
        'VNPAY',
        'ZALOPAY',
        'MOCK',
      ]);
      expect(PaymentWallet.linked.map((w) => w.label(vi)), [
        'VNPAY',
        'ZaloPay',
        'Ví Demo',
      ]);
      expect(PaymentWallet.of('MOCK').label(en), 'Demo wallet');
    });

    test('an unknown provider is named by its code', () {
      final wallet = PaymentWallet.of('MOMO');
      expect(wallet.label(vi), 'MOMO');
      expect(wallet.logoAsset, 'assets/payment/momo.png');
    });

    test('the demo wallet has no logo image: it takes the wallet icon', () {
      expect(PaymentWallet.of('MOCK').logoAsset, isNull);
    });

    test('the logo follows the provider code', () {
      expect(
        PaymentWallet.of('ZALOPAY').logoAsset,
        'assets/payment/zalopay.png',
      );
    });
  });

  group('PaymentOrder.fromJson', () {
    test('reads an order as core-backend sends it', () {
      final order = PaymentOrder.fromJson({
        'orderCode': 'ZP1',
        'type': 'DEPOSIT',
        'status': 'PENDING',
        'amount': 200000,
        'provider': 'ZALOPAY',
        'createdAt': '2026-10-28T09:12:00',
      });
      expect(order.orderCode, 'ZP1');
      expect(order.amount, 200000);
      expect(order.isDeposit, isTrue);
      expect(order.isPending, isTrue);
      expect(order.wallet.label(vi), 'ZaloPay');
      expect(order.createdAt, DateTime(2026, 10, 28, 9, 12));
    });

    test('an amount sent as text is read as a number', () {
      expect(PaymentOrder.fromJson({'amount': '30000'}).amount, 30000);
    });

    test('an unreadable amount is 0 and a missing date is null', () {
      final order = PaymentOrder.fromJson({'amount': 'abc'});
      expect(order.amount, 0);
      expect(order.createdAt, isNull);
      expect(order.orderCode, '');
      expect(order.isPending, isFalse);
    });

    test('a time with a zone is shown in local time', () {
      final createdAt = PaymentOrder.fromJson({
        'amount': 1,
        'createdAt': '2026-10-28T02:12:00Z',
      }).createdAt!;
      expect(createdAt.isUtc, isFalse);
      expect(createdAt, DateTime.utc(2026, 10, 28, 2, 12).toLocal());
    });

    test('a withdrawal is not a deposit', () {
      expect(
        PaymentOrder.fromJson({'type': 'WITHDRAW', 'amount': 1}).isDeposit,
        isFalse,
      );
    });
  });
}
