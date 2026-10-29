/// How the receipt review form closed after saving; it closes with null when nothing was saved.
enum ReviewExit {
  /// "Lưu": the receipt is saved.
  saved,

  /// "Lưu & quét tiếp": saved, and the user goes on with the next receipt (the next ready one of the queue, or a new
  /// scan).
  savedScanNext,
}
