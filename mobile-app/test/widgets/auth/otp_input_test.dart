import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/widgets/auth/otp_input.dart';

import '../../helpers/app_settings_scope.dart';

const String _label = 'Mã OTP';
const String _required = 'Vui lòng nhập mã OTP.';

void main() {
  late TextEditingController controller;
  late GlobalKey<FormState> formKey;

  setUp(() {
    controller = TextEditingController();
    formKey = GlobalKey<FormState>();
  });
  tearDown(() {
    controller.dispose();
    Intl.defaultLocale = null;
  });

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      withAppSettings(
        Scaffold(
          body: Form(
            key: formKey,
            child: OtpInput(
              controller: controller,
              length: 6,
              semanticsLabel: _label,
              validator: (otp) => otp.isEmpty ? _required : null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field() => find.descendant(
    of: find.byType(OtpInput),
    matching: find.byType(EditableText),
  );

  String box(WidgetTester tester, int index) {
    final texts = tester.widgetList<Text>(
      find.descendant(
        of: find.byKey(OtpInput.boxKey(index)),
        matching: find.byType(Text),
      ),
    );
    return texts.isEmpty ? '' : texts.first.data ?? '';
  }

  testWidgets('shows one box per digit, filled as the code is typed', (
    tester,
  ) async {
    await show(tester);

    for (var i = 0; i < 6; i++) {
      expect(find.byKey(OtpInput.boxKey(i)), findsOneWidget);
    }
    expect(find.byKey(OtpInput.boxKey(6)), findsNothing);

    await tester.enterText(field(), '4821');
    await tester.pump();

    expect(controller.text, '4821');
    expect(
      [for (var i = 0; i < 6; i++) box(tester, i)],
      ['4', '8', '2', '1', '', ''],
    );
  });

  testWidgets('a pasted code keeps its first six digits only', (tester) async {
    await show(tester);

    await tester.enterText(field(), '123 4567');
    await tester.pump();

    expect(controller.text, '123456');
    expect(box(tester, 5), '6');
  });

  testWidgets('deleting removes the last digit', (tester) async {
    await show(tester);
    await tester.enterText(field(), '123456');
    await tester.pump();

    await tester.enterText(field(), '12345');
    await tester.pump();

    expect(controller.text, '12345');
    expect(box(tester, 5), '');
  });

  testWidgets('the error of the validator shows under the boxes', (
    tester,
  ) async {
    await show(tester);

    expect(find.text(_required), findsNothing);
    formKey.currentState!.validate();
    await tester.pump();

    expect(find.text(_required), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(_required)).dy,
      greaterThan(tester.getBottomLeft(find.byKey(OtpInput.boxKey(0))).dy),
    );
  });

  testWidgets('tapping a box focuses the code field', (tester) async {
    await show(tester);

    await tester.tap(find.byKey(OtpInput.boxKey(3)));
    await tester.pump();

    expect(tester.widget<EditableText>(field()).focusNode.hasFocus, isTrue);
  });

  testWidgets('screen readers hear the label of the code', (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester);

    expect(find.bySemanticsLabel(RegExp(_label)), findsWidgets);
    semantics.dispose();
  });

  testWidgets('fits a 320 px phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await show(tester);
    await tester.enterText(field(), '123456');
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a long press selects without painting over the boxes', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(field());
    await tester.pump();
    final editable = tester.widget<EditableText>(field());
    expect(editable.selectionColor?.a, 0);
  });

  testWidgets('screen readers hear the code once, from the field', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await show(tester);
    await tester.enterText(field(), '48');
    await tester.pump();

    final node = tester.getSemantics(find.byType(OtpInput));
    expect(node.label, _label, reason: 'the boxes add no digits to the label');
    expect(node.value, '48');
    semantics.dispose();
  });
}
