import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/budget_overview.dart';
import 'package:finance_ai_app/models/budget_progress.dart';
import 'package:finance_ai_app/models/transaction_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/budget/budget_form_sheet.dart';
import 'package:finance_ai_app/screens/budget/widgets/budget_band_summary.dart';
import 'package:finance_ai_app/screens/budget/widgets/budget_group_card.dart';
import 'package:finance_ai_app/screens/budget/widgets/budget_period_tabs.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';

const int _httpUnauthorized = 401;
const int _httpForbidden = 403;

/// The spending limits of the user that run today (T9 spec, 3.5): Tuần / Tháng / Năm tabs and the total in the blue
/// band, then the exceeded budgets and the others in two cards. Tap a budget to edit it, swipe it left to delete it.
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  static const Key bandKey = ValueKey('budget-band');
  static const Key addKey = ValueKey('budget-add');
  static const Key backKey = ValueKey('budget-back');

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  static const double _gutter = 16;
  static const double _addButtonSize = 36;
  static const double _sheetRadius = 24;
  static const double _bottomPadding = 32;
  static const double _groupGap = 12;

  List<BudgetModel> _budgets = [];
  List<TransactionModel> _transactions = [];
  String? _period;
  bool _isLoading = true;

  /// The message of the last failed load; null once a load succeeds.
  String? _loadError;

  String get _currentPeriod => _period ?? BudgetPeriodType.month;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  /// A missing or refused login (401 or 403) means the session is over; anything else as [UserFacingError] words it.
  static String _messageOf(Object error, AppLocalizations loc) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == _httpUnauthorized || status == _httpForbidden) {
        return loc.errorSessionExpired;
      }
    }
    return UserFacingError.messageOf(error, loc);
  }

  Future<void> _load() async {
    final userId = SessionService.currentUserId;
    if (userId == null) {
      setState(() => _isLoading = false);
      // Not awaited: a pull to refresh must not keep its spinner turning until the dialog is closed.
      unawaited(_showSessionExpired());
      return;
    }
    if (_loadError != null) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    final List<BudgetModel> budgets;
    final List<TransactionModel> transactions;
    try {
      // Started together: the spending of each budget needs both. The first error is the one reported.
      final results = await Future.wait<Object>([
        AppRepository.instance.getBudgets(userId),
        AppRepository.instance.getTransactions(userId),
      ]);
      budgets = results[0] as List<BudgetModel>;
      transactions = results[1] as List<TransactionModel>;
    } catch (e) {
      debugPrint('Lỗi tải ngân sách: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = _messageOf(e, context.loc);
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _budgets = budgets;
      _transactions = transactions;
      _period ??= BudgetOverview.initialPeriod(budgets, DateTime.now());
      _isLoading = false;
    });
  }

  Future<void> _showSessionExpired() {
    return AppDialog.error(
      context,
      title: context.loc.commonSessionExpiredTitle,
      message: context.loc.accountInfoSignInAgain,
    );
  }

  Future<void> _openForm([BudgetModel? budget]) async {
    final userId = SessionService.currentUserId;
    if (userId == null) {
      await _showSessionExpired();
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
      ),
      builder: (_) => BudgetFormSheet(
        budget: budget,
        initialPeriodType: _currentPeriod,
        history: _transactions,
        loadCategories: () =>
            AppRepository.instance.getExpenseCategories(userId),
        onSubmit: (edited) => _submit(userId, edited),
      ),
    );
    if (saved != true || !mounted) return;
    await _load();
  }

  Future<String?> _submit(int userId, BudgetModel budget) async {
    // Read before the request: the sheet may be gone when it ends.
    final loc = context.loc;
    try {
      await AppRepository.instance.saveBudget(userId, budget);
      return null;
    } catch (e) {
      debugPrint('Lỗi lưu ngân sách: $e');
      return _messageOf(e, loc);
    }
  }

  /// Asks, then deletes; true once the budget is gone, so that its row leaves the list.
  Future<bool> _delete(BudgetProgress progress) async {
    final budget = progress.budget;
    final budgetId = budget.id;
    if (budgetId == null) return false;
    final loc = context.loc;
    final confirmed = await AppDialog.confirm(
      context,
      title: loc.budgetDeleteTitle,
      message: loc.budgetDeleteMessage(budget.categoryLabel(loc)),
      confirmText: loc.commonDelete,
      danger: true,
    );
    if (!confirmed || !mounted) return false;

    try {
      await AppRepository.instance.deleteBudget(budgetId);
    } catch (e) {
      debugPrint('Lỗi xóa ngân sách: $e');
      if (!mounted) return false;
      await AppDialog.error(
        context,
        title: context.loc.budgetDeleteFailedTitle,
        message: _messageOf(e, context.loc),
      );
      return false;
    }
    if (!mounted) return false;
    setState(() => _budgets = _budgets.where((b) => b.id != budgetId).toList());
    await AppDialog.success(context, title: context.loc.budgetDeleted);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final overview = BudgetOverview.of(
      budgets: _budgets,
      transactions: _transactions,
      periodType: _currentPeriod,
      today: DateTime.now(),
    );
    final total = overview.total;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            PageBand(
              key: BudgetScreen.bandKey,
              buttonKey: BudgetScreen.backKey,
              title: loc.budgetTitle,
              trailing: _AddButton(
                size: _addButtonSize,
                tooltip: loc.budgetCreate,
                onPressed: () => _openForm(),
              ),
              bottom: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BudgetPeriodTabs(
                    selected: _currentPeriod,
                    onChanged: (type) => setState(() => _period = type),
                  ),
                  if (!_isLoading && _loadError == null && total != null) ...[
                    const SizedBox(height: _groupGap),
                    BudgetBandSummary(summary: total),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _gutter,
                _gutter,
                _gutter,
                _bottomPadding,
              ),
              child: _buildBody(loc, overview),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations loc, BudgetOverview overview) {
    if (_isLoading) return const AppStateView.loading();
    final error = _loadError;
    if (error != null) {
      return AppStateView.error(
        title: loc.budgetLoadFailedTitle,
        message: error,
        onRetry: _load,
      );
    }
    if (overview.isEmpty) {
      return AppStateView.empty(
        icon: Icons.track_changes_rounded,
        title: loc.budgetEmptyPeriod,
        message: loc.budgetEmptyHint,
        actionLabel: loc.budgetCreate,
        onAction: _openForm,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (overview.over.isNotEmpty)
          BudgetGroupCard(
            kind: BudgetGroupKind.over,
            items: overview.over,
            onTap: (progress) => _openForm(progress.budget),
            onDelete: _delete,
          ),
        if (overview.over.isNotEmpty && overview.within.isNotEmpty)
          const SizedBox(height: _groupGap),
        if (overview.within.isNotEmpty)
          BudgetGroupCard(
            kind: BudgetGroupKind.within,
            items: overview.within,
            onTap: (progress) => _openForm(progress.budget),
            onDelete: _delete,
          ),
      ],
    );
  }
}

/// The round white translucent "+" at the end of the band.
class _AddButton extends StatelessWidget {
  final double size;
  final String tooltip;
  final VoidCallback onPressed;

  const _AddButton({
    required this.size,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BandColors.tint,
      shape: const CircleBorder(),
      child: InkWell(
        key: BudgetScreen.addKey,
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox.square(
          dimension: size,
          child: Icon(
            Icons.add_rounded,
            color: BandColors.primary,
            semanticLabel: tooltip,
          ),
        ),
      ),
    );
  }
}
