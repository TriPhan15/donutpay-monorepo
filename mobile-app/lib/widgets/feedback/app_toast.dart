import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';

/// What a toast tells the user; its icon and accent colour follow from it.
enum AppToastKind { success, error, info }

/// A short message that slides in at the top of the screen and goes away by itself.
///
/// It lives in the root [Overlay], so it stays up when the page that showed it is popped, and only one toast is shown
/// at a time: a new one replaces the one on screen. The slide in and out run on an [AnimationController]; the time
/// it stays up is a [Timer] owned by the toast's own State and cancelled in its dispose, so nothing is left running
/// once the toast is gone or the widget tree is torn down.
class AppToast {
  AppToast._();

  /// How long a toast stays up before it closes by itself.
  static const Duration displayDuration = Duration(seconds: 3);

  /// A toast with a button stays up a little longer, so there is time to reach it.
  static const Duration displayDurationWithAction = Duration(seconds: 5);

  /// The slide in, and the slide out.
  static const Duration transitionDuration = Duration(milliseconds: 250);

  static _ToastHandle? _current;

  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    AppToastKind.success,
    message,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    AppToastKind.error,
    message,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void info(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    AppToastKind.info,
    message,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void show(
    BuildContext context,
    AppToastKind kind,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      debugPrint('AppToast: không có Overlay để hiện thông báo "$message"');
      return;
    }
    showOn(
      overlay,
      kind,
      message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// For code without a BuildContext of its own (the 401 interceptor reaches the screen through the navigator key).
  static void showOn(
    OverlayState overlay,
    AppToastKind kind,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    assert(
      (actionLabel == null) == (onAction == null),
      'An action needs both a label and a callback.',
    );
    _current?.remove();
    final handle = _ToastHandle();
    final hasAction = actionLabel != null && onAction != null;
    handle.entry = OverlayEntry(
      builder: (_) => _ToastView(
        kind: kind,
        message: message,
        actionLabel: hasAction ? actionLabel : null,
        onAction: hasAction ? onAction : null,
        duration: hasAction ? displayDurationWithAction : displayDuration,
        onClosed: () {
          handle.remove();
          if (identical(_current, handle)) _current = null;
        },
      ),
    );
    _current = handle;
    overlay.insert(handle.entry);
  }
}

/// Removes its entry once, however many ways a toast can end (timer, swipe, button, a newer toast).
class _ToastHandle {
  late final OverlayEntry entry;
  bool _removed = false;

  void remove() {
    if (_removed) return;
    _removed = true;
    entry.remove();
    entry.dispose();
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.kind,
    required this.message,
    required this.duration,
    required this.onClosed,
    this.actionLabel,
    this.onAction,
  });

  final AppToastKind kind;
  final String message;
  final Duration duration;
  final VoidCallback onClosed;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  static const double _maxWidth = 560;
  static const double _radius = 16;
  static const double _iconBoxSize = 32;
  static const double _iconSize = 20;
  static const int _maxMessageLines = 3;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppToast.transitionDuration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(_curve);
  Timer? _hold;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _hold = Timer(widget.duration, _close);
  }

  @override
  void dispose() {
    _hold?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    _hold?.cancel();
    // The future of reverse() does not complete when the controller is disposed first, so there is nothing to undo.
    _controller.reverse().then((_) {
      if (mounted) widget.onClosed();
    });
  }

  void _runAction() {
    widget.onAction?.call();
    _close();
  }

  (IconData, Color) _lookOf(ThemeData theme) => switch (widget.kind) {
    AppToastKind.success => (
      Icons.check_circle_rounded,
      theme.semanticColors.successColor,
    ),
    AppToastKind.error => (Icons.error_rounded, theme.colorScheme.error),
    AppToastKind.info => (Icons.info_rounded, theme.colorScheme.primary),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, accent) = _lookOf(theme);
    final background = Color.alphaBlend(
      accent.withValues(alpha: 0.10),
      colors.surface,
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _curve,
                // Without a button the toast lets every touch through, so it never hides the app bar it lies over;
                // with one it takes touches, and a swipe up closes it.
                child: IgnorePointer(
                  ignoring: widget.actionLabel == null,
                  child: Dismissible(
                    key: ObjectKey(this),
                    direction: DismissDirection.up,
                    resizeDuration: null,
                    onDismissed: (_) => widget.onClosed(),
                    child: Semantics(
                      container: true,
                      liveRegion: true,
                      child: Material(
                        color: background,
                        elevation: 6,
                        shadowColor: Colors.black.withValues(alpha: 0.25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_radius),
                          side: BorderSide(
                            color: accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            14,
                            12,
                            widget.actionLabel == null ? 14 : 6,
                            12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: _iconBoxSize,
                                height: _iconBoxSize,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  icon,
                                  color: accent,
                                  size: _iconSize,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.message,
                                  maxLines: _maxMessageLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (widget.actionLabel != null)
                                TextButton(
                                  onPressed: _runAction,
                                  child: Text(
                                    widget.actionLabel!,
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
