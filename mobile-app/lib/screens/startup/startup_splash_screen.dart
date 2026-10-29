import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finance_ai_app/core/theme/app_theme.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';

/// Shown while the session is checked (T9 spec 3.11, M2). It repeats the native splash screen (launch_background.xml):
/// the brand gradient in both themes, logo C and the app name, so the hand-over from Android shows no jump.
class StartupSplashScreen extends StatelessWidget {
  const StartupSplashScreen({super.key});

  static const String appName = 'LedgerMind';
  static const String logoAsset = 'assets/images/logo.png';
  static const double logoSize = 96;
  static const double logoRadius = 28;
  static const double gap = 16;

  /// White status bar icons on the gradient, and a navigation bar that continues its bottom colour.
  static final SystemUiOverlayStyle overlayStyle = AppTheme.darkOverlayStyle
      .copyWith(systemNavigationBarColor: AppTheme.gradientEnd);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(logoRadius),
                  child: Image.asset(
                    logoAsset,
                    width: logoSize,
                    height: logoSize,
                  ),
                ),
                const SizedBox(height: gap),
                Text(
                  appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontSize: AppTextSize.amount,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
