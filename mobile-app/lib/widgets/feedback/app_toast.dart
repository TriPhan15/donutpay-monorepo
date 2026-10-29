import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/widgets/feedback/toast_stack.dart';

export 'package:finance_ai_app/widgets/feedback/toast_stack.dart'
    show AppToastKind;

/// A short message that slides in at the top of the screen and goes away by itself.
///
/// Toasts stack (T9 spec 3.11): the newest lies on top, up to two older ones show as plain layers behind it, and a
/// fourth pushes the oldest out. A tap on a stack of two or more opens it as a list, which stops every toast's timer
/// until it is folded back. Each toast closes on its own timer: [displayDuration], or [displayDurationWithAction]
/// with a button.
///
/// The stack lives in one entry of the root [Overlay], so it stays up when the page that showed it is popped. The
/// timers belong to the State of that entry and are cancelled in its dispose, so nothing is left running once the
/// widget tree is torn down.
class AppToast {
  AppToast._();

  static const Duration displayDuration = ToastEntryData.hold;

  static const Duration displayDurationWithAction =
      ToastEntryData.holdWithAction;

  /// The slide in, and the slide out.
  static const Duration transitionDuration = Duration(milliseconds: 250);

  static final ToastStack _stack = ToastStack()..addListener(_onStackChanged);
  static OverlayEntry? _entry;
  static OverlayState? _overlay;

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
    // Toasts left on an overlay that is gone (the tree was rebuilt after a logout) are dropped, not carried over.
    if (_entry != null && (!identical(_overlay, overlay) || !_overlayAlive)) {
      _detach();
      _stack.clear();
    }
    _stack.push(
      kind: kind,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    if (_entry == null) {
      final entry = OverlayEntry(
        builder: (_) => _ToastStackView(stack: _stack),
      );
      _entry = entry;
      _overlay = overlay;
      overlay.insert(entry);
    }
  }

  /// Drops every toast and the overlay entry; tests call it between cases, since the stack is shared.
  @visibleForTesting
  static void resetForTest() {
    _detach();
    _stack.clear();
  }

  static bool get _overlayAlive => _overlay?.mounted ?? false;

  static void _onStackChanged() {
    if (_stack.items.isEmpty) _detach();
  }

  static void _detach() {
    final entry = _entry;
    _entry = null;
    if (entry == null) return;
    // An entry whose overlay was disposed with the tree is already out of it.
    if (_overlayAlive && entry.mounted) {
      entry.remove();
      entry.dispose();
    }
    _overlay = null;
  }
}

/// A countdown that can stop and go on with the time it had left. It counts in [_tick] steps, which keeps it on the
/// test clock as well.
class _PausableTimer {
  _PausableTimer(this._left, this._onDone) {
    resume();
  }

  static const Duration _tick = Duration(milliseconds: 100);

  Duration _left;
  final VoidCallback _onDone;
  Timer? _timer;

  void resume() {
    if (_timer != null || _left <= Duration.zero) return;
    _timer = Timer.periodic(_tick, (_) {
      _left -= _tick;
      if (_left > Duration.zero) return;
      cancel();
      _onDone();
    });
  }

  void pause() => cancel();

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

class _ToastStackView extends StatefulWidget {
  const _ToastStackView({required this.stack});

  final ToastStack stack;

