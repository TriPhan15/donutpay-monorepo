import 'package:flutter/material.dart';

import 'package:finance_ai_app/models/app_notification.dart';
import 'package:finance_ai_app/screens/budget/budget_screen.dart';

/// Where tapping a notification leads. Every notification leads somewhere:
/// - a budget notification pushes [BudgetScreen] ([PageTarget]);
/// - a transaction or receipt notification with a transaction id shows that transaction in the Ledger's detail sheet,
///   which also carries its receipt status ([TransactionTarget]); without an id it opens the Ledger tab
///   ([LedgerTarget]), where the new transactions are;
/// - a type the app does not know shows its whole content in a sheet ([ContentTarget]).
sealed class NotificationTarget {
  const NotificationTarget();
}

final class PageTarget extends NotificationTarget {
  const PageTarget(this.builder);

  final WidgetBuilder builder;
}

final class TransactionTarget extends NotificationTarget {
  const TransactionTarget(this.transactionId);

  /// The server id of the transaction.
  final int transactionId;
}

final class LedgerTarget extends NotificationTarget {
  const LedgerTarget();
}

final class ContentTarget extends NotificationTarget {
  const ContentTarget();
}

abstract final class NotificationDestination {
  static NotificationTarget of(AppNotification notification) =>
      switch (notification.type) {
        NotificationType.budgetWarning || NotificationType.budgetExceeded =>
          PageTarget((_) => const BudgetScreen()),
        NotificationType.transactionAlert ||
        NotificationType.receiptProcessed =>
          switch (notification.transactionId) {
            final int id => TransactionTarget(id),
            null => const LedgerTarget(),
          },
        NotificationType.unknown => const ContentTarget(),
      };
}
