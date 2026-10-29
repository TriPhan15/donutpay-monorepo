import 'package:flutter/material.dart';

/// Colours of what sits on the blue header band (T9 spec, 2.3): white text, its 0.8 secondary, and the 0.18 white of
/// round buttons and pills. The same in light and dark, since the band stays a blue gradient in both.
abstract final class BandColors {
  static const Color primary = Colors.white;
  static const Color secondary = Color.fromRGBO(255, 255, 255, 0.8);
  static const Color tint = Color.fromRGBO(255, 255, 255, 0.18);
}
