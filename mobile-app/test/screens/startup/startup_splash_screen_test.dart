import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/screens/startup/startup_splash_screen.dart';

import '../../helpers/theme_colors.dart';

void main() {
  // The themes are read inside each test: building them here, outside testWidgets, starts a google_fonts load with no
  // binding and the whole file fails to load.
  ThemeData themeFor(Brightness brightness) =>
      brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

  for (final brightness in Brightness.values) {
    final mode = brightness.name;

    testWidgets('$mode: brand gradient, logo C and the app name', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeFor(brightness),
          home: const StartupSplashScreen(),
        ),
      );

      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(StartupSplashScreen),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (box.decoration as BoxDecoration).gradient,
        AppTheme.brandGradient,
        reason: 'the same gradient as the native splash, whatever the theme',
      );
      expect(
        find.image(const AssetImage(StartupSplashScreen.logoAsset)),
        findsOneWidget,
      );
      final name = find.text('LedgerMind');
      expect(name, findsOneWidget);
      expect(paintedColor(tester, name), Colors.white);
      expect(tester.widget<Text>(name).style?.fontSize, AppTextSize.amount);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('$mode: status bar icons are white on the gradient', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeFor(brightness),
          home: const StartupSplashScreen(),
        ),
      );

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find
            .descendant(
              of: find.byType(StartupSplashScreen),
              matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            )
            .first,
      );
      expect(region.value.statusBarIconBrightness, Brightness.light);
      expect(region.value.systemNavigationBarColor, AppTheme.gradientEnd);
    });
  }

  // The native launch window hands over to StartupSplashScreen: its navigation bar must already have the colour the
  // Flutter screen gives it, or the bar changes colour at the hand-over (backlog line 1).
  test(
    'every LaunchTheme gives the navigation bar the bottom colour of the gradient',
    () {
      final hex = AppTheme.gradientEnd
          .toARGB32()
          .toRadixString(16)
          .substring(2)
          .toUpperCase();
      for (final folder in [
        'values',
        'values-night',
        'values-v31',
        'values-night-v31',
      ]) {
        final xml = File(
          'android/app/src/main/res/$folder/styles.xml',
        ).readAsStringSync();
        final launch = RegExp(
          r'<style name="LaunchTheme"[^>]*>([\s\S]*?)</style>',
        ).firstMatch(xml)!.group(1)!;
        expect(
          launch,
          contains('<item name="android:navigationBarColor">#$hex</item>'),
          reason: folder,
        );
      }
    },
  );
}
