import 'package:finance_ai_app/widgets/receipt/receipt_scan_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // DONUT reads 1920x1440: gallery photos must not be shrunk below that or compressed hard.
  test('gallery photos keep at least the DONUT input size', () {
    expect(pickedImageMaxSide, greaterThanOrEqualTo(1920));
  });

  test('gallery photos are kept at high JPEG quality', () {
    expect(pickedImageQuality, greaterThanOrEqualTo(90));
  });
}
