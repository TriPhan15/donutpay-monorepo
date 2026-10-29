import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/password_policy.dart';

/// The password rules in two columns, always shown (T9 auth mockup H, account mockup R9). A met rule is ticked in the
/// success colour; an open one stays a ring in [pendingColor], the secondary text colour when null.
class PasswordRuleList extends StatelessWidget {
  const PasswordRuleList({
    super.key,
    required this.password,
    this.pendingColor,
  });

  static const int _columns = 2;
  static const double _iconSize = 16;

  final String password;
  final Color? pendingColor;

  @override
  Widget build(BuildContext context) {
    final success = context.colors.successColor;
    final pending =
        pendingColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    const rules = PasswordRule.values;
    return Column(
      children: [
        for (var row = 0; row < rules.length; row += _columns)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = row; i < row + _columns; i++)
                  Expanded(
                    child: i < rules.length
                        ? _rule(context, rules[i], success, pending)
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _rule(
    BuildContext context,
    PasswordRule rule,
    Color success,
    Color pending,
  ) {
    final met = rule.isMetBy(password);
    final color = met ? success : pending;
    return Row(
      key: ValueKey('password-rule-${rule.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          met ? Icons.check_circle : Icons.radio_button_unchecked,
          color: color,
          size: _iconSize,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            rule.label(context.loc),
            style: TextStyle(color: color, fontSize: AppTextSize.caption),
          ),
        ),
      ],
    );
  }
}
