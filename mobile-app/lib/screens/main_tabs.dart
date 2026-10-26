import 'package:flutter/foundation.dart';

/// The tabs of MainScaffold, in the order of its bottom bar.
enum MainTab { home, ledger, ai, profile }

/// Lets a page pushed over MainScaffold (the notification centre, opened from the home tab) bring one of its tabs to
/// the front without a callback threaded through every page in between. MainScaffold attaches itself while it is
/// mounted; with no MainScaffold (a page tested on its own) [opener] is null.
abstract final class MainTabs {
  static ValueChanged<MainTab>? _show;

  static void attach(ValueChanged<MainTab> show) => _show = show;

  /// Detaches [show] only if it is still the one attached, so a newer MainScaffold is not cut off by an older one.
  static void detach(ValueChanged<MainTab> show) {
    if (_show == show) _show = null;
  }

  /// A callback that shows [tab], or null when no MainScaffold is there to show it.
  static VoidCallback? opener(MainTab tab) {
    final show = _show;
    return show == null ? null : () => show(tab);
  }
}
