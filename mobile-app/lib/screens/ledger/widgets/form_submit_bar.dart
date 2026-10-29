import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';

/// The main button of a form, held at the bottom of the page (T9 spec, 3.3). Faded and inert while the form is not
/// valid ([onPressed] null); [busy] swaps the tick for a spinner and ignores taps while a save runs. An optional
/// outlined [secondaryLabel] button sits left of it, sharing the width and its enabled state.
class FormSubmitBar extends StatelessWidget {
  const FormSubmitBar({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
    this.secondaryLabel,
    this.onSecondary,
    this.header,
  });

  static const double disabledOpacity = 0.45;
  static const double _height = 52;
  static const double _radius = 16;
  static const double _iconSize = 20;
  static const double _spinnerSize = 18;
  static const double _gap = 10;

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  /// An outlined button left of the main one; enabled and faded together with it.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Shown above the buttons on the same surface, such as a count and a total.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !busy;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_radius),
    );
    const labelStyle = TextStyle(
      fontSize: AppTextSize.title,
      fontWeight: FontWeight.w700,
    );
    final main = FilledButton(
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: colors.primary,
        disabledForegroundColor: colors.onPrimary,
        shape: shape,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            SizedBox(
              width: _spinnerSize,
              height: _spinnerSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.onPrimary,
              ),
            )
          else
            const Icon(Icons.check_rounded, size: _iconSize),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
        ],
      ),
    );
    final secondary = secondaryLabel;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: AppTheme.softShadowFor(colors),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header case final Widget header) ...[
            header,
            const SizedBox(height: _gap),
          ],
          Opacity(
            // A save in progress keeps the buttons fully shown: they are busy, not invalid.
            opacity: onPressed == null ? disabledOpacity : 1,
            child: SizedBox(
              height: _height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (secondary != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: enabled ? onSecondary : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.primary,
                          disabledForegroundColor: colors.primary,
                          side: BorderSide(color: colors.primary, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: shape,
                        ),
                        child: Text(
                          secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle,
                        ),
                      ),
                    ),
                    const SizedBox(width: _gap),
                  ],
                  Expanded(child: main),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
