import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/utils/password_policy.dart';
import 'package:finance_ai_app/widgets/auth/password_rule_list.dart';

import '../../helpers/app_settings_scope.dart';
import '../../helpers/theme_colors.dart';

Finder _ruleIcon(PasswordRule rule) => find.descendant(
  of: find.byKey(ValueKey('password-rule-${rule.name}')),
  matching: find.byType(Icon),
);

void main() {
  tearDown(() => Intl.defaultLocale = null);

  Future<BuildContext> pump(WidgetTester tester, Widget list) async {
    late BuildContext context;
    await tester.pumpWidget(
      withAppSettings(
        Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return list;
            },
          ),
        ),
      ),
    );
    return context;
  }

  testWidgets(
    'met rules are ticked in the success colour, the open one takes pendingColor',
    (tester) async {
      final context = await pump(
        tester,
        const PasswordRuleList(
          password: 'Matkhau20',
          pendingColor: Colors.orange,
        ),
      );
      final success = context.colors.successColor;

      expect(
        tester.widget<Icon>(_ruleIcon(PasswordRule.special)).icon,
        Icons.radio_button_unchecked,
      );
      expect(
        paintedColor(tester, _ruleIcon(PasswordRule.special)),
        Colors.orange,
      );
      for (final rule in PasswordRule.values.where(
        (r) => r != PasswordRule.special,
      )) {
        expect(tester.widget<Icon>(_ruleIcon(rule)).icon, Icons.check_circle);
        expect(
          paintedColor(tester, _ruleIcon(rule)),
          success,
          reason: rule.name,
        );
      }
    },
  );

  testWidgets(
    'without pendingColor an open rule is in the secondary text colour',
    (tester) async {
      final context = await pump(tester, const PasswordRuleList(password: ''));

      expect(
        paintedColor(tester, _ruleIcon(PasswordRule.digit)),
        Theme.of(context).colorScheme.onSurfaceVariant,
      );
    },
  );
}
