import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/cubits/language_cubit.dart';
import 'package:finance_ai_app/cubits/theme_cubit.dart';
import 'package:finance_ai_app/models/user_model.dart';
import 'package:finance_ai_app/models/wallet_model.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/screens/budget/budget_screen.dart';
import 'package:finance_ai_app/screens/profile/account_credentials_screen.dart';
import 'package:finance_ai_app/screens/profile/account_info_screen.dart';
import 'package:finance_ai_app/screens/profile/guide_page.dart';
import 'package:finance_ai_app/screens/profile/savings_page.dart';
import 'package:finance_ai_app/screens/profile/settings_screen.dart';
import 'package:finance_ai_app/screens/profile/widgets/about_app_sheet.dart';
import 'package:finance_ai_app/screens/profile/widgets/feedback_sheet.dart';
import 'package:finance_ai_app/screens/profile/widgets/money_sources_sheet.dart';
import 'package:finance_ai_app/screens/profile/widgets/notification_settings_sheet.dart';
import 'package:finance_ai_app/screens/profile/widgets/profile_group.dart';
import 'package:finance_ai_app/screens/profile/widgets/profile_header_band.dart';
import 'package:finance_ai_app/screens/profile/widgets/security_sheet.dart';
import 'package:finance_ai_app/screens/linked/linked_services_page.dart';
import 'package:finance_ai_app/screens/auth/login_page.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/services/social_auth_service.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/common/demo_badge.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  UserModel? _user;
  List<WalletModel> _wallets = [];
  List<TransactionModel> _recentTransactions = [];

  /// Numbers the loads: reloads on dataChangedNotifier can overlap, only the latest one is shown.
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    // The page stays alive in the IndexedStack of MainScaffold: a write on another tab must show here too.
    RemoteApiHelper.instance.dataChangedNotifier.addListener(_load);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    RemoteApiHelper.instance.dataChangedNotifier.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_loadRequest;
    final userId = SessionService.currentUserId;
    if (userId == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }
    final UserModel? user;
    final List<WalletModel> wallets;
    final List<TransactionModel> txs;
    try {
      final summary = await AppRepository.instance.getHomeSummary(userId);
      user = summary[AppRepository.summaryUser] as UserModel?;
      wallets = summary[AppRepository.summaryWallets] as List<WalletModel>;
      txs =
          summary[AppRepository.summaryTransactions] as List<TransactionModel>;
    } catch (e) {
      UserFacingError.log('Profile load', e);
      if (!mounted || request != _loadRequest) return;
      // A reload the user did not ask for: a toast, not a dialog, and the data shown so far stays.
      setState(() => _isLoading = false);
      final loc = context.loc;
      AppToast.error(
        context,
        UserFacingError.messageOf(e, loc),
        actionLabel: loc.commonRetry,
        onAction: _load,
      );
      return;
    }
    if (!mounted || request != _loadRequest) return;
    final sorted = [...txs]..sort((a, b) => b.date.compareTo(a.date));
    setState(() {
      _isLoading = false;
      _user = user;
      _wallets = wallets;
      _recentTransactions = sorted.take(20).toList();
    });
  }

  /// Signs out. In full mode the server is asked to revoke the tokens first (they are needed for that request), then the
  /// local session is ALWAYS cleared and the user goes back to the login screen, even when the server call fails: a
  /// network error must never leave the user signed in.
  Future<void> _logout() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: context.loc.profileLogoutConfirmTitle,
      message: context.loc.profileLogoutConfirmMessage,
      confirmText: context.loc.profileLogout,
      danger: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await RemoteApiHelper.instance.logout();
      await SocialAuthService.instance.signOut();
    } catch (e) {
      // Both steps are best effort: whatever fails, the local sign-out below must still happen.
      debugPrint('Logout: the server or social sign-out step failed: $e');
    }
    await SessionService.clearSession();

    // Only the navigation needs the context: the session is already cleared even when this page is gone.
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _openAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountInfoScreen()),
    ).then((_) => _load());
  }

  /// The change-password page of the account screen (T9 spec 3.10: "Đổi mật khẩu" opens the page of 3.8).
  void _openChangePassword() {
    if (SessionService.currentUserId == null) {
      AppToast.error(context, context.loc.accountInfoSignInAgain);
      return;
    }
    _push(const AccountCredentialsScreen());
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final name = _user?.fullName ?? loc.defaultUserName;
    final email = _user?.email ?? '';
    final themeMode = context.select(
      (ThemeCubit cubit) => cubit.state.themeMode,
    );
    final language = context.select(
      (LanguageCubit cubit) => cubit.state.language,
    );
    const gap = SizedBox(height: 20);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          ProfileHeaderBand(
            name: name,
            email: email,
            onOpenAccount: _openAccount,
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: AppStateView.loading()),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileGroup(
                    title: loc.credentialsTitle,
                    rows: [
                      ProfileRow(
                        icon: Icons.person_outline_rounded,
                        label: loc.accountInfoTitle,
                        onTap: _openAccount,
                      ),
                    ],
                  ),
                  gap,
                  ProfileGroup(
                    title: loc.profileUtilities,
                    rows: [
                      ProfileRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: loc.profileMoneySources,
                        onTap: () => showMoneySourcesSheet(context, _wallets),
                      ),
                      ProfileRow(
                        icon: Icons.link_rounded,
                        label: loc.profileLinkedServices,
                        // The wallets are simulated: the row says so before it is opened.
                        badge: const DemoBadge(),
                        onTap: () => _push(const LinkedServicesPage()),
                      ),
                      ProfileRow(
                        icon: Icons.savings_outlined,
                        label: loc.savingsTitle,
                        onTap: () => _push(const SavingsPage()),
                      ),
                      ProfileRow(
                        icon: Icons.track_changes_rounded,
                        label: loc.profileBudget,
                        onTap: () => _push(const BudgetScreen()),
                      ),
                    ],
                  ),
                  gap,
                  ProfileGroup(
                    title: loc.settings,
                    rows: [
                      ProfileRow(
                        icon: Icons.light_mode_outlined,
                        label: loc.theme,
                        value: loc.themeModeLabel(themeMode),
                        onTap: _openSettings,
                      ),
                      ProfileRow(
                        icon: Icons.language_rounded,
                        label: loc.language,
                        value: loc.languageLabel(language),
                        onTap: _openSettings,
                      ),
                      ProfileRow(
                        icon: Icons.notifications_none_rounded,
                        label: loc.notificationsTitle,
                        onTap: () => showNotificationSettingsSheet(context),
                      ),
                      ProfileRow(
                        icon: Icons.lock_outline_rounded,
                        label: loc.profileSecurityPrivacy,
                        onTap: () => showSecuritySheet(
                          context,
                          recentTransactions: _recentTransactions,
                          onChangePassword: _openChangePassword,
                        ),
                      ),
                    ],
                  ),
                  gap,
                  ProfileGroup(
                    title: loc.profileSupport,
                    rows: [
                      ProfileRow(
                        icon: Icons.help_outline_rounded,
                        label: loc.profileHelp,
                        onTap: () => _push(const GuidePage()),
                      ),
                      ProfileRow(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: loc.profileFeedback,
                        onTap: () => showFeedbackSheet(context),
                      ),
                      ProfileRow(
                        icon: Icons.info_outline_rounded,
                        label: loc.profileAbout,
                        onTap: () => showAboutAppSheet(context),
                      ),
                    ],
                  ),
                  gap,
                  ProfileGroup(
                    rows: [
                      ProfileRow(
                        icon: Icons.logout_rounded,
                        label: loc.profileLogout,
                        danger: true,
                        onTap: _logout,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
