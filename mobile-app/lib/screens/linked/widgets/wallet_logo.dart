import 'package:flutter/material.dart';

import 'package:finance_ai_app/models/payment_order.dart';

/// The logo of a wallet in a rounded square (T9 spec 3.9). The image keeps its own colours; the demo wallet, or a wallet
/// without its file, shows a wallet icon in the primary colour on the primary container.
class WalletLogo extends StatelessWidget {
  const WalletLogo(this.wallet, {super.key, this.size = 40});

  static const double _radius = 12;

  final PaymentWallet wallet;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = ColoredBox(
      color: colors.primaryContainer,
      child: Icon(
        Icons.account_balance_wallet_rounded,
        color: colors.primary,
        size: size / 2,
      ),
    );
    final asset = wallet.logoAsset;
    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: SizedBox.square(
        dimension: size,
        child: asset == null
            ? icon
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => icon,
              ),
      ),
    );
  }
}
