import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'dart:io';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/sync_status.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/budget_progress.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ledger/edit_transaction_page.dart';
import 'package:finance_ai_app/widgets/budget/budget_alert_presenter.dart';
import 'package:finance_ai_app/widgets/budget/budget_section.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';
import 'package:finance_ai_app/widgets/receipt/receipt_status_badge.dart';
import 'package:finance_ai_app/widgets/sync/sync_status_badge.dart';

import 'add_transaction_page.dart';

enum LedgerPeriod { week, month, year }

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});

  @override
  State<LedgerPage> createState() => LedgerPageState();
}

class LedgerPageState extends State<LedgerPage> {
  static const int _monthsPerYear = 12;

  /// The month chart shows the selected month and this many before it.
  static const int _monthsBeforeSelected = 5;

  bool _isLoading = true;

  /// True when the list of the server could not be loaded: [_transactions] then holds only the transactions of this
  /// device that are waiting to be sent, which must stay reachable so that they can be resent.
  bool _transactionsFailed = false;
  List<TransactionModel> _transactions = [];

  /// clientIds of the transactions being resent, so that a second tap on the same one cannot start a second send.
  final Set<String> _resendingClientIds = {};

  /// Numbers the loads: a pull-to-refresh and a reload on dataChangedNotifier can overlap, only the latest one is shown.
  int _loadRequest = 0;
  List<BudgetModel> _budgets = [];
  bool _budgetsFailed = false;
  List<BudgetProgress> _budgetProgress = [];

  /// Server id of a transaction asked for by [showTransaction] that is not in the list yet: shown when the load ends.
  int? _pendingTransactionId;

  DateTime _selectedDate = DateTime.now();
  LedgerPeriod _period = LedgerPeriod.month;

  bool _showExpenses = true;
  bool _showIncome = true;
  String _sortOption = 'date_desc';
  double? _filterMinAmount;
  double? _filterMaxAmount;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  /// [amount] in VND, with a minus only when it is negative (a balance), as the language of [loc] writes it.
  static String _money(double amount, AppLocalizations loc) =>
      CurrencyHelper.formatVND(amount, loc, showSign: amount < 0);

