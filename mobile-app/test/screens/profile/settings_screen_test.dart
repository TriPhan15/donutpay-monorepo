import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/di/injection_container.dart';
import 'package:finance_ai_app/main.dart';
import 'package:finance_ai_app/repositories/settings_repository.dart';
import 'package:finance_ai_app/repositories/settings_repository_impl.dart';
import 'package:finance_ai_app/screens/auth/login_page.dart';
import 'package:finance_ai_app/screens/profile/settings_screen.dart';
import 'package:finance_ai_app/screens/profile/widgets/theme_preview_card.dart';

import '../../helpers/fake_settings_repository.dart';

void main() {
  tearDown(() async {
    await sl.reset();
    Intl.defaultLocale = null;
  });

  /// The app as main() builds it (signed out, so the login screen), with the settings screen pushed on top.
  Future<void> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const DonutPayApp());
    await tester.pumpAndSettle();
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    await tester.pumpAndSettle();
  }

  ListTile tileOf(WidgetTester tester, String label) => tester.widget<ListTile>(
    find.ancestor(of: find.text(label), matching: find.byType(ListTile)),
  );

  Finder card(ThemeMode mode) =>
      find.byKey(ValueKey('theme-card-${mode.name}'));

  bool cardSelected(WidgetTester tester, ThemeMode mode) =>
      tester.widget<ThemePreviewCard>(card(mode)).selected;

  final emoji = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}]',
    unicode: true,
  );

  Brightness screenBrightness(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness;

  MaterialApp materialApp(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp));

  group('when the device saves the choices', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        SettingsRepositoryImpl.languageKey: 'vi',
      });
      await configureDependencies();
      // A Future made here and awaited inside testWidgets never completes, so the test body gets its own instance.
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('lists every option in Vietnamese and marks the current ones', (
      tester,
    ) async {
      await openSettings(tester);

      for (final label in [
        'Giao diện và ngôn ngữ',
        'Giao diện',
        'Hệ thống',
        'Sáng',
        'Tối',
        'Tự đổi theo cài đặt của thiết bị',
        'Ngôn ngữ',
        'Tiếng Việt',
        'English',
        'VI',
        'EN',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(cardSelected(tester, ThemeMode.system), isTrue);
      expect(cardSelected(tester, ThemeMode.light), isFalse);
      expect(cardSelected(tester, ThemeMode.dark), isFalse);
      expect(tileOf(tester, 'Tiếng Việt').selected, isTrue);
      expect(tileOf(tester, 'English').selected, isFalse);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(emoji.hasMatch(text.data ?? ''), isFalse, reason: text.data);
      }
    });

    testWidgets(
      'choosing Dark turns the app dark at once, marks it and saves it without leaving the screen',
      (tester) async {
        await openSettings(tester);
        expect(screenBrightness(tester), Brightness.light);

        await tester.tap(card(ThemeMode.dark));
        await tester.pumpAndSettle();

        expect(materialApp(tester).themeMode, ThemeMode.dark);
        expect(screenBrightness(tester), Brightness.dark);
        expect(cardSelected(tester, ThemeMode.dark), isTrue);
        expect(cardSelected(tester, ThemeMode.system), isFalse);
        expect(sl<SettingsRepository>().themeMode, ThemeMode.dark);
        // The login screen read the preferences before the choice was saved: read the store again.
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        expect(prefs.getString(SettingsRepositoryImpl.themeModeKey), 'dark');
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'choosing Light keeps a light app even when the device is in dark mode',
      (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await openSettings(tester);
        expect(
          screenBrightness(tester),
          Brightness.dark,
          reason: 'with nothing saved the app follows the device',
        );
        expect(cardSelected(tester, ThemeMode.system), isTrue);

        await tester.tap(card(ThemeMode.light));
        await tester.pumpAndSettle();

        expect(screenBrightness(tester), Brightness.light);
        expect(cardSelected(tester, ThemeMode.light), isTrue);
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        expect(prefs.getString(SettingsRepositoryImpl.themeModeKey), 'light');
      },
    );

    testWidgets(
      'the status and navigation bar icons follow the theme, also on screens without an app bar',
      (tester) async {
        await openSettings(tester);
        final rootRegion = find.ancestor(
          of: find.byType(Navigator),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        );
        expect(rootRegion, findsOneWidget);
        expect(
          tester
              .widget<AnnotatedRegion<SystemUiOverlayStyle>>(rootRegion)
              .value,
          AppTheme.lightOverlayStyle,
        );

        await tester.tap(card(ThemeMode.dark));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<AnnotatedRegion<SystemUiOverlayStyle>>(rootRegion)
              .value,
          AppTheme.darkOverlayStyle,
        );
        expect(
          SystemChrome.latestStyle?.statusBarIconBrightness,
          Brightness.light,
        );
        expect(
          SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
          Brightness.light,
        );
      },
    );

    testWidgets(
      'tapping the current language asks nothing and changes nothing',
      (tester) async {
        await openSettings(tester);

        await tester.tap(find.text('Tiếng Việt'));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsNothing);
        expect(materialApp(tester).locale, const Locale('vi'));
      },
    );

    testWidgets(
      'cancelling or dismissing the language question keeps Vietnamese',
      (tester) async {
        await openSettings(tester);

        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        expect(find.text('Đổi sang English?'), findsOneWidget);
        expect(
          find.text('Toàn bộ chữ trong ứng dụng sẽ đổi sang ngôn ngữ này.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(materialApp(tester).locale, const Locale('vi'));
        expect(tileOf(tester, 'Tiếng Việt').selected, isTrue);

        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        // A tap above the sheet closes it without an answer.
        await tester.tapAt(const Offset(400, 40));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(materialApp(tester).locale, const Locale('vi'));
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        expect(
          prefs.getString(SettingsRepositoryImpl.languageKey),
          isNot('en'),
        );
      },
    );

    testWidgets(
      'confirming English translates the screen at once and sets the language of the next requests',
      (tester) async {
        await openSettings(tester);

        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Đổi'));
        await tester.pumpAndSettle();

        for (final label in [
          'Appearance and language',
          'Theme',
          'Light',
          'Dark',
          'System',
          'Follows your device setting',
          'Language',
          'Tiếng Việt',
          'English',
        ]) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(find.text('Giao diện và ngôn ngữ'), findsNothing);
        expect(tileOf(tester, 'English').selected, isTrue);
        expect(tileOf(tester, 'Tiếng Việt').selected, isFalse);
        expect(materialApp(tester).locale, const Locale('en'));
        expect(Intl.defaultLocale, 'en_US');
        expect(sl<SettingsRepository>().localeTag, 'en-US');
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        expect(prefs.getString(SettingsRepositoryImpl.languageKey), 'en');
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'going back after a change returns to the same screen as before',
      (tester) async {
        await openSettings(tester);
        await tester.tap(card(ThemeMode.dark));
        await tester.pumpAndSettle();
        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Đổi'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        expect(find.byType(SettingsScreen), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );
  });

  group('when the device cannot save', () {
    setUp(() {
      sl.registerSingleton<SettingsRepository>(
        FakeSettingsRepository(saveResult: false),
      );
    });

    testWidgets('the new theme stays applied and a toast says it was not saved', (
      tester,
    ) async {
      await openSettings(tester);

      await tester.tap(card(ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Không lưu được cài đặt. Thay đổi chỉ có hiệu lực đến khi đóng ứng dụng.',
        ),
        findsOneWidget,
      );
      expect(cardSelected(tester, ThemeMode.dark), isTrue);
      expect(screenBrightness(tester), Brightness.dark);
    });

    testWidgets(
      'a confirmed language that cannot be saved still applies and says so',
      (tester) async {
        await openSettings(tester);

        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Đổi'));
        await tester.pumpAndSettle();

        expect(materialApp(tester).locale, const Locale('en'));
        // The toast speaks the language just chosen.
        expect(
          find.text(
            "Couldn't save this setting. The change applies until you close the app.",
          ),
          findsOneWidget,
        );
      },
    );
  });
}
