import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dio/dio.dart';
import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/core/utils/savings_goal_planner.dart';
import 'package:finance_ai_app/core/utils/spending_history.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/spending_analysis.dart';
import 'package:finance_ai_app/models/spending_range.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/widgets/ai/spending_range_filter.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/dialogs/ai_components.dart';

/// Asks the user for the days of a custom report range, starting from [initial]; null when the user gives up.
typedef PickDateRange =
    Future<DateTimeRange?> Function(
      BuildContext context,
      DateTimeRange initial,
    );

/// The date picker offers the same years as the Ledger's.
const int _pickerFirstYear = 2020;
const int _pickerLastYear = 2100;
const int _httpServerError = 500;

Future<DateTimeRange?> _showDateRangePicker(
  BuildContext context,
  DateTimeRange initial,
) {
  final loc = context.loc;
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(_pickerFirstYear),
    lastDate: DateTime(_pickerLastYear),
    initialDateRange: initial,
    helpText: loc.aiPickRangeTitle,
    cancelText: loc.dialogCancel,
    confirmText: loc.commonApply,
    saveText: loc.commonApply,
  );
}

class AITabPage extends StatefulWidget {
  /// [pickDateRange] opens the date range picker; only tests pass another one.
  const AITabPage({super.key, this.pickDateRange = _showDateRangePicker});

  final PickDateRange pickDateRange;

  @override
  State<AITabPage> createState() => _AITabPageState();
}

class _AITabPageState extends State<AITabPage> {
  bool _isLoading = true;
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
    final userId = SessionService.currentUserId;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final results = await Future.wait([
      AppRepository.instance
          .getTransactions(userId)
          .catchError((_) => <TransactionModel>[]),
      RemoteApiHelper.instance.fetchSavings().catchError(
        (_) => <Map<String, dynamic>>[],
      ),
    ]);

    final txs = results[0] as List<TransactionModel>;
    final goals = results[1] as List<Map<String, dynamic>>;

    if (!mounted) return;
    setState(() {
      _transactions = txs;
      _savingsGoals = goals;
      _isLoading = false;
    });

