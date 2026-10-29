import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/payment_order.dart';
import 'package:finance_ai_app/screens/linked/widgets/wallet_logo.dart';
import 'package:finance_ai_app/screens/payment/widgets/payment_status_pill.dart';

/// The signed amount of [order]: "+" for a deposit, "-" for a withdrawal.
String paymentOrderAmount(PaymentOrder order, AppLocalizations loc) =>
    '${order.isDeposit ? '+' : '-'}'
    '${CurrencyHelper.formatVND(order.amount, loc, showSign: false)}';

/// One order of the deposit/withdrawal history (T9 spec 3.9, mockup R3): the wallet logo and name, the amount (green
/// once a deposit succeeded, struck through when cancelled, muted when it failed), the type and time, and the state
/// pill. Tapping it opens the order details.
class PaymentOrderRow extends StatelessWidget {
  PaymentOrderRow({required this.order, required this.onTap})
    : super(key: keyOf(order.orderCode));

  static Key keyOf(String orderCode) => ValueKey('payment-order-$orderCode');

  static const double _logoSize = 38;

  final PaymentOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final status = order.status;
    final createdAt = order.createdAt;
    final amountColor = switch (status) {
      paymentStatusSuccess when order.isDeposit => context.colors.incomeColor,
      paymentStatusCancelled || paymentStatusFailed => colors.onSurfaceVariant,
      _ => colors.onSurface,
    };
    final type = order.isDeposit ? loc.paymentDeposit : loc.paymentWithdrawal;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            WalletLogo(order.wallet, size: _logoSize),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.wallet.label(loc),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: AppTextSize.body,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          paymentOrderAmount(order, loc),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: amountColor,
                            fontSize: AppTextSize.body,
                            fontWeight: FontWeight.w700,
                            decoration: status == paymentStatusCancelled
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: amountColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          createdAt == null
                              ? type
                              : '$type · ${DateFormat('dd/MM HH:mm').format(createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: AppTextSize.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      PaymentStatusPill(status),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
