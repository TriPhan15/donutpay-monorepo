import 'package:flutter/material.dart';

import 'package:finance_ai_app/core/extensions/build_context_extension.dart';
import 'package:finance_ai_app/core/theme/app_typography.dart';
import 'package:finance_ai_app/core/theme/band_colors.dart';

/// The blue band of the Profile tab (T9 spec 3.1): the page title, then the letter avatar, the name, the email and a
/// round arrow; the whole profile row opens the account information.
class ProfileHeaderBand extends StatelessWidget {
  const ProfileHeaderBand({
    super.key,
    required this.name,
    required this.email,
    required this.onOpenAccount,
  });

  static const double _radius = 28;
  static const double _avatarSize = 52;
  static const double _arrowSize = 32;

  final String name;
  final String email;
  final VoidCallback onOpenAccount;

  /// The first letters of the first and the last word of [name], upper case; '?' when there is no word.
  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    // The band runs under the status bar, so its own padding keeps the content below it.
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 16 + topInset, 18, 20),
      decoration: BoxDecoration(
        gradient: context.colors.headerGradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(_radius),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              loc.navProfile,
              style: const TextStyle(
                color: BandColors.primary,
                fontSize: AppTextSize.pageTitle,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onOpenAccount,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  Container(
                    width: _avatarSize,
                    height: _avatarSize,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: BandColors.tint,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initialsOf(name),
                      style: const TextStyle(
                        color: BandColors.primary,
                        fontSize: AppTextSize.pageTitle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BandColors.primary,
                            fontSize: AppTextSize.title,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: BandColors.secondary,
                              fontSize: AppTextSize.secondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: BandColors.tint,
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: const ValueKey('profile-open-account'),
                      customBorder: const CircleBorder(),
                      onTap: onOpenAccount,
                      child: SizedBox(
                        width: _arrowSize,
                        height: _arrowSize,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: BandColors.primary,
                          size: 20,
                          semanticLabel: loc.accountInfoTitle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
