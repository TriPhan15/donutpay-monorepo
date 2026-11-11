import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/models/today_allowance.dart';

/// The thin blue band at the top of the AI tab (T9 spec 3.1): "Hôm nay tiêu được 180.000 ₫ · còn 11 ngày" with a bar
/// of what is spent and left of it today. A small spinner on the right shows while the analysis runs.
class AiTodayBand extends StatelessWidget {
  const AiTodayBand({
    super.key,
    required this.allowance,
    required this.isRefreshing,
  });

  @visibleForTesting
  static const Key loadingKey = ValueKey('ai-loading');
  @visibleForTesting
  static const Key barKey = ValueKey('ai-today-bar');

  static const double _radius = 28;
  static const double _spinnerSize = 18;
  static const double _barHeight = 6;

  final TodayAllowance allowance;

  /// True while the analysis runs: the band then shows a spinner in its corner.
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final topInset = MediaQuery.paddingOf(context).top;
    final a = allowance;
    String money(double v) => CurrencyHelper.formatVND(v, loc, showSign: v < 0);
    const secondary = TextStyle(
      color: BandColors.secondary,
      fontSize: AppTextSize.caption,
    );
    const message = TextStyle(
      color: BandColors.primary,
      fontSize: AppTextSize.body,
      fontWeight: FontWeight.w600,
      height: 1.4,
    );

    final Widget value;
    if (!a.hasIncome) {
      value = Text(loc.aiSafeToSpendNoIncome, style: message);
    } else {
      final amount = Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        children: [
          Text(
            money(a.perDay),
            style: const TextStyle(
              color: BandColors.primary,
              fontSize: AppTextSize.amount,
              fontWeight: FontWeight.w700,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(loc.aiTodayDaysLeft(a.daysLeft), style: secondary),
          ),
        ],
      );
      // An overspent month keeps its (negative) share in view, so the user sees how far over it is.
      value = a.isOver
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                amount,
                const SizedBox(height: 4),
                Text(loc.aiOverSafe, style: message),
              ],
            )
          : amount;
    }

    final remaining = a.remainingToday;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12 + topInset, 16, 16),
      decoration: BoxDecoration(
        gradient: context.colors.headerGradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(_radius),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.aiTodayLabel,
                      style: const TextStyle(
                        color: BandColors.secondary,
                        fontSize: AppTextSize.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    value,
                  ],
                ),
              ),
              if (isRefreshing) ...[
                const SizedBox(width: 12),
                _loadingIndicator(),
              ],
            ],
          ),
          if (a.hasIncome && !a.isOver) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(_barHeight / 2),
              child: LinearProgressIndicator(
                key: barKey,
                value: a.spentFraction,
                minHeight: _barHeight,
                backgroundColor: BandColors.tint,
                valueColor: const AlwaysStoppedAnimation(BandColors.primary),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              children: [
                Text(loc.aiTodaySpent(money(a.spentToday)), style: secondary),
                Text(
                  remaining >= 0
                      ? loc.aiTodayLeft(money(remaining))
                      : loc.aiTodayOver(money(-remaining)),
                  style: remaining >= 0
                      ? secondary
                      : secondary.copyWith(
                          color: BandColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _loadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(9),
      child: SizedBox.square(
        dimension: _spinnerSize,
        child: CircularProgressIndicator(
          key: loadingKey,
          strokeWidth: 2,
          color: BandColors.primary,
        ),
      ),
    );
  }
}
