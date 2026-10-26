import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/auth/login_page.dart';
import 'package:finance_ai_app/screens/main_scaffold.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/primary_button.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';

const String _loginPath = '/api/auth/login';
const String _home = 'home after sign-in';
const String _email = 'an@example.com';
const String _password = 'Secret123';

/// T10d: "remember me" keeps the session (as before) and also the email, which the login screen fills in after a
/// sign-out or a restart. The password is never stored by the app: the system password manager gets it through the
/// autofill group.
void main() {
  final backend = FakeBackend();

  setUpAll(() {
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    // The sign-in warms the home data up in the background; it must not reach a real database.
    AppRepository.instance.localStore = FakeLocalStore();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    // SharedPreferences shares one Future that must be created inside the test body (see budget_display_test.dart).
    SharedPreferences.setMockInitialValues({});
    backend.reset();
    backend.on(
      'POST',
      _loginPath,
      (_) => okResponse({
        'token': 'access-1',
        'refreshToken': 'refresh-1',
        'user': {'id': 1},
      }),
    );
    backend.on(
      'GET',
      '/api/users/me',
      (_) => okResponse({'id': 1, 'email': _email}),
    );
    backend.on('GET', '/api/transactions/mine', (_) => okResponse([]));
    LoginScreen.home = (_) => const Scaffold(body: Text(_home));
  });

  tearDown(() {
    LoginScreen.home = (_) => const MainScaffold();
    Intl.defaultLocale = null;
  });

  Future<void> openLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(withAppSettings(const LoginScreen()));
    await tester.pumpAndSettle();
  }

  Finder emailField() => find.byType(TextField).at(0);
  Finder passwordField() => find.byType(TextField).at(1);

  String fieldText(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).controller!.text;

  Future<void> signIn(
    WidgetTester tester, {
    String email = _email,
    bool untickRememberMe = false,
  }) async {
    if (untickRememberMe) {
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
    }
    await tester.enterText(emailField(), email);
    await tester.enterText(passwordField(), _password);
    await tester.tap(
      find.descendant(
        of: find.byType(PrimaryButton),
        matching: find.byType(ElevatedButton),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  testWidgets('a sign-in with "remember me" ticked keeps the email only', (
    tester,
  ) async {
    await openLogin(tester);
    await signIn(tester, email: '  $_email ');

    expect(find.text(_home), findsOneWidget);
    expect(await SessionService.rememberedEmail(), _email);
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      expect(
        '${prefs.get(key)}',
        isNot(contains(_password)),
        reason: 'the password is never stored ($key)',
      );
    }
  });

  testWidgets(
    'a sign-in with "remember me" unticked forgets the stored email',
    (tester) async {
      await SessionService.rememberEmail('old@example.com');
      await openLogin(tester);
      await signIn(tester, untickRememberMe: true);

      expect(find.text(_home), findsOneWidget);
      expect(await SessionService.rememberedEmail(), isNull);
    },
  );

  testWidgets('the remembered email is filled in after a sign-out', (
    tester,
  ) async {
    await SessionService.rememberEmail(_email);
    await SessionService.setCurrentUserId(1);
    await SessionService.setTokens('access-1', 'refresh-1');
    await SessionService.clearSession();

    await openLogin(tester);

    expect(fieldText(tester, emailField()), _email);
    expect(fieldText(tester, passwordField()), isEmpty);
  });

  testWidgets('without a remembered email the field stays empty', (
    tester,
  ) async {
    await openLogin(tester);
    expect(fieldText(tester, emailField()), isEmpty);
  });

  testWidgets('a failed sign-in does not change the remembered email', (
    tester,
  ) async {
    await SessionService.rememberEmail('old@example.com');
    backend.on('POST', _loginPath, (_) => jsonResponse(401, {'code': 401}));
    await openLogin(tester);
    await signIn(tester);

    expect(find.text(_home), findsNothing);
    expect(await SessionService.rememberedEmail(), 'old@example.com');
  });

  testWidgets(
    'email and password are one autofill group for the system password manager',
    (tester) async {
      await openLogin(tester);

      final group = find.byType(AutofillGroup);
      expect(group, findsOneWidget);
      expect(
        find.descendant(of: group, matching: find.byType(TextField)),
        findsNWidgets(2),
      );
      expect(tester.widget<TextField>(emailField()).autofillHints, [
        AutofillHints.email,
      ]);
      expect(tester.widget<TextField>(passwordField()).autofillHints, [
        AutofillHints.password,
      ]);
    },
  );
}
