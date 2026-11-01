import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/core/utils/savings_goal_planner.dart';
import 'package:finance_ai_app/core/utils/spending_history.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/spending_analysis.dart';
import 'package:finance_ai_app/models/spending_balance.dart';
import 'package:finance_ai_app/models/spending_highlights.dart';
import 'package:finance_ai_app/models/spending_range.dart';
import 'package:finance_ai_app/models/today_allowance.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ai/widgets/ai_balance_card.dart';
import 'package:finance_ai_app/screens/ai/widgets/ai_daily_chart_card.dart';
import 'package:finance_ai_app/screens/ai/widgets/ai_habits_card.dart';
import 'package:finance_ai_app/screens/ai/widgets/ai_highlights_card.dart';
import 'package:finance_ai_app/screens/ai/widgets/ai_today_band.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/inputs/date_picker_sheet.dart';

/// Asks the user for the days of a custom report range, starting from [initial]; null when the user gives up.
typedef PickDateRange =
    Future<DateTimeRange?> Function(
      BuildContext context,
      DateTimeRange initial,
    );

/// The date sheets offer the same years as the Ledger's.
const int _pickerFirstYear = 2020;
const int _pickerLastYear = 2100;
const int _httpServerError = 500;

/// One request of a load: what it gave, or why it failed. A failure is logged here and never thrown, so the other
/// request of the load still counts.
typedef _Attempt<T> = ({T? value, Object? error});

Future<_Attempt<T>> _attempt<T>(Future<T> request) async {
  try {
    return (value: await request, error: null);
  } catch (e) {
    debugPrint('Lỗi tải dữ liệu tab AI: $e');
    return (value: null, error: e);
  }
}

/// The first day, then the last one, each in the date sheet of the app (T9 spec 3.3); the last day cannot be before
/// the first.
Future<DateTimeRange?> _pickRangeWithSheets(
  BuildContext context,
  DateTimeRange initial,
) async {
  final loc = context.loc;
  final first = DateTime(_pickerFirstYear);
  final last = DateTime(_pickerLastYear, 12, 31);
  final start = await showDatePickerSheet(
    context,
    initial: initial.start,
    firstDate: first,
    lastDate: last,
    title: loc.aiPickRangeStart,
  );
  if (start == null || !context.mounted) return null;
  final end = await showDatePickerSheet(
    context,
    initial: initial.end.isBefore(start) ? start : initial.end,
    firstDate: start,
    lastDate: last,
    title: loc.aiPickRangeEnd,
  );
  if (end == null) return null;
  return DateTimeRange(start: start, end: end);
}

class AITabPage extends StatefulWidget {
  /// [pickDateRange] asks for the days of a custom range; only tests pass another one.
  const AITabPage({super.key, this.pickDateRange = _pickRangeWithSheets});

  final PickDateRange pickDateRange;

  @override
  State<AITabPage> createState() => _AITabPageState();
}

class _AITabPageState extends State<AITabPage> {
  static const double _gutter = 16;

  /// Room under the last card for the tab bar and its scan button.
  static const double _bottomGap = 100;

  bool _isLoading = true;

  /// Why the last load failed (the transactions, the goals or both); null when it went through. What was loaded before
  /// stays on screen meanwhile.
  Object? _loadError;

  /// Whether the transactions were ever loaded: without them a failure leaves nothing to show.
  bool _transactionsLoaded = false;
  List<TransactionModel> _transactions = [];
  SpendingAnalysis? _analysis;
  List<Map<String, dynamic>> _savingsGoals = [];

  bool _spadeLoading = false;
  bool _spadeFailed = false;

  /// Numbers each analysis; an answer that is not the latest one belongs to a filter the user has left.
  int _spadeRequestId = 0;
  SpendingPeriod _period = SpendingPeriod.month;
  SpendingRange? _customRange;
  Map<String, dynamic>? _budgetAdvice;
  bool _adviceLoading = false;

  /// Numbers each load of the transactions and goals, like [_spadeRequestId].
  int _loadRequestId = 0;

  /// Numbers each budget advice request, like [_spadeRequestId]: only the latest one may set or clear the advice.
  int _adviceRequestId = 0;

  List<TransactionModel> get _monthTxs {
    final now = DateTime.now();
    return _transactions
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .toList();
  }

  double get _monthIncome =>
      _monthTxs.where((t) => !t.isExpense).fold(0, (s, t) => s + t.amount);
  double get _monthExpense => _monthTxs
      .where((t) => t.countsAsSpending)
      .fold(0, (s, t) => s + t.amount);

  /// Worked out from the clock each time, so "this week" and "this month" never go stale while the tab stays open.
  SpendingRange get _range =>
      SpendingRange.of(_period, DateTime.now(), custom: _customRange);

