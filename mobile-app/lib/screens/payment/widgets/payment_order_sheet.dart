import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/app_date_format.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/payment_order.dart';
import 'package:finance_ai_app/screens/payment/widgets/payment_status_pill.dart';

/// Shows the details of [order]; true when the user asked to cancel it (only offered while it is pending).
Future<bool?> showPaymentOrderSheet(BuildContext context, PaymentOrder order) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => PaymentOrderSheet(order: order),
  );
}

/// "Chi tiết đơn" (T9 spec 3.9, mockup R3): the amount with its state pill, the Ví / Mã đơn / Thời gian rows and, while
/// the order is pending, a light red "Hủy đơn" button. Cancelling itself stays with the history screen.
class PaymentOrderSheet extends StatelessWidget {
  const PaymentOrderSheet({super.key, required this.order});

  static const Key cancelKey = ValueKey('payment-order-cancel');
  static const Key closeKey = ValueKey('payment-order-close');

  /// The fill of "Hủy đơn": the error colour at this alpha.
  static const double cancelTint = 0.12;

  static const EdgeInsets _padding = EdgeInsets.fromLTRB(20, 4, 20, 20);
  static const double _buttonHeight = 48;
  static const double _buttonRadius = 14;

  final PaymentOrder order;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final createdAt = order.createdAt;
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: colors.outlineVariant,
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: _padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    loc.paymentOrderDetails,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: AppTextSize.title,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: closeKey,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                  child: Text(
                    CurrencyHelper.formatVND(
                      order.amount,
                      loc,
                      showSign: false,
                    ),
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: AppTextSize.amount,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                PaymentStatusPill(order.status),
              ],
            ),
            const SizedBox(height: 12),
            _row(colors, loc.paymentDetailWallet, order.wallet.label(loc)),
            divider,
            _row(colors, loc.paymentDetailCode, order.orderCode),
            divider,
            _row(
              colors,
              loc.paymentDetailTime,
              createdAt == null ? '' : AppDateFormat.dateTime.format(createdAt),
            ),
            if (order.isPending) ...[
              const SizedBox(height: 16),
              SizedBox(
                key: cancelKey,
                height: _buttonHeight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error.withValues(alpha: cancelTint),
                    foregroundColor: colors.error,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_buttonRadius),
                    ),
                  ),
                  child: Text(
                    loc.paymentCancelOrder,
                    style: const TextStyle(
                      fontSize: AppTextSize.body,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(ColorScheme colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: AppTextSize.secondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: AppTextSize.body,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
