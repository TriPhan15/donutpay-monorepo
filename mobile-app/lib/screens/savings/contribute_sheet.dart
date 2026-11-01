import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/core/utils/money_input_formatter.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/models/contribution_plan.dart';
import 'package:finance_ai_app/models/savings_goal.dart';
import 'package:finance_ai_app/screens/ledger/widgets/form_submit_bar.dart';
import 'package:finance_ai_app/screens/ledger/widgets/transaction_form_fields.dart';
import 'package:finance_ai_app/screens/savings/widgets/contribute_goal_card.dart';
import 'package:finance_ai_app/screens/savings/widgets/quick_amount_grid.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

/// The "Góp tiền" sheet (T9 spec 3.6): the goal card that follows the amount, the amount field, the 4 × 2 quick
/// amounts, the suggestion (badged and preselected when the goal has a deadline), the wallet line and a button that
/// names the amount. It sends once, pops with the goal the server returns, and stays open with a toast when the
/// transfer is refused.
class ContributeSheet extends StatefulWidget {
  const ContributeSheet({
    super.key,
    required this.goal,
    required this.today,
    required this.onSubmit,
    this.loadBalance,
  });

  static const Key amountKey = ValueKey('contribute-amount');
  static const Key submitKey = ValueKey('contribute-submit');
  static const Key closeKey = ValueKey('contribute-close');
  static const Key hintKey = ValueKey('contribute-hint');
  static const Key walletKey = ValueKey('contribute-wallet');
  static const Key overfillKey = ValueKey('contribute-overfill');

  final SavingsGoal goal;
  final DateTime today;

  /// Moves the amount into the goal and returns the goal as it is now; throws when it is refused.
  final Future<SavingsGoal> Function(double amount) onSubmit;

  /// The wallet balance for the wallet line; null or a failure leaves the number out.
  final Future<double?> Function()? loadBalance;

  @override
  State<ContributeSheet> createState() => _ContributeSheetState();
}

class _ContributeSheetState extends State<ContributeSheet> {
  static const double _gutter = 20;

  final _amountController = TextEditingController();
  late final ContributionSuggestion? _suggestion = ContributionSuggestion.of(
    widget.goal,
    widget.today,
  );
  bool _prefilled = false;
  bool _isSending = false;
  double? _balance;

  double? get _amount => MoneyInputFormatter.parse(_amountController.text);

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  /// The suggestion is grouped in the language of the app, which the context only knows from here on.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final suggestion = _suggestion;
    if (_prefilled || suggestion == null) return;
    _prefilled = true;
    _amountController.text = MoneyInputFormatter.format(
      suggestion.chip ?? suggestion.amount,
      context.loc.localeName,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final load = widget.loadBalance;
    if (load == null) return;
    try {
      final balance = await load();
      if (mounted) setState(() => _balance = balance);
    } catch (e) {
      // The line simply goes without the number.
      UserFacingError.log('Savings wallet balance', e);
    }
  }

  void _select(double amount) {
    setState(() {
      _amountController.text = MoneyInputFormatter.format(
        amount,
        context.loc.localeName,
      );
    });
  }

  Future<void> _submit() async {
    final amount = _amount;
    if (_isSending || amount == null) return;
    final loc = context.loc;
    setState(() => _isSending = true);
    final SavingsGoal updated;
    try {
      updated = await widget.onSubmit(amount);
    } catch (e) {
      UserFacingError.log('Savings contribution', e);
      if (!mounted) return;
      setState(() => _isSending = false);
      AppToast.error(
        context,
        loc.savingsContributeFailed(
          UserFacingError.messageOf(
            e,
            loc,
            rejectedMessage: loc.savingsContributeRejected,
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = Theme.of(context).colorScheme;
    final amount = _amount;
    final suggestion = _suggestion;
    final deadline = widget.goal.deadline;
    final balance = _balance;
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
                    loc.savingsContribute,
                    style: const TextStyle(
                      fontSize: AppTextSize.title,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: ContributeSheet.closeKey,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ContributeGoalCard(goal: widget.goal, amount: amount ?? 0),
            const SizedBox(height: 16),
            AmountField(
              key: ContributeSheet.amountKey,
              controller: _amountController,
              label: loc.savingsContributeAmountLabel,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            QuickAmountGrid(
              selected: amount,
              suggested: suggestion?.chip,
              onSelected: _select,
            ),
            if (amount != null &&
                widget.goal.hasTarget &&
                amount > widget.goal.remaining) ...[
              const SizedBox(height: 10),
              Text(
                loc.savingsOverfillHint(
                  CurrencyHelper.formatCompactVND(widget.goal.remaining, loc),
                ),
                key: ContributeSheet.overfillKey,
                style: TextStyle(
                  color: Theme.of(context).semanticColors.warningColor,
                  fontSize: AppTextSize.caption,
                ),
              ),
            ],
            if (suggestion != null && deadline != null) ...[
              const SizedBox(height: 10),
              Text(
                loc.savingsSuggestionHint(
                  CurrencyHelper.formatCompactVND(suggestion.amount, loc),
                  deadline,
                ),
                key: ContributeSheet.hintKey,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: AppTextSize.caption,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              key: ContributeSheet.walletKey,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    color: colors.onPrimaryContainer,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      balance == null
                          ? loc.savingsWalletLineNoBalance
                          : loc.savingsWalletLine(
                              CurrencyHelper.formatVND(
                                balance,
                                loc,
                                showSign: false,
                              ),
                            ),
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontSize: AppTextSize.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FormSubmitBar(
              key: ContributeSheet.submitKey,
              label: amount == null
                  ? loc.savingsContribute
                  : loc.savingsContributeButton(
                      CurrencyHelper.formatVND(amount, loc, showSign: false),
                    ),
              busy: _isSending,
              onPressed: amount == null ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
