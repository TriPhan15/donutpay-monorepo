import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

const String _message = 'Đã lưu';
const String _show = 'show';

/// A page with a button at the top, under where the toast lies, and one that shows a toast through [onShow].
Widget _app({
  required void Function(BuildContext context) onShow,
  ThemeData? theme,
  VoidCallback? onTopTap,
}) {
  return MaterialApp(
    theme: theme,
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          actions: [TextButton(onPressed: onTopTap, child: const Text('top'))],
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: () => onShow(context),
            child: const Text(_show),
          ),
        ),
      ),
    ),
  );
}

Future<void> _tapShow(WidgetTester tester) async {
  await tester.tap(find.text(_show));
  await tester.pumpAndSettle();
}

Icon _toastIcon(WidgetTester tester) => tester.widget<Icon>(
  find.descendant(
    of: find.ancestor(of: find.text(_message), matching: find.byType(Row)),
    matching: find.byType(Icon),
  ),
);

void main() {
  setUp(AppToast.resetForTest);
  testWidgets(
    'shows the message near the top, keeps it through pumpAndSettle, and closes it by itself',
    (tester) async {
      await tester.pumpWidget(
        _app(onShow: (context) => AppToast.success(context, _message)),
      );
      await _tapShow(tester);

      expect(find.text(_message), findsOneWidget);
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(
        tester.getTopLeft(find.text(_message)).dy,
        lessThan(screenHeight / 4),
      );

      await tester.pump(AppToast.displayDuration);
      await tester.pumpAndSettle();
      expect(find.text(_message), findsNothing);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('each kind has its own icon and colour ($brightness)', (
      tester,
    ) async {
      final theme = ThemeData(brightness: brightness);
      final kinds = <AppToastKind, (IconData, Color)>{
        AppToastKind.success: (
          Icons.check_circle_rounded,
          theme.semanticColors.successColor,
        ),
        AppToastKind.error: (Icons.error_rounded, theme.colorScheme.error),
        AppToastKind.info: (Icons.info_rounded, theme.colorScheme.primary),
      };
      var kind = AppToastKind.success;
      await tester.pumpWidget(
        _app(
          theme: theme,
          onShow: (context) => AppToast.show(context, kind, _message),
        ),
      );

      for (final entry in kinds.entries) {
        kind = entry.key;
        await _tapShow(tester);
        final icon = _toastIcon(tester);
        expect(icon.icon, entry.value.$1, reason: '$kind');
        expect(icon.color, entry.value.$2, reason: '$kind');
        expect(
          tester.widget<Text>(find.text(_message)).style?.color,
          theme.colorScheme.onSurface,
        );
      }
    });
  }

  testWidgets('a second toast stacks on top and shows the count label', (
    tester,
  ) async {
    var count = 0;
    await tester.pumpWidget(
      _app(onShow: (context) => AppToast.info(context, 'Toast ${++count}')),
    );

    await _tapShow(tester);
    expect(find.textContaining('chạm để xem'), findsNothing);
    await _tapShow(tester);

    expect(
      find.text('Toast 1'),
      findsNothing,
      reason: 'the older one is a plain layer',
    );
    expect(find.text('Toast 2'), findsOneWidget);
    expect(find.text('2 thông báo · chạm để xem'), findsOneWidget);
  });

  testWidgets('a fourth toast pushes the oldest out', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      _app(onShow: (context) => AppToast.info(context, 'Toast ${++count}')),
    );

    for (var i = 0; i < 4; i++) {
      await _tapShow(tester);
    }

    expect(find.text('Toast 4'), findsOneWidget);
    expect(find.text('3 thông báo · chạm để xem'), findsOneWidget);
    await tester.tap(find.text('3 thông báo · chạm để xem'));
    await tester.pumpAndSettle();
    expect(find.text('Toast 1'), findsNothing);
    expect(find.text('Toast 2'), findsOneWidget);
  });

  testWidgets('each toast closes on its own timer', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      _app(onShow: (context) => AppToast.info(context, 'Toast ${++count}')),
    );

    await _tapShow(tester);
    await tester.pump(const Duration(seconds: 2));
    await _tapShow(tester);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.textContaining('chạm để xem'), findsNothing);
    expect(find.text('Toast 2'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Toast 2'), findsNothing);
  });

  testWidgets(
    'tapping the stack expands it into a list with ages and close buttons, and stops the timers',
    (tester) async {
      var count = 0;
      await tester.pumpWidget(
        _app(onShow: (context) => AppToast.info(context, 'Toast ${++count}')),
      );
      await _tapShow(tester);
      await _tapShow(tester);

      await tester.tap(find.text('2 thông báo · chạm để xem'));
      await tester.pumpAndSettle();
      expect(find.text('Toast 1'), findsOneWidget);
      expect(find.text('Toast 2'), findsOneWidget);
      expect(find.text('vừa xong'), findsNWidgets(2));
      expect(find.text('Thu gọn'), findsOneWidget);
      expect(find.text('Đóng tất cả'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Toast 1'), findsOneWidget, reason: 'timers stop');

      await tester.tap(find.byTooltip('Đóng').first);
      await tester.pumpAndSettle();
      expect(find.text('Toast 2'), findsNothing);
      expect(find.text('Toast 1'), findsOneWidget);
      expect(
        find.text('Đóng tất cả'),
        findsNothing,
        reason: 'a list of one folds back and its timer runs again',
      );
      await tester.pump(AppToast.displayDuration);
      await tester.pumpAndSettle();
      expect(find.text('Toast 1'), findsNothing);
    },
  );

  testWidgets('Đóng tất cả closes every toast', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      _app(onShow: (context) => AppToast.info(context, 'Toast ${++count}')),
    );
    await _tapShow(tester);
    await _tapShow(tester);
    await tester.tap(find.text('2 thông báo · chạm để xem'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đóng tất cả'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Toast'), findsNothing);
  });

  testWidgets('Thu gọn resumes the timers with the time that was left', (
    tester,
  ) async {
    var count = 0;
    await tester.pumpWidget(
      _app(onShow: (context) => AppToast.info(context, 'Toast ${++count}')),
    );
    await _tapShow(tester);
    await _tapShow(tester);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('2 thông báo · chạm để xem'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    await tester.tap(find.text('Thu gọn'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.text('Toast 2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Toast 2'), findsNothing);
    expect(find.text('Toast 1'), findsNothing);
  });

  testWidgets('a stack of two takes taps', (tester) async {
    var topTaps = 0;
    await tester.pumpWidget(
      _app(
        onShow: (context) => AppToast.error(context, _message),
        onTopTap: () => topTaps++,
      ),
    );
    await _tapShow(tester);
    await _tapShow(tester);

    await tester.tap(find.text(_message), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(topTaps, 0);
    expect(find.text('Đóng tất cả'), findsOneWidget);
  });

  testWidgets(
    'tearing the tree down while expanded leaves no timer and throws nothing',
    (tester) async {
      await tester.pumpWidget(
        _app(onShow: (context) => AppToast.info(context, _message)),
      );
      await _tapShow(tester);
      await _tapShow(tester);
      await tester.tap(find.text('2 thông báo · chạm để xem'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(AppToast.displayDurationWithAction);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the action runs its callback and closes the toast; such a toast stays up longer',
    (tester) async {
      var undone = 0;
      await tester.pumpWidget(
        _app(
          onShow: (context) => AppToast.success(
            context,
            _message,
            actionLabel: 'Hoàn tác',
            onAction: () => undone++,
          ),
        ),
      );
      await _tapShow(tester);

      await tester.pump(AppToast.displayDuration);
      await tester.pumpAndSettle();
      expect(
        find.text(_message),
        findsOneWidget,
        reason: 'a toast with a button waits displayDurationWithAction',
      );

      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.text(_message), findsNothing);
    },
  );

  testWidgets('a toast without a button lets taps reach what lies under it', (
    tester,
  ) async {
    var topTaps = 0;
    await tester.pumpWidget(
      _app(
        onShow: (context) => AppToast.error(context, _message),
        onTopTap: () => topTaps++,
      ),
    );
    await _tapShow(tester);

    await tester.tap(find.text('top'), warnIfMissed: false);
    expect(topTaps, 1);
  });

  testWidgets('stays up when the page that showed it is closed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (page) => Scaffold(
                    body: ElevatedButton(
                      onPressed: () {
                        AppToast.success(page, _message);
                        Navigator.pop(page);
                      },
                      child: const Text('save'),
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    expect(find.text('save'), findsNothing);
    expect(find.text(_message), findsOneWidget);
  });

  testWidgets(
    'tearing the tree down while a toast is up leaves no timer and throws nothing',
    (tester) async {
      await tester.pumpWidget(
        _app(onShow: (context) => AppToast.info(context, _message)),
      );
      await _tapShow(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(AppToast.displayDurationWithAction);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a toast can be shown on an overlay without a BuildContext of its own',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigatorKey, home: const Scaffold()),
      );

      AppToast.showOn(
        navigatorKey.currentState!.overlay!,
        AppToastKind.info,
        _message,
      );
      await tester.pumpAndSettle();

      expect(find.text(_message), findsOneWidget);
    },
  );
}