    _loadSpadePatterns(reportErrors: reportErrors);
    _loadBudgetAdvice(txs);
  }

  Future<void> _loadBudgetAdvice(List<TransactionModel> txs) async {
    final today = DateTime.now();
    final goal = SavingsGoalPlanner.pickUrgentGoal(_savingsGoals, today);
    if (goal == null) {
      if (mounted) setState(() => _budgetAdvice = null);
      return;
    }

    setState(() => _adviceLoading = true);
    try {
      // Savings contributions are not spending: the advisor would try to cut them like any other category.
      final data = txs
          .where((t) => !t.isSavingsContribution)
          .map(
            (t) => {
              'category': t.category,
              'amount': t.amount,
              'date': t.date.toIso8601String(),
              'isExpense': t.isExpense,
            },
          )
          .toList();
      final advice = await RemoteApiHelper.instance.recommendBudget(
        transactions: data,
        target: ((goal['target'] ?? 0) as num).toDouble(),
        current: ((goal['current'] ?? 0) as num).toDouble(),
        monthsLeft: SavingsGoalPlanner.monthsLeft(goal, today),
      );
      if (mounted) setState(() => _budgetAdvice = advice);
    } catch (e) {
      // Also the 422 of a history that is too short: old advice must not outlive a request that failed.
      debugPrint('Lỗi lấy gợi ý phân bổ tiền: $e');
      if (mounted) setState(() => _budgetAdvice = null);
    } finally {
      if (mounted) setState(() => _adviceLoading = false);
    }
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.loc.aiTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
      ),
      // The spinners take the primary colour of the theme, the refresh one on its surface.
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(reportErrors: true),
              child: _buildContent(colors),
            ),
    );
  }

  /// The icon colours of the insight cards identify each card and stay the same in both themes, like chart series.
  Widget _buildContent(ColorScheme colors) {
    final loc = context.loc;
    if (_transactions.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildInsightCard(
            colors,
            icon: Icons.ac_unit_rounded,
            iconColor: Colors.blueAccent,
            title: loc.aiNoData,
            subtitle: loc.aiNoDataHint,
          ),
          const SizedBox(height: 24),

          AiComponents.buildBudgetAdviceSection(
            colors,
            loc,
            _budgetAdvice,
            _adviceLoading,
          ),
          const SizedBox(height: 100),
        ],
      );
    }

    final range = _range;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSafeToSpendCard(colors),
        const SizedBox(height: 16),
        _buildInsightCard(
          colors,
          icon: Icons.trending_up_rounded,
          iconColor: colors.primary,
          title: loc.aiTrendTitle,
          subtitle: _getSpendingTrend(loc),
        ),
        const SizedBox(height: 16),
        _buildInsightCard(
          colors,
          icon: Icons.category_rounded,
          iconColor: Colors.orange,
          title: loc.aiTopCategoryTitle,
          subtitle: _getTopCategory(loc),
        ),
        const SizedBox(height: 16),
        _buildInsightCard(
          colors,
          icon: Icons.savings_rounded,
          iconColor: Colors.amber,
          title: loc.aiSavingTipTitle,
          subtitle: _getSavingTip(loc),
        ),
        const SizedBox(height: 16),
        _buildInsightCard(
          colors,
          icon: Icons.water_drop_rounded,
          iconColor: Colors.blue,
          title: loc.aiWeekCompareTitle,
          subtitle: _getWeeklyComparison(loc),
        ),
        const SizedBox(height: 24),
        Text(
          loc.aiChartTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SpendingRangeFilter(
          range: range,
          isRefreshing: _spadeLoading,
          onPeriodSelected: _onPeriodSelected,
          onRefresh: () => _loadSpadePatterns(reportErrors: true),
        ),
        const SizedBox(height: 16),
        _buildWeeklyChart(colors, range),
        const SizedBox(height: 24),
        AiComponents.buildSpadeSection(
          colors,
          loc,
          _analysis?.patterns ?? const [],
          _spadeLoading,
          hasError: _spadeFailed,
        ),
        const SizedBox(height: 24),

        AiComponents.build503020Card(
          colors,
          loc,
          _monthTxs,
          _monthIncome,
          _monthExpense,
        ),
        const SizedBox(height: 24),
        AiComponents.buildBudgetAdviceSection(
          colors,
          loc,
          _budgetAdvice,
          _adviceLoading,
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  /// What was spent in each bar of the chart; income does not count.
  List<double> _expensesPerBucket(List<SpendingBucket> buckets) => [
    for (final bucket in buckets)
      _transactions
          .where((t) => t.countsAsSpending && bucket.contains(t.date))
          .fold(0.0, (s, t) => s + t.amount),
  ];

  /// The four weeks of the current month, whatever period the chart shows.
  List<double> _getWeeklyExpenses(AppLocalizations loc) =>
      _expensesPerBucket(SpendingRange.month(DateTime.now()).buckets(loc));

  String _getWeeklyComparison(AppLocalizations loc) {
    final amounts = _getWeeklyExpenses(loc);
    if (amounts.every((a) => a == 0)) return loc.aiNoWeekData;

    int maxIdx = 0;
    for (int i = 1; i < 4; i++) {
      if (amounts[i] > amounts[maxIdx]) maxIdx = i;
    }
    return loc.aiTopWeek(maxIdx + 1, _fmt(loc, amounts[maxIdx]));
  }

  Widget _buildWeeklyChart(ColorScheme colors, SpendingRange range) {
    final buckets = range.buckets(context.loc);
    final weekExpenses = _expensesPerBucket(buckets);
    final maxY = (weekExpenses.reduce((a, b) => a > b ? a : b) * 1.2).clamp(
      100.0,
      double.infinity,
    );
    // The bars take the primary colour; grid, labels and the touch tooltip take theme colours, so that they switch
    // between light and dark with the rest of the screen.
    final gridLine = FlLine(
      color: colors.onSurfaceVariant.withValues(alpha: 0.1),
      strokeWidth: 1,
    );
    final labelStyle = TextStyle(color: colors.onSurfaceVariant, fontSize: 12);
    final tooltipStyle = TextStyle(
      color: colors.onSurface,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );

    return Container(
      key: ValueKey(range),
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => colors.surfaceContainer,
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(rod.toY.toString(), tooltipStyle),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (v) => gridLine,
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(buckets[v.toInt()].label, style: labelStyle),
                ),
              ),
            ),
          ),
          barGroups: List.generate(
            buckets.length,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: weekExpenses[i],
                  color: colors.primary,
                  width: 20,
                  borderRadius: BorderRadius.circular(6),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: colors.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafeToSpendCard(ColorScheme colors) {
    final loc = context.loc;
    if (_monthIncome <= 0) {
      return _buildInsightCard(
        colors,
        icon: Icons.account_balance_wallet_rounded,
        iconColor: colors.primary,
        title: loc.aiSafeToSpendTitle,
        subtitle: loc.aiSafeToSpendNoIncome,
      );
    }

    final goalReserve = _goalReserve(DateTime.now());

    final daysLeft =
        (DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day -
                DateTime.now().day +
                1)
            .clamp(1, 31);
    final safePerDay = (_monthIncome - _monthExpense - goalReserve) / daysLeft;
    final ok = safePerDay >= 0;
    final color = ok ? colors.primary : colors.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 8),
              // Wraps on a narrow phone instead of running past the card.
              Expanded(
                child: Text(
                  loc.aiSafeToSpendTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            loc.aiPerDay(_fmt(loc, safePerDay)),
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ok ? loc.aiDaysLeft(daysLeft) : loc.aiOverSafe,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _getSpendingTrend(AppLocalizations loc) {
    final lm = DateTime(DateTime.now().year, DateTime.now().month - 1);
    final lastTotal = _transactions
        .where(
          (t) =>
              t.countsAsSpending &&
              t.date.year == lm.year &&
              t.date.month == lm.month,
        )
        .fold(0.0, (s, t) => s + t.amount);
    if (lastTotal == 0) return loc.aiSpentThisMonth(_fmt(loc, _monthExpense));

    final diff = ((_monthExpense - lastTotal) / lastTotal * 100);
    final percent = diff.abs().toStringAsFixed(1);
    return diff > 0 ? loc.aiTrendUp(percent) : loc.aiTrendDown(percent);
  }

  String _getTopCategory(AppLocalizations loc) {
    if (_monthExpense <= 0) return loc.aiNoSpendingThisMonth;
    final Map<String, double> totals = {};
    for (var tx in _monthTxs.where((t) => t.countsAsSpending)) {
      totals[tx.category] = (totals[tx.category] ?? 0) + tx.amount;
    }
    final top = totals.entries.reduce((a, b) => a.value > b.value ? a : b);
    return loc.aiTopCategory(
      TransactionCategories.displayName(loc, top.key),
      _fmt(loc, top.value),
      (top.value / _monthExpense * 100).toStringAsFixed(0),
    );
  }

  /// The money kept out of this month's spending: what the urgent goal asks for. Without an unfinished goal (none, or
  /// all reached or deleted), what was contributed this month, because that money has already left the wallet.
  double _goalReserve(DateTime today) {
    final contributed = SavingsGoalPlanner.contributedInMonth(
      _transactions,
      today,
    );
    final goal = SavingsGoalPlanner.pickUrgentGoal(_savingsGoals, today);
    if (goal == null) return contributed;
    return SavingsGoalPlanner.goalReserve(
      monthlyNeed: SavingsGoalPlanner.monthlyNeed(goal, today),
      contributedThisMonth: contributed,
    );
  }

  String _getSavingTip(AppLocalizations loc) {
    final today = DateTime.now();
    final contributed = SavingsGoalPlanner.contributedInMonth(
      _transactions,
      today,
    );
    final goal = SavingsGoalPlanner.pickUrgentGoal(_savingsGoals, today);
    if (goal == null) {
      // No unfinished goal (none at all, or all reached): the old tips apply. This month's contributions have left the
      // wallet, so they are not part of the surplus.
      final surplus = _monthIncome - _monthExpense - contributed;
      return surplus > 0 ? loc.aiSurplus(_fmt(loc, surplus)) : loc.aiAddGoal;
    }
    final need = SavingsGoalPlanner.monthlyNeed(goal, today);
    if (need == 0) {
      return SavingsGoalPlanner.isOverdue(goal, today)
          ? loc.aiGoalOverdue
          : loc.aiGoalNoDeadline;
    }
    final reserve = SavingsGoalPlanner.goalReserve(
      monthlyNeed: need,
      contributedThisMonth: contributed,
    );
    if (_monthIncome - _monthExpense - reserve >= 0) return loc.aiOnTrack;
    return loc.aiGoalNeedMore(_fmt(loc, math.max(0, need - contributed)));
  }

  Widget _buildInsightCard(
    ColorScheme colors, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [a] in the language on screen, with a minus in front only when it is below zero.
  String _fmt(AppLocalizations loc, double a) =>
      CurrencyHelper.formatVND(a, loc, showSign: a < 0);
}
