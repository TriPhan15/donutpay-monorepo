/// The longest text core-backend takes in a form, so that a field stops there instead of the server answering 400 after
/// Save (TransactionRequestDto, ReviewRequestDto).
abstract final class InputLimits {
  /// A note, a place or a store name of a transaction.
  static const int noteMaxLength = 255;

  /// The comment of a review of the app.
  static const int reviewCommentMaxLength = 1000;
}
