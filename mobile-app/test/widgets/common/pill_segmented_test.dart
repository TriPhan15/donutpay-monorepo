import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/widgets/common/pill_segmented.dart';

void main() {
  Future<ColorScheme> pump(
    WidgetTester tester,
    Widget child, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    late ColorScheme colors;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              colors = Theme.of(context).colorScheme;
              return Padding(padding: const EdgeInsets.all(16), child: child);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return colors;
  }

  Color? textColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style?.color;

  Color? fill(WidgetTester tester, String label) {
    final box = tester.widget<AnimatedContainer>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return (box.decoration as BoxDecoration?)?.color;
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'the selected pill is primary with onPrimary text, the others plain (${mode.name})',
      (tester) async {
        final colors = await pump(
          tester,
          PillSegmented<int>(
            options: const [(1, 'Một'), (2, 'Hai'), (3, 'Ba')],
            selected: 2,
            onChanged: (_) {},
          ),
          mode: mode,
        );
        expect(fill(tester, 'Hai'), colors.primary);
        expect(textColor(tester, 'Hai'), colors.onPrimary);
        expect(fill(tester, 'Một'), isNot(colors.primary));
        expect(textColor(tester, 'Một'), colors.onSurfaceVariant);
        final track = tester.widget<Container>(
          find.byKey(PillSegmented.trackKey),
        );
        expect(
          (track.decoration as BoxDecoration).color,
          colors.surfaceContainerHighest,
        );
        expect(tester.getSize(find.byKey(PillSegmented.trackKey)).height, 36);
      },
    );
  }

  testWidgets('tapping a pill reports its value', (tester) async {
    String? picked;
    await pump(
      tester,
      PillSegmented<String>(
        options: const [('a', 'Biểu đồ'), ('b', 'Lịch')],
        selected: 'a',
        onChanged: (v) => picked = v,
      ),
    );
    await tester.tap(find.text('Lịch'));
    expect(picked, 'b');
  });

  testWidgets('three long labels fit 320 px at text scale 1.3', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.3,
        maxScaleFactor: 1.3,
        child: PillSegmented<int>(
          options: const [
            (1, 'Biểu đồ chi tiêu'),
            (2, 'Lịch theo ngày'),
            (3, 'Danh mục chi'),
          ],
          selected: 1,
          onChanged: (_) {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final label in [
      'Biểu đồ chi tiêu',
      'Lịch theo ngày',
      'Danh mục chi',
    ]) {
      expect(tester.widget<Text>(find.text(label)).maxLines, 1);
    }
  });
}
