import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/linked/linked_services_page.dart';
import 'package:finance_ai_app/screens/profile/profile_page.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/demo_badge.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';
import '../../helpers/fake_settings_repository.dart';

const String _linkedServices = 'Dịch vụ liên kết';
const String _demoBadge = 'Bản demo';

/// T10d: the linked e-wallets are simulated (provider MOCK), so the page and its profile row say "Demo" before anyone
/// takes them for a real bank connection.
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

  tearDown(() => Intl.defaultLocale = null);

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    AppLanguage language = AppLanguage.vietnamese,
  }) async {
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        screen,
        settings: FakeSettingsRepository(language: language),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('the profile row of the linked services carries the badge', (
    tester,
  ) async {
    await pump(tester, const ProfilePage());

    final row = find.widgetWithText(ListTile, _linkedServices);
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.byType(DemoBadge)),
      findsOneWidget,
    );
    expect(find.byType(DemoBadge), findsOneWidget, reason: 'only that row');
    expect(find.text(_demoBadge), findsOneWidget);
  });

  testWidgets('the page shows the badge in its band and a notice in full', (
    tester,
  ) async {
    await pump(tester, const LinkedServicesPage());

    expect(
      find.descendant(
        of: find.byType(PageBand),
        matching: find.text(_demoBadge),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('dữ liệu giả lập, không kết nối ngân hàng'),
      findsOneWidget,
    );
  });

  testWidgets('in English the badge says Demo', (tester) async {
    await pump(
      tester,
      const LinkedServicesPage(),
      language: AppLanguage.english,
    );

    expect(find.text('Demo'), findsOneWidget);
    expect(find.textContaining('This is a demo'), findsOneWidget);
  });
}