  @override
  State<_ToastStackView> createState() => _ToastStackViewState();
}

class _ToastStackViewState extends State<_ToastStackView>
    with SingleTickerProviderStateMixin {
  static const double _maxWidth = 560;
  static const double _layerInset = 10;
  static const double _layerDrop = 9;
  static const double _layerHeight = 56;
  static const double _radius = 16;
  static const double _listGap = 6;

  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: AppToast.transitionDuration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _slide,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(_curve);

  final Map<int, _PausableTimer> _timers = {};
  int? _frontId;

  ToastStack get _stack => widget.stack;

  @override
  void initState() {
    super.initState();
    _stack.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    _stack.removeListener(_sync);
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _curve.dispose();
    _slide.dispose();
    super.dispose();
  }

  /// Keeps one timer per toast on screen, all stopped while the list is open, and slides a new front toast in.
  void _sync() {
    final items = _stack.items;
    final ids = {for (final item in items) item.id};
    _timers.removeWhere((id, timer) {
      if (ids.contains(id)) return false;
      timer.cancel();
      return true;
    });
    for (final item in items) {
      _timers.putIfAbsent(
        item.id,
        () => _PausableTimer(item.holdFor, () => _expire(item.id)),
      );
    }
    for (final timer in _timers.values) {
      _stack.expanded ? timer.pause() : timer.resume();
    }
    final front = items.isEmpty ? null : items.first.id;
    if (front != null && front != _frontId) {
      _slide.forward(from: 0);
    }
    _frontId = front;
  }

  /// A lone toast slides out before it goes; one with others behind it simply goes.
  void _expire(int id) {
    if (!mounted) return;
    final items = _stack.items;
    if (items.length == 1 && items.first.id == id) {
      // A newer toast arriving meanwhile cancels the slide out; this one goes all the same, behind it.
      _slide.reverse().whenCompleteOrCancel(() {
        if (mounted) _stack.remove(id);
      });
      return;
    }
    _stack.remove(id);
  }

  void _runAction(ToastEntryData item) {
    item.onAction?.call();
    _stack.remove(item.id);
  }

  @override
  Widget build(BuildContext context) {
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
            child: ListenableBuilder(
              listenable: _stack,
              builder: (context, _) {
                final items = _stack.items;
                if (items.isEmpty) return const SizedBox.shrink();
                return _stack.expanded ? _list(items) : _stacked(items);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _stacked(List<ToastEntryData> items) {
    final front = items.first;
    final behind = items.length - 1;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;

    Widget stack = Stack(
      clipBehavior: Clip.none,
      children: [
        for (var layer = behind; layer >= 1; layer--)
          Positioned(
            left: layer * _layerInset,
            right: layer * _layerInset,
            top: layer * _layerDrop,
            child: Container(
              height: _layerHeight,
              decoration: BoxDecoration(
                color: layer == 1
                    ? colors.surfaceContainerLow
                    : colors.surfaceContainer,
                borderRadius: BorderRadius.circular(_radius),
                boxShadow: light ? AppTheme.softShadow : null,
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: behind * _layerDrop),
          child: SlideTransition(
            position: _offset,
            child: FadeTransition(
              opacity: _curve,
              child: Dismissible(
                key: ValueKey(front.id),
                direction: DismissDirection.up,
                resizeDuration: null,
                onDismissed: (_) => _stack.remove(front.id),
                child: _ToastCard(
                  item: front,
                  trailing: front.hasAction
                      ? _ActionButton(item: front, onPressed: _runAction)
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (behind == 0) {
      // A lone toast without a button lets every touch through, so it never hides the app bar it lies over; with one
      // it takes touches, and a swipe up closes it.
      return IgnorePointer(ignoring: !front.hasAction, child: stack);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _stack.expand,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          stack,
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.scrim.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                context.locOrDefault.toastStackCount(items.length),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppTextSize.caption,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<ToastEntryData> items) {
    final loc = context.locOrDefault;
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final linkStyle = TextStyle(
      color: colors.primary,
      fontSize: AppTextSize.secondary,
      fontWeight: FontWeight.w700,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, item) in items.indexed) ...[
          if (index > 0) const SizedBox(height: _listGap),
          _ToastCard(
            item: item,
            age: toastAge(loc, now.difference(item.shownAt)),
            trailing: item.hasAction
                ? _ActionButton(item: item, onPressed: _runAction)
                : IconButton(
                    tooltip: loc.toastDismiss,
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                    onPressed: () => _stack.remove(item.id),
                  ),
          ),
        ],
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _stack.collapse,
              child: Text(loc.toastCollapse, style: linkStyle),
            ),
            Text('·', style: linkStyle),
            TextButton(
              onPressed: _stack.clear,
              child: Text(loc.toastCloseAll, style: linkStyle),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.item, required this.onPressed});

  final ToastEntryData item;
  final ValueChanged<ToastEntryData> onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = _ToastCard.accentOf(item.kind, Theme.of(context));
    return TextButton(
      onPressed: () => onPressed(item),
      child: Text(
        item.actionLabel!,
        style: TextStyle(color: accent, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// One toast: its icon in a tinted circle, the message, and [age] under it in the open list.
class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.item, this.age, this.trailing});

  static const double _radius = 16;
  static const double _iconBoxSize = 32;
  static const double _iconSize = 20;
  static const int _maxMessageLines = 3;

  final ToastEntryData item;
  final String? age;
  final Widget? trailing;

  static Color accentOf(AppToastKind kind, ThemeData theme) => switch (kind) {
    AppToastKind.success => theme.semanticColors.successColor,
    AppToastKind.error => theme.colorScheme.error,
    AppToastKind.info => theme.colorScheme.primary,
  };

  static IconData _iconOf(AppToastKind kind) => switch (kind) {
    AppToastKind.success => Icons.check_circle_rounded,
    AppToastKind.error => Icons.error_rounded,
    AppToastKind.info => Icons.info_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = accentOf(item.kind, theme);
    final background = Color.alphaBlend(
      accent.withValues(alpha: 0.10),
      colors.surface,
    );
    final message = Text(
      item.message,
      maxLines: _maxMessageLines,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: colors.onSurface,
        fontSize: AppTextSize.body,
        fontWeight: FontWeight.w500,
      ),
    );

    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: background,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: accent.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 12, trailing == null ? 14 : 6, 12),
          child: Row(
            children: [
              Container(
                width: _iconBoxSize,
                height: _iconBoxSize,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconOf(item.kind), color: accent, size: _iconSize),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: age == null
                    ? message
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          message,
                          Text(
                            age!,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: AppTextSize.caption,
                            ),
                          ),
                        ],
                      ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
