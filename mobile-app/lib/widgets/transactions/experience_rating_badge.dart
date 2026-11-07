import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/screens/ledger/widgets/experience_rating_field.dart';

/// Displays a transaction's store experience rating (0.5 to 5.0 stars) and/or review note.
/// Used in compact mode inside [TransactionRow] and in full mode inside [TransactionDetailPage].
class ExperienceRatingBadge extends StatelessWidget {
  const ExperienceRatingBadge({
    super.key,
    required this.rating,
    this.reviewNote,
    this.compact = true,
  });

  final double? rating;
  final String? reviewNote;
  final bool compact;

  Color _badgeTone(BuildContext context, double score) {
    final semantic = context.colors;
    if (score <= 2.0) return semantic.expenseColor;
    if (score <= 3.5) return semantic.warningColor;
    return semantic.successColor;
  }

  @override
  Widget build(BuildContext context) {
    final trimmedNote = reviewNote?.trim();
    final hasNote = trimmedNote != null && trimmedNote.isNotEmpty;
    if (rating == null && !hasNote) return const SizedBox.shrink();

    if (compact) {
      return _buildCompact(context, trimmedNote, hasNote);
    }
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context, String? note, bool hasNote) {
    final colors = Theme.of(context).colorScheme;
    final score = rating;
    final tone = score != null ? _badgeTone(context, score) : colors.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (score != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, size: 13, color: tone),
                const SizedBox(width: 3),
                Text(
                  score.toStringAsFixed(1),
                  style: TextStyle(
                    color: tone,
                    fontSize: AppTextSize.caption,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        if (score != null && hasNote) const SizedBox(width: 6),
        if (hasNote)
          Flexible(
            child: Text(
              '"$note"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: AppTextSize.caption,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFull(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final starColor = context.colors.warningColor;
    final loc = context.loc;
    final score = rating;
    if (score == null) return const SizedBox.shrink();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                score >= i
                    ? Icons.star_rounded
                    : (score >= i - 0.5
                          ? Icons.star_half_rounded
                          : Icons.star_border_rounded),
                size: 18,
                color: score >= i - 0.5 ? starColor : colors.outline,
              ),
          ],
        ),
        Text(
          '${score.toStringAsFixed(1)} / 5.0 · ${ExperienceRatingField.sentimentLabel(loc, score)}',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: AppTextSize.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
