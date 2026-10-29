import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';

/// What a dialog tells the user; its accent colour is read from the theme when the dialog is built.
enum _Tone { success, error, warning, info }

/// Two layouts (T9 spec 3.11): a message (success, error, warning, info) shows a large ring with its icon and one wide
/// button; a question (confirm, choose) has no icon and two text buttons split by a line.
///
/// Unset button texts default to the app's own (Done, Got it, Confirm, Cancel) in the language the app shows.
class AppDialog {
  static Future<void> success(
    BuildContext context, {
    required String title,
    String? message,
    String? buttonText,
  }) => _show(
    context,
    icon: Icons.check_circle_rounded,
    tone: _Tone.success,
    title: title,
    message: message,
    confirmText: buttonText ?? context.locOrDefault.dialogDone,
  ).then((_) {});

  static Future<void> error(
    BuildContext context, {
    required String title,
    String? message,
    String? buttonText,
  }) => _show(
    context,
    icon: Icons.error_rounded,
    tone: _Tone.error,
    title: title,
    message: message,
    confirmText: buttonText ?? context.locOrDefault.dialogGotIt,
  ).then((_) {});

  static Future<void> warning(
    BuildContext context, {
    required String title,
    String? message,
    String? buttonText,
  }) => _show(
    context,
    icon: Icons.warning_amber_rounded,
    tone: _Tone.warning,
    title: title,
    message: message,
    confirmText: buttonText ?? context.locOrDefault.dialogGotIt,
  ).then((_) {});

  static Future<void> info(
    BuildContext context, {
    required String title,
    String? message,
    String? buttonText,
  }) => _show(
    context,
    icon: Icons.info_rounded,
    tone: _Tone.info,
    title: title,
    message: message,
    confirmText: buttonText ?? context.locOrDefault.dialogGotIt,
  ).then((_) {});

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String? confirmText,
    String? cancelText,
    bool danger = false,
  }) async {
    final loc = context.locOrDefault;
    final r = await _ask(
      context,
      title: title,
      message: message,
      confirmText: confirmText ?? loc.dialogConfirm,
      cancelText: cancelText ?? loc.dialogCancel,
      danger: danger,
      dismissible: false,
    );
    return r == true;
  }

  /// A question with two answers that the user may also leave unanswered, by Back or a tap outside the dialog:
  /// true for [confirmText], false for [cancelText], null when the dialog was dismissed.
  static Future<bool?> choose(
    BuildContext context, {
    required String title,
    String? message,
    required String confirmText,
    required String cancelText,
  }) {
    return _ask(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      danger: false,
      dismissible: true,
    );
  }

  static Color _accentOf(_Tone tone, ThemeData theme) => switch (tone) {
    _Tone.success => theme.semanticColors.successColor,
    _Tone.error => theme.colorScheme.error,
    _Tone.warning => theme.semanticColors.warningColor,
    _Tone.info => theme.colorScheme.primary,
  };

  static const double _messageRadius = 24;
  static const double _questionRadius = 16;
  static const double _ringSize = 72;
  static const double _ringIconSize = 38;
  static const double _lineHeight = 1.55;

  static TextStyle _messageStyle(ColorScheme colors) => TextStyle(
    color: colors.onSurfaceVariant,
    fontSize: AppTextSize.body,
    height: _lineHeight,
  );

  /// Opens [dialog] with the app's dialog transition: a short fade and a scale from 0.85.
  static Future<bool?> _open(
    BuildContext context, {
    required bool dismissible,
    required Widget Function(BuildContext ctx) dialog,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: dismissible,
      barrierLabel: 'dialog',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 240),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Opacity(
          opacity: anim.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.85 + 0.15 * curved.value,
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, _) => dialog(ctx),
    );
  }

  static Future<bool?> _show(
    BuildContext context, {
    required IconData icon,
    required _Tone tone,
    required String title,
    String? message,
    required String confirmText,
  }) {
    return _open(
      context,
      dismissible: true,
      dialog: (ctx) {
        final theme = Theme.of(ctx);
        final colors = theme.colorScheme;
        final accent = _accentOf(tone, theme);
        // The dialog takes the surface colour of the theme; the title keeps the text colour it gives.
        return Dialog(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_messageRadius),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: _ringSize,
                    height: _ringSize,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accent, size: _ringIconSize),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppTextSize.pageTitle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: _messageStyle(colors),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  // The label takes the dialog's surface colour: white in light mode, dark on the light accents of
                  // the dark theme, which keeps them at 4.5:1 or more against that surface.
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: colors.surface,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: AppTextSize.title,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(confirmText),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// A question: no icon, the text centred, Cancel and the action as two text buttons split by a line.
  static Future<bool?> _ask(
    BuildContext context, {
    required String title,
    String? message,
    required String confirmText,
    required String cancelText,
    required bool danger,
    required bool dismissible,
  }) {
    return _open(
      context,
      dismissible: dismissible,
      dialog: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        final divider = colors.outlineVariant;
        return Dialog(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_questionRadius),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: AppTextSize.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: _messageStyle(colors),
                      ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: divider),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _QuestionButton(
                        label: cancelText,
                        color: colors.primary,
                        bold: false,
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ),
                    VerticalDivider(width: 1, thickness: 1, color: divider),
                    Expanded(
                      child: _QuestionButton(
                        label: confirmText,
                        color: danger ? colors.error : colors.primary,
                        bold: true,
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One of the two answers at the bottom of a question dialog.
class _QuestionButton extends StatelessWidget {
  const _QuestionButton({
    required this.label,
    required this.color,
    required this.bold,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final bool bold;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: const RoundedRectangleBorder(),
        textStyle: TextStyle(
          fontSize: AppTextSize.title,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
