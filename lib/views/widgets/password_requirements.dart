import 'package:flutter/material.dart';

import '../../core/constants/auth_constants.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';

/// The password rules as a checklist that turns green as each one is met.
/// Used by sign up, change password and reset password.
class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final rules = [
      _PasswordRequirement(
        text: context.l10n.eightPlusCharacters,
        met: password.length >= AuthConstants.minPasswordLength,
      ),
      _PasswordRequirement(
        text: context.l10n.uppercaseLetter,
        met: AuthConstants.hasUppercase.hasMatch(password),
      ),
      _PasswordRequirement(
        text: context.l10n.lowercaseLetter,
        met: AuthConstants.hasLowercase.hasMatch(password),
      ),
      _PasswordRequirement(
        text: context.l10n.aNumber,
        met: AuthConstants.hasDigit.hasMatch(password),
      ),
      _PasswordRequirement(
        text: context.l10n.specialCharacter,
        met: AuthConstants.hasSpecialChar.hasMatch(password),
      ),
    ];

    // Two columns so the button fits without scrolling.
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          children: [
            for (final rule in rules)
              SizedBox(width: constraints.maxWidth / 2, child: rule),
          ],
        ),
      ),
    );
  }
}

class _PasswordRequirement extends StatelessWidget {
  const _PasswordRequirement({required this.text, required this.met});

  final String text;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met ? SynkColors.teal : const Color(0xFF9CA3AF);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
