import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/wallet_model.dart';
import 'package:finance_ai_app/screens/profile/widgets/profile_sheet_frame.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';

/// "Nguồn tiền" (T9 spec 3.10, R1): the wallets on one grouped block, balances in grey on the right, the total on the
/// last row, and Done in the title row.
Future<void> showMoneySourcesSheet(
  BuildContext context,
  List<WalletModel> wallets,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MoneySourcesSheet(wallets: wallets),
  );
}

class _MoneySourcesSheet extends StatelessWidget {
  const _MoneySourcesSheet({required this.wallets});

  final List<WalletModel> wallets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;
    String money(double amount) =>
        CurrencyHelper.formatVND(amount, loc, showSign: amount < 0);
    final total = wallets.fold<double>(0, (sum, w) => sum + w.balance);
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: colors.outlineVariant,
    );
    return ProfileSheetFrame(
      title: loc.profileMoneySources,
      action: TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          loc.dialogDone,
          style: const TextStyle(
            fontSize: AppTextSize.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: wallets.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: AppStateView.empty(
                icon: Icons.account_balance_wallet_outlined,
                title: loc.moneySourcesEmpty,
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                // The page background: it stands out from the sheet in both themes.
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (final wallet in wallets) ...[
                    _Line(
                      label: wallet.name,
                      value: money(wallet.balance),
                      labelStyle: TextStyle(
                        color: colors.onSurface,
                        fontSize: AppTextSize.body,
                      ),
                      valueStyle: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: AppTextSize.body,
                      ),
                    ),
                    divider,
                  ],
                  _Line(
                    label: loc.moneySourcesTotal,
                    value: money(total),
                    labelStyle: TextStyle(
                      color: colors.onSurface,
                      fontSize: AppTextSize.body,
                      fontWeight: FontWeight.w700,
                    ),
                    valueStyle: TextStyle(
                      color: colors.onSurface,
                      fontSize: AppTextSize.body,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
