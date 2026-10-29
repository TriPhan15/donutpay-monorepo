import 'dart:math' as math;

/// A savings goal as `/api/savings` sends it (`{id, title, target, current, deadline}`). Missing numbers read as 0, an
/// empty deadline as none. [json] is the map itself, for [SavingsGoalPlanner] and the requests that need it.
class SavingsGoal {
  SavingsGoal.fromJson(this.json);

  final Map<String, dynamic> json;

  static double _number(Object? value) => (value as num?)?.toDouble() ?? 0;

  String get id => '${json['id']}';
  String get title => json['title']?.toString() ?? '';
  double get target => _number(json['target']);
  double get current => _number(json['current']);

  /// The `dd/MM/yyyy` target date; null when there is none.
  String? get deadline {
    final text = json['deadline']?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// What is still missing, never below 0.
  double get remaining => math.max(0, target - current);

  /// False for a goal whose target is 0 or missing (made elsewhere: the form asks for an amount above 0).
  bool get hasTarget => target > 0;

  /// Reached: a real target that the saved amount covers.
  bool get isDone => target > 0 && current >= target;

  /// The saved share of the target, between 0 and 1; 0 without a target.
  double get progress => target > 0 ? (current / target).clamp(0.0, 1.0) : 0;

  /// The percent shown, floored so that 100 only appears once the goal is reached.
  int get percentLabel => (progress * 100).floor();
}

/// The goals of the savings screen: the unfinished ones and the reached ones (each in list order), and the totals of
/// all of them.
class SavingsOverview {
  const SavingsOverview._({
    required this.open,
    required this.done,
    required this.totalSaved,
    required this.totalTarget,
  });

  factory SavingsOverview.of(List<SavingsGoal> goals) => SavingsOverview._(
    open: [
      for (final g in goals)
        if (!g.isDone) g,
    ],
    done: [
      for (final g in goals)
        if (g.isDone) g,
    ],
    totalSaved: goals.fold(0.0, (s, g) => s + g.current),
    totalTarget: goals.fold(0.0, (s, g) => s + g.target),
  );

  final List<SavingsGoal> open;
  final List<SavingsGoal> done;
  final double totalSaved;
  final double totalTarget;

  int get count => open.length + done.length;
  bool get isEmpty => count == 0;

  /// The saved share of all targets, between 0 and 1.
  double get progress =>
      totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0;
}
