import 'package:flutter/material.dart';

import 'package:finance_ai_app/models/app_notification.dart';
import 'package:finance_ai_app/screens/budget/budget_screen.dart';

/// Where tapping a notification leads.
///
/// Budget notifications push [BudgetScreen]. A transaction or receipt notification has no page of its own: the app shows
/// a transaction in the Ledger's detail sheet (with its receipt status), so [transactionIdOf] names the transaction and
/// the caller opens it there. A receipt notification without a transaction id opens nothing (there is no screen that
/// reviews a stored receipt).
abstract final class NotificationDestination {
  /// The page to push for [notification], or null when the app has none for it.
  static WidgetBuilder? of(AppNotification notification) =>
      switch (notification.type) {
        NotificationType.budgetWarning ||
        NotificationType.budgetExceeded => (_) => const BudgetScreen(),
        NotificationType.transactionAlert ||
        NotificationType.receiptProcessed ||
        NotificationType.unknown => null,
      };

  /// The transaction to show in the Ledger for [notification], or null when it does not lead to one.
  static int? transactionIdOf(AppNotification notification) =>
      switch (notification.type) {
        NotificationType.transactionAlert ||
        NotificationType.receiptProcessed => notification.transactionId,
        NotificationType.budgetWarning ||
        NotificationType.budgetExceeded ||
        NotificationType.unknown => null,
      };
}
