import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/repositories/app_repository.dart';
import 'package:finance_ai_app/screens/budget/budget_form_sheet.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/primary_button.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';

const int _httpUnauthorized = 401;
const int _httpForbidden = 403;

/// Lists the spending limits of the user, stored in the backend, and lets them add, edit and delete them.
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<BudgetModel> _budgets = [];
  bool _isLoading = true;

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
      await _showSessionExpired();
      return;
    }
    final List<BudgetModel> budgets;
    try {
      budgets = await AppRepository.instance.getBudgets(userId);
    } catch (e) {
      debugPrint('Lỗi tải ngân sách: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      await AppDialog.error(
        context,
        title: context.loc.budgetLoadFailedTitle,
        message: _messageOf(e, context.loc),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _budgets = budgets;
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BudgetFormSheet(
        budget: budget,
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

  Future<void> _delete(BudgetModel budget) async {
    final budgetId = budget.id;
    if (budgetId == null) return;
    final loc = context.loc;
    final confirmed = await AppDialog.confirm(
      context,
      title: loc.budgetDeleteTitle,
      message: loc.budgetDeleteMessage(budget.categoryLabel(loc)),
      confirmText: loc.commonDelete,
      danger: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await AppRepository.instance.deleteBudget(budgetId);
    } catch (e) {
      debugPrint('Lỗi xóa ngân sách: $e');
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: context.loc.budgetDeleteFailedTitle,
        message: _messageOf(e, context.loc),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _budgets = _budgets.where((b) => b.id != budgetId).toList());
    await AppDialog.success(context, title: context.loc.budgetDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      // Transparent so that it shows the page colour; icons and title take the app bar theme.
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          context.loc.budgetTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: colors.primary),
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: _isLoading
          ? const _BudgetSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (_budgets.isEmpty)
                    _EmptyState(onCreate: _openForm)
                  else
                    for (final budget in _budgets)
                      _BudgetCard(
                        budget: budget,
                        onEdit: () => _openForm(budget),
                        onDelete: () => _delete(budget),
                      ),
                ],
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.pie_chart_outline_rounded,
            color: colors.onSurfaceVariant,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            loc.budgetEmpty,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            loc.budgetEmptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 20),
          PrimaryButton(text: loc.budgetCreate, onPressed: onCreate),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  static final DateFormat _displayDate = DateFormat('dd/MM/yyyy');

  final BudgetModel budget;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.budget,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final categoryName = budget.categoryName;
    final loc = context.loc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          decoration: AppTheme.cardDecoration(colors),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  categoryName == null
                      ? Icons.pie_chart_rounded
                      : TransactionCategories.iconFor(categoryName),
                  color: colors.onPrimaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.categoryLabel(loc),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${BudgetPeriodType.label(loc, budget.periodType)} · '
                      '${_displayDate.format(budget.start)} – ${_displayDate.format(budget.end)}',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyHelper.formatVND(budget.amount, loc, showSign: false),
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.error,
                  size: 20,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three card-shaped placeholders that shimmer from the container colour of the theme to its surface.
class _BudgetSkeleton extends StatelessWidget {
  const _BudgetSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // The shimmer paints over the boxes, so their own colour only has to be opaque.
    final box = BoxDecoration(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
    );
    return Shimmer.fromColors(
      baseColor: colors.surfaceContainerHighest,
      highlightColor: colors.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(
          3,
          (_) => Container(
            height: 76,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: box,
          ),
        ),
      ),
    );
  }
}
