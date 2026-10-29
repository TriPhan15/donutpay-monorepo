import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:finance_ai_app/core/theme/app_typography.dart';

class AppTheme {
  // T9 sky blue palette (docs/superpowers/specs/2026-10-27-t9-redesign-design.md, 2.1). The legacy names stay, so every
  // screen that reads them or the colour scheme follows the new values.
  static const Color primary = Color(0xFF0284C7);
  static const Color primaryDark = Color(0xFF0369A1);
  static const Color gradientStart = Color(0xFF38BDF8);
  static const Color gradientEnd = Color(0xFF0369A1);

  static const Color cardDarkGradStart = Color(0xFF2B2B3A);
  static const Color cardDarkGradEnd = Color(0xFF16161F);

  static const Color bgLight = Color(0xFFF3F8FC);
  static const Color bgDark = Color(0xFFF4F4F6);
  static const Color navyDark = Color(0xFFFFFFFF);
  static const Color navyLight = Color(0xFFFFFFFF);
  static const Color navyMid = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFFFFFFFF);

  static const Color mintAccent = primary;
  static const Color mintLight = Color(0xFFE0F2FE);

  static const Color textWhite = Color(0xFF0F2236);
  static const Color textGray = Color(0xFF5B6F82);
  static const Color textPrimary = Color(0xFF0F2236);
  static const Color textSecondary = Color(0xFF5B6F82);

  static const Color dangerColor = Color(0xFFE5484D);
  static const Color warningColor = Color(0xFFB7791F);
  static const Color positive = Color(0xFF0E9F6E);
  static const Color negative = Color(0xFFE5484D);

  /// The part a progress bar is about to add (a savings contribution being typed), the same in both themes.
  static const Color pendingProgress = Color(0xFF7DD3FC);

  static const Color _lightSurface = Colors.white;
  static const Color _lightBorder = Color(0xFFE1EBF3);

  // Pale blue-greys for the light container roles (tracks, skeletons, tooltips), from the page colour down to the
  // track colour.
  static const Color _lightContainerLow = Color(0xFFF6F9FC);
  static const Color _lightContainerHigh = Color(0xFFE8F0F6);
  static const Color _lightContainerHighest = Color(0xFFDFE9F2);

  // Dark mode has its own tones and never falls back on the light-only colours above.
  static const Color _darkBackground = Color(0xFF0B1724);
  static const Color _darkSurface = Color(0xFF13233A);
  static const Color _darkContainerLow = Color(0xFF0F1D2E);
  static const Color _darkContainerHigh = Color(0xFF172A40);
  static const Color _darkContainerHighest = Color(0xFF1A3047);
  static const Color _darkTextPrimary = Color(0xFFE6EEF6);
  static const Color _darkTextSecondary = Color(0xFF93A7BA);
  static const Color _darkBorder = Color(0xFF22384D);
  static const Color _darkPrimary = Color(0xFF38BDF8);
  static const Color _darkOnPrimary = Color(0xFF082F49);
  static const Color _darkPrimaryContainer = Color(0xFF16344F);
  static const Color _darkOnPrimaryContainer = Color(0xFF7DD3FC);
  static const Color _darkPositive = Color(0xFF34D399);
  static const Color _darkNegative = Color(0xFFFB7185);
  static const Color _darkOnNegative = Color(0xFF3A0A10);
  static const Color _darkWarning = Color(0xFFF5C04A);
  static const Color _darkGradientStart = Color(0xFF0B4F7A);
  static const Color _darkGradientEnd = Color(0xFF082F49);

  // The 160 degree direction of the design: top to bottom, leaning slightly to the right.
  static const Alignment _gradientBegin = Alignment(-0.35, -1);
  static const Alignment _gradientEnd = Alignment(0.35, 1);

  /// The light header band, the auth screens and the splash screen: #38BDF8 to #0369A1.
  static const LinearGradient brandGradient = LinearGradient(
    begin: _gradientBegin,
    end: _gradientEnd,
    colors: [gradientStart, gradientEnd],
  );

  /// The header band in dark mode: the same direction, deeper blues.
  static const LinearGradient headerGradientDark = LinearGradient(
    begin: _gradientBegin,
    end: _gradientEnd,
    colors: [_darkGradientStart, _darkGradientEnd],
  );

  static const SystemUiOverlayStyle lightOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: _lightSurface,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  static const SystemUiOverlayStyle darkOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: _darkSurface,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  static SystemUiOverlayStyle overlayStyleFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkOverlayStyle : lightOverlayStyle;

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: primaryDark.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  /// [softShadow] on a light surface; nothing on a dark one, where a shadow does not show.
  static List<BoxShadow>? softShadowFor(ColorScheme colors) =>
      colors.brightness == Brightness.light ? softShadow : null;

  static BoxDecoration get card => BoxDecoration(
    color: navyLight,
    borderRadius: BorderRadius.circular(20),
    boxShadow: softShadow,
  );

  static const LinearGradient purpleCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cardDarkGradStart, cardDarkGradEnd],
  );

  /// Theme-aware version of [card], without its shadow: the surface colour alone sets the card apart, white on the
  /// grey light background and lighter than the dark one. Every caller is a plain Container, so the colour stays.
  static BoxDecoration cardDecoration(ColorScheme colors) => BoxDecoration(
    color: colors.surface,
    borderRadius: BorderRadius.circular(20),
  );

  // The light roles repeat the constants above, so a screen that still reads AppTheme.* matches one that reads the
  // colour scheme.
  static final ThemeData lightTheme = _buildTheme(
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          primaryContainer: mintLight,
          onPrimaryContainer: primaryDark,
          secondary: primary,
          onSecondary: Colors.white,
          surface: _lightSurface,
          surfaceContainerLowest: _lightSurface,
          surfaceContainerLow: _lightContainerLow,
          surfaceContainer: bgLight,
          surfaceContainerHigh: _lightContainerHigh,
          surfaceContainerHighest: _lightContainerHighest,
          onSurface: textPrimary,
          onSurfaceVariant: textSecondary,
          outlineVariant: _lightBorder,
          error: dangerColor,
          onError: Colors.white,
        ),
    background: bgLight,
    overlayStyle: lightOverlayStyle,
    semanticColors: SemanticColors.light,
  );

  static final ThemeData darkTheme = _buildTheme(
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: _darkPrimary,
          onPrimary: _darkOnPrimary,
          primaryContainer: _darkPrimaryContainer,
          onPrimaryContainer: _darkOnPrimaryContainer,
          secondary: _darkPrimary,
          onSecondary: _darkOnPrimary,
          surface: _darkSurface,
          surfaceContainerLowest: _darkBackground,
          surfaceContainerLow: _darkContainerLow,
          surfaceContainer: _darkSurface,
          surfaceContainerHigh: _darkContainerHigh,
          surfaceContainerHighest: _darkContainerHighest,
          onSurface: _darkTextPrimary,
          onSurfaceVariant: _darkTextSecondary,
          outlineVariant: _darkBorder,
          error: _darkNegative,
          onError: _darkOnNegative,
        ),
    background: _darkBackground,
    overlayStyle: darkOverlayStyle,
    semanticColors: SemanticColors.dark,
  );

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color background,
    required SystemUiOverlayStyle overlayStyle,
    required SemanticColors semanticColors,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      extensions: [semanticColors],
    );
    final text = colorScheme.onSurface;
    final border = BorderSide(color: colorScheme.outlineVariant);
    return base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: AppTypography.textTheme(base.textTheme, text),
      primaryTextTheme: AppTypography.tabular(base.primaryTextTheme),
      iconTheme: IconThemeData(color: text),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: overlayStyle,
        iconTheme: IconThemeData(color: text),
        titleTextStyle: GoogleFonts.beVietnamPro(
          color: text,
          fontSize: AppTextSize.pageTitle,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      // The pickers keep the look the app gave them before: the surface colour with the headline in the text colour.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        headerForegroundColor: colorScheme.onSurface,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
          textStyle: GoogleFonts.beVietnamPro(
            fontSize: AppTextSize.title,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: border,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: border,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

/// Fintech colours that the [ColorScheme] has no role for. Errors use [ColorScheme.error].
class SemanticColors extends ThemeExtension<SemanticColors> {
  /// Everything but the two money colours defaults to the light palette, so that two-colour instances keep compiling.
  const SemanticColors({
    required this.incomeColor,
    required this.expenseColor,
    this.successColor = AppTheme.positive,
    this.warningColor = AppTheme.warningColor,
    this.headerGradient = AppTheme.brandGradient,
    this.pendingProgressColor = AppTheme.pendingProgress,
  });

  const SemanticColors.defaultLight()
    : incomeColor = AppTheme.positive,
      expenseColor = AppTheme.negative,
      successColor = AppTheme.positive,
      warningColor = AppTheme.warningColor,
      headerGradient = AppTheme.brandGradient,
      pendingProgressColor = AppTheme.pendingProgress;

  const SemanticColors.defaultDark()
    : incomeColor = AppTheme._darkPositive,
      expenseColor = AppTheme._darkNegative,
      successColor = AppTheme._darkPositive,
      warningColor = AppTheme._darkWarning,
      headerGradient = AppTheme.headerGradientDark,
      pendingProgressColor = AppTheme.pendingProgress;

  static const SemanticColors light = SemanticColors.defaultLight();

  static const SemanticColors dark = SemanticColors.defaultDark();

  final Color incomeColor;
  final Color expenseColor;
  final Color successColor;
  final Color warningColor;

  /// The background of the header band at the top of a page.
  final LinearGradient headerGradient;

  /// The part of a progress bar that the current input is about to add.
  final Color pendingProgressColor;

  @override
  SemanticColors copyWith({
    Color? incomeColor,
    Color? expenseColor,
    Color? successColor,
    Color? warningColor,
    LinearGradient? headerGradient,
    Color? pendingProgressColor,
  }) {
    return SemanticColors(
      incomeColor: incomeColor ?? this.incomeColor,
      expenseColor: expenseColor ?? this.expenseColor,
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      headerGradient: headerGradient ?? this.headerGradient,
      pendingProgressColor: pendingProgressColor ?? this.pendingProgressColor,
    );
  }

  @override
  SemanticColors lerp(
    covariant ThemeExtension<SemanticColors>? other,
    double t,
  ) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      incomeColor: Color.lerp(incomeColor, other.incomeColor, t)!,
      expenseColor: Color.lerp(expenseColor, other.expenseColor, t)!,
      successColor: Color.lerp(successColor, other.successColor, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      headerGradient: LinearGradient.lerp(
        headerGradient,
        other.headerGradient,
        t,
      )!,
      pendingProgressColor: Color.lerp(
        pendingProgressColor,
        other.pendingProgressColor,
        t,
      )!,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticColors &&
          other.incomeColor == incomeColor &&
          other.expenseColor == expenseColor &&
          other.successColor == successColor &&
          other.warningColor == warningColor &&
          other.headerGradient == headerGradient &&
          other.pendingProgressColor == pendingProgressColor;

  @override
  int get hashCode => Object.hash(
    incomeColor,
    expenseColor,
    successColor,
    warningColor,
    headerGradient,
    pendingProgressColor,
  );
}
