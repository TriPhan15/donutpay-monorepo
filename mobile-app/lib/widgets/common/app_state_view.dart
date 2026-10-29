import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';

enum _StateKind { loading, empty, error }

/// What a screen shows instead of its data (T9 spec 3.11): a small grey spinner while loading; a grey icon, a title,
/// a short description and a text button when there is nothing to show or the data could not be loaded.
///
/// It sizes itself to its content, so it fits in a ListView or a Column; wrap it in a [Center] to fill a page.
class AppStateView extends StatelessWidget {
  const AppStateView.loading({super.key})
    : _kind = _StateKind.loading,
      icon = null,
      title = null,
      message = null,
      actionLabel = null,
      onAction = null;

  const AppStateView.empty({
    super.key,
    required IconData this.icon,
    required String this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  }) : _kind = _StateKind.empty;

  /// Offers "Retry" (the app's own text) through [onRetry].
  const AppStateView.error({
    super.key,
    required String this.title,
    this.message,
    required VoidCallback onRetry,
  }) : _kind = _StateKind.error,
       icon = Icons.cloud_off_rounded,
       actionLabel = null,
       onAction = onRetry;

  static const double spinnerSize = 24;
  static const double iconSize = 48;
  static const double _spinnerStroke = 2.5;

  final _StateKind _kind;
  final IconData? icon;
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_kind == _StateKind.loading) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SizedBox.square(
            dimension: spinnerSize,
            child: CircularProgressIndicator(
              strokeWidth: _spinnerStroke,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final label = _kind == _StateKind.error
        ? context.locOrDefault.commonRetry
        : actionLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: colors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: AppTextSize.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: AppTextSize.secondary,
                height: 1.45,
              ),
            ),
          ],
          if (label != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                textStyle: const TextStyle(
                  fontSize: AppTextSize.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}
