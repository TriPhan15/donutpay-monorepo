import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Groups the digits of an amount field while the user types, the way [CurrencyHelper.formatVND] groups them for the
/// same language: `1.000.000` in Vietnamese, `1,000,000` in English. Amounts are whole dong, so anything that is not a
/// digit is dropped. The caret keeps the same number of digits on its right, so typing or deleting in the middle of the
/// number does not throw it to the end; deleting a group separator deletes the digit in front of it.
///
/// [parse] reads such a text back, whatever language grouped it.
class MoneyInputFormatter extends TextInputFormatter {
  /// [localeName] as `AppLocalizations.localeName` gives it (`vi`, `en`).
  MoneyInputFormatter(String localeName)
    : _format = NumberFormat.decimalPattern(localeName);

  /// More digits than this are refused: 15 digits stay exact in a double and in an int.
  static const int maxDigits = 15;

  static final RegExp _nonDigit = RegExp(r'[^0-9]');
  static final RegExp _leadingZeros = RegExp(r'^0+(?=\d)');

  final NumberFormat _format;

  /// [amount] as the field shows it, for the text a form starts with. The amount is rounded to whole dong.
  static String format(num amount, String localeName) =>
      NumberFormat.decimalPattern(localeName).format(amount.round());

  /// The amount in [text], ignoring everything that is not a digit (group separators of any language, spaces, "đ").
  /// Null when nothing usable was typed or when the amount is not above zero.
  static double? parse(String text) {
    final digits = text.replaceAll(_nonDigit, '');
    if (digits.isEmpty) return null;
    final value = double.tryParse(digits);
    if (value == null || value <= 0) return null;
    return value;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final edited = _withoutDeletedSeparator(oldValue, newValue);
    final caret = edited.selection.isValid
        ? edited.selection.extentOffset.clamp(0, edited.text.length)
        : edited.text.length;
    final digitsAfterCaret = _digitCount(edited.text.substring(caret));

    var digits = edited.text.replaceAll(_nonDigit, '');
    if (digits.isEmpty) return TextEditingValue.empty;
    digits = digits.replaceFirst(_leadingZeros, '');
    if (digits.length > maxDigits) return oldValue;

    final formatted = _format.format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: _offsetWithDigitsAfter(formatted, digitsAfterCaret),
      ),
    );
  }

  /// A backspace right after a separator removes only the separator, which the grouping would put straight back: the
  /// digit in front of it goes instead, which is what the user meant.
  static TextEditingValue _withoutDeletedSeparator(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final removedOneCharacter =
        newValue.text.length == oldValue.text.length - 1 &&
        newValue.selection.isCollapsed &&
        newValue.selection.isValid;
    if (!removedOneCharacter) return newValue;
    if (_digitCount(newValue.text) != _digitCount(oldValue.text)) {
      return newValue;
    }
    final caret = newValue.selection.extentOffset;
    // Only a real backspace over a separator: the old text is the new one with one non-digit put back at the caret.
    // A replaced or pasted text of the same digit count (e.g. "45.000" -> "50000") is left alone.
    if (caret >= oldValue.text.length ||
        _isDigit(oldValue.text, caret) ||
        oldValue.text.replaceRange(caret, caret + 1, '') != newValue.text) {
      return newValue;
    }
    for (var i = caret - 1; i >= 0; i--) {
      if (_isDigit(newValue.text, i)) {
        return TextEditingValue(
          text: newValue.text.replaceRange(i, i + 1, ''),
          selection: TextSelection.collapsed(offset: i),
        );
      }
    }
    return newValue;
  }

  /// The offset in [text] that has exactly [digitsAfter] digits on its right.
  static int _offsetWithDigitsAfter(String text, int digitsAfter) {
    var seen = 0;
    for (var i = text.length; i > 0; i--) {
      if (seen == digitsAfter) return i;
      if (_isDigit(text, i - 1)) seen++;
    }
    return 0;
  }

  static int _digitCount(String text) => text.replaceAll(_nonDigit, '').length;

  static bool _isDigit(String text, int index) {
    final unit = text.codeUnitAt(index);
    return unit >= _zero && unit <= _nine;
  }

  static final int _zero = '0'.codeUnitAt(0);
  static final int _nine = '9'.codeUnitAt(0);
}
