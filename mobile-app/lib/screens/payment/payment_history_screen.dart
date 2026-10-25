import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';

/// Order states core-backend sends for a deposit or withdrawal.
const String paymentStatusSuccess = 'SUCCESS';
const String paymentStatusFailed = 'FAILED';
const String paymentStatusCancelled = 'CANCELLED';
const String paymentStatusPending = 'PENDING';

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

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  /// Why the last load failed, turned into a text in build so it follows the language.
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await RemoteApiHelper.instance.paymentHistory();
      if (!mounted) return;
      setState(() {
        _orders = list;
        _loading = false;
      });
    } catch (e) {
      UserFacingError.log('Load payment history', e);
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _cancel(String orderCode) async {
    try {
      await RemoteApiHelper.instance.cancelPayment(orderCode);
    } catch (e) {
      UserFacingError.log('Cancel payment', e);
      if (!mounted) return;
      final loc = context.loc;
      _snack(loc.paymentCancelFailed(UserFacingError.messageOf(e, loc)));
      return;
    }
    if (!mounted) return;
    _snack(context.loc.paymentCancelled(orderCode));
    await _load();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _fmt(dynamic v, AppLocalizations loc) {
    final n = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    return CurrencyHelper.formatVND(n, loc, showSign: false);
  }

  String _date(dynamic iso) {
    final d = DateTime.tryParse('$iso');
    if (d == null) return '';
    return DateFormat('dd/MM/yyyy HH:mm').format(d);
  }

  /// Success, failure and pending take the status colours of the theme; a cancelled order is neutral.
  Color _statusColor(ColorScheme colors, SemanticColors semantic, String s) {
    switch (s) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final semantic = theme.semanticColors;
    final loc = context.loc;
    final error = _error;
    return Scaffold(
      backgroundColor: colors.surface,
      // The back arrow takes the app bar theme.
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(
          loc.paymentHistoryTitle,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  loc.paymentHistoryLoadFailed(
                    UserFacingError.messageOf(error, loc),
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            )
          : _orders.isEmpty
          ? Center(
              child: Text(
                loc.paymentHistoryEmpty,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                // The tokens come from this build: nothing looks up the theme per row.
                itemBuilder: (_, i) => _tile(colors, semantic, loc, _orders[i]),
              ),
            ),
    );
  }

  /// A deposit is money coming in (the income colour), a withdrawal money going out (the warning colour).
  Widget _tile(
    ColorScheme colors,
    SemanticColors semantic,
    AppLocalizations loc,
    Map<String, dynamic> o,
  ) {
    final type = '${o['type']}';
    final status = '${o['status']}';
    final isDeposit = type == 'DEPOSIT';
    final canCancel = status == paymentStatusPending;
    final flow = isDeposit ? semantic.incomeColor : semantic.warningColor;
    final statusColor = _statusColor(colors, semantic, status);
    final detailStyle = TextStyle(color: colors.onSurfaceVariant, fontSize: 11);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDeposit
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: flow,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isDeposit ? loc.paymentDeposit : loc.paymentWithdrawal,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${isDeposit ? '+' : '-'}${_fmt(o['amount'], loc)}',
                style: TextStyle(color: flow, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${o['provider'] ?? ''}',
                style: TextStyle(color: colors.primary, fontSize: 12),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  paymentStatusLabel(loc, status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(_date(o['createdAt']), style: detailStyle),
            ],
          ),
          Text(loc.paymentOrderCode('${o['orderCode']}'), style: detailStyle),
          if (canCancel) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _cancel('${o['orderCode']}'),
                style: TextButton.styleFrom(foregroundColor: colors.error),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(loc.paymentCancelOrder),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
