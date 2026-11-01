import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/screens/profile/widgets/profile_sheet_frame.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/dialogs/app_sheet.dart';
import 'package:finance_ai_app/widgets/transactions/transaction_row.dart';

/// "Bảo mật & quyền riêng tư" (T9 spec 3.10, M1): Change password (the caller opens the screen) and Activity history.
Future<void> showSecuritySheet(
  BuildContext context, {
  required List<TransactionModel> recentTransactions,
  required VoidCallback onChangePassword,
}) {
  return showAppSheet<void>(context, (sheetContext) {
    final loc = sheetContext.loc;
    final colors = Theme.of(sheetContext).colorScheme;
    return ProfileSheetFrame(
      title: loc.profileSecurityPrivacy,
      child: Column(
        children: [
          _SecurityRow(
            icon: Icons.lock_outline_rounded,
            title: loc.credentialsChangePassword,
            description: loc.securityChangePasswordDescription,
            onTap: () {
              Navigator.pop(sheetContext);
              onChangePassword();
            },
          ),
          Divider(height: 1, thickness: 1, color: colors.outlineVariant),
          _SecurityRow(
            icon: Icons.history_rounded,
            title: loc.activityLogTitle,
            description: loc.activityLogSubtitle,
            onTap: () {
              Navigator.pop(sheetContext);
              if (context.mounted) {
                showActivityLogSheet(context, recentTransactions);
              }
            },
          ),
        ],
      ),
    );
  });
}

/// The recent transactions of the account, newest first as given, in the rows the home and statistics lists use.
Future<void> showActivityLogSheet(
  BuildContext context,
  List<TransactionModel> transactions,
) {
  return showAppSheet<void>(context, (sheetContext) {
    final loc = sheetContext.loc;
    final colors = Theme.of(sheetContext).colorScheme;
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          children: [
            Text(
              loc.activityLogTitleCount(transactions.length),
              style: TextStyle(
                color: colors.onSurface,
                fontSize: AppTextSize.title,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            if (transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: AppStateView.empty(
                  icon: Icons.history_rounded,
                  title: loc.activityLogTitle,
                ),
              )
            else
              for (var i = 0; i < transactions.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colors.outlineVariant,
                  ),
                TransactionRow(transaction: transactions[i]),
              ],
          ],
        ),
      ),
    );
  });
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: colors.primary, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: colors.onSurface,
          fontSize: AppTextSize.body,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        description,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: AppTextSize.caption,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colors.onSurfaceVariant,
        size: 20,
      ),
    );
  }
}
