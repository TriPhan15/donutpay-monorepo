import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/models/app_notification.dart';
import 'package:finance_ai_app/screens/notifications/widgets/notification_content_sheet.dart';

import '../../../helpers/app_settings_scope.dart';
import '../../../helpers/fake_settings_repository.dart';
import '../../../helpers/theme_colors.dart';

const String _message =
    'Giao dịch 5.000.000 ₫ lớn hơn thường lệ. Nếu không phải bạn thực hiện, hãy kiểm tra lại lịch sử giao dịch.';

AppNotification _notification({bool withTime = true}) => AppNotification(
  id: 1,
  type: NotificationType.transactionAlert,
  message: _message,
  isRead: true,
  createdAt: withTime ? DateTime(2026, 10, 25, 14, 2) : null,
);

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));
  tearDown(() => Intl.defaultLocale = null);

  Future<void> openSheet(
    WidgetTester tester,
    AppNotification notification, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await tester.pumpWidget(
      withAppSettings(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showNotificationContentSheet(context, notification),
              child: const Text('open'),
            ),
          ),
        ),
        settings: FakeSettingsRepository(themeMode: themeMode),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(BottomSheet), matching: finder);

  testWidgets('shows the title, the type and time rows and the whole message', (
    tester,
  ) async {
    await openSheet(tester, _notification());

    expect(inSheet(find.text('Chi tiết thông báo')), findsOneWidget);
    expect(inSheet(find.text('Loại')), findsOneWidget);
    expect(inSheet(find.text('Cảnh báo giao dịch')), findsOneWidget);
    expect(inSheet(find.text('Thời gian')), findsOneWidget);
    expect(inSheet(find.text('25/10/2026 14:02')), findsOneWidget);
    final message = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(message.data, _message);
    expect(message.maxLines, isNull);
  });

  testWidgets('without a time there is no time row', (tester) async {
    await openSheet(tester, _notification(withTime: false));

    expect(inSheet(find.text('Loại')), findsOneWidget);
    expect(inSheet(find.text('Thời gian')), findsNothing);
  });

  testWidgets('the close button closes the sheet', (tester) async {
    await openSheet(tester, _notification());

    await tester.tap(inSheet(find.byIcon(Icons.close_rounded)));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      '${mode.name} theme: the message block stands out from the sheet',
      (tester) async {
        await openSheet(tester, _notification(), themeMode: mode);
        final theme = Theme.of(tester.element(find.byType(SelectableText)));

        final block = boxColor(tester, find.byType(SelectableText));
        expect(block, theme.scaffoldBackgroundColor);
        expect(block, isNot(theme.colorScheme.surface));
        expect(
          materialColor(tester, find.byType(BottomSheet)),
          theme.colorScheme.surface,
        );
      },
    );
  }
}
