import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/models/savings_goal.dart';
import 'package:finance_ai_app/screens/savings/contribute_sheet.dart';
import 'package:finance_ai_app/screens/savings/savings_goal_form_page.dart';
import 'package:finance_ai_app/screens/savings/widgets/savings_goal_list.dart';
import 'package:finance_ai_app/screens/savings/widgets/savings_summary_card.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';
import 'package:finance_ai_app/widgets/common/app_state_view.dart';
import 'package:finance_ai_app/widgets/common/page_band.dart';
import 'package:finance_ai_app/widgets/common/pill_segmented.dart';
import 'package:finance_ai_app/widgets/dialogs/app_dialog.dart';
import 'package:finance_ai_app/widgets/feedback/app_toast.dart';

/// The savings goals of the user (T9 spec 3.6, mockup R9): the blue band with "+", the Đang thực hiện / Đã xong toggle,
/// the total card and the goals of the chosen tab. Tap an unfinished goal to add money to it, a reached one (or long
/// press any) to edit it; swipe left to delete it.
class SavingsPage extends StatefulWidget {
  const SavingsPage({super.key});

  static const Key bandKey = ValueKey('savings-band');
  static const Key addKey = ValueKey('savings-add');
  static const Key backKey = ValueKey('savings-back');

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  static const double _gutter = 16;
  static const double _gap = 12;
  static const double _bottomPadding = 32;
  static const double _addButtonSize = 36;
  static const double _sheetRadius = 24;

  List<SavingsGoal> _goals = [];
  bool _isLoading = true;
  bool _showDone = false;

  /// Numbers the loads, so that an older one answering last does not overwrite a newer list.
  int _request = 0;

  /// The message of the last failed load; null once a load succeeds.
  String? _loadError;

