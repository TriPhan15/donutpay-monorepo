import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/models/app_notification.dart';
import 'package:finance_ai_app/screens/notifications/widgets/notification_row.dart';
import 'package:finance_ai_app/widgets/dialogs/app_sheet.dart';

/// "Notification details" (T9 spec 3.7, R7): the whole of a notification the app has no page for. A title with a close
/// button, the Type and Time rows, and the full message on a light grey block, where it can be selected and copied.
Future<void> showNotificationContentSheet(
  BuildContext context,
  AppNotification notification,
) {
  return showAppSheet<void>(
    context,
    (_) => _NotificationContentSheet(notification: notification),
  );
}

class _NotificationContentSheet extends StatelessWidget {
  const _NotificationContentSheet({required this.notification});

  static const EdgeInsets _padding = EdgeInsets.fromLTRB(20, 12, 20, 20);
  static const Size _handle = Size(40, 4);
  static const double _handleRadius = 10;
  static const double _handleGap = 8;
  static const double _blockGap = 6;
  static const EdgeInsets _blockPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 12,
  );
  static const double _blockRadius = 14;
  static const double _messageLineHeight = 1.55;

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;
    final createdAt = notification.createdAt;
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: colors.outlineVariant,
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: _padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: _handle.width,
                height: _handle.height,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(_handleRadius),
                ),
              ),
            ),
            const SizedBox(height: _handleGap),
            Row(
              children: [
                Expanded(
                  child: Text(
                    loc.notificationDetailTitle,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: AppTextSize.title,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: Icon(
                    Icons.close_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            _InfoRow(
              label: loc.notificationDetailType,
              value: loc.notificationTypeLabel(notification.type),
            ),
            if (createdAt != null) ...[
              divider,
              _InfoRow(
                label: loc.notificationDetailTime,
                value: DateFormat.yMd(
                  loc.localeName,
                ).add_Hm().format(createdAt),
              ),
            ],
            const SizedBox(height: _blockGap),
            Container(
              padding: _blockPadding,
              decoration: BoxDecoration(
                // The page background: lighter than the sheet in light mode, darker in dark mode, where the container
                // colours of the scheme match the sheet.
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(_blockRadius),
              ),
              child: SelectableText(
                notification.message,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: AppTextSize.body,
                  height: _messageLineHeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled line of the sheet: the label on the left in the secondary colour, the value on the right.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  static const double _verticalPadding = 13;
  static const double _labelGap = 16;

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _verticalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: AppTextSize.secondary,
            ),
          ),
          const SizedBox(width: _labelGap),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: AppTextSize.body,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