  @override
  void initState() {
    super.initState();
    _load();
    RemoteApiHelper.instance.dataChangedNotifier.addListener(_load);
    SessionService.needRefreshAI.addListener(_onNeedRefreshAIChanged);
  }

  @override
  void dispose() {
    RemoteApiHelper.instance.dataChangedNotifier.removeListener(_load);
    SessionService.needRefreshAI.removeListener(_onNeedRefreshAIChanged);
    super.dispose();
  }

  void _onNeedRefreshAIChanged() {
    if (SessionService.needRefreshAI.value) {
      if (mounted) _load();
      SessionService.needRefreshAI.value = false;
    }
  }

  Future<void> _load({bool reportErrors = false}) async {
    final requestId = ++_loadRequestId;
    final userId = SessionService.currentUserId;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final (transactionsResult, goalsResult) = await (
      _attempt(AppRepository.instance.getTransactions(userId)),
      _attempt(RemoteApiHelper.instance.fetchSavings()),
    ).wait;
    final txs = transactionsResult.value;
    final goals = goalsResult.value;

    // A newer load has started: its list is the fresher one, so this one must not overwrite it.
    if (!mounted || requestId != _loadRequestId) return;
    // A request that failed leaves what was loaded before as it is: an empty list would pass for "no data".
    setState(() {
      if (txs != null) {
        _transactions = txs;
        _transactionsLoaded = true;
      }
      if (goals != null) _savingsGoals = goals;
      _loadError = transactionsResult.error ?? goalsResult.error;
      _isLoading = false;
    });

    // The analysis and the advice are worked out from the transactions: without fresh ones the last ones stay.
    if (txs == null) return;
    _loadSpadePatterns(reportErrors: reportErrors);
    _loadBudgetAdvice(txs);
  }

  Future<void> _loadBudgetAdvice(List<TransactionModel> txs) async {
    final requestId = ++_adviceRequestId;
    final today = DateTime.now();
    final goal = SavingsGoalPlanner.pickUrgentGoal(_savingsGoals, today);
    if (goal == null) {
      if (mounted) {
        setState(() {
          _budgetAdvice = null;
          _adviceLoading = false;
        });
      }
      return;
    }

    setState(() => _adviceLoading = true);
    Map<String, dynamic>? advice;
    try {
      // Savings contributions are not spending: the advisor would try to cut them like any other category.
      final data = SpendingHistory.forBudgetAdvice(txs, today)
          .map(
            (t) => {
              'category': t.category,
              'amount': t.amount,
              'date': t.date.toIso8601String(),
              'isExpense': t.isExpense,
            },
          )
          .toList();
      advice = await RemoteApiHelper.instance.recommendBudget(
        transactions: data,
        target: ((goal['target'] ?? 0) as num).toDouble(),
        current: ((goal['current'] ?? 0) as num).toDouble(),
        monthsLeft: SavingsGoalPlanner.monthsLeft(goal, today),
      );
    } catch (e) {
      // Also the 422 of a history that is too short: old advice must not outlive a request that failed.
      debugPrint('Lỗi lấy gợi ý phân bổ tiền: $e');
      advice = null;
    }
    // The page is gone, or a newer request has taken over: this answer, or failure, must not touch its advice.
    if (!mounted || requestId != _adviceRequestId) return;
    setState(() {
      _budgetAdvice = advice;
      _adviceLoading = false;
    });
  }

  void _onPeriodSelected(SpendingPeriod period) {
    if (period == SpendingPeriod.custom) {
      _pickCustomRange();
      return;
    }
    if (period == _period) return;
    // The filter only redraws the charts; the analysis always covers the same 26 weeks.
    setState(() => _period = period);
  }

