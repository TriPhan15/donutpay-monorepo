import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';
import 'package:finance_ai_app/screens/startup/startup_splash_screen.dart';

/// The page of every screen of the sign-in flow (T9 spec 3.2, style H): the blue gradient fills the screen, a head sits
/// on it, the form [child] lies on a card in the middle and an optional [footer] link follows in white. Everything
/// scrolls together, so nothing is cut off on a small phone or hidden behind the keyboard.
///
/// The head is either a back button with [title] and [description] (register, password recovery), or, with
/// [AuthFormLayout.brand], logo C with the app name and a tagline (login).
class AuthFormLayout extends StatelessWidget {
  const AuthFormLayout({
    super.key,
    required String this.title,
    required String this.description,
    required this.child,
    this.footer,
  }) : tagline = null;

  const AuthFormLayout.brand({
    super.key,
    required String this.tagline,
    required this.child,
    this.footer,
  }) : title = null,
       description = null;

  static const Key backKey = ValueKey('auth-back');
  static const Key cardKey = ValueKey('auth-card');

  static const double logoSize = 76;
  static const double _logoRadius = 22;
  static const double _gutter = 16;
  static const double _cardRadius = 20;
  // The back button and its icon, as on PageBand.
  static const double _buttonSize = 36;
  static const double _iconSize = 20;
  static const List<BoxShadow> _logoShadow = [
    BoxShadow(color: Color(0x2E000000), blurRadius: 16, offset: Offset(0, 8)),
  ];

  final String? title;
  final String? description;
  final String? tagline;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final gradient = context.colors.headerGradient;
    // White status bar icons on the gradient, in both themes, and a navigation bar that continues its bottom colour.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.darkOverlayStyle.copyWith(
        systemNavigationBarColor: gradient.colors.last,
      ),
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: gradient),
          child: SafeArea(
            child: SizedBox.expand(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(_gutter, 12, _gutter, 16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (tagline != null)
                      _BrandHead(tagline: tagline!)
                    else
                      _BackHead(title: title!, description: description!),
                    const SizedBox(height: 20),
                    Container(
                      key: cardKey,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(_cardRadius),
                        boxShadow: AppTheme.softShadowFor(colors),
                      ),
                      child: child,
                    ),
                    if (footer != null) ...[
                      const SizedBox(height: 16),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo C, the app name and the tagline, centred on the gradient.
class _BrandHead extends StatelessWidget {
  const _BrandHead({required this.tagline});

  final String tagline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AuthFormLayout._logoRadius),
              boxShadow: AuthFormLayout._logoShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AuthFormLayout._logoRadius),
              child: Image.asset(
                StartupSplashScreen.logoAsset,
                width: AuthFormLayout.logoSize,
                height: AuthFormLayout.logoSize,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            StartupSplashScreen.appName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BandColors.primary,
              fontSize: AppTextSize.amount,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tagline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BandColors.secondary,
              fontSize: AppTextSize.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A round translucent back button and the page title, with the description under them. Built here rather than with
/// PageBand, whose own gradient and rounded bottom would show a seam on the gradient page.
class _BackHead extends StatelessWidget {
  const _BackHead({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Material(
              color: BandColors.tint,
              shape: const CircleBorder(),
              child: InkWell(
                key: AuthFormLayout.backKey,
                customBorder: const CircleBorder(),
                // maybePop, so that a PopScope of the page can keep it open.
                onTap: () => Navigator.maybePop(context),
                child: SizedBox(
                  width: AuthFormLayout._buttonSize,
                  height: AuthFormLayout._buttonSize,
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: BandColors.primary,
                    size: AuthFormLayout._iconSize,
                    semanticLabel: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BandColors.primary,
                  fontSize: AppTextSize.pageTitle,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            color: BandColors.secondary,
            fontSize: AppTextSize.secondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// "Question? **Action**" in white under the card; the whole line is the tap target.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  final String question;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Its own see-through Material: the splash would otherwise be drawn on the Scaffold's, under the gradient.
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text.rich(
              TextSpan(
                text: question,
                style: const TextStyle(color: BandColors.secondary),
                children: [
                  TextSpan(
                    text: action,
                    style: const TextStyle(
                      color: BandColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: AppTextSize.secondary),
            ),
          ),
        ),
      ),
    );
  }
}
