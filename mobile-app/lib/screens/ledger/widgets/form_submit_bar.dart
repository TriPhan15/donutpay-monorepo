import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';

/// The main button of a form, held at the bottom of the page (T9 spec, 3.3). Faded and inert while the form is not
/// valid ([onPressed] null); [busy] swaps the tick for a spinner and ignores taps while a save runs.
class FormSubmitBar extends StatelessWidget {
  const FormSubmitBar({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
  });

  static const double disabledOpacity = 0.45;
  static const double _height = 52;
  static const double _radius = 16;
  static const double _iconSize = 20;
  static const double _spinnerSize = 18;

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !busy;
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
      child: Opacity(
        // A save in progress keeps the button fully shown: it is busy, not invalid.
        opacity: onPressed == null ? disabledOpacity : 1,
        child: SizedBox(
          width: double.infinity,
          height: _height,
          child: FilledButton(
            onPressed: enabled ? onPressed : null,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              disabledBackgroundColor: colors.primary,
              disabledForegroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radius),
              ),
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
                    style: const TextStyle(
                      fontSize: AppTextSize.title,
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
