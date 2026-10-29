import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/profile/account_credentials_screen.dart';
import 'package:finance_ai_app/screens/profile/account_info_screen.dart';
import 'package:finance_ai_app/screens/profile/guide_page.dart';
import 'package:finance_ai_app/screens/profile/profile_page.dart';
import 'package:finance_ai_app/screens/profile/settings_screen.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';
import '../../helpers/fake_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final backend = FakeBackend();

  setUpAll(() {
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    AppRepository.instance.localStore = FakeLocalStore();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend.reset();
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    await SessionService.setTokens('access-token', 'refresh-token');
    backend.on(
      'GET',
      '/api/users/me',
      (_) => okResponse({'id': 1, 'email': 'an@example.com'}),
    );
    backend.on('GET', '/api/transactions/mine', (_) => okResponse([]));
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Intl.defaultLocale = null;
    AppToast.resetForTest();
  });

  Future<void> pumpProfile(
    WidgetTester tester,
    FakeSettingsRepository settings,
  ) async {
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      withAppSettings(const ProfilePage(), settings: settings),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('the language and theme rows show the current choices', (
    tester,
  ) async {
    await pumpProfile(tester, FakeSettingsRepository());

    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);
    expect(find.text('Giao diện'), findsOneWidget);
    expect(find.text('Theo hệ thống'), findsOneWidget);
  });

  testWidgets('the two rows are translated when the app is in English', (
    tester,
  ) async {
    await pumpProfile(
      tester,
      FakeSettingsRepository(
        language: AppLanguage.english,
        themeMode: ThemeMode.dark,
      ),
    );

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets(
    'both rows open the settings screen, and a choice made there shows on the row after going back',
    (tester) async {
      await pumpProfile(tester, FakeSettingsRepository());

      await tester.tap(find.text('Giao diện'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('theme-card-dark')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.text('Tối'), findsOneWidget);
      expect(find.text('Theo hệ thống'), findsNothing);

      await tester.tap(find.text('Ngôn ngữ'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    },
  );

  testWidgets('the band shows the profile and opens the account information', (
    tester,
  ) async {
    await pumpProfile(tester, FakeSettingsRepository());

    for (final caption in ['Tài khoản', 'Tiện ích', 'Cài đặt', 'Hỗ trợ']) {
      expect(find.text(caption), findsOneWidget, reason: caption);
    }
    expect(find.text('an@example.com'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-open-account')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountInfoScreen), findsOneWidget);
  });

  testWidgets('Thông báo opens its sheet and Hướng dẫn opens the guide page', (
    tester,
  ) async {
    await pumpProfile(tester, FakeSettingsRepository());

    await tester.tap(find.text('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.text('Cài đặt thông báo'), findsOneWidget);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hướng dẫn sử dụng'));
    await tester.pumpAndSettle();
    expect(find.byType(GuidePage), findsOneWidget);
  });

  testWidgets(
    'Đổi mật khẩu in the security sheet opens the credentials screen',
    (tester) async {
      await pumpProfile(tester, FakeSettingsRepository());

      await tester.tap(find.text('Bảo mật & Quyền riêng tư'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đổi mật khẩu'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountCredentialsScreen), findsOneWidget);
    },
  );

  testWidgets('without a session Đổi mật khẩu asks to sign in again', (
    tester,
  ) async {
    await pumpProfile(tester, FakeSettingsRepository());
    await SessionService.clearSession();

    await tester.tap(find.text('Bảo mật & Quyền riêng tư'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi mật khẩu'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountCredentialsScreen), findsNothing);
    expect(find.text('Vui lòng đăng nhập lại.'), findsOneWidget);
  });

  testWidgets('the profile loads /mine once per reload', (tester) async {
    await pumpProfile(tester, FakeSettingsRepository());

    expect(
      backend.calls.where((c) => c == 'GET /api/transactions/mine'),
      hasLength(1),
    );
    expect(backend.calls.where((c) => c == 'GET /api/users/me'), hasLength(1));
  });
}
