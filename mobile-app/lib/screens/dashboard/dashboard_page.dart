import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/models/user_model.dart';
import 'package:finance_ai_app/models/wallet_model.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/models/budget_progress.dart';
import 'package:finance_ai_app/models/home_budget_summary.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/budget/budget_screen.dart';
import 'package:finance_ai_app/screens/ledger/add_transaction_page.dart';
import 'package:finance_ai_app/screens/notifications/notification_screen.dart';
import 'package:finance_ai_app/screens/dashboard/widgets/home_header_band.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/screens/main_tabs.dart';
import 'package:finance_ai_app/screens/dashboard/widgets/home_recent_card.dart';
import 'package:finance_ai_app/screens/profile/savings_page.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/widgets/budget/budget_alert_presenter.dart';
import 'package:finance_ai_app/widgets/budget/home_budget_band.dart';

class DashboardPage extends StatefulWidget {
  /// Shows a transaction (by its server id) on the Ledger tab: where a transaction notification and a tapped recent
  /// transaction lead.
  final ValueChanged<int>? onOpenTransaction;

  /// Opens the receipt scan options of MainScaffold (the same sheet as its scan button).
  final VoidCallback? onScanReceipt;
  const DashboardPage({super.key, this.onOpenTransaction, this.onScanReceipt});
  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  void reload() => _load();

  /// The number on the bell. The bell listens to it directly, so a new count repaints the bell, not the page.
  final ValueNotifier<int> _unreadNotifications = ValueNotifier<int>(0);

  /// Numbers the unread-count requests: only the answer to the latest one is shown, an older one arriving late is not.
  int _unreadRequest = 0;

  /// Numbers the loads, like [_unreadRequest]: a pull-to-refresh and a reload on dataChangedNotifier can overlap.
  int _loadRequest = 0;

  bool _isLoading = true;

  /// Set once a load has succeeded: later loads keep the page on screen instead of the spinner, and a later failure
  /// keeps what is shown.
  bool _hasData = false;

  /// The first load failed: the page offers to try again instead of showing zeros.
  bool _loadFailed = false;

  UserModel? _user;
  HomeBudgetSummary? _budgetSummary;
  bool _budgetsFailed = false;

