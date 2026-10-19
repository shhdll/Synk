import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';
import 'synk_dialog.dart';

// Shared feedback for edit screens, so every page that saves something
// confirms and reports it the same way.
class SynkFeedback {
  SynkFeedback._();

  static const String savedMessage = 'Your changes have been saved.';

  // Asks before leaving a screen with unsaved changes.
  // Resolves to true when the user chose to discard and leave.
  static Future<bool> confirmDiscardChanges(BuildContext context) async {
    final SynkDialogAction? action = await SynkDialog.destructive(
      icon: Icons.edit_off_rounded,
      title: 'Discard changes?',
      message: "Your changes haven't been saved. If you leave now, you'll lose them.",
      primaryLabel: 'Keep editing',
      secondaryLabel: 'Discard and leave',
    ).show(context, barrierDismissible: false);

    return action == SynkDialogAction.secondary;
  }

  // Keeps the existing save confirmation unchanged.
  static Future<void> showSaved(
    BuildContext context, {
    String message = savedMessage,
  }) {
    return showSuccessDialog(context, title: 'Saved!', message: message);
  }

  // Shared success popup for completed actions.
  static Future<void> showSuccessDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'Done',
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x6B1E1C24),
      builder: (_) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: _SuccessDialog(
            title: title,
            message: message,
            buttonLabel: buttonLabel,
            icon: Icons.check_rounded,
            iconBackground: SynkColors.teal,
            iconColor: Colors.white,
          ),
        );
      },
    );
  }

  // Shows a blocking error popup using the same card and button style.
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'Got it',
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x6B1E1C24),
      builder: (_) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: _SuccessDialog(
            title: title,
            message: message,
            buttonLabel: buttonLabel,
            icon: Icons.event_busy_rounded,
            iconBackground: const Color(0x24FF7A36),
            iconColor: SynkColors.orangeDark,
          ),
        );
      },
    );
  }

  // Shows errors using the shared floating Snackbar.
  static void showError(BuildContext context, String message) {
    _show(context, message, success: false);
  }

  static void _show(
    BuildContext context,
    String message, {
    required bool success,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: success ? SynkColors.teal : const Color(0xFFE85D5D),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }
}

// Shared one-button success popup.
class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        width: 332,
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
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
                child: Icon(
                  icon,
                  size: 32,
                  color: iconColor,
                ),
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
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: Container(
                height: 56,
                alignment: Alignment.center,
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
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