  Future<void> _pickCustomRange() async {
    final current = _range;
    final picked = await widget.pickDateRange(
      context,
      DateTimeRange(start: current.start, end: current.end),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _period = SpendingPeriod.custom;
      _customRange = SpendingRange.custom(picked.start, picked.end);
    });
  }

  static String _messageOf(Object error, AppLocalizations loc) {
    if (error is! DioException) return loc.errorUnexpected;
    final status = error.response?.statusCode;
    if (status == null) return loc.aiErrorNetwork;
    if (status >= _httpServerError) return loc.aiErrorServer;
    return loc.aiErrorRejected;
  }

  /// Mines the spending habits of the last 26 weeks, whatever period the charts show. Only a call the user asked for
  /// ([reportErrors]: the refresh button, a pull to refresh) opens an error dialog. The tab is built at start-up behind
  /// the others, so a failure of a background load is logged and shown on the card only.
  Future<void> _loadSpadePatterns({bool reportErrors = false}) async {
    final requestId = ++_spadeRequestId;
    final history = SpendingHistory.forAnalysis(_transactions, DateTime.now());
    // Nothing to mine without spending, so the AI service is not called for it.
    if (history.isEmpty) {
      setState(() {
        _analysis = SpendingAnalysis.empty;
        _spadeFailed = false;
        _spadeLoading = false;
      });
      return;
    }
    setState(() {
      _spadeLoading = true;
      _spadeFailed = false;
    });

    SpendingAnalysis? analysis;
    Object? failure;
    try {
      analysis = await RemoteApiHelper.instance.analyzeSpending([
        for (final t in history)
          {
            'category': t.category,
            'amount': t.amount,
            'date': t.date.toIso8601String(),
            'isExpense': t.isExpense,
          },
      ]);
    } catch (e) {
      failure = e;
    }
    // The page is gone, or a newer request has taken over: drop this answer.
    if (!mounted || requestId != _spadeRequestId) return;

    final loaded = analysis;
    final error = failure;
    setState(() {
      if (loaded != null) _analysis = loaded;
      _spadeFailed = error != null;
      _spadeLoading = false;
    });
    if (error == null) return;

    debugPrint('Lỗi phân tích thói quen chi tiêu: $error');
    if (reportErrors) {
      await AppDialog.error(
        context,
        title: context.loc.aiAnalyzeFailedTitle,
        message: _messageOf(error, context.loc),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: AppStateView.loading()));
    }
    final loadError = _loadError;
    if (loadError != null && !_transactionsLoaded) {
      return Scaffold(
        body: Center(
          child: AppStateView.error(
            title: context.loc.aiLoadFailedTitle,
            message: UserFacingError.messageOf(loadError, context.loc),
            onRetry: () => _load(reportErrors: true),
          ),
        ),
      );
    }
    // The band runs up under the status bar and keeps its content below it itself.
    return Scaffold(
      body: SafeArea(
        top: false,
        // No colours of its own: the spinner takes the primary colour and the surface of the theme.
        child: RefreshIndicator(
          onRefresh: () => _load(reportErrors: true),
          child: _buildContent(),
        ),
      ),
    );
  }

  /// Everything is worked out from the clock at each build, so "today", "this week" and "this month" never go stale
  /// while the tab stays open.
  Widget _buildContent() {
    final loc = context.loc;
    final today = DateTime.now();
    final band = AiTodayBand(
      allowance: TodayAllowance.of(
        transactions: _transactions,
        savingsGoals: _savingsGoals,
        today: today,
      ),
      isRefreshing: _spadeLoading,
      onRefresh: () => _loadSpadePatterns(reportErrors: true),
    );
    final advice = AiBalanceCard(
      balance: _transactions.isEmpty
          ? null
          : SpendingBalance.of(_monthTxs, _monthIncome, _monthExpense),
      advice: _budgetAdvice,
      adviceLoading: _adviceLoading,
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: _bottomGap),
      children: [
        band,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _transactions.isEmpty
                ? [
                    if (_loadError != null) _buildLoadFailedNotice(),
                    const SizedBox(height: 24),
                    AppStateView.empty(
                      icon: Icons.insights_outlined,
                      title: loc.aiNoData,
                      message: loc.aiNoDataMessage,
                    ),
                    advice,
                  ]
                : [
                    if (_loadError != null) _buildLoadFailedNotice(),
                    AiHighlightsCard(
                      highlights: SpendingHighlights.of(
                        transactions: _transactions,
                        savingsGoals: _savingsGoals,
                        today: today,
                      ),
                    ),
                    AiDailyChartCard(
                      range: _range,
                      transactions: _transactions,
                      today: today,
                      onPeriodSelected: _onPeriodSelected,
                    ),
                    AiHabitsCard(
                      analysis: _analysis,
                      isLoading: _spadeLoading,
                      hasError: _spadeFailed,
                      transactions: _transactions,
                      today: today,
                      onRetry: () => _loadSpadePatterns(reportErrors: true),
                    ),
                    advice,
                  ],
          ),
        ),
      ],
    );
  }

  /// Above the cards when a refresh failed: they show what was loaded before, and the user can try again.
  Widget _buildLoadFailedNotice() {
    final loc = context.loc;
    final warning = Theme.of(context).semanticColors.warningColor;
    return Container(
      margin: const EdgeInsets.only(top: _gutter),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loc.aiLoadFailedNotice,
                  style: const TextStyle(fontSize: AppTextSize.secondary),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _load(reportErrors: true),
              child: Text(loc.commonRetry),
            ),
          ),
        ],
      ),
    );
  }
}
