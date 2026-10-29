import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/screens/profile/widgets/profile_sheet_frame.dart';

/// The version shown to the user; the same as `version:` in pubspec.yaml (no package to read it at run time).
const String appVersion = '1.0.0';

const String _appName = 'LedgerMind';
const String _logoAsset = 'assets/images/logo.png';

/// "Về ứng dụng" (T9 spec 3.10, M2): logo C, name and description, then the Version, Developer, School and open
/// source licence rows. Replaces Flutter's own about dialog and its English texts.
Future<void> showAboutAppSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => const _AboutAppSheet(),
  );
}

class _AboutAppSheet extends StatelessWidget {
  const _AboutAppSheet();

  static const double _logoSize = 48;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final labelStyle = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: AppTextSize.body,
    );
    final valueStyle = TextStyle(
      color: colors.onSurface,
      fontSize: AppTextSize.body,
      fontWeight: FontWeight.w600,
    );
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: colors.outlineVariant,
    );
    Widget info(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          Text(value, style: valueStyle),
        ],
      ),
    );
    return ProfileSheetFrame(
      title: loc.profileAbout,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  _logoAsset,
                  width: _logoSize,
                  height: _logoSize,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _appName,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: AppTextSize.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      loc.aboutDescription,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: AppTextSize.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          info(loc.aboutVersion, appVersion),
          divider,
          info(loc.aboutDeveloper, loc.aboutDeveloperValue),
          divider,
          info(loc.aboutSchool, loc.aboutSchoolValue),
          divider,
          InkWell(
            onTap: () => showLicensePage(
              context: context,
              applicationName: _appName,
              applicationVersion: appVersion,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(child: Text(loc.aboutLicenses, style: labelStyle)),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
