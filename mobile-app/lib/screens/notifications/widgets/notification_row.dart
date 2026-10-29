import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/category_colors.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/app_notification.dart';
import 'package:finance_ai_app/models/notification_age.dart';

extension NotificationTypeLabels on AppLocalizations {
  String notificationTypeLabel(NotificationType type) => switch (type) {
    NotificationType.budgetWarning => notificationTypeBudgetWarning,
    NotificationType.budgetExceeded => notificationTypeBudgetExceeded,
    NotificationType.transactionAlert => notificationTypeTransactionAlert,
    NotificationType.receiptProcessed => notificationTypeReceiptProcessed,
    NotificationType.unknown => notificationTypeOther,
  };
}

/// The icon and colour of each kind of notification.
abstract final class NotificationTypeStyle {
  static IconData iconOf(NotificationType type) => switch (type) {
    NotificationType.budgetWarning => Icons.warning_amber_rounded,
    NotificationType.budgetExceeded => Icons.error_outline_rounded,
    NotificationType.transactionAlert => Icons.swap_horiz_rounded,
    NotificationType.receiptProcessed => Icons.receipt_long_rounded,
    NotificationType.unknown => Icons.notifications_rounded,
  };

  static Color accentOf(NotificationType type, ThemeData theme) =>
      switch (type) {
        NotificationType.budgetWarning => theme.semanticColors.warningColor,
        NotificationType.budgetExceeded => theme.colorScheme.error,
        NotificationType.transactionAlert => theme.colorScheme.primary,
        NotificationType.receiptProcessed => theme.semanticColors.successColor,
        NotificationType.unknown => theme.colorScheme.onSurfaceVariant,
      };
}

/// The time of a notification in the list: the time alone today, "Yesterday, 19:20", the day and the time earlier in
/// the year, the date alone in an earlier year.
String notificationListTime(
  DateTime createdAt, {
  required DateTime now,
  required String locale,
  required AppLocalizations loc,
}) {
  final time = DateFormat.Hm(locale).format(createdAt);
  return switch (NotificationAge.of(createdAt, now)) {
    NotificationAge.today => time,
    NotificationAge.yesterday => loc.notificationsYesterdayAt(time),
    NotificationAge.thisYear =>
      '${DateFormat.Md(locale).format(createdAt)}, $time',
    NotificationAge.older => DateFormat.yMd(locale).format(createdAt),
  };
}

/// One row of the white notification block (T9 spec 3.7, R2): a small icon of its kind, the kind and the time on one
/// line, at most two lines of the message, and a blue dot while unread. [isFirst] and [isLast] round the block's
/// corners; every row but the last draws the line under it.
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.notification,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
    this.now,
  });

  static const double _radius = 16;
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 12,
  );
  static const double _iconTile = 36;
  static const double _iconTileRadius = 12;
  static const double _iconSize = 18;
  static const double _iconGap = 12;
  static const double _timeGap = 8;
  static const double _messageGap = 2;
  static const double _messageLineHeight = 1.4;
  static const double _dotSize = 9;
  static const double _dotGap = 10;

  /// Puts the dot level with the first line of text.
  static const double _dotTop = 6;

  final AppNotification notification;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  /// The current time; [DateTime.now] when null.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;
    final unread = !notification.isRead;
    final accent = NotificationTypeStyle.accentOf(notification.type, theme);
    final createdAt = notification.createdAt;
    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(_radius) : Radius.zero,
      bottom: isLast ? const Radius.circular(_radius) : Radius.zero,
    );
    return Material(
      color: colors.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      // One node for a screen reader: kind, time, message and "unread" are read together.
      child: MergeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: _padding,
            decoration: isLast
                ? null
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: colors.outlineVariant),
                    ),
                  ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: _iconTile,
                  height: _iconTile,
                  decoration: BoxDecoration(
                    color: CategoryColors.tileFor(accent, theme.brightness),
                    borderRadius: BorderRadius.circular(_iconTileRadius),
                  ),
                  child: Icon(
                    NotificationTypeStyle.iconOf(notification.type),
                    color: accent,
                    size: _iconSize,
                  ),
                ),
                const SizedBox(width: _iconGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              loc.notificationTypeLabel(notification.type),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: unread
                                    ? colors.onSurface
                                    : colors.onSurfaceVariant,
                                fontSize: AppTextSize.body,
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (createdAt != null) ...[
                            const SizedBox(width: _timeGap),
                            Text(
                              notificationListTime(
                                createdAt,
                                now: now ?? DateTime.now(),
                                locale: loc.localeName,
                                loc: loc,
                              ),
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: AppTextSize.caption,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: _messageGap),
                      Text(
                        notification.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unread
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                          fontSize: AppTextSize.secondary,
                          height: _messageLineHeight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: _dotGap),
                  Padding(
                    padding: const EdgeInsets.only(top: _dotTop),
                    child: Semantics(
                      label: loc.notificationsUnread,
                      child: Container(
                        width: _dotSize,
                        height: _dotSize,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
