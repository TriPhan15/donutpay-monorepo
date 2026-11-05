import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finance_ai_app/core/constants/input_limits.dart';
import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/l10n/app_localizations.dart';
import 'package:finance_ai_app/screens/ledger/widgets/transaction_form_fields.dart';

/// Optional store experience rating (0.5 to 5.0 stars in 0.5 increments) and personal review note field
/// shared across ReviewFormPage, AddTransactionPage, and EditTransactionPage.
class ExperienceRatingField extends StatelessWidget {
  const ExperienceRatingField({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    required this.reviewNoteController,
  });

  static const Key starRowKey = ValueKey('experience-star-row');
  static const Key clearButtonKey = ValueKey('experience-rating-clear');
  static const Key reviewNoteFieldKey = ValueKey('experience-review-note');

  static const int _starCount = 5;
  static const double _starSize = 32;
  static const Color _activeStarColor = Color(0xFFF59E0B);

  final double? rating;
  final ValueChanged<double?> onRatingChanged;
  final TextEditingController reviewNoteController;

  /// Sentiment label for a given [rating], or the unrated hint when null.
  static String sentimentLabel(AppLocalizations loc, double? rating) {
    if (rating == null) return loc.experienceRatingUnrated;
    if (rating <= 1.5) return loc.experienceRatingBad;
    if (rating <= 2.5) return loc.experienceRatingFair;
    if (rating <= 3.5) return loc.experienceRatingAverage;
    if (rating <= 4.5) return loc.experienceRatingGood;
    return loc.experienceRatingExcellent;
  }

  /// Snaps a horizontal position [dx] within [totalWidth] to a 0.5-increment rating in [0.5, 5.0].
  static double ratingAtPosition(double dx, double totalWidth) {
    if (totalWidth <= 0) return 0.5;
    final clamped = dx.clamp(0.0, totalWidth);
    final raw = (clamped / totalWidth) * _starCount;
    final halfSteps = (raw * 2).ceil().clamp(1, _starCount * 2);
    return halfSteps / 2.0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.loc;
    final currentRating = rating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: FormFieldLabel(loc.experienceRatingLabel)),
            if (currentRating != null)
              TextButton.icon(
                key: clearButtonKey,
                onPressed: () => onRatingChanged(null),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(
                  loc.experienceRatingClear,
                  style: const TextStyle(fontSize: AppTextSize.caption),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  _HalfStarPicker(
                    key: starRowKey,
                    rating: currentRating,
                    onChanged: onRatingChanged,
                  ),
                  if (currentRating != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _activeStarColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${currentRating.toStringAsFixed(1)} ★',
                        style: const TextStyle(
                          color: _activeStarColor,
                          fontSize: AppTextSize.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                sentimentLabel(loc, currentRating),
                style: TextStyle(
                  color: currentRating == null
                      ? colors.onSurfaceVariant
                      : colors.onSurface,
                  fontSize: AppTextSize.caption,
                  fontWeight: currentRating == null
                      ? FontWeight.w400
                      : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: reviewNoteFieldKey,
          controller: reviewNoteController,
          textCapitalization: TextCapitalization.sentences,
          minLines: 1,
          maxLines: 2,
          inputFormatters: [
            LengthLimitingTextInputFormatter(InputLimits.noteMaxLength),
          ],
          style: const TextStyle(fontSize: AppTextSize.body),
          decoration: InputDecoration(
            labelText: loc.experienceReviewNoteLabel,
            hintText: loc.experienceReviewNoteHint,
            prefixIcon: const Icon(Icons.rate_review_outlined),
          ),
        ),
      ],
    );
  }
}

class _HalfStarPicker extends StatelessWidget {
  const _HalfStarPicker({
    super.key,
    required this.rating,
    required this.onChanged,
  });

  final double? rating;
  final ValueChanged<double?> onChanged;

  static const int _count = ExperienceRatingField._starCount;
  static const double _size = ExperienceRatingField._starSize;
  static const double _totalWidth = _count * _size;

  IconData _iconForStar(int index) {
    final value = rating;
    if (value == null) return Icons.star_border_rounded;
    if (value >= index) return Icons.star_rounded;
    if (value >= index - 0.5) return Icons.star_half_rounded;
    return Icons.star_border_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Theme.of(context).colorScheme.outline;
    final hasRating = rating != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => onChanged(
        ExperienceRatingField.ratingAtPosition(
          details.localPosition.dx,
          _totalWidth,
        ),
      ),
      onHorizontalDragUpdate: (details) => onChanged(
        ExperienceRatingField.ratingAtPosition(
          details.localPosition.dx,
          _totalWidth,
        ),
      ),
      child: SizedBox(
        width: _totalWidth,
        height: _size,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= _count; i++)
              SizedBox(
                key: ValueKey('experience-star-$i'),
                width: _size,
                height: _size,
                child: Icon(
                  _iconForStar(i),
                  size: _size - 2,
                  color: hasRating && rating! >= i - 0.5
                      ? ExperienceRatingField._activeStarColor
                      : inactiveColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
