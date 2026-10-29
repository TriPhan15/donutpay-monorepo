import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/screens/profile/widgets/profile_group.dart';
import 'package:finance_ai_app/screens/profile/widgets/profile_header_band.dart';

import '../../../helpers/app_settings_scope.dart';
import '../../../helpers/fake_settings_repository.dart';
import '../../../helpers/theme_colors.dart';

void main() {
  test('initialsOf takes the first letters of the first and the last word', () {
    expect(ProfileHeaderBand.initialsOf('Nguyễn Văn An'), 'NA');
    expect(ProfileHeaderBand.initialsOf('an'), 'A');
    expect(ProfileHeaderBand.initialsOf('  '), '?');
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    group('${mode.name} theme', () {
      testWidgets(
        'a group paints its caption, icon boxes, values and the danger row from the theme',
        (tester) async {
          var plainTaps = 0;
          var dangerTaps = 0;
          await tester.pumpWidget(
            withAppSettings(
              Scaffold(
                body: ProfileGroup(
                  title: 'Nhóm',
                  rows: [
                    ProfileRow(
                      icon: Icons.light_mode_outlined,
                      label: 'Giao diện',
                      value: 'Sáng',
                      onTap: () => plainTaps++,
                    ),
                    ProfileRow(
                      icon: Icons.logout_rounded,
                      label: 'Đăng xuất',
                      danger: true,
                      onTap: () => dangerTaps++,
                    ),
                  ],
                ),
              ),
              settings: FakeSettingsRepository(themeMode: mode),
            ),
          );
          await tester.pumpAndSettle();
          final colors = Theme.of(
            tester.element(find.byType(ProfileGroup)),
          ).colorScheme;

          expect(
            paintedColor(tester, find.text('Nhóm')),
            colors.onSurfaceVariant,
          );
          expect(
            paintedColor(tester, find.byIcon(Icons.light_mode_outlined)),
            colors.primary,
          );
          expect(
            boxColor(tester, find.byIcon(Icons.light_mode_outlined)),
            colors.primaryContainer,
          );
          expect(
            paintedColor(tester, find.text('Sáng')),
            colors.onSurfaceVariant,
          );
          expect(paintedColor(tester, find.text('Đăng xuất')), colors.error);
          expect(
            paintedColor(tester, find.byIcon(Icons.logout_rounded)),
            colors.error,
          );
          expect(
            find.byIcon(Icons.chevron_right_rounded),
            findsOneWidget,
            reason: 'the danger row has no chevron',
          );
          expect(find.byType(ListTile), findsNWidgets(2));

          await tester.tap(find.text('Giao diện'));
          await tester.tap(find.text('Đăng xuất'));
          expect(plainTaps, 1);
          expect(dangerTaps, 1);
        },
      );

      testWidgets(
        'the header band shows the profile in band colours and opens the account',
        (tester) async {
          var opened = 0;
          await tester.pumpWidget(
            withAppSettings(
              Scaffold(
                body: ProfileHeaderBand(
                  name: 'Nguyễn Văn An',
                  email: 'an@example.com',
                  onOpenAccount: () => opened++,
                ),
              ),
              settings: FakeSettingsRepository(themeMode: mode),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            paintedColor(tester, find.text('Cá nhân')),
            BandColors.primary,
          );
          expect(
            paintedColor(tester, find.text('Nguyễn Văn An')),
            BandColors.primary,
          );
          expect(
            paintedColor(tester, find.text('an@example.com')),
            BandColors.secondary,
          );
          expect(find.text('NA'), findsOneWidget);

          await tester.tap(find.byKey(const ValueKey('profile-open-account')));
          expect(opened, 1);
        },
      );
    });
  }
}
