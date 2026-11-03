import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/widgets/dialogs/app_sheet.dart';

void main() {
  const double screenHeight = 800;
  const double tallContent = 700;
  const Key contentKey = ValueKey('sheet-content');
  const Key openKey = ValueKey('open-sheet');

  /// Opens a sheet with [tallContent] of content from a button and returns what it popped.
  Future<void> openSheet(
    WidgetTester tester, {
    bool? isScrollControlled,
    required void Function(Future<int?> result) onOpened,
  }) async {
    tester.view.physicalSize = const Size(400, screenHeight);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: openKey,
              onPressed: () {
                Widget builder(BuildContext _) => Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    key: contentKey,
                    height: tallContent,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(7),
                      child: const Text('pick'),
                    ),
                  ),
                );
                onOpened(
                  isScrollControlled == null
                      ? showAppSheet<int>(context, builder)
                      : showAppSheet<int>(
                          context,
                          builder,
                          isScrollControlled: isScrollControlled,
                        ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(openKey));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the built sheet and returns what it pops', (tester) async {
    late Future<int?> result;
    await openSheet(tester, onOpened: (r) => result = r);

    expect(find.byKey(contentKey), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();

    expect(await result, 7);
    expect(find.byKey(contentKey), findsNothing);
  });

  testWidgets(
    'is scroll controlled by default: not capped at 9/16 of the screen',
    (tester) async {
      await openSheet(tester, onOpened: (_) {});

      expect(tester.getSize(find.byKey(contentKey)).height, tallContent);
    },
  );

  testWidgets('isScrollControlled false caps the sheet at 9/16 of the screen', (
    tester,
  ) async {
    await openSheet(tester, isScrollControlled: false, onOpened: (_) {});

    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      screenHeight * 9 / 16,
    );
  });

  testWidgets('has no drag handle and no safe area of its own', (tester) async {
    await openSheet(tester, onOpened: (_) {});

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.showDragHandle, isFalse);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(SafeArea),
      ),
      findsNothing,
    );
  });

  testWidgets('leaves the shape to the theme', (tester) async {
    await openSheet(tester, onOpened: (_) {});

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.shape, isNull);
  });
}
