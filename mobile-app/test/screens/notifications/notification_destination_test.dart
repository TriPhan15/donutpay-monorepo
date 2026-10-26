import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/models/app_notification.dart';
import 'package:finance_ai_app/screens/notifications/notification_destination.dart';

AppNotification _of(NotificationType type, {int? transactionId}) =>
    AppNotification(
      id: 1,
      type: type,
      message: 'Thông báo 1',
      isRead: false,
      transactionId: transactionId,
    );

/// T10d: every type of notification leads somewhere.
void main() {
  test('budget notifications open a page', () {
    for (final type in [
      NotificationType.budgetWarning,
      NotificationType.budgetExceeded,
    ]) {
      expect(
        NotificationDestination.of(_of(type, transactionId: 5)),
        isA<PageTarget>(),
        reason: type.name,
      );
    }
  });

  test('transaction and receipt notifications open their transaction', () {
    for (final type in [
      NotificationType.transactionAlert,
      NotificationType.receiptProcessed,
    ]) {
      expect(
        NotificationDestination.of(_of(type, transactionId: 5)),
        isA<TransactionTarget>().having(
          (target) => target.transactionId,
          'transactionId',
          5,
        ),
        reason: type.name,
      );
    }
  });

  test('without a transaction id they open the Ledger', () {
    for (final type in [
      NotificationType.transactionAlert,
      NotificationType.receiptProcessed,
    ]) {
      expect(
        NotificationDestination.of(_of(type)),
        isA<LedgerTarget>(),
        reason: type.name,
      );
    }
  });

  test('a type the app does not know shows its content', () {
    expect(
      NotificationDestination.of(
        _of(NotificationType.unknown, transactionId: 5),
      ),
      isA<ContentTarget>(),
    );
  });
}