  /// The wallet balance the server keeps (User.walletBalance, sent as walletBalance); rows not yet synced are not in it.
  double _currentBalance = 0;
  double _pendingBalanceChange = 0;
  double _monthlyIncome = 0;
  double _monthlyExpense = 0;
  List<TransactionModel> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The page stays alive in the IndexedStack of MainScaffold: a write on another tab must show here too.
    RemoteApiHelper.instance.dataChangedNotifier.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    RemoteApiHelper.instance.dataChangedNotifier.removeListener(_load);
    WidgetsBinding.instance.removeObserver(this);
    _unreadNotifications.dispose();
    super.dispose();
  }

  /// Back from the background: the server may have raised notifications meanwhile. The observer is removed in
  /// dispose, so a page that is gone never asks. There is no polling.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshUnreadNotifications());
    }
  }

  Future<void> _load() async {
    final request = ++_loadRequest;
    // Only a page with nothing to show yet is replaced by the spinner; a reload keeps it.
    if (!_hasData) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }
    final userId = SessionService.currentUserId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    // Not awaited: the bell has its own request and never holds up, or breaks, the rest of the page.
    unawaited(_refreshUnreadNotifications());

    final now = DateTime.now();

    try {
      // Started together: the budgets do not depend on the summary, so the wait is that of the slower request.
      final budgetsRequest = AppRepository.instance.tryGetBudgets(userId);
      final summary = await AppRepository.instance.getHomeSummary(userId);
      final budgets = await budgetsRequest;

      if (!mounted || request != _loadRequest) return;

      final List<TransactionModel> txs =
          summary[AppRepository.summaryTransactions];
      final wallets =
          summary[AppRepository.summaryWallets] as List<WalletModel>;
      final balance = wallets.fold<double>(0.0, (s, w) => s + w.balance);
      final pendingChange =
          summary[AppRepository.summaryPendingWalletChange] as double;

      double mInc = 0, mExp = 0;
      for (final tx in txs) {
        if (tx.date.year != now.year || tx.date.month != now.month) continue;
        if (!tx.isExpense) {
          mInc += tx.amount;
        } else if (tx.countsAsSpending) {
          mExp += tx.amount;
        }
      }

      // The budgets whose week or month contains today, the most used first.
      final budgetProgress = budgets == null
          ? <BudgetProgress>[]
          : (BudgetProgress.activeOn(now, budgets, txs)
              ..sort((a, b) => b.percent.compareTo(a.percent)));

      setState(() {
        _user = summary[AppRepository.summaryUser];
        // Budgets failing on a reload keep the band that was shown, like the rest of the page.
        if (budgets != null || !_hasData) {
          _budgetSummary = HomeBudgetSummary.from(budgetProgress, now);
          _budgetsFailed = budgets == null;
        }

        _currentBalance = balance;
        _pendingBalanceChange = pendingChange;
        _monthlyIncome = mInc;
        _monthlyExpense = mExp;
        _recentTransactions = txs.take(5).toList();

        _isLoading = false;
        _hasData = true;
      });
      // Not awaited: a dialog waiting for the user must not keep the pull-to-refresh spinner turning.
      unawaited(
        BudgetAlertPresenter.showNew(
          context,
          userId: userId,
          progresses: budgetProgress,
        ),
      );
    } catch (e) {
      debugPrint('Lỗi tải trang chủ: $e');
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _isLoading = false;
        _loadFailed = !_hasData;
      });
    }
  }

  /// Notifications are kept by the server, so there is nothing to count when signed out. On failure the bell keeps its
  /// last number.
  Future<void> _refreshUnreadNotifications() async {
    if (!mounted || SessionService.currentUserId == null) {
      return;
    }
    final request = ++_unreadRequest;
    try {
      final count = await RemoteApiHelper.instance.getUnreadNotificationCount();
      if (mounted && request == _unreadRequest) {
        _unreadNotifications.value = count;
      }
    } on DioException catch (e) {
      if (mounted) {
        debugPrint(
          'Lỗi tải số thông báo chưa đọc: HTTP ${e.response?.statusCode ?? e.type.name}',
        );
      }
    } on FormatException catch (e) {
      if (mounted) debugPrint('Lỗi đọc số thông báo chưa đọc: ${e.message}');
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NotificationScreen(onOpenTransaction: widget.onOpenTransaction),
      ),
    );
    // Whatever was read or marked there shows on the bell as soon as the user is back.
    if (mounted) unawaited(_refreshUnreadNotifications());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = context.loc;
    if (_isLoading) {
      return const Center(child: AppStateView.loading());
    }
    if (_loadFailed) {
      return Center(
        child: AppStateView.error(
          title: loc.dashboardLoadFailedTitle,
          message: loc.dashboardLoadFailedMessage,
          onRetry: _load,
        ),
      );
    }

    // The band runs up under the status bar and keeps its content below it itself.
    return SafeArea(
      top: false,
      // No colours of its own: the spinner takes the primary colour and the surface of the theme.
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  HomeHeaderBand(
                    userName: _user?.fullName ?? loc.defaultUserName,
                    balance: _currentBalance,
                    pendingChange: _pendingBalanceChange,
                    monthIncome: _monthlyIncome,
                    monthExpense: _monthlyExpense,
                    unreadNotifications: _unreadNotifications,
                    onOpenNotifications: _openNotifications,
                    onAddTransaction: _openAddTransaction,
                    onScanReceipt: widget.onScanReceipt,
                    onOpenBudgets: _openBudgetScreen,
                    onOpenSavings: () => _navigateTo(const SavingsPage()),
                    onOpenTransaction: widget.onOpenTransaction,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: HomeBudgetBand(
                      summary: _budgetSummary,
                      loadFailed: _budgetsFailed,
                      onOpen: _openBudgetScreen,
                      onRetry: _load,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: HomeRecentCard(
                      transactions: _recentTransactions,
                      onOpenTransaction: widget.onOpenTransaction,
                      onSeeAll: MainTabs.opener(MainTab.ledger),
                      onAddTransaction: _openAddTransaction,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBudgetScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BudgetScreen()),
    ).then((_) {
      if (mounted) _load();
    });
  }

  // The list refreshes through dataChangedNotifier once the transaction is saved, as from the Ledger.
  void _openAddTransaction() => _navigateTo(const AddTransactionPage());

  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}
