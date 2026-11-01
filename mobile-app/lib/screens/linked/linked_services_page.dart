import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/payment_order.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/screens/linked/top_up_sheet.dart';
import 'package:finance_ai_app/screens/linked/widgets/syncing_banner.dart';
import 'package:finance_ai_app/screens/linked/widgets/wallet_list_card.dart';
import 'package:finance_ai_app/screens/payment/payment_history_screen.dart';
import 'package:finance_ai_app/screens/payment/widgets/payment_status_pill.dart';
import 'package:finance_ai_app/widgets/common/demo_badge.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

/// "Dịch vụ liên kết" (T9 spec 3.9, mockup M4): the blue band with the Demo badge and the history clock, a short
/// description, the "Đang đồng bộ …" banner while a payment waits on the gateway, the wallets in one card and the demo
/// note as a soft line at the end.
class LinkedServicesPage extends StatefulWidget {
  const LinkedServicesPage({super.key});

  static const Key historyKey = ValueKey('linked-history');

  @override
  State<LinkedServicesPage> createState() => _LinkedServicesPageState();
}

class _LinkedServicesPageState extends State<LinkedServicesPage> {
  /// 60 checks, 2 s apart: about two minutes for the user to pay in the wallet app.
  static const int _maxPollTries = 60;
  static const double _buttonSize = 36;

  bool _syncing = false;
  Timer? _poll;

  /// True while a status check is on the way: the next tick then waits for it instead of asking again.
  bool _checking = false;

  /// What the banner names while [_syncing]: the amount and the wallet it comes from.
  double _syncAmount = 0;
  PaymentWallet? _syncWallet;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  String _fmt(double v) =>
      CurrencyHelper.formatVND(v, context.loc, showSign: false);

  Future<void> _openSync(PaymentWallet wallet) async {
    final amount = await showTopUpSheet(context, wallet);
    if (amount == null || !mounted) return;
    await _runSync(wallet, amount);
  }

  Future<void> _runSync(PaymentWallet wallet, double amount) async {
    setState(() {
      _syncing = true;
      _syncAmount = amount;
      _syncWallet = wallet;
    });
    try {
      final order = await RemoteApiHelper.instance.createPayment(
        type: paymentTypeDeposit,
        amount: amount,
        provider: wallet.provider,
      );
      final orderCode = order['orderCode'] as String;
      final payUrl = order['payUrl'] as String;
      final uri = Uri.parse(payUrl);
      final opened =
          await canLaunchUrl(uri) &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      // Left while the order was created: nobody is there to tell, and dispose has nothing to cancel.
      if (!mounted) return;
      if (!opened) {
        // Nothing can be paid, so nothing is waited for.
        AppToast.error(context, context.loc.linkedOpenPayUrlFailed);
        setState(() => _syncing = false);
        return;
      }
      _pollSync(orderCode, amount);
    } catch (e) {
      UserFacingError.log('Create sync order', e);
      if (mounted) {
        final loc = context.loc;
        AppToast.error(
          context,
          loc.linkedCreateOrderFailed(UserFacingError.messageOf(e, loc)),
        );
        setState(() => _syncing = false);
      }
    }
  }

  void _pollSync(String orderCode, double amount) {
    _poll?.cancel();
    _checking = false;
    int tries = 0;
    _poll = Timer.periodic(const Duration(seconds: 2), (t) async {
      if (_checking) return;
      _checking = true;
      tries++;
      try {
        final st = await RemoteApiHelper.instance.paymentStatus(orderCode);
        final status = st['status'];
        if (status != paymentStatusPending) {
          t.cancel();
          if (!mounted) return;
          setState(() => _syncing = false);
          final loc = context.loc;
          if (status == paymentStatusSuccess) {
            RemoteApiHelper.instance.notifyDataChanged();
            AppToast.success(context, loc.linkedSynced(_fmt(amount)));
            if (mounted) Navigator.pop(context, true);
          } else {
            AppToast.info(
              context,
              loc.linkedSyncOutcome(paymentStatusLabel(loc, '$status')),
            );
          }
        }
      } catch (e) {
        // One failed check is not the end: the next tick asks again.
        UserFacingError.log('Payment status', e);
      } finally {
        _checking = false;
      }
      if (tries >= _maxPollTries && t.isActive) {
        t.cancel();
        if (!mounted) return;
        setState(() => _syncing = false);
        AppToast.error(context, context.loc.linkedPollTimedOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final syncWallet = _syncWallet;
    return Scaffold(
      body: Column(
        children: [
          PageBand(
            title: loc.profileLinkedServices,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DemoBadge(),
                const SizedBox(width: 8),
                _historyButton(loc),
              ],
            ),
          ),
          Expanded(
            child: AbsorbPointer(
              absorbing: _syncing,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      loc.linkedWalletsDescription,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: AppTextSize.secondary,
                      ),
                    ),
                  ),
                  if (_syncing && syncWallet != null) ...[
                    const SizedBox(height: 12),
                    SyncingBanner(
                      message: loc.linkedSyncingFrom(
                        _fmt(_syncAmount),
                        syncWallet.label(loc),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  WalletListCard(
                    wallets: PaymentWallet.linked,
                    onSync: _openSync,
                  ),
                  const SizedBox(height: 12),
                  _demoNote(colors, loc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyButton(AppLocalizations loc) {
    return Tooltip(
      message: loc.linkedHistoryTooltip,
      child: Material(
        color: BandColors.tint,
        shape: const CircleBorder(),
        child: InkWell(
          key: LinkedServicesPage.historyKey,
          customBorder: const CircleBorder(),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
          ),
          child: const SizedBox.square(
            dimension: _buttonSize,
            child: Icon(
              Icons.history_rounded,
              color: BandColors.primary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  /// The wallets here are simulated (provider MOCK): said in full, so nobody takes them for a real bank connection.
  Widget _demoNote(ColorScheme colors, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              loc.linkedDemoNotice,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: AppTextSize.caption,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
