import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/payment_order.dart';

/// [status] of an order as the user should read it in the language of [loc]; an unknown state is shown as it came.
String paymentStatusLabel(AppLocalizations loc, String status) {
  switch (status) {
    case paymentStatusSuccess:
      return loc.paymentStatusSuccess;
    case paymentStatusFailed:
      return loc.paymentStatusFailed;
    case paymentStatusCancelled:
      return loc.paymentStatusCancelled;
    case paymentStatusPending:
      return loc.paymentStatusPending;
    default:
      return status;
  }
}

/// Success, failure and pending take the status colours of the theme; a cancelled order is neutral.
Color paymentStatusColor(
  ColorScheme colors,
  SemanticColors semantic,
  String status,
) {
  switch (status) {
    case paymentStatusSuccess:
      return semantic.successColor;
    case paymentStatusFailed:
      return colors.error;
    case paymentStatusCancelled:
      return colors.onSurfaceVariant;
    default:
      return semantic.warningColor;
  }
}

/// The state of an order as a small pill (T9 spec 3.9): the status colour on a tint of itself.
class PaymentStatusPill extends StatelessWidget {
  const PaymentStatusPill(this.status, {super.key});

  static const double tintAlpha = 0.18;
  static const double _radius = 8;

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = paymentStatusColor(
      theme.colorScheme,
      theme.semanticColors,
      status,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: tintAlpha),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Text(
        paymentStatusLabel(context.loc, status),
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: AppTextSize.caption,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
