import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/profile/account_credentials_screen.dart';
import 'package:finance_ai_app/screens/profile/account_info_screen.dart';
import 'package:finance_ai_app/screens/profile/profile_page.dart';
import 'package:finance_ai_app/screens/profile/savings_page.dart';
import 'package:finance_ai_app/screens/savings/widgets/contribute_goal_card.dart';
import 'package:finance_ai_app/screens/savings/widgets/quick_amount_grid.dart';
import 'package:finance_ai_app/screens/savings/widgets/savings_goal_list.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';
import '../../helpers/fake_settings_repository.dart';
import '../../helpers/theme_colors.dart';
import '../../helpers/vnd.dart';

/// The colour a [Divider] is drawn with, whether its own or the one of the theme.
Color _dividerColor(WidgetTester tester, Finder divider) {
  final line =
      tester
              .widget<Container>(
                find.descendant(of: divider, matching: find.byType(Container)),
              )
              .decoration!
          as BoxDecoration;
  return (line.border! as Border).bottom.color;
}

/// The colour of the nearest [Material] around what [finder] finds.
Color? _materialAround(WidgetTester tester, Finder finder) => tester
    .widget<Material>(
      find.ancestor(of: finder, matching: find.byType(Material)).first,
    )
    .color;

void main() {
  final backend = FakeBackend();

  setUpAll(() {
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    // ProfilePage also reads the transactions waiting to be sent; the fake keeps it away from a real database.
    AppRepository.instance.localStore = FakeLocalStore();
  });

  setUp(() async {
    // SharedPreferences shares one Future that must be created inside the test body (see budget_display_test.dart).
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    await SessionService.setTokens('access-token', 'refresh-token');
    SharedPreferences.setMockInitialValues({});

    backend.reset();
    backend.on(
      'GET',
      '/api/users/me',
      (_) => okResponse({
        'id': 1,
        'email': 'an@example.com',
        'phone': '0912345678',
      }),
    );
    backend.on('GET', '/api/transactions/mine', (_) => okResponse([]));
    backend.on(
      'GET',
      '/api/savings',
      (_) => okResponse([
        {
          'id': 1,
          'title': 'Du lịch',
          'target': 10000000,
          'current': 2500000,
          'deadline': '31/12/2026',
        },
      ]),
    );
  });

  // The language cubit of withAppSettings sets the default locale of intl.
  tearDown(() => Intl.defaultLocale = null);

  /// Pumps [screen] in [mode] without waiting for anything to load.
  Future<void> start(WidgetTester tester, Widget screen, ThemeMode mode) async {
    // Tall and wide, because the test font is much wider than a real one.
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        screen,
        settings: FakeSettingsRepository(themeMode: mode),
      ),
    );
  }

  ThemeData themeOf(WidgetTester tester, Type screen) =>
      Theme.of(tester.element(find.byType(screen)));

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    group('${mode.name} theme', () {
      testWidgets(
        'ProfilePage: spinner, band, groups, icon boxes, values and the sign-out row follow the theme',
        (tester) async {
          // The tab as MainScaffold shows it: its transparent Scaffold lets the page colour through.
          await start(tester, const Scaffold(body: ProfilePage()), mode);
          await tester.pump();
          final colors = themeOf(tester, ProfilePage).colorScheme;
          expect(
            find.byType(AppStateView),
            findsOneWidget,
            reason: 'the small spinner while loading',
          );

          await tester.pumpAndSettle();

          expect(find.byType(AppStateView), findsNothing);
          expect(
            paintedColor(tester, find.text('Cá nhân')),
            BandColors.primary,
          );
          expect(paintedColor(tester, find.text('an')), BandColors.primary);
          expect(
            paintedColor(tester, find.text('an@example.com')),
            BandColors.secondary,
          );
          expect(paintedColor(tester, find.text('A')), BandColors.primary);

          expect(
            paintedColor(tester, find.text('Tài khoản')),
            colors.onSurfaceVariant,
          );
          final group = tester.widget<Material>(
            find
                .ancestor(
                  of: find.text('Thông tin tài khoản'),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(group.color, colors.surface);
          expect(
            paintedColor(tester, find.text('Thông tin tài khoản')),
            colors.onSurface,
          );
          expect(
            paintedColor(tester, find.byIcon(Icons.person_outline_rounded)),
            colors.primary,
          );
          expect(
            boxColor(tester, find.byIcon(Icons.person_outline_rounded)),
            colors.primaryContainer,
          );
          expect(
            paintedColor(
              tester,
              find.text(mode == ThemeMode.light ? 'Sáng' : 'Tối'),
            ),
            colors.onSurfaceVariant,
          );
          expect(paintedColor(tester, find.text('Đăng xuất')), colors.error);
          expect(
            paintedColor(tester, find.byIcon(Icons.logout_rounded)),
            colors.error,
          );
        },
      );

      testWidgets(
        'SavingsPage: band, toggle, total card, goal row and the Góp tiền sheet follow the theme',
        (tester) async {
          await start(tester, const SavingsPage(), mode);
          final theme = themeOf(tester, SavingsPage);
          final colors = theme.colorScheme;
          expect(find.byType(AppStateView), findsOneWidget);

          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();

          expect(
            boxDecoration(tester, find.text('Sổ tiết kiệm')).gradient,
            theme.semanticColors.headerGradient,
          );
          expect(
            paintedColor(tester, find.text('Sổ tiết kiệm')),
            BandColors.primary,
          );
          expect(
            _materialAround(tester, find.byKey(SavingsPage.addKey)),
            BandColors.tint,
          );
          expect(
            paintedColor(tester, find.text('Đang thực hiện')),
            colors.onPrimary,
          );
          expect(
            paintedColor(tester, find.text('Đã xong')),
            colors.onSurfaceVariant,
          );

          expect(
            boxColor(tester, find.text('Tổng đã tiết kiệm')),
            colors.surface,
          );
          expect(
            paintedColor(tester, find.text('Tổng đã tiết kiệm')),
            colors.onSurfaceVariant,
          );
          expect(
            paintedColor(tester, find.text(vnd(2500000))),
            colors.onSurface,
          );

          expect(paintedColor(tester, find.text('Du lịch')), colors.onSurface);
          expect(
            paintedColor(tester, find.text('Còn thiếu')),
            colors.onSurfaceVariant,
          );
          final bar = tester.widget<LinearProgressIndicator>(
            find.byKey(SavingsGoalList.barKey('1')),
          );
          expect(bar.color, colors.primary);
          expect(bar.backgroundColor, colors.surfaceContainerHighest);

          await tester.tap(find.text('Du lịch'));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(QuickAmountGrid.tileKey(5e5)));
          await tester.pump();

          final added = tester.widget<FractionallySizedBox>(
            find.byKey(ContributeGoalCard.addedSegmentKey),
          );
          expect(
            (added.child! as ColoredBox).color,
            theme.semanticColors.pendingProgressColor,
          );
          expect(
            _materialAround(tester, find.byKey(QuickAmountGrid.tileKey(5e5))),
            colors.primaryContainer,
          );
          expect(
            paintedColor(tester, find.textContaining('Trừ từ ví')),
            colors.onPrimaryContainer,
          );
        },
      );

      testWidgets(
        'AccountInfoScreen: band, captions, rows, lock and dividers follow the theme',
        (tester) async {
          await start(tester, const AccountInfoScreen(), mode);
          await tester.pumpAndSettle();
          final theme = themeOf(tester, AccountInfoScreen);
          final colors = theme.colorScheme;
          final context = tester.element(find.byType(AccountInfoScreen));

          expect(
            materialColor(tester, find.byType(Scaffold)),
            theme.scaffoldBackgroundColor,
          );
          expect(
            boxDecoration(tester, find.text('Thông tin tài khoản')).gradient,
            context.colors.headerGradient,
          );
          expect(paintedColor(tester, find.text('A')), BandColors.primary);
          expect(
            paintedColor(tester, find.text('an').first),
            BandColors.primary,
          );
          expect(
            paintedColor(tester, find.text('an@example.com').first),
            BandColors.secondary,
          );
          for (final caption in ['Thông tin cá nhân', 'Bảo mật']) {
            expect(
              paintedColor(tester, find.text(caption)),
              colors.onSurfaceVariant,
              reason: caption,
            );
          }
          for (final label in ['Họ và tên', 'Email', 'Số điện thoại']) {
            expect(
              paintedColor(tester, find.text(label)),
              colors.onSurface,
              reason: label,
            );
          }
          expect(
            paintedColor(tester, find.text('******5678')),
            colors.onSurfaceVariant,
          );
          final emailRow = find.byKey(const ValueKey('account-row-email'));
          expect(
            paintedColor(
              tester,
              find.descendant(
                of: emailRow,
                matching: find.byIcon(Icons.lock_outline_rounded),
              ),
            ),
            colors.onSurfaceVariant,
          );
          expect(_materialAround(tester, emailRow), colors.surface);
          expect(
            _dividerColor(tester, find.byType(Divider).first),
            colors.outlineVariant,
          );
          expect(
            paintedColor(tester, find.text('Đổi mật khẩu')),
            colors.onSurface,
          );
        },
      );

      testWidgets(
        'AccountCredentialsScreen: band, card, rules, tick and the success view follow the theme',
        (tester) async {
          backend.on(
            'PUT',
            '/api/auth/change-password',
            (_) => okResponse(null),
          );
          await start(tester, const AccountCredentialsScreen(), mode);
          await tester.pumpAndSettle();
          final theme = themeOf(tester, AccountCredentialsScreen);
          final colors = theme.colorScheme;
          final semantic = tester
              .element(find.byType(AccountCredentialsScreen))
              .colors;

          expect(
            materialColor(tester, find.byType(Scaffold)),
            theme.scaffoldBackgroundColor,
          );
          expect(
            paintedColor(tester, find.text('Đổi mật khẩu').first),
            BandColors.primary,
          );
          expect(
            _materialAround(
              tester,
              find.widgetWithText(TextField, 'Mật khẩu cũ'),
            ),
            colors.surface,
          );

          await tester.enterText(
            find.widgetWithText(TextField, 'Mật khẩu cũ'),
            'OldPass123',
          );
          await tester.enterText(
            find.widgetWithText(TextField, 'Mật khẩu mới'),
            'Matkhau20',
          );
          await tester.pump();
          Finder ruleIcon(String name) => find.descendant(
            of: find.byKey(ValueKey('password-rule-$name')),
            matching: find.byType(Icon),
          );
          expect(
            paintedColor(tester, ruleIcon('special')),
            semantic.warningColor,
          );
          expect(
            paintedColor(tester, ruleIcon('digit')),
            semantic.successColor,
          );

          await tester.enterText(
            find.widgetWithText(TextField, 'Mật khẩu mới'),
            'Matkhau@20',
          );
          await tester.enterText(
            find.widgetWithText(TextField, 'Xác nhận mật khẩu mới'),
            'Matkhau@20',
          );
          await tester.pump();
          final tick = find.byKey(
            const ValueKey('change-password-confirm-match'),
          );
          expect(paintedColor(tester, tick), semantic.successColor);
          final confirm = tester.widget<InputDecorator>(
            find.descendant(
              of: find.widgetWithText(TextField, 'Xác nhận mật khẩu mới'),
              matching: find.byType(InputDecorator),
            ),
          );
          expect(
            confirm.decoration.enabledBorder?.borderSide.color,
            semantic.successColor,
          );

          await tester.tap(find.byType(FilledButton));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();

          final done = find.byIcon(Icons.check_rounded).first;
          expect(paintedColor(tester, done), semantic.successColor);
          expect(
            boxColor(tester, done),
            semantic.successColor.withValues(alpha: 0.14),
          );
          expect(
            paintedColor(tester, find.text('Đổi mật khẩu thành công')),
            colors.onSurface,
          );
          expect(
            paintedColor(
              tester,
              find.textContaining('Các thiết bị khác cần đăng nhập lại'),
            ),
            colors.onSurfaceVariant,
          );
        },
      );
    });
  }
}
