/// Turns a person's name into a piece of a file name: no diacritics, no spaces, only [A-Za-z0-9].
abstract final class FileNamePart {
  /// Vietnamese letters with a diacritic, grouped by the plain letter they become (lower case; upper case is derived).
  static const Map<String, String> _plainLetters = {
    'a': 'àáảãạăằắẳẵặâầấẩẫậ',
    'e': 'èéẻẽẹêềếểễệ',
    'i': 'ìíỉĩị',
    'o': 'òóỏõọôồốổỗộơờớởỡợ',
    'u': 'ùúủũụưừứửữự',
    'y': 'ỳýỷỹỵ',
    'd': 'đ',
  };

  static final Map<String, String> _plainOf = {
    for (final entry in _plainLetters.entries)
      for (final rune in entry.value.runes) ...{
        String.fromCharCode(rune): entry.key,
        String.fromCharCode(rune).toUpperCase(): entry.key.toUpperCase(),
      },
  };

  static final RegExp _notAllowed = RegExp('[^A-Za-z0-9]');

  /// "Phan Thanh Trí" -> "PhanThanhTri"; empty when nothing usable is left or [name] is null.
  static String fromName(String? name) {
    if (name == null) return '';
    final plain = name.split('').map((c) => _plainOf[c] ?? c).join();
    return plain.replaceAll(_notAllowed, '');
  }
}
