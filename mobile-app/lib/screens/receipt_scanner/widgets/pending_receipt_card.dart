import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/scan_queue_item.dart';

/// One receipt of the pending list (T9 spec, 3.1 "Chờ xác nhận"): the photo on the left, a stripe in the colour of its
/// status, what the AI read, and one quick button (Lưu, Kiểm tra or Đọc lại). In the selection mode a checkbox takes
/// the place of the button.
class PendingReceiptCard extends StatelessWidget {
  const PendingReceiptCard({
    super.key,
    required this.item,
    required this.title,
    this.selecting = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onQuickSave,
    this.onReview,
    this.onRetry,
  });

  static const double _radius = 20;
  static const double _stripe = 4;
  static const double _photoWidth = 56;
  static const double _photoHeight = 74;
  static const double _photoRadius = 12;
  static const String _timePattern = 'dd/MM, HH:mm';

  final ScanQueueItem item;

  /// The store name, "Đang đọc…" or "Ảnh n": the screen knows the place of the receipt in the list.
  final String title;
  final bool selecting;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// One of these three gives the quick button; with none there is no button.
  final VoidCallback? onQuickSave;
  final VoidCallback? onReview;
  final VoidCallback? onRetry;

  static String _errorText(AppLocalizations loc, String? error) =>
      switch (error) {
        ScanQueueError.network => loc.pendingErrorNetwork,
        ScanQueueError.missingImage => loc.pendingErrorMissingImage,
        _ => loc.pendingErrorServer,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = context.colors;
    final loc = context.loc;
    final status = item.status;
    final stripeColor = switch (status) {
      ScanQueueStatus.ready => semantic.successColor,
      ScanQueueStatus.failed => semantic.expenseColor,
      _ => semantic.warningColor,
    };
    final result = item.result;
    final failed = status == ScanQueueStatus.failed;
    final subtitle = failed
        ? _errorText(loc, item.error)
        : DateFormat(_timePattern).format(result?.date ?? item.createdAt);
    final amount = result?.amount;
    final needsCheck = result != null && !result.allValid;
    final secondaryStyle = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: AppTextSize.caption,
    );

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: _stripe, color: stripeColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Photo(path: item.imagePath, dimmed: failed),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: AppTextSize.body,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: failed
                                  ? secondaryStyle.copyWith(
                                      color: semantic.expenseColor,
                                    )
                                  : secondaryStyle,
                            ),
                            const SizedBox(height: 6),
                            if (status == ScanQueueStatus.ready) ...[
                              if (amount != null)
                                Text(
                                  CurrencyHelper.formatVND(
                                    amount,
                                    loc,
                                    showSign: false,
                                  ),
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    fontSize: AppTextSize.body,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              Text(
                                TransactionCategories.displayName(
                                  loc,
                                  result!.category,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: secondaryStyle,
                              ),
                              if (needsCheck)
                                Text(
                                  loc.reviewNeedsCheck,
                                  style: secondaryStyle.copyWith(
                                    color: semantic.warningColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ] else
                              _StatusLabel(status: status, color: stripeColor),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _trailing(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trailing(BuildContext context) {
    final loc = context.loc;
    if (selecting) {
      return Checkbox(
        value: selected,
        onChanged: onTap == null ? null : (_) => onTap!(),
      );
    }
    if (onQuickSave case final VoidCallback save) {
      return _QuickButton(
        label: loc.pendingQuickSave,
        icon: Icons.check_rounded,
        onPressed: save,
      );
    }
    if (onReview case final VoidCallback review) {
      return _QuickButton(label: loc.pendingReview, onPressed: review);
    }
    if (onRetry case final VoidCallback retry) {
      return _QuickButton(label: loc.pendingRetry, onPressed: retry);
    }
    return const SizedBox.shrink();
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.path, required this.dimmed});

  final String path;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(PendingReceiptCard._photoRadius),
      child: SizedBox(
        width: PendingReceiptCard._photoWidth,
        height: PendingReceiptCard._photoHeight,
        child: Opacity(
          opacity: dimmed ? 0.5 : 1,
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: colors.surfaceContainerHighest,
              child: Icon(
                Icons.receipt_long_outlined,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status, required this.color});

  final ScanQueueStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final (icon, label) = switch (status) {
      ScanQueueStatus.queued => (
        Icons.schedule_rounded,
        loc.pendingStatusQueued,
      ),
      ScanQueueStatus.reading => (Icons.sync_rounded, loc.pendingStatusReading),
      _ => (Icons.error_outline_rounded, loc.pendingStatusFailed),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: AppTextSize.caption,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.label, required this.onPressed, this.icon});

  static const double _maxWidth = 96;

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Never wider than a third of a narrow card, so the receipt keeps room for its name.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: Material(
        color: colors.primaryContainer,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon case final IconData icon) ...[
                  Icon(icon, size: 15, color: colors.primary),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: AppTextSize.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
