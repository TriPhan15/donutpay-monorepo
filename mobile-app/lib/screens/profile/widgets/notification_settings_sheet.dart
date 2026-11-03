import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/models/notification_preferences.dart';
import 'package:finance_ai_app/screens/profile/widgets/profile_sheet_frame.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/dialogs/app_sheet.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

/// "Cài đặt thông báo" (T9 spec 3.10, M1): two switches, each with a light blue icon box and a line saying what it does,
/// and a Save button that keeps the choices on the device ([NotificationPreferences]).
Future<void> showNotificationSettingsSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    (_) => _NotificationSettingsSheet(host: context),
  );
}

class _NotificationSettingsSheet extends StatefulWidget {
  const _NotificationSettingsSheet({required this.host});

  /// Where the toast goes once the sheet is closed.
  final BuildContext host;

  @override
  State<_NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState
    extends State<_NotificationSettingsSheet> {
  /// Null until the stored choices are read.
  NotificationPreferences? _prefs;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    NotificationPreferences.load().then((prefs) {
      if (mounted) setState(() => _prefs = prefs);
    });
  }

  Future<void> _save(NotificationPreferences prefs) async {
    setState(() => _saving = true);
    final saved = await prefs.save();
    if (mounted) Navigator.pop(context);
    final host = widget.host;
    if (!host.mounted) return;
    if (saved) {
      AppToast.success(host, host.loc.notificationSettingsSaved);
    } else {
      AppToast.error(host, host.loc.settingsSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = Theme.of(context).colorScheme;
    final prefs = _prefs;
    if (prefs == null) {
      return ProfileSheetFrame(
        title: loc.notificationSettingsTitle,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: AppStateView.loading()),
        ),
      );
    }
    return ProfileSheetFrame(
      title: loc.notificationSettingsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SwitchRow(
            icon: Icons.notifications_none_rounded,
            title: loc.notificationSettingsPush,
            description: loc.notificationSettingsPushDescription,
            value: prefs.push,
            onChanged: (v) => setState(() => _prefs = prefs.copyWith(push: v)),
          ),
          Divider(height: 1, thickness: 1, color: colors.outlineVariant),
          _SwitchRow(
            icon: Icons.warning_amber_rounded,
            title: loc.notificationSettingsBudgetAlert,
            description: loc.notificationSettingsBudgetAlertDescription,
            value: prefs.budgetAlert,
            onChanged: (v) =>
                setState(() => _prefs = prefs.copyWith(budgetAlert: v)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : () => _save(prefs),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                loc.commonSave,
                style: const TextStyle(
                  fontSize: AppTextSize.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: colors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: AppTextSize.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: AppTextSize.caption,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
