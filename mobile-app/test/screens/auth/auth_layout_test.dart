import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/screens/auth/forgot_password_page.dart';
import 'package:finance_ai_app/screens/auth/login_page.dart';
import 'package:finance_ai_app/screens/auth/register_page.dart';
import 'package:finance_ai_app/screens/auth/reset_password_page.dart';
import 'package:finance_ai_app/widgets/auth/auth_form_layout.dart';

import '../../helpers/app_settings_scope.dart';

/// Every auth screen on a 320 x 640 phone with the text 1.3 times larger: nothing overflows and the whole card
/// scrolls into view.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Intl.defaultLocale = null);

  Future<void> showSmall(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(withAppSettings(screen));
    await tester.pumpAndSettle();
  }

  final screens = <String, Widget>{
    'LoginScreen': const LoginScreen(),
    'RegisterScreen': const RegisterScreen(),
    'ForgotPasswordScreen': const ForgotPasswordScreen(),
    'ResetPasswordScreen': const ResetPasswordScreen(email: 'an@example.com'),
  };
  for (final entry in screens.entries) {
    testWidgets('${entry.key} fits a 320 px phone with large text', (
      tester,
    ) async {
      await showSmall(tester, entry.value);

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byType(ElevatedButton),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(ElevatedButton).hitTestable(), findsOneWidget);
    });
  }

  testWidgets('the white link under the login card opens the register screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(withAppSettings(const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AuthFooterLink));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
  });
}
