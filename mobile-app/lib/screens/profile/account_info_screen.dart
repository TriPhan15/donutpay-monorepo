import 'package:flutter/material.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/screens/profile/account_credentials_screen.dart';
import 'package:finance_ai_app/screens/profile/user_info_screen.dart';
import 'package:finance_ai_app/services/session_service.dart';

class AccountInfoScreen extends StatelessWidget {
  const AccountInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    // The titles and the chevrons take the ListTile defaults of the theme: onSurface and onSurfaceVariant.
    return Scaffold(
      appBar: AppBar(title: Text(loc.accountInfoTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          ListTile(
            leading: Icon(Icons.person_outline, color: colors.primary),
            title: Text(loc.credentialsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final userId = SessionService.currentUserId;
              if (userId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(loc.accountInfoSignInAgain)),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AccountCredentialsScreen(userId: userId),
                ),
              );
            },
          ),
          Divider(color: colors.onSurfaceVariant.withValues(alpha: 0.1)),
          ListTile(
            leading: Icon(Icons.badge_outlined, color: colors.primary),
            title: Text(loc.userInfoTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final userId = SessionService.currentUserId;
              if (userId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(loc.accountInfoSignInAgain)),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserInfoScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
