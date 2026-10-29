import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/models/spending_analysis.dart';

const Map<String, dynamic> _contractExample = {
  'status': 'OK',
  'patterns': [
    {
      'itemsets': [
        ['Ăn uống'],
        ['Mua sắm'],
      ],
      'support': 6,
      'weight': 1.4213,
      'weightedSupport': 0.4373,
      'weeks': ['2026-W31', '2026-W33'],
    },
  ],
  'rules': [
    {
      'antecedent': ['Ăn uống'],
      'consequent': ['Mua sắm'],
      'support': 6,
      'antecedentSupport': 8,
      'confidence': 0.75,
      'laplaceConfidence': 0.7,
      'lift': 1.5,
      'weeks': ['2026-W31', '2026-W33'],
    },
  ],
  'habits': [
    {
      'category': 'Siêu thị & Chợ',
      'occurrences': 12,
      'meanGapDays': 6.8,
      'stdGapDays': 1.3,
      'lastDate': '2026-10-20',
      'nextExpectedDate': '2026-10-27',
    },
  ],
  'categories': [
    {'category': 'Ăn uống', 'total': 3200000.0, 'share': 0.41, 'weeks': 12},
  ],
  'meta': {
    'algorithm': 'WCM-SPADE',
    'weeksWithData': 12,
    'minWeeks': 8,
    'windowWeeks': 26,
    'minSupport': 0.25,
    'rawSupportBound': 2,
    'maxWeight': 1.8,
  },
};

void main() {
  test('reads the contract of /spade/analyze', () {
    final a = SpendingAnalysis.fromJson(_contractExample);

    expect(a.status, SpendingAnalysisStatus.ok);
    expect(a.rules.single.antecedent, ['Ăn uống']);
    expect(a.rules.single.consequent, ['Mua sắm']);
    expect(a.rules.single.antecedentSupport, 8);
    expect(a.rules.single.laplaceConfidence, 0.7);
    expect(a.rules.single.lift, 1.5);
    expect(a.habits.single.category, 'Siêu thị & Chợ');
    expect(a.habits.single.meanGapDays, 6.8);
    expect(a.habits.single.lastDate, DateTime(2026, 10, 20));
    expect(a.habits.single.nextExpectedDate, DateTime(2026, 10, 27));
    expect(a.patterns.single.itemsets, [
      ['Ăn uống'],
      ['Mua sắm'],
    ]);
    expect(a.patterns.single.support, 6);
    expect(a.patterns.single.weightedSupport, 0.4373);
    expect(a.patterns.single.weeks, ['2026-W31', '2026-W33']);
    expect(a.weeksWithData, 12);
    expect(a.minWeeks, 8);
  });

  test('an old or broken answer becomes an empty analysis', () {
    final a = SpendingAnalysis.fromJson({
      'patterns': [
        {'pattern': 'an uong → di lai', 'count': 4},
      ],
    });

    expect(a.status, SpendingAnalysisStatus.insufficientData);
    expect(a.patterns, isEmpty);
    expect(a.rules, isEmpty);
    expect(a.habits, isEmpty);
    expect(a.weeksWithData, 0);
  });

  test('INSUFFICIENT_DATA and unknown statuses are insufficient data', () {
    expect(
      SpendingAnalysis.fromJson({'status': 'INSUFFICIENT_DATA'}).status,
      SpendingAnalysisStatus.insufficientData,
    );
    expect(
      SpendingAnalysis.fromJson({'status': 'WHATEVER'}).status,
      SpendingAnalysisStatus.insufficientData,
    );
  });

  test('wrong types and a bad date drop the entry instead of throwing', () {
    final a = SpendingAnalysis.fromJson({
      'status': 'OK',
      'patterns': 'oops',
      'rules': [
        42,
        {'antecedent': 'x'},
      ],
      'habits': [
        {
          'category': 'A',
          'lastDate': 'not a date',
          'nextExpectedDate': '2026-10-27',
        },
      ],
      'meta': {'weeksWithData': 'many'},
    });

    expect(a.patterns, isEmpty);
    expect(a.habits, isEmpty);
    expect(a.weeksWithData, 0);
  });

  test('empty is an empty insufficient analysis', () {
    expect(
      SpendingAnalysis.empty.status,
      SpendingAnalysisStatus.insufficientData,
    );
    expect(SpendingAnalysis.empty.patterns, isEmpty);
  });
}
