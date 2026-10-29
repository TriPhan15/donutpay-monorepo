import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/l10n/app_localizations_vi.dart';
import 'package:finance_ai_app/models/app_notification.dart';
import 'package:finance_ai_app/screens/notifications/widgets/notification_row.dart';

import '../../../helpers/app_settings_scope.dart';
import '../../../helpers/fake_settings_repository.dart';
import '../../../helpers/theme_colors.dart';

final DateTime _now = DateTime(2026, 10, 29, 12);
const String _unread = 'Chưa đọc';

AppNotification _notification({
  NotificationType type = NotificationType.budgetWarning,
  bool isRead = false,
  String message = 'Ăn uống đã dùng 82% hạn mức.',
  DateTime? createdAt,
  bool withTime = true,
}) => AppNotification(
  id: 1,
  type: type,
  message: message,
  isRead: isRead,
  createdAt: withTime ? (createdAt ?? DateTime(2026, 10, 29, 10, 24)) : null,
);

Finder _unreadDot() => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == _unread,
);

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));
  tearDown(() => Intl.defaultLocale = null);

  Future<void> pumpRows(
    WidgetTester tester,
    List<AppNotification> notifications, {
    ThemeMode themeMode = ThemeMode.light,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      withAppSettings(
        Scaffold(
          body: ListView(
            children: [
              for (final (index, notification) in notifications.indexed)
                NotificationRow(
                  notification: notification,
                  onTap: onTap ?? () {},
                  isFirst: index == 0,
                  isLast: index == notifications.length - 1,
                  now: _now,
                ),
            ],
          ),
        ),
        settings: FakeSettingsRepository(themeMode: themeMode),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('notificationListTime', () {
    final loc = AppLocalizationsVi();
    String at(DateTime createdAt) =>
        notificationListTime(createdAt, now: _now, locale: 'vi', loc: loc);

    test('today shows the time alone', () {
      expect(at(DateTime(2026, 10, 29, 10, 24)), '10:24');
    });

    test('yesterday says so before the time', () {
      expect(at(DateTime(2026, 10, 28, 19, 20)), 'Hôm qua, 19:20');
    });

    test('earlier this year shows the day and the time', () {
      expect(at(DateTime(2026, 10, 25, 14, 2)), '25/10, 14:02');
    });

    test('an earlier year shows the date alone', () {
      expect(at(DateTime(2025, 12, 31, 8)), '31/12/2025');
    });
  });

  testWidgets('an unread row has the dot and a bold kind; a read one neither', (
    tester,
  ) async {
    await pumpRows(tester, [
      _notification(),
      _notification(type: NotificationType.budgetExceeded, isRead: true),
    ]);

    expect(_unreadDot(), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.text('Sắp chạm hạn mức ngân sách'))
          .style!
          .fontWeight,
      FontWeight.w700,
    );
    expect(
      tester.widget<Text>(find.text('Đã vượt ngân sách')).style!.fontWeight,
      FontWeight.w600,
    );
    expect(find.text('10:24'), findsNWidgets(2));
  });

  testWidgets('the message stops after two lines', (tester) async {
    final long = 'Giao dịch lớn hơn thường lệ. ' * 15;
    await pumpRows(tester, [_notification(message: long)]);

    final message = tester.widget<Text>(find.text(long));
    expect(message.maxLines, 2);
    expect(message.overflow, TextOverflow.ellipsis);
  });

  testWidgets('without a time the row shows the kind and the message only', (
    tester,
  ) async {
    await pumpRows(tester, [_notification(withTime: false)]);

    expect(
      find.descendant(
        of: find.byType(NotificationRow),
        matching: find.byType(Text),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets(
    'a long kind and a long date fit a 320 px screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        withAppSettings(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: NotificationRow(
                notification: _notification(
                  type: NotificationType.receiptProcessed,
                  createdAt: DateTime(2025, 12, 31, 8),
                  message: 'Hóa đơn ' * 40,
                ),
                onTap: () {},
                isFirst: true,
                isLast: true,
                now: _now,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('31/12/2025'), findsOneWidget);
    },
  );

  testWidgets('a screen reader reads the whole row as one tappable node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpRows(tester, [_notification()]);

    final node = tester.getSemantics(
      find.descendant(
        of: find.byType(NotificationRow),
        matching: find.byType(InkWell),
      ),
    );
    expect(node.label, contains('Sắp chạm hạn mức ngân sách'));
    expect(node.label, contains('10:24'));
    expect(node.label, contains('Ăn uống đã dùng 82% hạn mức.'));
    expect(node.label, contains(_unread));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('a tap calls onTap once', (tester) async {
    var taps = 0;
    await pumpRows(tester, [_notification()], onTap: () => taps++);

    await tester.tap(find.byType(NotificationRow));
    expect(taps, 1);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      '${mode.name} theme: the row takes its colours from the theme',
      (tester) async {
        await pumpRows(themeMode: mode, tester, [
          _notification(),
          _notification(type: NotificationType.budgetExceeded, isRead: true),
        ]);
        final context = tester.element(find.byType(ListView));
        final theme = Theme.of(context);
        final colors = theme.colorScheme;

        expect(
          theme.brightness,
          mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        expect(
          paintedColor(tester, find.byIcon(Icons.warning_amber_rounded)),
          context.colors.warningColor,
        );
        expect(
          paintedColor(tester, find.byIcon(Icons.error_outline_rounded)),
          colors.error,
        );
        final dot = tester.widget<Container>(
          find.descendant(of: _unreadDot(), matching: find.byType(Container)),
        );
        expect((dot.decoration! as BoxDecoration).color, colors.primary);
        expect(
          materialColor(tester, find.byType(NotificationRow).first),
          colors.surface,
        );
        expect(
          paintedColor(tester, find.text('Ăn uống đã dùng 82% hạn mức.').first),
          colors.onSurface,
        );
        expect(
          paintedColor(tester, find.text('Ăn uống đã dùng 82% hạn mức.').last),
          colors.onSurfaceVariant,
        );
      },
    );
  }
}
