import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The seven text sizes of the app (T9 spec, 2.2). Screens use these names instead of writing sizes; nothing is
/// smaller than [caption].
abstract final class AppTextSize {
  /// Large amounts: the balance, the amount input.
  static const double amountLarge = 30;

  /// The total amount inside a card.
  static const double amount = 24;

  /// Page titles on the header band, success dialog titles.
  static const double pageTitle = 18;

  /// Section, card and sheet titles; primary buttons.
  static const double title = 16;

  /// Main text: transaction names, list rows, content.
  static const double body = 14;

  /// Secondary text: second lines, chips, hints.
  static const double secondary = 13;

  /// Captions: input labels, chart axes, bottom tab names, calendar cells.
  static const double caption = 12;

  static const List<double> scale = [
    amountLarge,
    amount,
    pageTitle,
    title,
    body,
    secondary,
    caption,
  ];
}

/// The text theme of the app: Be Vietnam Pro on the seven-step scale, with tabular figures so that amounts line up.
abstract final class AppTypography {
  static const List<FontFeature> _tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  static TextStyle _style(double size, FontWeight weight) => TextStyle(
    fontSize: size,
    fontWeight: weight,
    fontFeatures: _tabularFigures,
  );

  static final TextTheme _scale = TextTheme(
    displayLarge: _style(AppTextSize.amountLarge, FontWeight.w700),
    displayMedium: _style(AppTextSize.amountLarge, FontWeight.w700),
    displaySmall: _style(AppTextSize.amountLarge, FontWeight.w700),
    headlineLarge: _style(AppTextSize.amount, FontWeight.w700),
    headlineMedium: _style(AppTextSize.amount, FontWeight.w700),
    headlineSmall: _style(AppTextSize.amount, FontWeight.w700),
    titleLarge: _style(AppTextSize.pageTitle, FontWeight.w700),
    titleMedium: _style(AppTextSize.title, FontWeight.w600),
    titleSmall: _style(AppTextSize.body, FontWeight.w600),
    bodyLarge: _style(AppTextSize.body, FontWeight.w400),
    bodyMedium: _style(AppTextSize.body, FontWeight.w400),
    bodySmall: _style(AppTextSize.secondary, FontWeight.w400),
    labelLarge: _style(AppTextSize.title, FontWeight.w600),
    labelMedium: _style(AppTextSize.secondary, FontWeight.w500),
    labelSmall: _style(AppTextSize.caption, FontWeight.w500),
  );

  /// [base] resized to the scale, then set in Be Vietnam Pro (which picks its variant from each weight) and painted
  /// in [textColor].
  static TextTheme textTheme(TextTheme base, Color textColor) =>
      GoogleFonts.beVietnamProTextTheme(
        base.merge(_scale),
      ).apply(bodyColor: textColor, displayColor: textColor);

  static const TextStyle _tabularStyle = TextStyle(
    fontFeatures: _tabularFigures,
  );

  static const TextTheme _tabularOnly = TextTheme(
    displayLarge: _tabularStyle,
    displayMedium: _tabularStyle,
    displaySmall: _tabularStyle,
    headlineLarge: _tabularStyle,
    headlineMedium: _tabularStyle,
    headlineSmall: _tabularStyle,
    titleLarge: _tabularStyle,
    titleMedium: _tabularStyle,
    titleSmall: _tabularStyle,
    bodyLarge: _tabularStyle,
    bodyMedium: _tabularStyle,
    bodySmall: _tabularStyle,
    labelLarge: _tabularStyle,
    labelMedium: _tabularStyle,
    labelSmall: _tabularStyle,
  );

  /// [base] with tabular figures only, for text themes that keep their own sizes.
  static TextTheme tabular(TextTheme base) => base.merge(_tabularOnly);
}
