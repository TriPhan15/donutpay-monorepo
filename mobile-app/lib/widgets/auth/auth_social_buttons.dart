import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/theme/app_typography.dart';

/// "— [dividerText] —" and two outlined buttons side by side, Google and Facebook (T9 auth mockup H). Null callbacks
/// turn both buttons off, while a sign-in is out.
class AuthSocialButtons extends StatelessWidget {
  const AuthSocialButtons({
    super.key,
    required this.dividerText,
    required this.onGoogle,
    required this.onFacebook,
  });

  // Brand names and colours: the same in every language and theme. Both stay at 3:1 or more on the surface colour.
  static const String google = 'Google';
  static const String facebook = 'Facebook';
  static const Color googleColor = Color(0xFFDB4437);
  static const Color facebookColor = Color(0xFF1877F2);

  final String dividerText;
  final VoidCallback? onGoogle;
  final VoidCallback? onFacebook;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: colors.outlineVariant)),
            Flexible(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  dividerText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: AppTextSize.caption,
                  ),
                ),
              ),
            ),
            Expanded(child: Divider(color: colors.outlineVariant)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                icon: Icons.g_mobiledata_rounded,
                color: googleColor,
                label: google,
                onTap: onGoogle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SocialButton(
                icon: Icons.facebook,
                color: facebookColor,
                label: facebook,
                onTap: onFacebook,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// An outlined button on the surface colour: the brand icon, then the brand name.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  static const double _height = 48;
  static const double _radius = 14;

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_radius),
      side: BorderSide(color: colors.outlineVariant, width: 1.5),
    );
    return Material(
      color: colors.surface,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: SizedBox(
          height: _height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: AppTextSize.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
