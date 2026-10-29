import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/budget/budget_screen.dart';
import 'package:finance_ai_app/screens/budget/widgets/budget_group_card.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/fake_backend.dart';
import '../../helpers/fake_local_store.dart';
import '../../helpers/fake_settings_repository.dart';

String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

Map<String, Object?> _budget(int id, String category, num amount) {
  final range = BudgetPeriodType.rangeContaining(
    BudgetPeriodType.month,
    DateTime.now(),
  );
  return {
    'id': id,
    'categoryId': id,
    'categoryName': category,
    'amount': amount,
    'periodType': BudgetPeriodType.month,
    'startDate': _ymd(range.start),
    'endDate': _ymd(range.end),
  };
}

void main() {
  final backend = FakeBackend();

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    RemoteApiHelper.instance.init(httpClientAdapter: backend);
    AppRepository.instance.localStore = FakeLocalStore();
  });

  setUp(() async {
    // SharedPreferences shares one Future that must be created inside the test body (see budget_display_test.dart).
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearSession();
    await SessionService.setCurrentUserId(1);
    SharedPreferences.setMockInitialValues({});

    backend.reset();
    backend.on(
      'GET',
      '/api/budgets',
      (_) => okResponse([
        _budget(10, 'Ăn uống', 1000000),
        _budget(11, 'Di chuyển', 1000000),
      ]),
    );
    backend.on(
      'GET',
      '/api/transactions/mine',
      (_) => okResponse([
        {
          'id': 1,
          'title': 'Ăn',
          'amount': 1500000,
          'date': DateTime.now().toIso8601String(),
          'category': 'Ăn uống',
          'isExpense': true,
        },
      ]),
    );
  });

  // The language cubit of withAppSettings sets the default locale of intl.
  tearDown(() => Intl.defaultLocale = null);

  Future<void> start(WidgetTester tester, ThemeMode mode) async {
    tester.view.physicalSize = const Size(600, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withAppSettings(
        const BudgetScreen(),
        settings: FakeSettingsRepository(themeMode: mode),
      ),
    );
    await tester.pumpAndSettle();
  }

  ThemeData themeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(BudgetScreen)));

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    group('${mode.name} theme', () {
      testWidgets('the band takes the header gradient of the theme', (
        tester,
      ) async {
        await start(tester, mode);
        final band = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(BudgetScreen.bandKey),
                matching: find.byType(Container),
              )
              .first,
        );

        expect(
          (band.decoration as BoxDecoration).gradient,
          tester.element(find.byType(BudgetScreen)).colors.headerGradient,
        );
      });

      testWidgets('group headers are tinted red and green of the theme', (
        tester,
      ) async {
        await start(tester, mode);
        final theme = themeOf(tester);
        Color? tint(BudgetGroupKind kind) => tester
            .widget<Container>(find.byKey(BudgetGroupCard.headerKey(kind)))
            .color;

        expect(
          tint(BudgetGroupKind.over),
          theme.colorScheme.error.withValues(
            alpha: BudgetGroupCard.headerTintAlpha,
          ),
        );
        expect(
          tint(BudgetGroupKind.within),
          theme.semanticColors.successColor.withValues(
            alpha: BudgetGroupCard.headerTintAlpha,
          ),
        );
      });

      testWidgets('the error view draws its icon in the secondary colour', (
        tester,
      ) async {
        backend.on('GET', '/api/budgets', (_) => jsonResponse(500, {}));
        await start(tester, mode);

        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byType(AppStateView),
            matching: find.byType(Icon),
          ),
        );
        expect(icon.color, themeOf(tester).colorScheme.onSurfaceVariant);
      });
    });
  }
}
