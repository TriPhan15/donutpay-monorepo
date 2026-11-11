import 'package:flutter_test/flutter_test.dart';

import 'package:finance_ai_app/core/utils/file_name_part.dart';

void main() {
  test('strips diacritics and spaces from a Vietnamese name', () {
    expect(FileNamePart.fromName('Phan Thanh Trí'), 'PhanThanhTri');
  });

  test('turns đ and Đ into d and D', () {
    expect(FileNamePart.fromName('Đặng Đức'), 'DangDuc');
  });

  test('handles stacked diacritics in lower and upper case', () {
    expect(FileNamePart.fromName('Nguyễn Thị Ánh Ngọc'), 'NguyenThiAnhNgoc');
  });

  test('drops punctuation and keeps digits', () {
    expect(FileNamePart.fromName("a.b_c-d 9'x"), 'abcd9x');
  });

  test('is empty for null, blank or symbol-only names', () {
    expect(FileNamePart.fromName(null), '');
    expect(FileNamePart.fromName('   '), '');
    expect(FileNamePart.fromName('***'), '');
  });
}
