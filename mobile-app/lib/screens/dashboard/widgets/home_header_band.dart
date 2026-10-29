import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/widgets/common/amount_eye_button.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/cubits/amount_visibility_cubit.dart';
import 'package:finance_ai_app/widgets/notifications/notification_bell.dart';
import 'package:finance_ai_app/widgets/receipt/scan_queue_banner.dart';

/// The blue band at the top of the home screen (T9 spec, 3.1): greeting and bell, the balance with its eye, the two
/// month pills, four round shortcuts and, while receipts are in the scan queue, the scan strip at its foot.
class HomeHeaderBand extends StatelessWidget {
  const HomeHeaderBand({
    super.key,
    required this.userName,
    required this.balance,
    required this.pendingChange,
    required this.monthIncome,
    required this.monthExpense,
    required this.unreadNotifications,
    required this.onOpenNotifications,
    required this.onAddTransaction,
    this.onScanReceipt,
    required this.onOpenBudgets,
    required this.onOpenSavings,
    this.onOpenTransaction,
  });

  static const double _radius = 28;

  final String userName;

  /// The balance the server keeps; [pendingChange] is what the rows still waiting on the device would add to it.
  final double balance;
  final double pendingChange;
  final double monthIncome;
  final double monthExpense;
  final ValueListenable<int> unreadNotifications;
  final VoidCallback onOpenNotifications;
  final VoidCallback onAddTransaction;
  final VoidCallback? onScanReceipt;
  final VoidCallback onOpenBudgets;
  final VoidCallback onOpenSavings;

  /// Handed to the pending receipts opened from the scan strip.
  final ValueChanged<int>? onOpenTransaction;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    // The band runs under the status bar, so its own padding keeps the content below it.
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 16 + topInset, 18, 20),
      decoration: BoxDecoration(
        gradient: context.colors.headerGradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(_radius),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Greeting(
            userName: userName,
            unreadNotifications: unreadNotifications,
            onOpenNotifications: onOpenNotifications,
          ),
          const SizedBox(height: 14),
          Text(
            loc.dashboardBalance,
            style: const TextStyle(
              color: BandColors.secondary,
              fontSize: AppTextSize.secondary,
            ),
          ),
          // Only the amounts listen to the eye: showing them does not rebuild the rest of the band.
          BlocBuilder<AmountVisibilityCubit, bool>(
            builder: (context, hidden) => _Amounts(
              hidden: hidden,
              balance: balance,
              pendingChange: pendingChange,
              monthIncome: monthIncome,
              monthExpense: monthExpense,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Shortcut(
                icon: Icons.add_circle_outline_rounded,
                label: loc.addTransactionTitle,
                onTap: onAddTransaction,
              ),
              _Shortcut(
                icon: Icons.receipt_long_rounded,
                label: loc.dashboardScanReceipt,
                onTap: onScanReceipt,
              ),
              _Shortcut(
                icon: Icons.account_balance_wallet_rounded,
                label: loc.budgetTitle,
                onTap: onOpenBudgets,
              ),
              _Shortcut(
                icon: Icons.savings_rounded,
                label: loc.dashboardSavingsShort,
                onTap: onOpenSavings,
              ),
            ],
          ),
          // Takes no room while the scan queue is empty; the gap above it comes with it.
          ScanQueueBanner(
            onOpenTransaction: onOpenTransaction,
            padding: const EdgeInsets.only(top: 14),
          ),
        ],
      ),
    );
  }
}

/// The text colours on the blue band, the same in light and dark mode: the band stays a dark enough blue in both.
class _Greeting extends StatelessWidget {
  final String userName;
  final ValueListenable<int> unreadNotifications;
  final VoidCallback onOpenNotifications;

  const _Greeting({
    required this.userName,
    required this.unreadNotifications,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.loc.dashboardGreeting,
                style: const TextStyle(
                  color: BandColors.secondary,
                  fontSize: AppTextSize.secondary,
                ),
              ),
              Text(
                userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BandColors.primary,
                  fontSize: AppTextSize.pageTitle,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: BandColors.tint,
            shape: BoxShape.circle,
          ),
          child: NotificationBell(
            unreadCount: unreadNotifications,
            onPressed: onOpenNotifications,
            color: BandColors.primary,
          ),
        ),
      ],
    );
  }
}

/// The balance with the eye on its right, the note on the rows not sent yet, and the two month pills. While [hidden]
/// every one of them shows dots.
class _Amounts extends StatelessWidget {
  static const Duration _fade = Duration(milliseconds: 200);

  final bool hidden;
  final double balance;
  final double pendingChange;
  final double monthIncome;
  final double monthExpense;

  const _Amounts({
    required this.hidden,
    required this.balance,
    required this.pendingChange,
    required this.monthIncome,
    required this.monthExpense,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    String shown(String Function() text) =>
        hidden ? AmountEyeButton.hiddenText : text();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: _fade,
                  child: Text(
                    shown(
                      () => CurrencyHelper.formatVND(
                        balance,
                        loc,
                        showSign: balance < 0,
                      ),
                    ),
                    key: ValueKey(hidden),
                    maxLines: 1,
                    style: const TextStyle(
                      color: BandColors.primary,
                      fontSize: AppTextSize.amountLarge,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            AmountEyeButton(hidden: hidden),
          ],
        ),
        if (pendingChange != 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              shown(
                () => loc.dashboardPendingNotInBalance(
                  CurrencyHelper.formatVND(
                    pendingChange,
                    loc,
                    showSign: pendingChange < 0,
                  ),
                ),
              ),
              style: const TextStyle(
                color: BandColors.secondary,
                fontSize: AppTextSize.caption,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(
              shown(
                () => loc.dashboardMonthIncome(
                  CurrencyHelper.formatCompactVND(monthIncome, loc),
                ),
              ),
            ),
            _Pill(
              shown(
                () => loc.dashboardMonthExpense(
                  CurrencyHelper.formatCompactVND(monthExpense, loc),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: BandColors.tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: BandColors.primary,
          fontSize: AppTextSize.secondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One of the four shortcuts: a round translucent tile over a label of at most two lines.
class _Shortcut extends StatelessWidget {
  static const double _tileSize = 48;

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _Shortcut({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            children: [
              Container(
                width: _tileSize,
                height: _tileSize,
                decoration: const BoxDecoration(
                  color: BandColors.tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: BandColors.primary, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BandColors.primary,
                  fontSize: AppTextSize.caption,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
