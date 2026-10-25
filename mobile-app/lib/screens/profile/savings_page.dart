import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/utils/user_facing_error.dart';
import 'package:finance_ai_app/services/remote_api_helper.dart';
import 'package:finance_ai_app/services/session_service.dart';

class SavingsPage extends StatefulWidget {
  const SavingsPage({super.key});

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  List<Map<String, dynamic>> _goals = [];
  bool _isLoading = true;

  final _fmtCur = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      final goals = await RemoteApiHelper.instance.fetchSavings();
      if (!mounted) return;
      setState(() {
        _goals = goals;
        _isLoading = false;
      });
    } catch (e) {
      UserFacingError.log('Savings load', e);
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack(
        context.loc.savingsLoadFailed(
          UserFacingError.messageOf(e, context.loc),
        ),
      );
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double get _totalSaved =>
      _goals.fold(0.0, (s, g) => s + ((g['current'] as num?) ?? 0).toDouble());
  double get _totalTarget =>
      _goals.fold(0.0, (s, g) => s + ((g['target'] as num?) ?? 0).toDouble());

  static double _amountOf(String text) =>
      double.tryParse(text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

  /// After a write on the server: the AI tab and this list read the savings again.
  void _afterWrite() {
    SessionService.needRefreshAI.value = true;
    _load();
  }

  void _addGoal() {
    final loc = context.loc;
    showDialog<void>(
      context: context,
      builder: (_) => _SavingFormDialog(
        title: loc.savingsAddTitle,
        submitLabel: loc.savingsAdd,
        fields: [
          _SavingField(loc.savingsGoalName, TextInputType.text),
          _SavingField(loc.savingsTargetAmount, TextInputType.number),
          _SavingField(loc.savingsSavedAmount, TextInputType.number),
          _SavingField(loc.savingsDeadlineField, TextInputType.text),
        ],
        onSubmit: (values) async {
          final title = values[0].trim();
          final target = _amountOf(values[1]);
          if (title.isEmpty || target <= 0) return false;
          await RemoteApiHelper.instance.addSaving({
            'title': title,
            'target': target,
            'current': _amountOf(values[2]),
            'deadline': values[3].trim(),
          });
          _afterWrite();
          return true;
        },
      ),
    );
  }

  void _editAmount(int index) {
    final goal = _goals[index];
    final loc = context.loc;
    showDialog<void>(
      context: context,
      builder: (_) => _SavingFormDialog(
        title: loc.savingsUpdateTitle('${goal['title']}'),
        submitLabel: loc.commonSave,
        fields: [
          _SavingField(
            loc.savingsCurrentAmount,
            TextInputType.number,
            initialText: ((goal['current'] as num?) ?? 0).toInt().toString(),
          ),
        ],
        onSubmit: (values) async {
          await RemoteApiHelper.instance.updateSavingCurrent(
            goal['id'].toString(),
            _amountOf(values[0]),
          );
          _afterWrite();
          return true;
        },
      ),
    );
  }

  /// Removes the goal at once; when the server refuses or cannot be reached, it comes back where it was.
  Future<void> _deleteGoal(int index) async {
    final removed = _goals[index];
    setState(() => _goals.removeAt(index));
    try {
      await RemoteApiHelper.instance.deleteSaving(removed['id'].toString());
    } catch (e) {
      UserFacingError.log('Savings delete', e);
      if (!mounted) return;
      setState(() => _goals.insert(index.clamp(0, _goals.length), removed));
      _showSnack(
        context.loc.savingsDeleteFailed(
          UserFacingError.messageOf(e, context.loc),
        ),
      );
      return;
    }
    SessionService.needRefreshAI.value = true;
    if (!mounted) return;
    _showSnack(context.loc.savingsDeleted('${removed['title']}'));
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
          context.loc.savingsTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: colors.primary),
            onPressed: _addGoal,
          ),
        ],
      ),
      body: _isLoading
          ? _buildSkeletonLoading(colors)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 24),
                  _buildActionGrid(colors),
                  const SizedBox(height: 24),
                  _buildGoalsList(colors),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    final progress = _totalTarget > 0
        ? (_totalSaved / _totalTarget).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        // Brand card with white text: the same colours in both themes.
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A2540), AppTheme.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.loc.savingsTotalSaved,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fmtCur.format(_totalSaved),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    context.loc.savingsGoalCount(_goals.length),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.loc.savingsTarget(_fmtCur.format(_totalTarget)),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(ColorScheme colors) {
    final actions = [
      (Icons.add_circle_rounded, context.loc.savingsAddGoalAction, _addGoal),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: actions
            .map(
              (a) => GestureDetector(
                onTap: a.$3,
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(a.$1, color: colors.primary, size: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      a.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildGoalsList(ColorScheme colors) {
    // Made once for the whole list rather than once per goal.
    final tint = colors.primary.withValues(alpha: 0.12);
    final smallStyle = TextStyle(color: colors.onSurfaceVariant, fontSize: 11);
    final amountStyle = TextStyle(
      color: colors.primary,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.loc.savingsGoalList,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_goals.isNotEmpty)
                Text(
                  context.loc.savingsGoalCount(_goals.length),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_goals.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.savings_outlined,
                    color: colors.onSurfaceVariant,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.loc.savingsEmpty,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.loc.savingsEmptyHint,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_goals.length, (i) {
              final g = _goals[i];
              final target = ((g['target'] as num?) ?? 0).toDouble();
              final current = ((g['current'] as num?) ?? 0).toDouble();
              final progress = target > 0
                  ? (current / target).clamp(0.0, 1.0)
                  : 0.0;
              final isComplete = progress >= 1.0;
              final pctText = '${(progress * 100).toStringAsFixed(0)}%';
              final goalId = g['id']?.toString() ?? '$i';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Dismissible(
                  key: Key(goalId),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _deleteGoal(i),
                  background: Container(
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete_rounded, color: colors.onError),
                  ),
                  child: GestureDetector(
                    onTap: () => _editAmount(i),
                    onLongPress: () => _deleteGoal(i),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: tint,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  isComplete
                                      ? Icons.check_circle_rounded
                                      : Icons.savings_rounded,
                                  color: colors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g['title']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if ((g['deadline']?.toString() ?? '')
                                        .isNotEmpty)
                                      Text(
                                        context.loc.savingsDeadline(
                                          '${g['deadline']}',
                                        ),
                                        style: smallStyle,
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _fmtCur.format(current),
                                    style: amountStyle,
                                  ),
                                  Text(
                                    pctText,
                                    style: TextStyle(
                                      color: isComplete
                                          ? colors.primary
                                          : colors.onSurfaceVariant,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: colors.onSurfaceVariant
                                        .withValues(alpha: 0.2),
                                    // Orange while the goal is under way: bright enough on both themes.
                                    valueColor: AlwaysStoppedAnimation(
                                      isComplete
                                          ? colors.primary
                                          : Colors.orangeAccent,
                                    ),
                                    minHeight: 6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: tint,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  context.loc.savingsUpdate,
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_fmtCur.format(current), style: smallStyle),
                              Text(
                                '/ ${_fmtCur.format(target)}',
                                style: smallStyle,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading(ColorScheme colors) {
    final skeleton = colors.surface.withValues(alpha: 0.6);
    return ListView(
      padding: const EdgeInsets.only(bottom: 32, top: 16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildSkeletonBox(
          skeleton,
          height: 180,
          margin: const EdgeInsets.symmetric(horizontal: 20),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              4,
              (_) => Column(
                children: [
                  _buildSkeletonBox(
                    skeleton,
                    width: 64,
                    height: 64,
                    shape: BoxShape.rectangle,
                    borderRadius: 18,
                  ),
                  const SizedBox(height: 8),
                  _buildSkeletonBox(
                    skeleton,
                    width: 40,
                    height: 10,
                    borderRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildSkeletonBox(
            skeleton,
            width: 150,
            height: 20,
            borderRadius: 6,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSkeletonBox(
                  skeleton,
                  height: 90,
                  borderRadius: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonBox(
    Color color, {
    double? width,
    double? height,
    EdgeInsetsGeometry? margin,
    BoxShape shape = BoxShape.rectangle,
    double borderRadius = 20,
  }) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? BorderRadius.circular(borderRadius)
            : null,
      ),
    );
  }
}

/// One text field of a [_SavingFormDialog].
class _SavingField {
  final String label;
  final TextInputType keyboardType;
  final String initialText;

  const _SavingField(this.label, this.keyboardType, {this.initialText = ''});
}

/// The add and update dialogs of the savings. It owns its controllers (disposed with it, after the route is gone) and
/// stays open when the request fails, so nothing typed is lost; the error shown is a fixed text, the raw one is logged.
class _SavingFormDialog extends StatefulWidget {
  final String title;
  final String submitLabel;
  final List<_SavingField> fields;

  /// Returns false when the values are not acceptable (the dialog stays open), throws when the request fails.
  final Future<bool> Function(List<String> values) onSubmit;

  const _SavingFormDialog({
    required this.title,
    required this.submitLabel,
    required this.fields,
    required this.onSubmit,
  });

  @override
  State<_SavingFormDialog> createState() => _SavingFormDialogState();
}

class _SavingFormDialogState extends State<_SavingFormDialog> {
  late final List<TextEditingController> _controllers = [
    for (final field in widget.fields)
      TextEditingController(text: field.initialText),
  ];
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final accepted = await widget.onSubmit(
        _controllers.map((c) => c.text).toList(),
      );
      if (!mounted) return;
      if (accepted) {
        Navigator.pop(context);
        return;
      }
      setState(() => _isSaving = false);
    } catch (e) {
      UserFacingError.log('Savings save', e);
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = UserFacingError.messageOf(e, context.loc);
      });
    }
  }

  /// The text and the fill come from the theme; the label keeps the secondary text colour also when focused.
  TextField _field(ColorScheme colors, int index) {
    final field = widget.fields[index];
    return TextField(
      controller: _controllers[index],
      keyboardType: field.keyboardType,
      decoration: InputDecoration(
        labelText: field.label,
        labelStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final error = _error;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.fields.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _field(colors, i),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error, style: TextStyle(color: colors.error, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(
            context.loc.dialogCancel,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _isSaving ? null : _submit,
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}
