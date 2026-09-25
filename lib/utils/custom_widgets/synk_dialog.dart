import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';

// What the user chose in a SynkDialog.
enum SynkDialogAction { primary, secondary }

// The app's confirmation popup: a centred white card over a dimmed, blurred
// screen, with one gradient primary button and one secondary button.
//
// Two shapes are used by the Create Activity flow:
//   SynkDialog.success(...)     – "Activity created!"
//   SynkDialog.destructive(...) – "Discard activity?"
class SynkDialog extends StatelessWidget {
  const SynkDialog({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.secondaryLabel,
    this.secondaryIsDestructive = false,
    this.showPrimaryArrow = true,
  });

  // Teal check in a filled circle. Used for "Activity created!".
  factory SynkDialog.success({
    Key? key,
    required String title,
    required String message,
    required String primaryLabel,
    required String secondaryLabel,
  }) {
    return SynkDialog(
      key: key,
      icon: Icons.check_rounded,
      iconColor: Colors.white,
      iconBackground: SynkColors.teal,
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      secondaryLabel: secondaryLabel,
    );
  }

  // Orange icon on a soft orange circle, with a red secondary action.
  // Used for "Discard activity?" — the primary button is the safe choice.
  factory SynkDialog.destructive({
    Key? key,
    required IconData icon,
    required String title,
    required String message,
    required String primaryLabel,
    required String secondaryLabel,
  }) {
    return SynkDialog(
      key: key,
      icon: icon,
      iconColor: SynkColors.orangeDark,
      iconBackground: const Color(0x24FF7A36),
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      secondaryLabel: secondaryLabel,
      secondaryIsDestructive: true,
      showPrimaryArrow: false,
    );
  }

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String message;
  final String primaryLabel;
  final String secondaryLabel;
  final bool secondaryIsDestructive;
  final bool showPrimaryArrow;

  // Shows the dialog and resolves to the chosen action, or null if it was
  // dismissed by tapping outside or with the system back gesture.
  //
  // Set [barrierDismissible] to false when a choice is required.
  Future<SynkDialogAction?> show(
    BuildContext context, {
    bool barrierDismissible = true,
  }) {
    return showDialog<SynkDialogAction>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: const Color(0x6B1E1C24),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: this,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        width: 332,
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: SynkColors.textPrimary.withValues(alpha: 0.22),
              blurRadius: 60,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, size: 32, color: iconColor),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                height: 1.15,
                color: SynkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: SynkColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 22),
            _PrimaryButton(
              label: primaryLabel,
              showArrow: showPrimaryArrow,
              onTap: () =>
                  Navigator.of(context).pop(SynkDialogAction.primary),
            ),
            const SizedBox(height: 8),
            _SecondaryButton(
              label: secondaryLabel,
              isDestructive: secondaryIsDestructive,
              onTap: () =>
                  Navigator.of(context).pop(SynkDialogAction.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

// Gradient orange pill, matching the Create Activity flow's main button.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.showArrow,
    required this.onTap,
  });

  final String label;
  final bool showArrow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [SynkColors.orange, SynkColors.orangeDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: SynkColors.orange.withValues(alpha: 0.40),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (showArrow) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Outlined white pill, or plain red text when the action is destructive.
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.isDestructive,
    required this.onTap,
  });

  final String label;
  final bool isDestructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: isDestructive ? 52 : 56,
        decoration: isDestructive
            ? null
            : BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: Colors.white.withValues(alpha: 0.85),
                border: Border.all(
                  color: SynkColors.textPrimary.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isDestructive
                  ? const Color(0xFFE53935)
                  : SynkColors.textPrimary,
              fontSize: isDestructive ? 16 : 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}