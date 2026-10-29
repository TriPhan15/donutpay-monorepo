import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/cubits/language_cubit.dart';
import 'package:finance_ai_app/cubits/theme_cubit.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/app_language.dart';
import 'package:finance_ai_app/screens/profile/widgets/language_confirm_sheet.dart';
import 'package:finance_ai_app/screens/profile/widgets/theme_preview_card.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

extension SettingsLabels on AppLocalizations {
  String themeModeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => light,
    ThemeMode.dark => dark,
    ThemeMode.system => system,
  };

  String languageLabel(AppLanguage language) => switch (language) {
    AppLanguage.vietnamese => vietnamese,
    AppLanguage.english => english,
  };
}

/// "Giao diện và ngôn ngữ" (T9 spec 3.10, M2 + R10): three preview cards for the theme, applied at once, and the two
/// languages, changed after a confirmation sheet.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageBand(title: loc.appearanceLanguageTitle),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _Caption(loc.theme),
                const _ThemeCards(),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    loc.systemThemeDescription,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: AppTextSize.caption,
                    ),
                  ),
                ),
                _Caption(loc.language),
                const _LanguageList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showSaveFailed(BuildContext context) {
  AppToast.error(context, context.loc.settingsSaveFailed);
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: AppTextSize.caption,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ThemeCards extends StatelessWidget {
  const _ThemeCards();

  static const List<ThemeMode> _options = [
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark,
  ];

  Future<void> _select(BuildContext context, ThemeMode mode) async {
    final saved = await context.read<ThemeCubit>().changeThemeMode(mode);
    if (!context.mounted) return;
    if (!saved) _showSaveFailed(context);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return BlocSelector<ThemeCubit, ThemeState, ThemeMode>(
      selector: (state) => state.themeMode,
      builder: (context, selected) => Row(
        children: [
          for (var i = 0; i < _options.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: ThemePreviewCard(
                key: ValueKey('theme-card-${_options[i].name}'),
                mode: _options[i],
                label: _options[i] == ThemeMode.system
                    ? loc.themeCardSystem
                    : loc.themeModeLabel(_options[i]),
                selected: _options[i] == selected,
                onTap: () => _select(context, _options[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LanguageList extends StatelessWidget {
  const _LanguageList();

  static String _codeOf(AppLanguage language) => switch (language) {
    AppLanguage.vietnamese => 'VI',
    AppLanguage.english => 'EN',
  };

  Future<void> _select(
    BuildContext context,
    AppLanguage language,
    AppLanguage current,
  ) async {
    if (language == current) return;
    final confirmed = await showLanguageConfirmSheet(context, language);
    if (!confirmed || !context.mounted) return;
    final saved = await context.read<LanguageCubit>().changeLanguage(language);
    if (!context.mounted || saved) return;
    // The screen has not rebuilt in the new language yet: take the text straight from it.
    AppToast.error(context, language.localizations.settingsSaveFailed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loc = context.loc;
    return BlocSelector<LanguageCubit, LanguageState, AppLanguage>(
      selector: (state) => state.language,
      builder: (context, selected) => Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (i, language) in AppLanguage.values.indexed) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 62,
                  color: colors.outlineVariant,
                ),
              ListTile(
                selected: language == selected,
                onTap: () => _select(context, language, selected),
                leading: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    _codeOf(language),
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: AppTextSize.caption,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  loc.languageLabel(language),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: AppTextSize.body,
                    fontWeight: language == selected
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
                trailing: language == selected
                    ? Icon(Icons.check_rounded, color: colors.primary)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
