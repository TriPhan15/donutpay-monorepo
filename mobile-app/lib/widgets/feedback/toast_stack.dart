import 'package:flutter/foundation.dart';

import 'package:finance_ai_app/l10n/app_localizations.dart';

/// What a toast tells the user; its icon and accent colour follow from it.
enum AppToastKind { success, error, info }

/// One toast in the stack: what it says, its optional button, and how long it stays up on its own.
@immutable
class ToastEntryData {
  const ToastEntryData({
    required this.id,
    required this.kind,
    required this.message,
    required this.shownAt,
    this.actionLabel,
    this.onAction,
  });

  /// How long a toast stays up before it closes by itself.
  static const Duration hold = Duration(seconds: 3);

  /// A toast with a button stays up a little longer, so there is time to reach it.
  static const Duration holdWithAction = Duration(seconds: 5);

  final int id;
  final AppToastKind kind;
  final String message;
  final DateTime shownAt;
  final String? actionLabel;
  final VoidCallback? onAction;

  bool get hasAction => actionLabel != null && onAction != null;

  Duration get holdFor => hasAction ? holdWithAction : hold;
}

/// The toasts on screen, newest first, at most [maxLayers] of them; and whether they are shown as a list.
///
/// Plain state only: the timers that close each toast belong to the widget that shows the stack.
class ToastStack extends ChangeNotifier {
  static const int maxLayers = 3;

  /// The clock that stamps a toast and that the open list measures its age with; tests move it by hand.
  static DateTime Function() now = DateTime.now;

  final List<ToastEntryData> _items = [];
  bool _expanded = false;
  int _nextId = 0;

  List<ToastEntryData> get items => List.unmodifiable(_items);

  bool get expanded => _expanded;

  /// Puts a new toast on top; the oldest one goes when there would be more than [maxLayers].
  ToastEntryData push({
    required AppToastKind kind,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final item = ToastEntryData(
      id: _nextId++,
      kind: kind,
      message: message,
      shownAt: now(),
      actionLabel: actionLabel,
      onAction: onAction,
    );
    _items.insert(0, item);
    if (_items.length > maxLayers) _items.removeLast();
    notifyListeners();
    return item;
  }

  void remove(int id) {
    final before = _items.length;
    _items.removeWhere((item) => item.id == id);
    if (_items.length == before) return;
    // A list of one is no list: it folds back, and the toast's timer runs again.
    if (_items.length < 2) _expanded = false;
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty && !_expanded) return;
    _items.clear();
    _expanded = false;
    notifyListeners();
  }

  void expand() {
    if (_expanded || _items.isEmpty) return;
    _expanded = true;
    notifyListeners();
  }

  void collapse() {
    if (!_expanded) return;
    _expanded = false;
    notifyListeners();
  }
}

/// How long ago a toast was shown, as the open list says it.
String toastAge(AppLocalizations loc, Duration age) {
  if (age < const Duration(seconds: 5)) return loc.toastJustNow;
  if (age < const Duration(minutes: 1)) {
    return loc.toastSecondsAgo(age.inSeconds);
  }
  return loc.toastMinutesAgo(age.inMinutes);
}
