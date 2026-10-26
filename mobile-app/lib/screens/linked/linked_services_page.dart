import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/screens/payment/payment_history_screen.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

class LinkedServicesPage extends StatefulWidget {
  const LinkedServicesPage({super.key});

  @override
  State<LinkedServicesPage> createState() => _LinkedServicesPageState();
}

class _LinkedServicesPageState extends State<LinkedServicesPage> {
  /// 60 checks, 2 s apart: about two minutes for the user to pay in the wallet app.
  static const int _maxPollTries = 60;
  static const String _demoProvider = 'MOCK';

  /// The smallest amount a wallet accepts, in VND.
  static const double _minAmount = 1000;

  /// Provider code and brand name; the demo wallet has no brand, its name follows the language.
  static const List<(String, String?)> _wallets = [
    ('VNPAY', 'VNPAY'),
    ('ZALOPAY', 'ZaloPay'),
    (_demoProvider, null),
  ];

  bool _syncing = false;
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  String _fmt(double v) =>
      CurrencyHelper.formatVND(v, context.loc, showSign: false);

  /// The provider logo is an image and keeps its own colours; only the fallback icon takes the theme.
  Widget _logo(ColorScheme colors, String provider, {double size = 32}) {
    final fallback =
        {
          'VNPAY': Icons.account_balance_rounded,
          'ZALOPAY': Icons.account_balance_wallet_rounded,
          _demoProvider: Icons.wallet_rounded,
        }[provider] ??
        Icons.payment_rounded;
    return Image.asset(
      'assets/payment/${provider.toLowerCase()}.png',
      width: size,
      height: size,
      errorBuilder: (_, _, _) =>
          Icon(fallback, color: colors.primary, size: size),
    );
  }

  Future<void> _openSync(String provider, String label) async {
    final ctrl = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.loc.linkedSyncFrom(label)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ctx.loc.linkedAmountPrompt,
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            // Text and hint take the theme: onSurface and onSurfaceVariant.
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(hintText: ctx.loc.linkedAmountHint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.loc.dialogCancel),
          ),
          FilledButton(
            onPressed: () {
              final a = double.tryParse(
                ctrl.text.trim().replaceAll(RegExp(r'[^\d]'), ''),
              );
              Navigator.pop(ctx, a);
            },
            child: Text(ctx.loc.linkedSync),
          ),
        ],
      ),
    );
    if (amount == null || !mounted) return;
    if (amount < _minAmount) {
      AppToast.error(context, context.loc.linkedMinAmount(_fmt(_minAmount)));
      return;
    }
    await _runSync(provider, amount);
  }

  Future<void> _runSync(String provider, double amount) async {
    setState(() => _syncing = true);
    try {
      final order = await RemoteApiHelper.instance.createPayment(
        type: 'DEPOSIT',
        amount: amount,
        provider: provider,
      );
      final orderCode = order['orderCode'] as String;
      final payUrl = order['payUrl'] as String;
      final uri = Uri.parse(payUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    int tries = 0;
    _poll = Timer.periodic(const Duration(seconds: 2), (t) async {
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
            RemoteApiHelper.instance.dataChangedNotifier.value++;
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
    return Scaffold(
      backgroundColor: colors.surface,
      // The icons take the app bar theme (onSurface).
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(
          loc.profileLinkedServices,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: loc.linkedHistoryTooltip,
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
            ),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _syncing,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              loc.linkedWalletsHeading,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              loc.linkedWalletsDescription,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ..._wallets.map(
              (w) =>
                  _walletTile(colors, loc, w.$1, w.$2 ?? loc.linkedDemoWallet),
            ),
            if (_syncing) ...[
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      loc.linkedSyncing,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _walletTile(
    ColorScheme colors,
    AppLocalizations loc,
    String provider,
    String label,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _logo(colors, provider, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                // Green "linked" status: readable on both themes (6.1:1 on the dark surface).
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      loc.linkedLinked,
                      style: const TextStyle(color: Colors.green, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => _openSync(provider, label),
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: Text(loc.linkedSync),
          ),
        ],
      ),
    );
  }
}
