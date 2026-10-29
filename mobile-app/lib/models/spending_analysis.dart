/// The answer of the AI service to /spade/analyze. Every part is read leniently: a missing key or a value of the wrong
/// type becomes an empty list or 0, so an old or broken answer never throws.
enum SpendingAnalysisStatus { ok, insufficientData }

class SpendingPattern {
  final List<List<String>> itemsets;
  final int support;
  final double weightedSupport;
  final List<String> weeks;

  const SpendingPattern({
    required this.itemsets,
    required this.support,
    required this.weightedSupport,
    required this.weeks,
  });

  factory SpendingPattern.fromJson(Map<String, dynamic> json) =>
      SpendingPattern(
        itemsets: _itemsets(json['itemsets']),
        support: _int(json['support']),
        weightedSupport: _double(json['weightedSupport']),
        weeks: _strings(json['weeks']),
      );
}

class SpendingRule {
  final List<String> antecedent;
  final List<String> consequent;
  final int support;
  final int antecedentSupport;
  final double confidence;
  final double laplaceConfidence;
  final double lift;
  final List<String> weeks;

  const SpendingRule({
    required this.antecedent,
    required this.consequent,
    required this.support,
    required this.antecedentSupport,
    required this.confidence,
    required this.laplaceConfidence,
    required this.lift,
    required this.weeks,
  });

  factory SpendingRule.fromJson(Map<String, dynamic> json) => SpendingRule(
    antecedent: _strings(json['antecedent']),
    consequent: _strings(json['consequent']),
    support: _int(json['support']),
    antecedentSupport: _int(json['antecedentSupport']),
    confidence: _double(json['confidence']),
    laplaceConfidence: _double(json['laplaceConfidence']),
    lift: _double(json['lift']),
    weeks: _strings(json['weeks']),
  );
}

class PeriodicHabit {
  final String category;
  final int occurrences;
  final double meanGapDays;
  final DateTime lastDate;
  final DateTime nextExpectedDate;

  const PeriodicHabit({
    required this.category,
    required this.occurrences,
    required this.meanGapDays,
    required this.lastDate,
    required this.nextExpectedDate,
  });

  /// Null when a date is missing or unreadable: a habit without its dates cannot be shown.
  static PeriodicHabit? tryParse(Map<String, dynamic> json) {
    final last = _date(json['lastDate']);
    final next = _date(json['nextExpectedDate']);
    if (last == null || next == null) return null;
    return PeriodicHabit(
      category: json['category'] is String ? json['category'] as String : '',
      occurrences: _int(json['occurrences']),
      meanGapDays: _double(json['meanGapDays']),
      lastDate: last,
      nextExpectedDate: next,
    );
  }
}

class SpendingAnalysis {
  final SpendingAnalysisStatus status;
  final List<SpendingPattern> patterns;
  final List<SpendingRule> rules;
  final List<PeriodicHabit> habits;
  final int weeksWithData;
  final int minWeeks;

  const SpendingAnalysis({
    required this.status,
    required this.patterns,
    required this.rules,
    required this.habits,
    required this.weeksWithData,
    required this.minWeeks,
  });

  static const SpendingAnalysis empty = SpendingAnalysis(
    status: SpendingAnalysisStatus.insufficientData,
    patterns: [],
    rules: [],
    habits: [],
    weeksWithData: 0,
    minWeeks: 0,
  );

  factory SpendingAnalysis.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : const <String, dynamic>{};
    return SpendingAnalysis(
      status: json['status'] == 'OK'
          ? SpendingAnalysisStatus.ok
          : SpendingAnalysisStatus.insufficientData,
      patterns: _maps(json['patterns'])
          .map(SpendingPattern.fromJson)
          .where((p) => p.itemsets.isNotEmpty)
          .toList(),
      rules: _maps(json['rules'])
          .map(SpendingRule.fromJson)
          .where((r) => r.antecedent.isNotEmpty && r.consequent.isNotEmpty)
          .toList(),
      habits: _maps(
        json['habits'],
      ).map(PeriodicHabit.tryParse).whereType<PeriodicHabit>().toList(),
      weeksWithData: _int(meta['weeksWithData']),
      minWeeks: _int(meta['minWeeks']),
    );
  }
}

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? [
        for (final e in value)
          if (e is Map) Map<String, dynamic>.from(e),
      ]
    : const [];

List<String> _strings(Object? value) => value is List
    ? [
        for (final e in value)
          if (e is String) e,
      ]
    : const [];

List<List<String>> _itemsets(Object? value) =>
    value is List ? [for (final e in value) _strings(e)] : const [];

int _int(Object? value) => value is num ? value.toInt() : 0;

double _double(Object? value) => value is num ? value.toDouble() : 0;

DateTime? _date(Object? value) {
  if (value is! String) return null;
  final parsed = DateTime.tryParse(value);
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}
