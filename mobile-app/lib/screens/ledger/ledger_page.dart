import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'dart:io';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/utils/ledger_excel_builder.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/utils/app_date_format.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/models/transaction_filter.dart';
import 'package:finance_ai_app/screens/ledger/widgets/day_grouped_list.dart';
import 'package:finance_ai_app/screens/ledger/widgets/stats_calendar_card.dart';
import 'package:finance_ai_app/screens/ledger/widgets/stats_category_card.dart';
import 'package:finance_ai_app/screens/ledger/widgets/stats_chart_card.dart';
import 'package:finance_ai_app/screens/ledger/widgets/stats_header_band.dart';
import 'package:finance_ai_app/screens/ledger/widgets/transaction_filter_sheet.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/common/pill_segmented.dart';
import 'package:finance_ai_app/widgets/inputs/date_picker_sheet.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/budget_progress.dart';
import 'package:finance_ai_app/models/ledger_stats.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/ledger/transaction_detail_page.dart';
import 'package:finance_ai_app/widgets/budget/budget_alert_presenter.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

import 'add_transaction_page.dart';

export 'package:finance_ai_app/models/ledger_stats.dart' show LedgerPeriod;

/// The three views of the statistics tab (T9 spec, 3.1).
enum StatsView { chart, calendar, categories }

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});

  @override
  State<LedgerPage> createState() => LedgerPageState();
}

class LedgerPageState extends State<LedgerPage> {
  /// The server is asked once the user has stopped typing for this long.
  static const Duration _searchDebounce = Duration(milliseconds: 350);

  /// A shorter text is only filtered on the device: the server rejects it.
  static const int _minServerQueryLength = 2;

  /// The years the date sheet offers.
  static const int _firstYear = 2020;
  static const int _lastYear = 2100;

  static const double _gutter = 16;

  /// Room under the list for the scan button of the tab bar.
  static const double _bottomSpace = 100;

  bool _isLoading = true;

  /// True when the list of the server could not be loaded: [_transactions] then holds only the transactions of this
  /// device that are waiting to be sent, which must stay reachable so that they can be resent.
  bool _transactionsFailed = false;
  List<TransactionModel> _transactions = [];

  /// Numbers the loads: a pull-to-refresh and a reload on dataChangedNotifier can overlap, only the latest one is shown.
  int _loadRequest = 0;
  List<BudgetModel> _budgets = [];

  /// Server id of a transaction asked for by [showTransaction] that is not in the list yet: shown when the load ends.
  int? _pendingTransactionId;

  DateTime _selectedDate = DateTime.now();
  LedgerPeriod _period = LedgerPeriod.month;

  StatsView _view = StatsView.chart;

  /// What the "Lọc" sheet chose; it narrows the transaction list only, never the totals.
  TransactionFilter _filter = TransactionFilter.none;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  /// Ids the server found for [_searchQuery] (accent-insensitive, typo-tolerant). They only add to what the device
  /// matches by itself, never hide it. Null when there is no answer for the current query (query too short, request
  /// not answered yet, server error): the list is then filtered on the device alone. While the user keeps typing it
  /// still holds the answer for the previous query, until the new one arrives.
  Set<int>? _serverMatchIds;
  Timer? _searchTimer;

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
    _searchTimer?.cancel();
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
        _refreshPeriod();
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
      _refreshPeriod();
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
    setState(() {
      _selectedDate = tx.date;
      _refreshPeriod();
    });
    unawaited(_openDetails(tx));
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

  String _periodLabel(AppLocalizations loc) {
    switch (_period) {
      case LedgerPeriod.week:
        final e = _weekEnd.subtract(const Duration(days: 1));
        return '${AppDateFormat.dayMonth.format(_weekStart)} - ${AppDateFormat.date.format(e)}';
      case LedgerPeriod.month:
        return loc.statsMonthLabel(
          '${_selectedDate.month}',
          '${_selectedDate.year}',
        );
      case LedgerPeriod.year:
        return loc.ledgerYearLabel('${_selectedDate.year}');
    }
  }

  /// Every transaction of the period on screen: what the totals, the calendar and the categories measure. Kept by
  /// [_refreshPeriod], not worked out again on every build.
  List<TransactionModel> _periodAll = [];

  /// The income and the spending of [_periodAll].
  DayTotals _periodTotals = const DayTotals(income: 0, expense: 0);

  /// Works out [_periodAll] and [_periodTotals] again. To be called, inside setState, by everything that changes
  /// [_transactions], [_period] or [_selectedDate].
  void _refreshPeriod() {
    _periodAll = _transactions
        .where((tx) => _inSelectedPeriod(tx.date))
        .toList();
    _periodTotals = LedgerStats.totals(_periodAll);
  }

