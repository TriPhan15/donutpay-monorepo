import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/models/payment_order.dart';
import 'package:finance_ai_app/screens/linked/widgets/wallet_logo.dart';

/// The linked wallets in one card (T9 spec 3.9, mockup M1/M4): per row the logo, the name, a green "Đã liên kết" and a
/// light blue "Đồng bộ" button.
class WalletListCard extends StatelessWidget {
  const WalletListCard({
    super.key,
    required this.wallets,
    required this.onSync,
  });

  static Key syncKey(String provider) => ValueKey('wallet-sync-$provider');

  static const double _radius = 16;

  final List<PaymentWallet> wallets;
  final ValueChanged<PaymentWallet> onSync;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Column(
        children: [
          for (var i = 0; i < wallets.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: colors.outlineVariant),
            _WalletRow(wallet: wallets[i], onSync: () => onSync(wallets[i])),
          ],
        ],
      ),
    );
  }
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({required this.wallet, required this.onSync});

  static const double _buttonRadius = 12;

  final PaymentWallet wallet;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final success = context.colors.successColor;
    final loc = context.loc;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_buttonRadius),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          WalletLogo(wallet),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet.label(loc),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: AppTextSize.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.check_rounded, color: success, size: 14),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        loc.linkedLinked,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: success,
                          fontSize: AppTextSize.caption,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            key: WalletListCard.syncKey(wallet.provider),
            color: colors.primaryContainer,
            shape: shape,
            child: InkWell(
              customBorder: shape,
              onTap: onSync,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sync_rounded, color: colors.primary, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      loc.linkedSync,
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: AppTextSize.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
