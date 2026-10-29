import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';

/// One choice of the theme (T9 spec 3.10, M2): a small picture of the app in that theme (the system one half light,
/// half dark) over its name; the chosen card has a blue border.
class ThemePreviewCard extends StatelessWidget {
  const ThemePreviewCard({
    super.key,
    required this.mode,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const double _radius = 16;
  static const double _previewHeight = 84;
  static const double _previewRadius = 12;

  final ThemeMode mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_radius),
      side: selected
          ? BorderSide(color: colors.primary, width: 2)
          : BorderSide(color: colors.outlineVariant),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: colors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(_previewRadius),
                  child: SizedBox(
                    height: _previewHeight,
                    child: switch (mode) {
                      ThemeMode.light => _MiniApp(theme: AppTheme.lightTheme),
                      ThemeMode.dark => _MiniApp(theme: AppTheme.darkTheme),
                      ThemeMode.system => Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _MiniApp(theme: AppTheme.lightTheme)),
                          Expanded(child: _MiniApp(theme: AppTheme.darkTheme)),
                        ],
                      ),
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? colors.primary : colors.onSurface,
                    fontSize: AppTextSize.secondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The app drawn in a few blocks with the colours of [theme]: the band, a card and two lines of text.
class _MiniApp extends StatelessWidget {
  const _MiniApp({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    Widget line(double rightInset) => Padding(
      padding: EdgeInsets.only(left: 8, right: rightInset, top: 6),
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: scheme.outlineVariant,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 22,
            decoration: BoxDecoration(
              gradient: theme.semanticColors.headerGradient,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Container(
              height: 18,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          line(22),
          line(36),
        ],
      ),
    );
  }
}