  /// The transactions of the period that match the search box; the filter is applied on top of them.
  List<TransactionModel> get _searchMatches {
    final q = _searchQuery.toLowerCase().trim();
    if (q.isEmpty) return _periodAll;
    return _periodAll.where((tx) {
      final localMatch =
          tx.title.toLowerCase().contains(q) ||
          tx.category.toLowerCase().contains(q) ||
          (tx.reviewNote?.toLowerCase().contains(q) ?? false);
      // The server only adds matches the device cannot find (no accents, typos); its ids are cleared as soon as the text
      // changes, so a row that matched the previous text is not shown under the new one. A transaction not sent yet is not
      // in the server index: only the device can match it. The id is text on the device, a number on the server.
      final serverId = tx.id == null ? null : int.tryParse(tx.id!);
      return localMatch || (_serverMatchIds?.contains(serverId) ?? false);
    }).toList();
  }

  /// The listed transactions: the search matches through the filter, and in the calendar only those of the chosen day.
  List<TransactionModel> get _listed => _filter.apply(_listSource);

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    final query = value.trim();
    setState(() {
      _searchQuery = value;
      // The ids belong to the previous text: until the answer for this one arrives only the device matches.
      _serverMatchIds = null;
    });
    if (query.length < _minServerQueryLength) return;
    _searchTimer = Timer(_searchDebounce, () => _searchOnServer(query));
  }

  Future<void> _searchOnServer(String query) async {
    final ids = await AppRepository.instance.searchTransactionIds(query);
    // The user kept typing or closed the search while the request was on its way: this answer is outdated.
    if (!mounted || query != _searchQuery.trim()) return;
    setState(() => _serverMatchIds = ids?.toSet());
  }

  void _closeSearch() {
    _searchTimer?.cancel();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _serverMatchIds = null;
      _searchController.clear();
    });
  }

  void _shiftPeriod(int dir) {
    _showPeriodOf(switch (_period) {
      LedgerPeriod.week => _selectedDate.add(Duration(days: 7 * dir)),
      LedgerPeriod.month => _dayShownIn(
        DateTime(_selectedDate.year, _selectedDate.month + dir, 1),
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
      _refreshPeriod();
    });
  }

  /// The day the calendar selects in the month of [firstDay]: today in the current month, else the first day.
  static DateTime _dayShownIn(DateTime firstDay) {
    final today = DateTime.now();
    return today.year == firstDay.year && today.month == firstDay.month
        ? DateTime(today.year, today.month, today.day)
        : firstDay;
  }

  /// The calendar shows a month: picking a week or a year leaves it for the chart.
  void _setPeriod(LedgerPeriod period) {
    setState(() {
      _period = period;
      if (period != LedgerPeriod.month && _view == StatsView.calendar) {
        _view = StatsView.chart;
      }
      _refreshPeriod();
    });
  }

  /// Opening the calendar from a week or a year moves the period to the month (T9 spec, 3.1); the selected day stays,
  /// and it is today until the user moves away.
  void _setView(StatsView view) {
    setState(() {
      _view = view;
      if (view == StatsView.calendar) {
        _period = LedgerPeriod.month;
        _refreshPeriod();
      }
    });
  }

  /// The period label opens the date sheet: the page moves to the period of the picked day.
  Future<void> _pickDate() async {
    final picked = await showDatePickerSheet(
      context,
      initial: _selectedDate,
      firstDate: DateTime(_firstYear),
      lastDate: DateTime(_lastYear, 12, 31),
      title: context.loc.statsPickDate,
    );
    if (picked != null) _showPeriodOf(picked);
  }

  /// The search matches the list draws from: in the calendar, those of the chosen day.
  List<TransactionModel> get _listSource {
    final matches = _searchMatches;
    if (_view != StatsView.calendar) return matches;
    return matches
        .where((tx) => DateUtils.isSameDay(tx.date, _selectedDate))
        .toList();
  }

  /// The categories measure the whole period: a filter or a search changes nothing there, which a line under them says.
  bool get _narrowsList => _filter.isActive || _searchQuery.trim().isNotEmpty;

  Future<void> _openFilter() async {
    // "Xem n giao dịch" counts what the list will show.
    final matches = _listSource;
    final picked = await showTransactionFilterSheet(
      context,
      initial: _filter,
      countFor: (draft) => draft.apply(matches).length,
    );
    if (picked == null || !mounted) return;
    setState(() => _filter = picked);
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: AppStateView.loading()));
    }
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: _bottomSpace),
          children: [
            StatsHeaderBand(
              periodLabel: _periodLabel(loc),
              period: _period,
              income: _periodTotals.income,
              expense: _periodTotals.expense,
              filterActive: _filter.isActive,
              searching: _isSearching,
              searchController: _searchController,
              onSearchOpen: () => setState(() => _isSearching = true),
              onSearchClose: _closeSearch,
              onSearchChanged: _onSearchChanged,
              onFilter: _openFilter,
              onExport: _exportToExcel,
              onPrevious: () => _shiftPeriod(-1),
              onNext: () => _shiftPeriod(1),
              onPickDate: _pickDate,
              onPeriodChanged: _setPeriod,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(_gutter, _gutter, _gutter, 0),
              child: PillSegmented<StatsView>(
                options: [
                  (StatsView.chart, loc.statsViewChart),
                  (StatsView.calendar, loc.statsViewCalendar),
                  (StatsView.categories, loc.statsViewCategories),
                ],
                selected: _view,
                onChanged: _setView,
              ),
            ),
            if (_transactionsFailed)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _gutter,
                  _gutter,
                  _gutter,
                  0,
                ),
                child: _buildLoadFailedNotice(colors, semantic),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(_gutter, 12, _gutter, 0),
              child: switch (_view) {
                StatsView.chart => StatsChartCard(
                  period: _period,
                  buckets: LedgerStats.chartBuckets(
                    _period,
                    _selectedDate,
                    _transactions,
                  ),
                ),
                StatsView.calendar => StatsCalendarCard(
                  month: _selectedDate,
                  selectedDay: _selectedDate,
                  today: DateTime.now(),
                  totals: LedgerStats.byDay(_periodAll),
                  onDaySelected: _showPeriodOf,
                ),
                StatsView.categories => StatsCategoryCard(
                  shares: LedgerStats.categoryShares(_periodAll),
                  periodLabel: _periodLabel(loc),
                ),
              },
            ),
            if (_view != StatsView.categories)
              Padding(
                padding: const EdgeInsets.fromLTRB(_gutter, 20, _gutter, 0),
                child: _buildList(loc),
              )
            else if (_narrowsList)
              Padding(
                padding: const EdgeInsets.fromLTRB(_gutter, 12, _gutter, 0),
                child: Text(
                  loc.statsCategoriesFilterHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: AppTextSize.secondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// A savings contribution on the server can be deleted only by a user who has no savings goal at all: such a row
  /// was typed by hand before goals existed (the server refuses the delete otherwise). When the goals cannot be read,
  /// the row stays locked.
  /// The transactions of the period (in the calendar, of the chosen day) through the search and the filter. Empty because
  /// of the filter or the search, it offers to reset them; empty for real, it offers to add a transaction.
  Widget _buildList(AppLocalizations loc) {
    final calendar = _view == StatsView.calendar;
    final listed = _listed;
    final hasAny = calendar
        ? _periodAll.any((tx) => DateUtils.isSameDay(tx.date, _selectedDate))
        : _periodAll.isNotEmpty;
    return DayGroupedList(
      transactions: listed,
      sort: _filter.sort,
      onOpen: _openDetails,
      title: calendar
          ? loc.statsTransactionsOfDay(
              AppDateFormat.dayMonth.format(_selectedDate),
            )
          : loc.statsTransactions,
      trailing: calendar
          ? TextButton(
              onPressed: _openAddTransaction,
              child: Text(loc.statsAdd),
            )
          : null,
      singleDaySummary: calendar,
      empty: hasAny
          ? AppStateView.empty(
              icon: Icons.filter_alt_off_outlined,
              title: loc.statsNoMatch,
              actionLabel: loc.filterReset,
              onAction: _resetFilter,
            )
          : AppStateView.empty(
              icon: Icons.receipt_long_outlined,
              title: loc.ledgerEmptyPeriod,
              actionLabel: loc.addTransactionTitle,
              onAction: _openAddTransaction,
            ),
    );
  }

  /// Puts the filter back to all / any / newest and closes the search.
  void _resetFilter() {
    _closeSearch();
    setState(() => _filter = TransactionFilter.none);
  }

  /// Shows [tx] on its own page; an edit, a delete or a resend there reloads the list.
  Future<void> _openDetails(TransactionModel tx) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TransactionDetailPage(transaction: tx)),
    );
    if (changed == true && mounted) _load();
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
              style: const TextStyle(fontSize: AppTextSize.secondary),
            ),
          ),
        ],
      ),
    );
  }

  /// The name for the file of the export; null when it cannot be had, the export then goes on without it.
  Future<String?> _currentUserName() async {
    final userId = SessionService.currentUserId;
    if (userId == null) return null;
    try {
      return (await AppRepository.instance.getCurrentUser(userId))?.fullName;
    } catch (e) {
      debugPrint('Không lấy được tên người dùng: $e');
      return null;
    }
  }

  Future<void> _exportToExcel() async {
    final loc = context.loc;
    try {
      final report = LedgerExcelBuilder.build(
        loc: loc,
        month: _selectedDate,
        transactions: _transactions,
        budgets: _budgets,
        userName: await _currentUserName(),
      );
      if (report == null) throw StateError('The workbook could not be encoded');

      final file = File('${Directory.systemTemp.path}/${report.fileName}');
      await file.writeAsBytes(report.bytes);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          fileNameOverrides: [report.fileName],
          subject: report.title,
          text: report.shareText,
        ),
      );
    } catch (e) {
      debugPrint('Lỗi xuất Excel: $e');
      if (!mounted) return;
      AppToast.error(context, loc.ledgerExcelFailed);
    }
  }
}
