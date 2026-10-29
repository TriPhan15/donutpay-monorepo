import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/core/utils/currency_helper.dart';
import 'package:finance_ai_app/cubits/amount_visibility_cubit.dart';
import 'package:finance_ai_app/models/ledger_stats.dart';
import 'package:finance_ai_app/widgets/common/amount_eye_button.dart';

/// The blue band of the statistics tab (T9 spec, 3.1): the title with Tìm / Lọc / Excel, the period row
/// (eye | ‹ period › | Tuần/Tháng/Năm ▾) and the pills Thu / Chi / Còn, which the eye hides together with the home
/// balance.
class StatsHeaderBand extends StatelessWidget {
  const StatsHeaderBand({
    super.key,
    required this.periodLabel,
    required this.period,
    required this.income,
    required this.expense,
    required this.filterActive,
    required this.searching,
    required this.searchController,
    required this.onSearchOpen,
    required this.onSearchClose,
    required this.onSearchChanged,
    required this.onFilter,
    required this.onExport,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
    required this.onPeriodChanged,
  });

  @visibleForTesting
  static const Key bandKey = ValueKey('stats-band');
  @visibleForTesting
  static const Key searchKey = ValueKey('stats-search');
  @visibleForTesting
  static const Key closeSearchKey = ValueKey('stats-search-close');
  @visibleForTesting
  static const Key filterKey = ValueKey('stats-filter');
  @visibleForTesting
  static const Key exportKey = ValueKey('stats-export');
  @visibleForTesting
  static const Key previousKey = ValueKey('stats-previous');
  @visibleForTesting
  static const Key nextKey = ValueKey('stats-next');
  @visibleForTesting
  static const Key periodMenuKey = ValueKey('stats-period-menu');

  static const double _radius = 28;
  static const double _buttonSize = 36;
  static const double _rowGap = 12;

  final String periodLabel;
  final LedgerPeriod period;

  /// Income and spending of the whole period, whatever the filter; "Còn" is their difference.
  final double income;
  final double expense;
  final bool filterActive;
  final bool searching;
  final TextEditingController searchController;
  final VoidCallback onSearchOpen;
  final VoidCallback onSearchClose;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilter;
  final VoidCallback onExport;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickDate;
  final ValueChanged<LedgerPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      key: bandKey,
      padding: EdgeInsets.fromLTRB(16, 12 + topInset, 16, 16),
      decoration: BoxDecoration(
        gradient: context.colors.headerGradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(_radius),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _buttonSize + 8,
            child: searching ? _searchRow(context) : _titleRow(context),
          ),
          const SizedBox(height: _rowGap),
          _periodRow(context),
          const SizedBox(height: _rowGap),
          // Only the pills listen to the eye: showing them does not rebuild the rest of the band.
          BlocBuilder<AmountVisibilityCubit, bool>(
            builder: (context, hidden) =>
                _Pills(hidden: hidden, income: income, expense: expense),
          ),
        ],
      ),
    );
  }

  Widget _titleRow(BuildContext context) {
    final loc = context.loc;
    return Row(
      children: [
        Expanded(
          child: Text(
            loc.ledgerTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BandColors.primary,
              fontSize: AppTextSize.pageTitle,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _BandButton(
          key: searchKey,
          icon: Icons.search_rounded,
          tooltip: loc.statsSearch,
          onTap: onSearchOpen,
        ),
        const SizedBox(width: 8),
        _BandButton(
          key: filterKey,
          icon: Icons.tune_rounded,
          tooltip: loc.filterTitle,
          filled: filterActive,
          onTap: onFilter,
        ),
        const SizedBox(width: 8),
        _BandButton(
          key: exportKey,
          icon: Icons.file_download_outlined,
          tooltip: loc.statsExport,
          onTap: onExport,
        ),
      ],
    );
  }

  Widget _searchRow(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: searchController,
            autofocus: true,
            onChanged: onSearchChanged,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: AppTextSize.body,
            ),
            decoration: InputDecoration(
              hintText: context.loc.ledgerSearchHint,
              filled: true,
              fillColor: colors.surface,
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_buttonSize / 2),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_buttonSize / 2),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_buttonSize / 2),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _BandButton(
          key: closeSearchKey,
          icon: Icons.close_rounded,
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onTap: onSearchClose,
        ),
      ],
    );
  }

  Widget _periodRow(BuildContext context) {
    final loc = context.loc;
    final periodNames = {
      LedgerPeriod.week: loc.budgetPeriodWeek,
      LedgerPeriod.month: loc.budgetPeriodMonth,
      LedgerPeriod.year: loc.budgetPeriodYear,
    };
    return Row(
      children: [
        BlocBuilder<AmountVisibilityCubit, bool>(
          builder: (context, hidden) => AmountEyeButton(hidden: hidden),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Chevron(
                key: previousKey,
                icon: Icons.chevron_left_rounded,
                tooltip: MaterialLocalizations.of(context).previousPageTooltip,
                onTap: onPrevious,
              ),
              Flexible(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onPickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    // Two lines rather than an ellipsis: a narrow phone keeps the whole period, e.g. a week's end.
                    child: Text(
                      periodLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BandColors.primary,
                        fontSize: AppTextSize.body,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              _Chevron(
                key: nextKey,
                icon: Icons.chevron_right_rounded,
                tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                onTap: onNext,
              ),
            ],
          ),
        ),
        PopupMenuButton<LedgerPeriod>(
          key: periodMenuKey,
          initialValue: period,
          onSelected: onPeriodChanged,
          itemBuilder: (_) => [
            for (final entry in periodNames.entries)
              PopupMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
            decoration: BoxDecoration(
              color: BandColors.tint,
              borderRadius: BorderRadius.circular(_buttonSize / 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  periodNames[period]!,
                  style: const TextStyle(
                    color: BandColors.primary,
                    fontSize: AppTextSize.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: BandColors.primary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A round 36 px button on the band; [filled] turns it white with a primary icon (a filter is on).
class _BandButton extends StatelessWidget {
  const _BandButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? BandColors.primary : BandColors.tint,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: StatsHeaderBand._buttonSize,
            child: Icon(
              icon,
              size: 20,
              color: filled
                  ? Theme.of(context).colorScheme.primary
                  : BandColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: BandColors.primary, size: 22),
    );
  }
}

/// Thu / Chi / Còn of the period, in compact amounts; dots while [hidden].
class _Pills extends StatelessWidget {
  static const Duration _fade = Duration(milliseconds: 200);
  static const double _dot = 8;

  final bool hidden;
  final double income;
  final double expense;

  const _Pills({
    required this.hidden,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    String shown(double amount) => hidden
        ? AmountEyeButton.hiddenText
        : CurrencyHelper.formatCompactVND(amount, loc);
    return Row(
      children: [
        Expanded(
          child: _pill(
            context.colors.successColor,
            loc.statsIncome(shown(income)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _pill(
            Theme.of(context).colorScheme.error,
            loc.statsExpense(shown(expense)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _pill(null, loc.statsLeft(shown(income - expense)))),
      ],
    );
  }

  Widget _pill(Color? dot, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: BandColors.tint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (dot != null) ...[
            Container(
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
                border: Border.all(color: BandColors.primary, width: 1.5),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: AnimatedSwitcher(
              duration: _fade,
              // A narrow phone wraps the amount under its label instead of cutting it.
              child: Text(
                text,
                key: ValueKey(text),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BandColors.primary,
                  fontSize: AppTextSize.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