  @override
  void initState() {
    super.initState();
    // The page stays alive in the IndexedStack of MainScaffold: every write, on any tab, reloads it.
    RemoteApiHelper.instance.dataChangedNotifier.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    RemoteApiHelper.instance.dataChangedNotifier.removeListener(_load);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_loadRequest;
    final userId = SessionService.currentUserId;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _transactions = [];
        _budgets = [];
      });
      return;
    }

    // Started together: the budgets do not depend on the transactions, so the wait is that of the slower request.
    final budgetsRequest = AppRepository.instance.tryGetBudgets(userId);
    List<TransactionModel> txs;
    var transactionsFailed = false;
    try {
      txs = await AppRepository.instance.getTransactions(userId);
    } catch (e) {
      debugPrint('Lỗi tải giao dịch: $e');
      transactionsFailed = true;
      txs = await AppRepository.instance.getUnsyncedTransactions(userId);
    }
    final budgets = await budgetsRequest;

    if (!mounted || request != _loadRequest) return;
    setState(() {
      _isLoading = false;
      _transactionsFailed = transactionsFailed;
      _transactions = txs;
      _budgets = budgets ?? [];
      _budgetsFailed = budgets == null;
      _refreshBudgetProgress();
    });
    _openPendingTransaction();
    if (budgets != null) {
      // Not awaited, so a dialog waiting for the user does not hold up the pull-to-refresh.
      unawaited(
        BudgetAlertPresenter.showNew(
          context,
          userId: userId,
          progresses: BudgetProgress.activeOn(DateTime.now(), budgets, txs),
        ),
      );
    }
  }

  void reload() => _refresh();

  /// Shows the transaction with the server id [id] in its detail sheet, with the period moved to its date (a tapped
  /// notification). Not in the list yet (created after the last load): the list is loaded again first.
  void showTransaction(int id) {
    _pendingTransactionId = id;
    if (_transactionWithId(id) != null) {
      _openPendingTransaction();
    } else if (!_isLoading) {
      _load();
    }
    // While a load runs, it opens the transaction when it ends.
  }

  TransactionModel? _transactionWithId(int id) {
    final wanted = '$id';
    for (final tx in _transactions) {
      if (tx.id == wanted) return tx;
    }
    return null;
  }

  void _openPendingTransaction() {
    final id = _pendingTransactionId;
    if (id == null || !mounted) return;
    _pendingTransactionId = null;
    final tx = _transactionWithId(id);
    if (tx == null) {
      AppToast.info(context, context.loc.notificationsTransactionNotFound);
      return;
    }
    setState(() => _selectedDate = tx.date);
    _showTransactionDetails(tx);
  }

  /// Asked for by the user (pull-to-refresh, a tap on the tab it is on): what waits in the outbox is sent again first.
  /// Not awaited, the outcome of each send reaches the page through dataChangedNotifier.
  Future<void> _refresh() {
    final userId = SessionService.currentUserId;
    if (userId != null) {
      unawaited(AppRepository.instance.resendUnsyncedTransactions(userId));
    }
    return _load();
  }

  /// The budgets that overlap the period on screen, each measured over its own dates. It is kept in state because a
  /// keystroke in the search box rebuilds the page, and that must not recompute it.
  void _refreshBudgetProgress() {
    _budgetProgress = BudgetProgress.overlapping(
      _periodStart,
      _periodLastDay,
      _budgets,
      _transactions,
    );
  }

  /// The first day of the week, month or year on screen.
  DateTime get _periodStart => switch (_period) {
    LedgerPeriod.week => _weekStart,
    LedgerPeriod.month => DateTime(_selectedDate.year, _selectedDate.month, 1),
    LedgerPeriod.year => DateTime(_selectedDate.year, 1, 1),
  };

  /// The last day of the week, month or year on screen (the whole day belongs to the period).
  DateTime get _periodLastDay => switch (_period) {
    LedgerPeriod.week => _weekEnd.subtract(const Duration(days: 1)),
    LedgerPeriod.month => DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    ),
    LedgerPeriod.year => DateTime(_selectedDate.year, 12, 31),
  };

  DateTime get _weekStart {
    final d = _selectedDate;
    final base = DateTime(d.year, d.month, d.day);
    return base.subtract(Duration(days: (d.weekday - 1) % 7));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 7));

  bool _inSelectedPeriod(DateTime date) => switch (_period) {
    LedgerPeriod.week => !date.isBefore(_weekStart) && date.isBefore(_weekEnd),
    LedgerPeriod.month =>
      date.year == _selectedDate.year && date.month == _selectedDate.month,
    LedgerPeriod.year => date.year == _selectedDate.year,
  };

  /// Whether the period on screen is the one of today: the "Today" button is offered only when it is not.
  bool get _showsToday => _inSelectedPeriod(DateTime.now());

  String _periodLabel(AppLocalizations loc) {
    switch (_period) {
      case LedgerPeriod.week:
        final e = _weekEnd.subtract(const Duration(days: 1));
        return '${DateFormat('dd/MM').format(_weekStart)} - ${DateFormat('dd/MM/yyyy').format(e)}';
      case LedgerPeriod.month:
        return _monthLabel(loc);
      case LedgerPeriod.year:
        return loc.ledgerYearLabel('${_selectedDate.year}');
    }
  }

  /// The selected month as the language of [loc] names it, e.g. "October 2026".
  String _monthLabel(AppLocalizations loc) =>
      DateFormat('MMMM yyyy', loc.localeName).format(_selectedDate);

  List<TransactionModel> get _periodTransactions {
    final q = _searchQuery.toLowerCase().trim();
    final list = _transactions.where((tx) {
      final inPeriod = _inSelectedPeriod(tx.date);
      final matchType =
          (_showExpenses && tx.isExpense) || (_showIncome && !tx.isExpense);
      final matchSearch =
          q.isEmpty ||
          tx.title.toLowerCase().contains(q) ||
          tx.category.toLowerCase().contains(q);

      final matchMin =
          _filterMinAmount == null || tx.amount >= _filterMinAmount!;
      final matchMax =
          _filterMaxAmount == null || tx.amount <= _filterMaxAmount!;

      return inPeriod && matchType && matchSearch && matchMin && matchMax;
    }).toList();

    list.sort((a, b) {
      if (_sortOption == 'date_asc') return a.date.compareTo(b.date);
      if (_sortOption == 'amount_desc') return b.amount.compareTo(a.amount);
      if (_sortOption == 'amount_asc') return a.amount.compareTo(b.amount);
      return b.date.compareTo(a.date);
    });
    return list;
  }

  double get _periodIncome => _periodTransactions
      .where((tx) => !tx.isExpense)
      .fold(0.0, (s, tx) => s + tx.amount);

  double get _periodExpense => _periodTransactions
      .where((tx) => tx.countsAsSpending)
      .fold(0.0, (s, tx) => s + tx.amount);

  void _shiftPeriod(int dir) {
    _showPeriodOf(switch (_period) {
      LedgerPeriod.week => _selectedDate.add(Duration(days: 7 * dir)),
      LedgerPeriod.month => DateTime(
        _selectedDate.year,
        _selectedDate.month + dir,
        1,
      ),
      LedgerPeriod.year => DateTime(
        _selectedDate.year + dir,
        _selectedDate.month,
        1,
      ),
    });
  }

  /// Moves the page to the week, month or year (whichever is on screen) that contains [day].
  void _showPeriodOf(DateTime day) {
    if (!mounted) return;
    setState(() {
      _selectedDate = day;
      _refreshBudgetProgress();
    });
  }

  /// The add form tells the date of what it saved: the page moves to its period, so the new transaction is in sight.
  void _openAddTransaction() {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionPage(onSaved: _showPeriodOf),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final semantic = theme.semanticColors;
    final loc = context.loc;
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: loc.ledgerSearchHint,
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : Text(
                loc.ledgerTitle,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                }),
              )
            : IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () => setState(() => _isSearching = true),
              ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: (!_showExpenses || !_showIncome)
                  ? colors.primary
                  : colors.onSurfaceVariant,
            ),
            onPressed: _showTypePicker,
          ),
          IconButton(
            icon: Icon(Icons.add_box_rounded, color: colors.primary),
            onPressed: _openAddTransaction,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  if (_transactionsFailed)
                    _buildLoadFailedNotice(colors, semantic),
                  _buildDateStepper(colors),
                  const SizedBox(height: 16),
                  _buildPeriodHeader(colors),
                  const SizedBox(height: 16),
                  _buildChartCard(colors, semantic),
                  const SizedBox(height: 16),
                  _buildStatCards(colors, semantic),
                  const SizedBox(height: 24),
                  _buildRecentList(colors, semantic),
                  const SizedBox(height: 24),
                  _buildSummaryBlock(colors, semantic),
                ],
              ),
            ),
    );
  }

  Widget _buildDateStepper(ColorScheme colors) {
    return Center(
      child: InkWell(
        onTap: _pickFullDate,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softShadowFor(colors),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.loc.ledgerCalendar,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('dd/MM/yyyy').format(_selectedDate),
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _wdShort(DateTime d, AppLocalizations loc) {
    final w = [
      loc.weekdayShortMon,
      loc.weekdayShortTue,
      loc.weekdayShortWed,
      loc.weekdayShortThu,
      loc.weekdayShortFri,
      loc.weekdayShortSat,
      loc.weekdayShortSun,
    ];
    return w[d.weekday - 1];
  }

  Future<void> _pickFullDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final monthChanged =
        picked.month != _selectedDate.month ||
        picked.year != _selectedDate.year;
    setState(() {
      _selectedDate = picked;
      _refreshBudgetProgress();
    });
    if (monthChanged) _load();
  }

  Widget _circleBtn(ColorScheme colors, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          boxShadow: AppTheme.softShadowFor(colors),
        ),
        child: Icon(icon, size: 20, color: colors.onSurface),
      ),
    );
  }

  Widget _buildPeriodHeader(ColorScheme colors) {
    final loc = context.loc;
    return Row(
      children: [
        _circleBtn(colors, Icons.chevron_left_rounded, () => _shiftPeriod(-1)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _periodLabel(loc),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!_showsToday)
                TextButton.icon(
                  key: const ValueKey('ledger-today'),
                  onPressed: () => _showPeriodOf(DateTime.now()),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Icon(Icons.today_rounded, size: 16),
                  label: Text(loc.dateFieldToday),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _circleBtn(colors, Icons.chevron_right_rounded, () => _shiftPeriod(1)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          // The menu itself opens on the canvas colour of the theme, its surface.
          child: DropdownButtonHideUnderline(
            child: DropdownButton<LedgerPeriod>(
              value: _period,
              isDense: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colors.onPrimaryContainer,
                size: 18,
              ),
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              items: [
                DropdownMenuItem(
                  value: LedgerPeriod.week,
                  child: Text(loc.budgetPeriodWeek),
                ),
                DropdownMenuItem(
                  value: LedgerPeriod.month,
                  child: Text(loc.budgetPeriodMonth),
                ),
                DropdownMenuItem(
                  value: LedgerPeriod.year,
                  child: Text(loc.budgetPeriodYear),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _period = v;
                    _refreshBudgetProgress();
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard(ColorScheme colors, SemanticColors semantic) {
    final loc = context.loc;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: AppTheme.cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _legendDot(colors, semantic.incomeColor, loc.ledgerLegendIncome),
              const SizedBox(width: 16),
              _legendDot(
                colors,
                semantic.expenseColor,
                loc.ledgerLegendExpense,
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: SizedBox(
              key: ValueKey(
                '${_period.name}_${_selectedDate.month}_${_selectedDate.year}',
              ),
              height: 180,
              child: _buildBarChart(colors, semantic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(ColorScheme colors, SemanticColors semantic) {
    final List<double> income = [];
    final List<double> expense = [];
    final List<String> labels = [];
    final loc = context.loc;

    if (_period == LedgerPeriod.week) {
      for (int i = 0; i < 7; i++) {
        final day = _weekStart.add(Duration(days: i));
        income.add(_sumOn(day, false, isDay: true));
        expense.add(_sumOn(day, true, isDay: true));
        labels.add(_wdShort(day, loc));
      }
    } else {
      // A month shows it and the 5 before it; a year shows its 12 months.
      final months = _period == LedgerPeriod.year
          ? [
              for (var month = 1; month <= _monthsPerYear; month++)
                DateTime(_selectedDate.year, month),
            ]
          : [
              for (var i = _monthsBeforeSelected; i >= 0; i--)
                DateTime(_selectedDate.year, _selectedDate.month - i),
            ];
      for (final m in months) {
        income.add(_sumOn(m, false, isDay: false));
        expense.add(_sumOn(m, true, isDay: false));
        labels.add(loc.ledgerChartMonth('${m.month}'));
      }
    }
    // 12 groups must fit a phone: narrower bars and labels for the year.
    final isYear = _period == LedgerPeriod.year;
    final barWidth = isYear ? 4.0 : 7.0;
    final barsSpace = isYear ? 2.0 : 4.0;

    double maxV = 1;
    for (final v in [...income, ...expense]) {
      if (v > maxV) maxV = v;
    }
    // The bars keep the income and expense colours; the grid and the labels are theme text colours.
    final gridLine = FlLine(
      color: colors.onSurfaceVariant.withValues(alpha: 0.15),
      strokeWidth: 1,
    );
    final labelStyle = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: isYear ? 9 : 11,
    );

    return BarChart(
      BarChartData(
        maxY: maxV * 1.2,
        barTouchData: BarTouchData(enabled: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxV / 2,
          getDrawingHorizontalLine: (v) => gridLine,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[i],
                    style: labelStyle,
                    maxLines: 1,
                    softWrap: false,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(
          labels.length,
          (i) => BarChartGroupData(
            x: i,
            barsSpace: barsSpace,
            barRods: [
              BarChartRodData(
                toY: income[i],
                color: semantic.incomeColor,
                width: barWidth,
                borderRadius: BorderRadius.circular(4),
              ),
              BarChartRodData(
                toY: expense[i],
                color: semantic.expenseColor,
                width: barWidth,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _sumOn(DateTime ref, bool expense, {required bool isDay}) {
    return _transactions
        .where((t) {
          if (expense ? !t.countsAsSpending : t.isExpense) return false;
          if (isDay) return DateUtils.isSameDay(t.date, ref);
          return t.date.year == ref.year && t.date.month == ref.month;
        })
        .fold(0.0, (s, t) => s + t.amount);
  }

  Widget _buildStatCards(ColorScheme colors, SemanticColors semantic) {
    final loc = context.loc;
    return Row(
      children: [
        Expanded(
          child: _statCard(
            colors,
            icon: Icons.south_west_rounded,
            label: loc.ledgerIncome,
            amount: _periodIncome,
            color: semantic.incomeColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            colors,
            icon: Icons.north_east_rounded,
            label: loc.ledgerExpense,
            amount: _periodExpense,
            color: semantic.expenseColor,
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    ColorScheme colors, {
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(amount, context.loc),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(ColorScheme colors, Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRecentList(ColorScheme colors, SemanticColors semantic) {
    final txs = _periodTransactions;
    final loc = context.loc;
    // Made once for the whole list rather than once per row.
    final card = AppTheme.cardDecoration(colors);
    final detailStyle = TextStyle(color: colors.onSurfaceVariant, fontSize: 12);
    final expenseStyle = TextStyle(
      color: semantic.expenseColor,
      fontWeight: FontWeight.bold,
    );
    final incomeStyle = TextStyle(
      color: semantic.incomeColor,
      fontWeight: FontWeight.bold,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.ledgerRecent,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        if (txs.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: card,
            child: Text(
              loc.ledgerEmptyPeriod,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          )
        else
          ...txs.map(
            (tx) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: card,
                child: InkWell(
                  onTap: () => _showTransactionDetails(tx),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: tx.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(tx.icon, color: tx.color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${TransactionCategories.displayName(loc, tx.category)} • ${DateFormat('dd/MM HH:mm').format(tx.date)}',
                              style: detailStyle,
                            ),
                            if (tx.receiptStatus != null) ...[
                              const SizedBox(height: 4),
                              ReceiptStatusBadge(status: tx.receiptStatus!),
                            ],
                            if (tx.isUnsynced) ...[
                              const SizedBox(height: 4),
                              SyncStatusBadge(status: tx.syncStatus),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        '${tx.isExpense ? "- " : "+ "}${_money(tx.amount, loc)}',
                        style: tx.isExpense ? expenseStyle : incomeStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryBlock(ColorScheme colors, SemanticColors semantic) {
    final balance = _periodIncome - _periodExpense;
    final loc = context.loc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BudgetSection(progresses: _budgetProgress, loadFailed: _budgetsFailed),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              loc.commonSummary,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            TextButton.icon(
              onPressed: _exportToExcel,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Excel'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(colors),
          child: Column(
            children: [
              _summaryRow(
                colors,
                loc.ledgerTotalIncome,
                _periodIncome,
                semantic.incomeColor,
              ),
              const SizedBox(height: 8),
              _summaryRow(
                colors,
                loc.ledgerTotalExpense,
                _periodExpense,
                semantic.expenseColor,
              ),
              const Divider(height: 24),
              _summaryRow(
                colors,
                loc.ledgerBalance,
                balance,
                balance >= 0 ? semantic.incomeColor : semantic.expenseColor,
                bold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(
    ColorScheme colors,
    String label,
    double amount,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: bold ? colors.onSurface : colors.onSurfaceVariant,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          _money(amount, context.loc),
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showTypePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final sectionStyle = TextStyle(
          color: Theme.of(ctx).colorScheme.primary,
          fontWeight: FontWeight.bold,
        );
        final loc = ctx.loc;
        return StatefulBuilder(
          builder: (ctx, setModalState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.ledgerFilterTitle,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  Text(loc.ledgerFilterType, style: sectionStyle),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(loc.ledgerFilterAll),
                        selected: _showExpenses && _showIncome,
                        onSelected: (_) => setModalState(() {
                          _showExpenses = true;
                          _showIncome = true;
                        }),
                      ),
                      ChoiceChip(
                        label: Text(loc.ledgerFilterExpenseOnly),
                        selected: _showExpenses && !_showIncome,
                        onSelected: (_) => setModalState(() {
                          _showExpenses = true;
                          _showIncome = false;
                        }),
                      ),
                      ChoiceChip(
                        label: Text(loc.ledgerFilterIncomeOnly),
                        selected: !_showExpenses && _showIncome,
                        onSelected: (_) => setModalState(() {
                          _showExpenses = false;
                          _showIncome = true;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(loc.ledgerFilterAmount, style: sectionStyle),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(loc.ledgerFilterAnyAmount),
                        selected:
                            _filterMaxAmount == null &&
                            _filterMinAmount == null,
                        onSelected: (_) => setModalState(() {
                          _filterMinAmount = null;
                          _filterMaxAmount = null;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('< 100k'),
                        selected: _filterMaxAmount == 100000,
                        onSelected: (_) => setModalState(() {
                          _filterMinAmount = null;
                          _filterMaxAmount = 100000;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('100k - 500k'),
                        selected:
                            _filterMinAmount == 100000 &&
                            _filterMaxAmount == 500000,
                        onSelected: (_) => setModalState(() {
                          _filterMinAmount = 100000;
                          _filterMaxAmount = 500000;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('> 500k'),
                        selected:
                            _filterMinAmount == 500000 &&
                            _filterMaxAmount == null,
                        onSelected: (_) => setModalState(() {
                          _filterMinAmount = 500000;
                          _filterMaxAmount = null;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(loc.ledgerFilterSort, style: sectionStyle),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(loc.ledgerSortNewest),
                        selected: _sortOption == 'date_desc',
                        onSelected: (_) =>
                            setModalState(() => _sortOption = 'date_desc'),
                      ),
                      ChoiceChip(
                        label: Text(loc.ledgerSortOldest),
                        selected: _sortOption == 'date_asc',
                        onSelected: (_) =>
                            setModalState(() => _sortOption = 'date_asc'),
                      ),
                      ChoiceChip(
                        label: Text(loc.ledgerSortHighest),
                        selected: _sortOption == 'amount_desc',
                        onSelected: (_) =>
                            setModalState(() => _sortOption = 'amount_desc'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        loc.ledgerFilterApply,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTransactionDetails(TransactionModel tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colors = theme.colorScheme;
        final semantic = theme.semanticColors;
        final labelStyle = TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 15,
        );
        final loc = ctx.loc;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tx.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(tx.icon, color: tx.color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              TransactionCategories.displayName(
                                loc,
                                tx.category,
                              ),
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildDetailRow(
                    labelStyle,
                    loc.ledgerDetailAmount,
                    '${tx.isExpense ? "-" : "+"}${_money(tx.amount, loc)}',
                    tx.isExpense ? semantic.expenseColor : semantic.incomeColor,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    labelStyle,
                    loc.ledgerDetailTime,
                    DateFormat('dd/MM/yyyy - HH:mm').format(tx.date),
                    colors.onSurface,
                  ),
                  if (tx.receiptStatus != null) ...[
                    const SizedBox(height: 12),
                    // A Wrap, not a Row: on a narrow screen or with a large font the badge drops to its own line instead of
                    // overflowing. The full-width box keeps the label left and the badge right while both fit on one line.
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(
                            loc.ledgerDetailReceiptStatus,
                            style: labelStyle,
                          ),
                          ReceiptStatusBadge(status: tx.receiptStatus!),
                        ],
                      ),
                    ),
                  ],
                  if (tx.isUnsynced) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(loc.ledgerDetailSync, style: labelStyle),
                          SyncStatusBadge(status: tx.syncStatus),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.ledgerDetailUnsyncedHint,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (tx.imageUrl != null && tx.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      loc.ledgerDetailReceiptImage,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              backgroundColor: Colors.black,
                              appBar: AppBar(
                                backgroundColor: Colors.black,
                                iconTheme: const IconThemeData(
                                  color: Colors.white,
                                ),
                              ),
                              body: Center(
                                child: InteractiveViewer(
                                  child: Image.network(tx.imageUrl!),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: colors.surface,
                          width: double.infinity,
                          height: 200,
                          child: Image.network(
                            tx.imageUrl!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  // The server has no copy of an unsynced transaction, so the only thing to do with it is to send it again.
                  if (tx.isUnsynced) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.cloud_upload_rounded),
                        label: Text(
                          loc.ledgerResend,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _resendTransactionAction(tx);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Editing goes through the server, so only a transaction it already has can be edited.
                  if (tx.id != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit_rounded),
                        label: Text(
                          loc.editTransactionTitle,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _editTransactionAction(tx);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.error.withValues(alpha: 0.1),
                        foregroundColor: colors.error,
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.delete_rounded),
                      label: Text(
                        loc.ledgerDelete,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (tx.isUnsynced) {
                          _deleteUnsyncedAction(tx);
                        } else {
                          _deleteTransactionAction(tx.id!);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    TextStyle labelStyle,
    String label,
    String value,
    Color valColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text(
          value,
          style: TextStyle(
            color: valColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _editTransactionAction(TransactionModel tx) async {
    if (!mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditTransactionPage(transaction: tx)),
    );
  }

  Future<void> _deleteTransactionAction(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        final loc = ctx.loc;
        return AlertDialog(
          title: Text(
            loc.ledgerDeleteTitle,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            loc.ledgerDeleteMessage,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                loc.dialogCancel,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: colors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                loc.ledgerDeleteNow,
                style: TextStyle(
                  color: colors.onError,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final success = await RemoteApiHelper.instance.deleteTransaction(id);
    if (!mounted) return;
    final loc = context.loc;
    // Deleted on the server for good (there is no restore endpoint), so the toast offers no undo.
    if (success) {
      AppToast.success(context, loc.ledgerDeleted);
    } else {
      AppToast.error(context, loc.ledgerDeleteFailed);
    }
  }

  /// Sends a transaction that the server has not confirmed again. It carries the clientId it was created with, so when
  /// the first send did arrive the server answers with that transaction instead of creating a second one.
  Future<void> _resendTransactionAction(TransactionModel tx) async {
    if (!mounted) return;
    final loc = context.loc;
    final userId = SessionService.currentUserId;
    if (userId == null) {
      await AppDialog.error(
        context,
        title: loc.commonSessionExpiredTitle,
        message: loc.accountInfoSignInAgain,
      );
      return;
    }
    final clientId = tx.clientId;
    if (clientId == null || !_resendingClientIds.add(clientId)) return;

    SyncStatus? outcome;
    String? failure;
    try {
      outcome = await AppRepository.instance.resendTransaction(userId, tx);
    } on TransactionRefusedException catch (e) {
      failure = e.messageFor(loc);
    } catch (e) {
      debugPrint('Lỗi gửi lại giao dịch: $e');
      failure = loc.ledgerResendFailedMessage;
    } finally {
      _resendingClientIds.remove(clientId);
    }
    if (!mounted) return;

    if (failure != null) {
      await AppDialog.error(
        context,
        title: loc.ledgerResendFailedTitle,
        message: failure,
      );
    } else if (outcome == SyncStatus.synced) {
      AppToast.success(context, loc.ledgerResent);
    } else {
      await AppDialog.warning(
        context,
        title: loc.ledgerStillNotSentTitle,
        message: loc.ledgerStillNotSentMessage,
      );
    }
  }

  /// Removes a transaction that the server never confirmed from the device only: there is nothing on the server to
  /// delete, and its local row number is not a server id.
  Future<void> _deleteUnsyncedAction(TransactionModel tx) async {
    if (!mounted) return;
    final userId = SessionService.currentUserId;
    final clientId = tx.clientId;
    if (userId == null || clientId == null) return;

    final loc = context.loc;
    final confirmed = await AppDialog.confirm(
      context,
      title: loc.ledgerDeleteUnsyncedTitle,
      message: loc.ledgerDeleteUnsyncedMessage,
      confirmText: loc.ledgerDeleteNow,
      danger: true,
    );
    if (!confirmed || !mounted) return;

    await AppRepository.instance.deleteUnsyncedTransaction(userId, clientId);
    if (!mounted) return;
    AppToast.success(context, context.loc.ledgerDeletedUnsynced);
  }

  Widget _buildLoadFailedNotice(ColorScheme colors, SemanticColors semantic) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: semantic.warningColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: semantic.warningColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.loc.ledgerLoadFailedNotice,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    final loc = context.loc;
    final monthName = _monthLabel(loc);

    var excel = Excel.createExcel();
    var sheet = excel[loc.ledgerExcelSheet(monthName)];

    sheet.appendRow([
      TextCellValue(loc.ledgerExcelDate),
      TextCellValue(loc.transactionCategoryLabel),
      TextCellValue(loc.transactionExpenseMoney),
      TextCellValue(loc.transactionIncomeMoney),
    ]);

    double totalExpense = 0;
    double totalIncome = 0;

    final monthTxs = _transactions
        .where(
          (tx) =>
              tx.date.year == _selectedDate.year &&
              tx.date.month == _selectedDate.month,
        )
        .toList();

    for (var tx in monthTxs) {
      final dateStr = DateFormat('dd/MM/yyyy').format(tx.date);
      if (tx.isExpense) {
        if (tx.countsAsSpending) totalExpense += tx.amount;
        sheet.appendRow([
          TextCellValue(dateStr),
          TextCellValue(TransactionCategories.displayName(loc, tx.category)),
          DoubleCellValue(tx.amount),
          TextCellValue(''),
        ]);
      } else {
        totalIncome += tx.amount;
        sheet.appendRow([
          TextCellValue(dateStr),
          TextCellValue(TransactionCategories.displayName(loc, tx.category)),
          TextCellValue(''),
          DoubleCellValue(tx.amount),
        ]);
      }
    }

    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue(loc.ledgerExcelTotal),
      TextCellValue(''),
      DoubleCellValue(totalExpense),
      DoubleCellValue(totalIncome),
    ]);
    sheet.appendRow([
      TextCellValue(loc.ledgerBalance),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalIncome - totalExpense),
    ]);

    sheet.appendRow([]);
    sheet.appendRow([TextCellValue(loc.ledgerExcelBudgetHeader(monthName))]);
    sheet.appendRow([
      TextCellValue(loc.transactionCategoryLabel),
      TextCellValue(loc.ledgerExcelLimit),
      TextCellValue(loc.ledgerExcelSpent),
      TextCellValue(loc.ledgerExcelRemaining),
    ]);

    final monthStart = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final monthEnd = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    for (final progress in BudgetProgress.overlapping(
      monthStart,
      monthEnd,
      _budgets,
      _transactions,
    )) {
      sheet.appendRow([
        TextCellValue(progress.budget.categoryLabel(loc)),
        DoubleCellValue(progress.limit),
        DoubleCellValue(progress.spent),
        DoubleCellValue(progress.remaining),
      ]);
    }

    final directory = Directory.systemTemp;
    final fileName =
        '${loc.ledgerExcelFileName(monthName, DateFormat('ddMMyyyy').format(DateTime.now()))}.xlsx';
    final file = File('${directory.path}/$fileName');
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          fileNameOverrides: [fileName],
          subject: loc.ledgerExcelSheet(monthName),
          text: loc.ledgerExcelShareText(monthName),
        ),
      );
    }
  }
}
