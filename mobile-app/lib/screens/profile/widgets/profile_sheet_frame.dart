import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/theme/app_typography.dart';

/// The frame of every sheet opened from the Profile tab: the drag handle, a title row ending in [action] (or a close
/// button), then [child]. It scrolls and stays above the keyboard.
class ProfileSheetFrame extends StatelessWidget {
  const ProfileSheetFrame({
    super.key,
    required this.title,
    this.action,
    required this.child,
  });

  static const Size _handle = Size(40, 4);
  static const double _handleRadius = 10;

  final String title;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: _handle.width,
                  height: _handle.height,
                  decoration: BoxDecoration(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(_handleRadius),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: AppTextSize.title,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  action ??
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 4),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
