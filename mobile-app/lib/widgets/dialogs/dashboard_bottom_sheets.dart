import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finance_ai_app/models/wallet_model.dart';

/// The sheets take their surface colour from the theme's bottomSheetTheme; their content reads the colour scheme once
/// per sheet.
class DashboardBottomSheets {
  static void showBankSources(BuildContext context, List<WalletModel> wallets) {
    final fmtCur = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        final balanceStyle = TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.bold,
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nguồn tiền',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Các ví đã liên kết với tài khoản',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                if (wallets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Chưa có ví nào.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  )
                else
                  ...wallets.map(
                    (w) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(w.colorValue).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Color(w.colorValue),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        w.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: Text(
                        fmtCur.format(w.balance),
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

  static void showAllFeatures(
    BuildContext context, {

    required VoidCallback onSavings,
    required VoidCallback onBankSources,
    required VoidCallback onLinkedServices,
  }) {
    final features = [
      (
        Icons.savings_rounded,
        'Sổ tiết kiệm',
        'Quản lý mục tiêu tiết kiệm',
        onSavings,
      ),
      (
        Icons.account_balance_wallet_rounded,
        'Nguồn tiền',
        'Xem ví và số dư',
        onBankSources,
      ),
      (
        Icons.link_rounded,
        'Dịch vụ liên kết',
        'MoMo, ZaloPay, ngân hàng...',
        onLinkedServices,
      ),
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        final descriptionStyle = TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 10,
          height: 1.2,
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tất cả tính năng',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.53,
                  physics: const NeverScrollableScrollPhysics(),
                  children: features.map((f) {
                    return GestureDetector(
                      onTap: f.$4,
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              f.$1,
                              color: colors.onPrimaryContainer,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            f.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            f.$3,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: descriptionStyle,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
