import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/core/utils/money_input_formatter.dart';
import 'package:finance_ai_app/models/payment_order.dart';
import 'package:finance_ai_app/models/top_up_amount.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/screens/ledger/widgets/transaction_form_fields.dart';
import 'package:finance_ai_app/screens/linked/widgets/top_up_quick_amounts.dart';
import 'package:finance_ai_app/screens/linked/widgets/wallet_logo.dart';
import 'package:finance_ai_app/widgets/dialogs/app_sheet.dart';

/// Asks how much to sync from [wallet]; the amount, or null when the sheet is closed.
Future<double?> showTopUpSheet(BuildContext context, PaymentWallet wallet) {
  return showAppSheet<double>(context, (_) => TopUpSheet(wallet: wallet));
}

/// The "Đồng bộ tiền" sheet (T9 spec 3.9, mockup M1): the wallet card, the amount field, the four quick amounts, the
/// "Tối thiểu 1.000 ₫ … chuyển sang cổng" line (in the error colour while the amount is below it) and "Tiếp tục thanh
/// toán", which pops the amount. Creating the order stays with the page.
class TopUpSheet extends StatefulWidget {
  const TopUpSheet({super.key, required this.wallet});

  static const Key amountKey = ValueKey('top-up-amount');
  static const Key submitKey = ValueKey('top-up-submit');
  static const Key closeKey = ValueKey('top-up-close');
  static const Key hintKey = ValueKey('top-up-hint');

  final PaymentWallet wallet;

  @override
  State<TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<TopUpSheet> {
  static const double _gutter = 20;
  static const double _cardRadius = 14;

  final _amountController = TextEditingController();

  double? get _amount => MoneyInputFormatter.parse(_amountController.text);

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _select(double amount) {
    setState(() {
      _amountController.text = MoneyInputFormatter.format(
        amount,
        context.loc.localeName,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = Theme.of(context).colorScheme;
    final amount = _amount;
    final error = TopUpAmount.validate(amount);
    final walletName = widget.wallet.label(loc);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    loc.linkedSheetTitle,
                    style: const TextStyle(
                      fontSize: AppTextSize.title,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: TopUpSheet.closeKey,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(_cardRadius),
              ),
              child: Row(
                children: [
                  WalletLogo(widget.wallet),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.linkedSheetFrom(walletName),
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: AppTextSize.body,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          loc.linkedSheetTarget,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: AppTextSize.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AmountField(
              key: TopUpSheet.amountKey,
              controller: _amountController,
              label: loc.linkedAmountLabel,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TopUpQuickAmounts(selected: amount, onSelected: _select),
            const SizedBox(height: 8),
            Text(
              loc.linkedMinAmountHint(
                CurrencyHelper.formatVND(
                  TopUpAmount.minimum,
                  loc,
                  showSign: false,
                ),
                walletName,
              ),
              key: TopUpSheet.hintKey,
              style: TextStyle(
                color: error == TopUpAmountError.belowMinimum
                    ? colors.error
                    : colors.onSurfaceVariant,
                fontSize: AppTextSize.caption,
              ),
            ),
            const SizedBox(height: 16),
            FormSubmitBar(
              key: TopUpSheet.submitKey,
              label: loc.linkedContinuePayment,
              onPressed: error == null
                  ? () => Navigator.pop(context, amount)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
