import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/constants/transaction_categories.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/models/transaction_model.dart';

/// Sections of the AI tab. Each builder takes the colour scheme that the calling screen read once in its build, and the
/// texts of the language on screen.
///
/// Amber marks the money-allocation advice, blue and orange the needs and wants of the 50/30/20 rule: identity
/// colours that stay the same in both themes, like chart series, and are bright enough on the dark surface.
class AiComponents {
  static const String _sequenceSeparator = ' → ';
  static const String _itemSeparator = '+';

  /// Prefix the AI service puts in front of its advice summary; it is not meant for the user.
  static const String _summaryPrefix = '(AI dùng Luật Khai Phá Chung) ';

  /// Data: spelling-free category tokens the AI service may send, and the category name each stands for.
  static const Map<String, String> _aiTokenNames = {
    'an uong': TransactionCategories.food,
    'di lai': 'Đi lại',
    'hoa don': 'Hóa đơn',
    'suc khoe': 'Sức khỏe',
    'giao duc': 'Giáo dục',
    'nha o': 'Nhà ở',
    'dien nuoc': 'Điện nước',
    'internet': 'Internet',
    'xang': 'Xăng',
    'y te': 'Y tế',
    'du lich': 'Du lịch',
    'giai tri': 'Giải trí',
    'mua sam': 'Mua sắm',
    'ca phe': 'Cà phê',
    'an vat': 'Ăn vặt',
    'lam dep': 'Làm đẹp',
    'game': 'Game',
    'shopping': 'Shopping',
    'quan ao': 'Quần áo',
    'do choi': 'Đồ chơi',
    'khac': TransactionCategories.otherExpense,
  };

  static String _money(AppLocalizations loc, double amount) =>
      CurrencyHelper.formatVND(amount, loc, showSign: amount < 0);

  /// One category of a pattern as the user should read it: an AI token becomes its category name, and a default
  /// category is shown in the language of [loc].
  static String _categoryOf(AppLocalizations loc, String item) {
    final trimmed = item.trim();
    return TransactionCategories.displayName(
      loc,
      _aiTokenNames[trimmed] ?? trimmed,
    );
  }

  /// A pattern of the AI service ("a+b → c") with each category in the language of [loc].
  static String formatAiPattern(AppLocalizations loc, String rawPattern) =>
      rawPattern
          .split(_sequenceSeparator)
          .map(
            (step) => step
                .split(_itemSeparator)
                .map((item) => _categoryOf(loc, item))
                .join(_itemSeparator),
          )
          .join(_sequenceSeparator);

