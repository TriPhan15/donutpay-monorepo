/// The comment of the feedback sheet, built from what the user types and the suggestion chips they tap (T9 spec
/// 3.10): a chip is joined to the comment with ", " and never added twice.
abstract final class FeedbackDraft {
  static final RegExp _trailingSeparators = RegExp(r'[\s,]+$');

  /// [comment] with [chip] appended; unchanged when the chip is already in it.
  static String addChip(String comment, String chip) {
    if (hasChip(comment, chip)) return comment;
    final trimmed = comment.replaceAll(_trailingSeparators, '').trim();
    return trimmed.isEmpty ? chip : '$trimmed, $chip';
  }

  /// Whether [chip] is one of the comma-separated pieces of [comment].
  static bool hasChip(String comment, String chip) =>
      comment.split(',').any((piece) => piece.trim() == chip);
}
