import 'dart:async';

import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/budget_model.dart';
import 'package:finance_ai_app/models/budget_progress.dart';
import 'package:finance_ai_app/services/budget_alert_tracker.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';

/// Tells the user when a budget reaches 80% or 100% of its limit, in one AppDialog and only once per threshold.
///
/// Every screen that knows about budgets may call [showNew] whenever it (re)loads: the [BudgetAlertTracker] keeps the
/// alerts already shown from coming back, and the calls are queued so that two screens loading at the same moment
/// (the home screen and the ledger live side by side in the tab bar) never open two dialogs.
class BudgetAlertPresenter {
  /// The last call in the queue; null while nobody has asked yet.
  static Future<void>? _previous;

  /// Shows the alerts of [progresses] that were not shown before, as one dialog: an error when a budget is exceeded,
  /// otherwise a warning. Shows nothing when there is nothing new, or when [context] is gone by then; in that case the
  /// alerts are not marked as shown and stay for the next call. Never throws.
  static Future<void> showNew(
    BuildContext context, {
    required int userId,
    required Iterable<BudgetProgress> progresses,
    BudgetAlertTracker? tracker,
  }) async {
    final snapshot = progresses.toList();
    final before = _previous;
    final finished = Completer<void>();
    _previous = finished.future;
    try {
      if (before != null) await before;
      if (!context.mounted) return;
      await _show(
        context,
        userId,
        snapshot,
        tracker ?? BudgetAlertTracker.instance,
      );
    } catch (e) {
      debugPrint('Lỗi hiển thị cảnh báo ngân sách: $e');
    } finally {
      finished.complete();
    }
  }

  static Future<void> _show(
    BuildContext context,
    int userId,
    List<BudgetProgress> progresses,
    BudgetAlertTracker tracker,
  ) async {
    await tracker.ensureLoaded();
    if (!context.mounted) return;

    final alerts = tracker.pending(userId, progresses);
    if (alerts.isEmpty) return;
    // Marked before the dialog opens, so nothing that runs while it is open can announce the same alerts again.
    final saved = tracker.markShown(userId, alerts);

    alerts.sort((a, b) => b.level.index.compareTo(a.level.index));
    // The texts follow the language the app shows right now.
    final loc = context.locOrDefault;
    final message = alerts.map((alert) => _lineOf(alert, loc)).join('\n');
    if (alerts.first.level == BudgetAlertLevel.exceeded) {
      await AppDialog.error(
        context,
        title: loc.budgetAlertExceededTitle,
        message: message,
      );
    } else {
      await AppDialog.warning(
        context,
        title: loc.budgetAlertWarningTitle,
        message: message,
      );
    }
    await saved;
  }

  static String _lineOf(BudgetAlert alert, AppLocalizations loc) {
    final progress = alert.progress;
    final budget = progress.budget;
    final name = budget.categoryLabel(loc);
    final period = BudgetPeriodType.label(loc, budget.periodType).toLowerCase();
    final amounts =
        '${_money(loc, progress.spent)} / ${_money(loc, progress.limit)}';
    final percent = '${progress.percentLabel}';
    return switch (alert.level) {
      BudgetAlertLevel.exceeded => loc.budgetAlertExceededLine(
        name,
        period,
        amounts,
        percent,
      ),
      _ => loc.budgetAlertWarningLine(name, period, amounts, percent),
    };
  }

  static String _money(AppLocalizations loc, double amount) =>
      CurrencyHelper.formatVND(amount, loc, showSign: false);

  /// Forgets the queue, so a dialog left open by one test cannot hold back the next.
  @visibleForTesting
  static void resetQueue() => _previous = null;
}