  String _money(double amount) =>
      CurrencyHelper.formatVND(amount, context.loc, showSign: false);

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final request = ++_request;
    if (_loadError != null) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final goals = await RemoteApiHelper.instance.fetchSavings();
      if (!mounted || request != _request) return;
      setState(() {
        _goals = goals;
        _isLoading = false;
      });
    } catch (e) {
      UserFacingError.log('Savings load', e);
      if (!mounted || request != _request) return;
      final loc = context.loc;
      final message = UserFacingError.messageOf(e, loc);
      // Goals already on screen stay there: only a first load (or an empty list) gives way to the error state.
      if (_goals.isNotEmpty) {
        setState(() => _isLoading = false);
        AppToast.error(context, loc.savingsReloadFailed(message));
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = message;
      });
    }
  }

  /// After a write on the server: the AI tab and this list read the savings again.
  void _afterWrite() {
    SessionService.needRefreshAI.value = true;
    _load();
  }

  /// Opens the form; [save] sends it and returns null or the message of the failure.
  Future<void> _openForm({
    SavingsGoal? goal,
    required Future<void> Function(
      String title,
      double target,
      String? deadline,
    )
    save,
    required String Function(String title) savedMessage,
  }) async {
    // A save that answers after the page was closed (back or close while it ran) reports itself.
    var closed = false;
    String? savedTitle;
    void reportSaved(String title) {
      if (!mounted) return;
      _afterWrite();
      AppToast.success(context, savedMessage(title));
    }

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SavingsGoalFormPage(
          goal: goal,
          onSubmit: ({required title, required target, deadline}) async {
            final loc = context.loc;
            try {
              await save(title, target, deadline);
              savedTitle = title;
              if (closed) reportSaved(title);
              return null;
            } catch (e) {
              UserFacingError.log('Savings save', e);
              return UserFacingError.messageOf(e, loc);
            }
          },
        ),
      ),
    );
    closed = true;
    final title = savedTitle;
    if (title != null) reportSaved(title);
  }

  void _create() => _openForm(
    save: (title, target, deadline) => RemoteApiHelper.instance.addSaving(
      title: title,
      target: target,
      deadline: deadline,
    ),
    savedMessage: context.loc.savingsCreated,
  );

  /// Edits the name, target and deadline; the saved amount only moves through contributions.
  void _edit(SavingsGoal goal) => _openForm(
    goal: goal,
    save: (title, target, deadline) => RemoteApiHelper.instance.updateSaving(
      goal.id,
      title: title,
      target: target,
      // Always sent: the server clears the deadline when it is missing.
      deadline: deadline,
    ),
    savedMessage: context.loc.savingsUpdated,
  );

  /// Opens the "Góp tiền" sheet of [goal]; once the money is moved, the list shows the goal as the server now has it and
  /// the user is told, with congratulations when the goal is reached.
  Future<void> _contribute(SavingsGoal goal) async {
    // A contribution that answers after the sheet was closed (drag, barrier or close while it ran) reports itself.
    var closed = false;
    SavingsGoal? moved;
    final popped = await showModalBottomSheet<SavingsGoal>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
      ),
      builder: (_) => ContributeSheet(
        goal: goal,
        today: _today,
        onSubmit: (amount) async {
          final result = await RemoteApiHelper.instance.contributeToSaving(
            goal.id,
            amount,
          );
          moved = result;
          if (closed) _reportContribution(goal, result);
          return result;
        },
        loadBalance: RemoteApiHelper.instance.fetchWalletBalance,
      ),
    );
    closed = true;
    final updated = popped ?? moved;
    if (updated != null) _reportContribution(goal, updated);
  }

  /// Shows [goal] as the server returned it after a contribution ([now]) and tells the user.
  void _reportContribution(SavingsGoal goal, SavingsGoal now) {
    if (!mounted) return;
    setState(() {
      _goals = [for (final g in _goals) g.id == goal.id ? now : g];
    });
    _afterWrite();

    final loc = context.loc;
    final title = now.title.isEmpty ? goal.title : now.title;
    AppToast.success(
      context,
      now.isDone
          ? loc.savingsGoalReached(title)
          : loc.savingsContributed(title),
    );
  }

  /// Asks, then deletes; true once the goal is gone, so its row leaves the list. A goal holding money says how much goes
  /// back to the wallet (the server refunds it).
  Future<bool> _delete(SavingsGoal goal) async {
    final loc = context.loc;
    final confirmed = await AppDialog.confirm(
      context,
      title: loc.savingsDeleteTitle,
      message: goal.current > 0
          ? loc.savingsDeleteConfirmRefund(_money(goal.current))
          : loc.savingsDeleteConfirm,
      confirmText: loc.commonDelete,
      danger: true,
    );
    if (!confirmed || !mounted) return false;
    try {
      await RemoteApiHelper.instance.deleteSaving(goal.id);
    } catch (e) {
      UserFacingError.log('Savings delete', e);
      if (!mounted) return false;
      AppToast.error(
        context,
        context.loc.savingsDeleteFailed(
          UserFacingError.messageOf(e, context.loc),
        ),
      );
      return false;
    }
    SessionService.needRefreshAI.value = true;
    if (!mounted) return true;
    setState(() => _goals = _goals.where((g) => g.id != goal.id).toList());
    final done = context.loc;
    AppToast.success(
      context,
      goal.current > 0
          ? done.savingsDeletedRefunded(goal.title, _money(goal.current))
          : done.savingsDeleted(goal.title),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            PageBand(
              key: SavingsPage.bandKey,
              buttonKey: SavingsPage.backKey,
              title: loc.savingsTitle,
              trailing: _AddButton(
                size: _addButtonSize,
                tooltip: loc.savingsCreate,
                onPressed: _create,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _gutter,
                _gutter,
                _gutter,
                _bottomPadding,
              ),
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final loc = context.loc;
    if (_isLoading) return const AppStateView.loading();
    final error = _loadError;
    if (error != null) {
      return AppStateView.error(
        title: loc.savingsLoadFailedTitle,
        message: error,
        onRetry: _load,
      );
    }
    final overview = SavingsOverview.of(_goals);
    final shown = _showDone ? overview.done : overview.open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PillSegmented<bool>(
          options: [(false, loc.savingsTabActive), (true, loc.savingsTabDone)],
          selected: _showDone,
          onChanged: (done) => setState(() => _showDone = done),
        ),
        if (!overview.isEmpty) ...[
          const SizedBox(height: _gap),
          SavingsSummaryCard(overview: overview),
        ],
        const SizedBox(height: _gap),
        if (shown.isNotEmpty)
          SavingsGoalList(
            goals: shown,
            today: _today,
            // A reached goal, or one without a target yet, has nothing to add money to: it opens the form.
            onTap: (goal) => goal.isDone || !goal.hasTarget
                ? _edit(goal)
                : _contribute(goal),
            onLongPress: _edit,
            onDelete: _delete,
          )
        else if (_showDone)
          AppStateView.empty(
            icon: Icons.emoji_events_outlined,
            title: loc.savingsEmptyDoneTitle,
            message: loc.savingsEmptyDoneHint,
          )
        else
          AppStateView.empty(
            icon: Icons.savings_outlined,
            title: loc.savingsEmptyActiveTitle,
            message: loc.savingsEmptyActiveHint,
            actionLabel: loc.savingsCreate,
            onAction: _create,
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
        key: SavingsPage.addKey,
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
