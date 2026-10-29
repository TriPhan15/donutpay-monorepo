import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';

import '../../helpers/theme_colors.dart';

void main() {
  test('the scale has exactly seven sizes, the smallest 12', () {
    expect(AppTextSize.scale, [30, 24, 18, 16, 14, 13, 12]);
    expect(AppTextSize.scale.reduce(math.min), 12);
  });

  // The themes load Be Vietnam Pro through google_fonts; inside testWidgets that load never reaches the network.
  testWidgets(
    'every text style of both themes is on the scale and in Be Vietnam Pro',
    (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        for (final style in allTextStyles(theme.textTheme)) {
          expect(AppTextSize.scale, contains(style!.fontSize));
          expect(style.fontFamily, contains('BeVietnamPro'));
          expect(
            style.fontFeatures,
            contains(const FontFeature.tabularFigures()),
          );
          expect(style.color, theme.colorScheme.onSurface);
        }
      }
    },
  );

  testWidgets('roles map to the spec sizes', (tester) async {
    final t = AppTheme.lightTheme.textTheme;

    expect(t.displaySmall!.fontSize, AppTextSize.amountLarge);
    expect(t.headlineSmall!.fontSize, AppTextSize.amount);
    expect(t.titleLarge!.fontSize, AppTextSize.pageTitle);
    expect(t.titleMedium!.fontSize, AppTextSize.title);
    expect(t.bodyMedium!.fontSize, AppTextSize.body);
    expect(t.bodySmall!.fontSize, AppTextSize.secondary);
    expect(t.labelSmall!.fontSize, AppTextSize.caption);
    expect(t.labelLarge!.fontSize, AppTextSize.title);
    expect(t.titleLarge!.fontWeight, FontWeight.w700);
    expect(t.bodyMedium!.fontWeight, FontWeight.w400);
  });

  testWidgets('app bar titles and buttons use the scale', (tester) async {
    final theme = AppTheme.lightTheme;

    expect(theme.appBarTheme.titleTextStyle!.fontSize, AppTextSize.pageTitle);
    expect(
      theme.elevatedButtonTheme.style!.textStyle!.resolve({})!.fontSize,
      AppTextSize.title,
    );
  });
}