  /// [hasError] is true when the last analysis failed; it replaces the "not enough data" message, which would be wrong then.
  static Widget buildSpadeSection(
    ColorScheme colors,
    AppLocalizations loc,
    List<Map<String, dynamic>> spadePatterns,
    bool isLoading, {
    bool hasError = false,
  }) {
    // Made once for the whole list rather than once per pattern.
    final cardDecoration = BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
    );
    final indexDecoration = BoxDecoration(
      color: colors.primaryContainer,
      borderRadius: BorderRadius.circular(10),
    );
    final indexStyle = TextStyle(
      color: colors.onPrimaryContainer,
      fontWeight: FontWeight.bold,
      fontSize: 13,
    );
    final detailStyle = TextStyle(
      color: colors.primary,
      fontSize: 12,
      fontStyle: FontStyle.italic,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // The title wraps on a narrow phone; the badge keeps its size.
            Flexible(
              child: Text(
                loc.aiSpadeTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'WCM-SPADE',
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          loc.aiSpadeSubtitle,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (hasError)
          _buildSpadeMessageCard(
            colors,
            icon: Icons.cloud_off_rounded,
            title: loc.aiSpadeLoadFailedTitle,
            message: loc.aiSpadeLoadFailedMessage,
          )
        else if (spadePatterns.isEmpty)
          _buildSpadeMessageCard(
            colors,
            icon: Icons.auto_graph_rounded,
            title: loc.aiSpadeNotEnoughTitle,
            message: loc.aiSpadeNotEnoughMessage,
          )
        else
          ...List.generate(spadePatterns.length, (i) {
            final p = spadePatterns[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDecoration,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: indexDecoration,
                      child: Center(
                        child: Text('#${i + 1}', style: indexStyle),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatAiPattern(
                              loc,
                              p['pattern']?.toString() ?? '',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            loc.aiSpadeDetail(
                              '${p['count']}',
                              '${p['wsupport']}',
                            ),
                            style: detailStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  static Widget _buildSpadeMessageCard(
    ColorScheme colors, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: colors.onPrimaryContainer, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildBudgetAdviceSection(
    ColorScheme colors,
    AppLocalizations loc,
    Map<String, dynamic>? budgetAdvice,
    bool isLoading,
  ) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (budgetAdvice == null) return const SizedBox.shrink();

    final recs = (budgetAdvice['recommendations'] as List?) ?? [];
    String summary = budgetAdvice['summary']?.toString() ?? '';

    summary = summary.replaceAll(_summaryPrefix, '');

    if (summary.isEmpty && recs.isEmpty) return const SizedBox.shrink();

    // A cut is shown in the error colour, a keep or a raise in the primary colour.
    final cutColor = colors.error;
    final keepColor = colors.primary;
    final amountsStyle = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: 13,
    );
    final reasonStyle = TextStyle(color: colors.onSurfaceVariant, fontSize: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // The title wraps on a narrow phone; the badge keeps its size.
            Flexible(
              child: Text(
                loc.aiAdviceTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'WCM-SPADE',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          loc.aiAdviceSubtitle,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (summary.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.tips_and_updates_rounded,
                  color: Colors.amber,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    summary,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        if (recs.isNotEmpty) const SizedBox(height: 12),
        ...recs.map((r) {
          final m = Map<String, dynamic>.from(r as Map);
          final isCut = ((m['delta'] as num?) ?? 0).toDouble() < 0;
          final accent = isCut ? cutColor : keepColor;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCut
                            ? Icons.trending_down_rounded
                            : Icons.trending_up_rounded,
                        color: accent,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${m['action']} · ${m['tag']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        CurrencyHelper.formatVND(
                          ((m['delta'] as num?) ?? 0).toDouble(),
                          loc,
                        ),
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    loc.aiAdvicePerMonth(
                      _money(loc, ((m['current'] as num?) ?? 0).toDouble()),
                      _money(loc, ((m['suggested'] as num?) ?? 0).toDouble()),
                    ),
                    style: amountsStyle,
                  ),
                  if ((m['reason']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(m['reason'].toString(), style: reasonStyle),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  static Widget buildBudgetGuardSection(
    ColorScheme colors,
    AppLocalizations loc,
    List<Map<String, dynamic>> spadePatterns,
    List<TransactionModel> transactions,
  ) {
    final now = DateTime.now();
    final recentCats = transactions
        .where((tx) => tx.isExpense && now.difference(tx.date).inDays < 7)
        .map((t) => t.category)
        .toSet();
    final spadeWarnings = <Widget>[];
    final warnedCons = <String>{};

    // Made once for all the warnings rather than once per warning.
    final warningDecoration = BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
    );
    final headingStyle = TextStyle(
      color: colors.primary,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );

    for (final p in spadePatterns) {
      if (spadeWarnings.length >= 2) break;
      final parts = (p['pattern']?.toString() ?? '').split(' → ');
      if (parts.length < 2) continue;

      final antes = parts.first.split('+').map((s) => s.trim()).toList();
      final cons = parts.last.split('+').first.trim();
      final hitAnte = antes.firstWhere(
        (a) => recentCats.contains(a),
        orElse: () => '',
      );

      if (hitAnte.isEmpty ||
          cons.isEmpty ||
          cons == hitAnte ||
          !warnedCons.add(cons)) {
        continue;
      }

      final txt = loc.aiGuardRule(
        _categoryOf(loc, hitAnte),
        _categoryOf(loc, cons),
      );

      spadeWarnings.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: warningDecoration,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.psychology_alt_rounded,
                  color: colors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.aiGuardHeading, style: headingStyle),
                      const SizedBox(height: 6),
                      Text(
                        txt,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (spadeWarnings.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.aiGuardTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          loc.aiGuardSubtitle,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ...spadeWarnings,
      ],
    );
  }

  /// The expenses of [txs] that the 50/30/20 card counts as needs: those in an essential default category, matched by
  /// the name core-backend stores (TransactionCategories.essentialExpenses).
  static double needsTotal(List<TransactionModel> txs) => txs
      .where(
        (t) =>
            t.isExpense &&
            TransactionCategories.essentialExpenses.contains(t.category.trim()),
      )
      .fold(0, (s, t) => s + t.amount);

  static Widget build503020Card(
    ColorScheme colors,
    AppLocalizations loc,
    List<TransactionModel> monthTxs,
    double monthIncome,
    double monthExpense,
  ) {
    if (monthIncome <= 0) return const SizedBox.shrink();

    final needs = needsTotal(monthTxs);
    double wants = monthExpense - needs;
    final needsPct = needs / monthIncome * 100,
        wantsPct = wants / monthIncome * 100,
        savePct = (monthIncome - monthExpense) / monthIncome * 100;

    // Past its target, a share turns to the error colour; the track is the neutral container colour.
    Widget row(
      String lbl,
      double pct,
      double target,
      Color c, {
      bool atLeast = false,
    }) {
      final over = atLeast ? pct < target : pct > target;
      final color = over ? colors.error : c;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(lbl, style: const TextStyle(fontSize: 13)),
                ),
                Text(
                  '${pct.toStringAsFixed(0)}% / ${atLeast ? '≥' : '≤'}${target.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: colors.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      );
    }

    String advice = loc.ai503020OnTrack;
    if (needsPct > 50 && needsPct >= wantsPct) {
      advice = loc.ai503020NeedsHigh(needsPct.toStringAsFixed(0));
    } else if (wantsPct > 30) {
      advice = loc.ai503020WantsHigh(wantsPct.toStringAsFixed(0));
    } else if (savePct < 20) {
      advice = loc.ai503020SavingsLow(savePct.toStringAsFixed(0));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.ai503020Title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            loc.ai503020Groups,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 12),
          row(loc.ai503020Needs, needsPct, 50, Colors.blueAccent),
          row(loc.ai503020Wants, wantsPct, 30, Colors.orangeAccent),
          row(loc.ai503020Savings, savePct, 20, colors.primary, atLeast: true),
          const SizedBox(height: 2),
          Text(
            advice,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
