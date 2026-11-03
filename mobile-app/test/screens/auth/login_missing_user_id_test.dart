import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/auth/login_page.dart';
import 'package:finance_ai_app/screens/auth/register_page.dart';
import 'package:finance_ai_app/screens/main_scaffold.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/auth/auth_social_buttons.dart';
import 'package:finance_ai_app/widgets/common/primary_button.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';

const String _loginPath = '/api/auth/login';
const String _socialLoginPath = '/api/auth/social-login';
const String _home = 'home after sign-in';
const String _loginFailedTitle = 'Đăng nhập thất bại';
const String _registerFailedTitle = 'Đăng ký thất bại';
const String _invalidResponse =
    'Phản hồi từ máy chủ không hợp lệ. Vui lòng thử lại.';

/// An answer that signs in but names no user: a session with tokens and without an id would open an app whose tabs are
/// all empty or end the session at the first request. The sign-in must stop, with nothing kept.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final backend = FakeBackend();

  // The Facebook sign-in is a plain channel call; this is the answer of the Facebook SDK on a successful login.
  const facebookChannel = MethodChannel('app.meedu/flutter_facebook_auth');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() {
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    AppRepository.instance.localStore = FakeLocalStore();
    messenger.setMockMethodCallHandler(facebookChannel, (call) async {
      switch (call.method) {
        case 'login':
          return {
            'type': 'limited',
            'userId': 'fb-1',
            'userName': 'An',
            'userEmail': 'an@example.com',
            'token': 'facebook-token',
            'nonce': 'nonce-1',
          };
        case 'getUserData':
          // On Android the plugin decodes the answer from a JSON text.
          return jsonEncode({'email': 'an@example.com', 'name': 'An'});
      }
      return null;
    });
  });

  tearDownAll(() => messenger.setMockMethodCallHandler(facebookChannel, null));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    // SharedPreferences shares one Future that must be created inside the test body (see budget_display_test.dart).
    SharedPreferences.setMockInitialValues({});
    backend.reset();
    backend.on('GET', '/api/users/me', (_) => okResponse({'id': 1}));
    backend.on('GET', '/api/transactions/mine', (_) => okResponse([]));
    LoginScreen.home = (_) => const Scaffold(body: Text(_home));
  });

  tearDown(() {
    LoginScreen.home = (_) => const MainScaffold();
    Intl.defaultLocale = null;
  });

  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(withAppSettings(screen));
    await tester.pumpAndSettle();
  }

  Future<void> tapFacebook(WidgetTester tester) async {
    await tester.tap(find.text(AuthSocialButtons.facebook));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  Future<void> submitLogin(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'an@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'Secret123');
    await tester.tap(
      find.descendant(
        of: find.byType(PrimaryButton),
        matching: find.byType(ElevatedButton),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  void expectStoppedWithError(String title) {
    expect(find.text(title), findsOneWidget);
    expect(find.text(_invalidResponse), findsOneWidget);
    expect(find.text(_home), findsNothing);
    expect(SessionService.currentToken, isNull);
    expect(SessionService.currentRefreshToken, isNull);
    expect(SessionService.currentUserId, isNull);
  }

  group('the answer has tokens but no user id', () {
    final answer = {'token': 'access-1', 'refreshToken': 'refresh-1'};

    testWidgets('password login stays on the login screen, keeps no token', (
      tester,
    ) async {
      backend.on('POST', _loginPath, (_) => okResponse(answer));
      await open(tester, const LoginScreen());
      await submitLogin(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expectStoppedWithError(_loginFailedTitle);
    });

    testWidgets('social login stays on the login screen, keeps no token', (
      tester,
    ) async {
      backend.on('POST', _socialLoginPath, (_) => okResponse(answer));
      await open(tester, const LoginScreen());
      await tapFacebook(tester);

      expect(backend.calls, contains('POST $_socialLoginPath'));
      expect(find.byType(LoginScreen), findsOneWidget);
      expectStoppedWithError(_loginFailedTitle);
    });

    testWidgets('social sign-up stays on the register screen, keeps no token', (
      tester,
    ) async {
      backend.on('POST', _socialLoginPath, (_) => okResponse(answer));
      await open(tester, const RegisterScreen());
      await tapFacebook(tester);

      expect(backend.calls, contains('POST $_socialLoginPath'));
      expect(find.byType(RegisterScreen), findsOneWidget);
      expectStoppedWithError(_registerFailedTitle);
    });

    testWidgets('a session of an earlier sign-in is not left behind', (
      tester,
    ) async {
      await SessionService.setTokens('old-access', 'old-refresh');
      backend.on('POST', _socialLoginPath, (_) => okResponse(answer));
      await open(tester, const LoginScreen());
      await tapFacebook(tester);

      expectStoppedWithError(_loginFailedTitle);
    });
  });

  testWidgets('social login with a user id still signs in and opens the app', (
    tester,
  ) async {
    backend.on(
      'POST',
      _socialLoginPath,
      (_) => okResponse({
        'token': 'access-1',
        'refreshToken': 'refresh-1',
        'user': {'id': 7},
      }),
    );
    await open(tester, const LoginScreen());
    await tapFacebook(tester);

    expect(find.text(_home), findsOneWidget);
    expect(SessionService.currentToken, 'access-1');
    expect(SessionService.currentUserId, 7);
  });
}
