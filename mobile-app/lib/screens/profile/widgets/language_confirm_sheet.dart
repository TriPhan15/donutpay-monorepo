import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/screens/profile/settings_screen.dart';

/// "Đổi sang English?" (T9 spec 3.10, R10): asks before the app changes its language. True only for the Switch button;
/// Cancel, Back and a tap outside the sheet give false.
Future<bool> showLanguageConfirmSheet(
  BuildContext context,
  AppLanguage target,
) async {
  final answer = await showModalBottomSheet<bool>(
    context: context,
    builder: (sheetContext) {
      final colors = Theme.of(sheetContext).colorScheme;
      final loc = sheetContext.loc;
      final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      );
      const buttonText = TextStyle(
        fontSize: AppTextSize.title,
        fontWeight: FontWeight.w700,
      );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                loc.languageConfirmTitle(loc.languageLabel(target)),
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: AppTextSize.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                loc.languageConfirmMessage,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: AppTextSize.secondary,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primaryContainer,
                          foregroundColor: colors.primary,
                          shape: shape,
                        ),
                        child: Text(loc.dialogCancel, style: buttonText),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: FilledButton.styleFrom(shape: shape),
                        child: Text(
                          loc.languageConfirmAction,
                          style: buttonText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return answer ?? false;
}
