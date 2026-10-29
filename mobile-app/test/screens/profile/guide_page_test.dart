import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/screens/profile/guide_page.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_settings_repository.dart';

void main() {
  tearDown(() => Intl.defaultLocale = null);

  Future<void> pumpGuide(WidgetTester tester, AppLanguage language) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        const GuidePage(),
        settings: FakeSettingsRepository(language: language),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('five numbered steps about this app, no old topics, no emoji', (
    tester,
  ) async {
    await pumpGuide(tester, AppLanguage.vietnamese);

    expect(find.text('Hướng dẫn sử dụng'), findsOneWidget);
    final titles = [
      'Trang chủ',
      'Thống kê',
      'Quét hóa đơn',
      'Phân tích chi tiêu',
      'Ngân sách và tiết kiệm',
    ];
    var previousTop = double.negativeInfinity;
    for (final (i, title) in titles.indexed) {
      expect(find.text(title), findsOneWidget, reason: title);
      expect(find.text('${i + 1}'), findsOneWidget);
      final top = tester.getTopLeft(find.text(title)).dy;
      expect(top, greaterThan(previousTop), reason: 'order of $title');
      previousTop = top;
    }
    expect(find.textContaining('Dashboard'), findsNothing);
    expect(find.textContaining('Chuyển tiền'), findsNothing);
    final emoji = RegExp(
      r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
      unicode: true,
    );
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(emoji.hasMatch(text.data ?? ''), isFalse, reason: text.data);
    }
  });

  testWidgets('the steps are translated in English', (tester) async {
    await pumpGuide(tester, AppLanguage.english);

    for (final title in [
      'Home',
      'Statistics',
      'Scan receipts',
      'Spending analysis',
      'Budgets and savings',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
  });
}
