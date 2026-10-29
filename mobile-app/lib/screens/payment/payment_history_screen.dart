import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/models/payment_order.dart';
import 'package:finance_ai_app/screens/payment/widgets/payment_order_row.dart';
import 'package:finance_ai_app/screens/payment/widgets/payment_order_sheet.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

/// "Lịch sử nạp/rút" (T9 spec 3.9, mockup R3): the blue band and the orders in one card; tapping an order opens
/// "Chi tiết đơn", where a pending one can be cancelled.
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  static const double _cardRadius = 16;

  List<PaymentOrder> _orders = [];
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
        _orders = list.map(PaymentOrder.fromJson).toList();
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

  Future<void> _open(PaymentOrder order) async {
    final cancel = await showPaymentOrderSheet(context, order);
    if (cancel == true && mounted) await _cancel(order.orderCode);
  }

  Future<void> _cancel(String orderCode) async {
    try {
      await RemoteApiHelper.instance.cancelPayment(orderCode);
    } catch (e) {
      UserFacingError.log('Cancel payment', e);
      if (!mounted) return;
      final loc = context.loc;
      AppToast.error(
        context,
        loc.paymentCancelFailed(UserFacingError.messageOf(e, loc)),
      );
      return;
    }
    if (!mounted) return;
    AppToast.success(context, context.loc.paymentCancelled(orderCode));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final error = _error;
    final Widget body;
    if (_loading) {
      body = const _StateList(child: AppStateView.loading());
    } else if (error != null) {
      body = _StateList(
        child: AppStateView.error(
          title: loc.paymentHistoryLoadFailed(
            UserFacingError.messageOf(error, loc),
          ),
          onRetry: _load,
        ),
      );
    } else if (_orders.isEmpty) {
      body = _StateList(
        child: AppStateView.empty(
          icon: Icons.receipt_long_outlined,
          title: loc.paymentHistoryEmpty,
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(_cardRadius),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (var i = 0; i < _orders.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: colors.outlineVariant,
                      ),
                    PaymentOrderRow(
                      order: _orders[i],
                      onTap: () => _open(_orders[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Scaffold(
      body: Column(
        children: [
          PageBand(title: loc.paymentHistoryTitle),
          Expanded(
            child: RefreshIndicator(onRefresh: _load, child: body),
          ),
        ],
      ),
    );
  }
}

/// A state view in a scrollable list, so that pulling down still reloads.
class _StateList extends StatelessWidget {
  const _StateList({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 48),
      children: [child],
    );
  }
}
