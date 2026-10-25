import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/wallet_model.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';

/// Sheets and dialogs take their surface colour from the theme, and so do switches, buttons and text fields; the rest
/// reads the colour scheme once per sheet.
class ProfileBottomSheets {
  static void showNotificationSettings(BuildContext context) {
    bool pushEnabled = true;
    bool budgetAlert = true;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.loc.notificationSettingsTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text(ctx.loc.notificationSettingsPush),
                  value: pushEnabled,
                  onChanged: (v) => setModalState(() => pushEnabled = v),
                ),
                SwitchListTile(
                  title: Text(ctx.loc.notificationSettingsBudgetAlert),
                  value: budgetAlert,
                  onChanged: (v) => setModalState(() => budgetAlert = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.loc.notificationSettingsSaved),
                        ),
                      );
                    },
                    child: Text(ctx.loc.commonSave),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void showBankSources(BuildContext context, List<WalletModel> wallets) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        final balanceStyle = TextStyle(color: colors.primary);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.loc.profileMoneySources,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (wallets.isEmpty)
                  Text(
                    ctx.loc.moneySourcesEmpty,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  )
                else
                  ...wallets.map(
                    (w) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Color(w.colorValue),
                      ),
                      title: Text(w.name),
                      trailing: Text(
                        CurrencyHelper.formatVND(
                          w.balance,
                          ctx.loc,
                          showSign: w.balance < 0,
                        ),
                        style: balanceStyle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showActivityLog(
    BuildContext context,
    List<TransactionModel> recentTransactions,
  ) {
    final formatDate = DateFormat('dd/MM/yyyy HH:mm');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colors = theme.colorScheme;
        final semantic = theme.semanticColors;
        final dateStyle = TextStyle(color: colors.onSurfaceVariant);
        final expenseStyle = TextStyle(
          color: semantic.expenseColor,
          fontWeight: FontWeight.bold,
        );
        final incomeStyle = TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.bold,
        );
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (_, controller) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    ctx.loc.activityLogTitleCount(recentTransactions.length),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: recentTransactions.length,
                    itemBuilder: (_, i) {
                      final tx = recentTransactions[i];
                      return ListTile(
                        leading: Icon(tx.icon, color: tx.color),
                        title: Text(tx.title),
                        subtitle: Text(
                          formatDate.format(tx.date),
                          style: dateStyle,
                        ),
                        trailing: Text(
                          '${tx.isExpense ? "-" : "+"} ${CurrencyHelper.formatVND(tx.amount, ctx.loc, showSign: false)}',
                          style: tx.isExpense ? expenseStyle : incomeStyle,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showSecurityMenu(
    BuildContext context,
    List<TransactionModel> recentTransactions,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        final subtitleStyle = TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 12,
        );
        final chevronColor = colors.onSurfaceVariant.withValues(alpha: 0.5);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.loc.profileSecurityPrivacy,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.pin_rounded,
                      color: colors.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    ctx.loc.pinSetupTitle,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    ctx.loc.pinSetupSubtitle,
                    style: subtitleStyle,
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: chevronColor,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    showPinSetup(context);
                  },
                ),
                Divider(
                  height: 1,
                  indent: 60,
                  endIndent: 16,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.1),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      color: colors.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    ctx.loc.activityLogTitle,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    ctx.loc.activityLogSubtitle,
                    style: subtitleStyle,
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: chevronColor,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    showActivityLog(context, recentTransactions);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showPinSetup(BuildContext context) {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        final loc = ctx.loc;
        // The fields take their fill and outline from the theme's inputDecorationTheme.
        final secondaryStyle = TextStyle(color: colors.onSurfaceVariant);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            loc.pinSetupTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                style: const TextStyle(letterSpacing: 8),
                decoration: InputDecoration(
                  labelText: loc.pinNewLabel,
                  labelStyle: secondaryStyle,
                  filled: true,
                  counterStyle: secondaryStyle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                style: const TextStyle(letterSpacing: 8),
                decoration: InputDecoration(
                  labelText: loc.pinConfirmLabel,
                  labelStyle: secondaryStyle,
                  filled: true,
                  counterStyle: secondaryStyle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                loc.dialogCancel,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final pin = pinCtrl.text.trim();
                final confirm = confirmCtrl.text.trim();
                if (pin.length != 4) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(loc.pinLengthInvalid)));
                  return;
                }
                if (pin != confirm) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(loc.pinMismatch)));
                  return;
                }
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('app_pin', pin);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(loc.pinSaved)));
              },
              child: Text(loc.commonSave),
            ),
          ],
        );
      },
    );
  }

  static void showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        final loc = ctx.loc;
        final topicStyle = TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.bold,
        );
        final bodyStyle = TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 13,
        );
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            builder: (_, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  loc.profileHelp,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...[
                  ('📊 ${loc.helpDashboardTitle}', loc.helpDashboardBody),
                  ('📒 ${loc.helpLedgerTitle}', loc.helpLedgerBody),
                  ('📷 ${loc.helpScanTitle}', loc.helpScanBody),
                  ('🤖 ${loc.helpAiTitle}', loc.helpAiBody),
                  ('💸 ${loc.helpTransferTitle}', loc.helpTransferBody),
                ].map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$1, style: topicStyle),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item.$2, style: bodyStyle)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showFeedback(BuildContext context) {
    int selectedStars = 5;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        final secondaryStyle = TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 13,
        );
        final loc = ctx.loc;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              '${loc.feedbackTitle} ⭐',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc.feedbackDescription,
                  style: secondaryStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starValue = index + 1;
                    return IconButton(
                      icon: Icon(
                        starValue <= selectedStars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 36,
                      ),
                      onPressed: () =>
                          setDialogState(() => selectedStars = starValue),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                // Text, fill and outline come from the theme.
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: loc.feedbackHint,
                    hintStyle: secondaryStyle,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  loc.feedbackLater,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        final success = await RemoteApiHelper.instance
                            .submitAppReview(
                              selectedStars,
                              commentController.text.trim(),
                            );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? loc.feedbackThanks
                                    : loc.feedbackFailed,
                              ),
                            ),
                          );
                        }
                      },
                child: isSubmitting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: colors.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        loc.feedbackSubmit,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  static void showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'LedgerMind',
      applicationVersion: 'v1.0.0',
      applicationLegalese: '© 2026 Nhom7 - HUIT',
      children: [
        const SizedBox(height: 12),
        Text(
          context.loc.aboutDescription,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}
