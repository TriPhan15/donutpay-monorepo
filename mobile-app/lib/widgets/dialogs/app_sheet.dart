import 'package:flutter/material.dart';

/// Opens the app's modal bottom sheet and returns what it pops.
///
/// The look (rounded top, surface colour) comes from the theme's `bottomSheetTheme`, so no shape is set here. There is
/// no drag handle and no safe area; a sheet that needs either keeps its own `showModalBottomSheet` call.
///
/// A sheet is scroll controlled by default: it takes the height it needs and rises with the keyboard, instead of being
/// capped at 9/16 of the screen. Pass `isScrollControlled: false` for a short sheet that should keep that cap.
Future<T?> showAppSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    builder: builder,
  );
}
