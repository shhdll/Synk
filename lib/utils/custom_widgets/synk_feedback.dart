import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import 'synk_dialog.dart';

// Shared feedback for edit screens, so every page that saves something
// confirms and reports it the same way.
class SynkFeedback {
  SynkFeedback._();

  // Asks before leaving a screen with unsaved changes.
  // Resolves to true when the user chose to discard and leave.
  static Future<bool> confirmDiscardChanges(BuildContext context) async {
    final SynkDialogAction? action = await SynkDialog.destructive(
      icon: Icons.edit_off_rounded,
      title: context.l10n.discardChanges,
      message: context.l10n.unsavedChangesWillBeLost,
      primaryLabel: context.l10n.keepEditing,
      secondaryLabel: context.l10n.discardAndLeave,
    ).show(context, barrierDismissible: false);

    return action == SynkDialogAction.secondary;
  }

  // Shows "Saved", with an extra line only when there is more to say.
  static Future<void> showSaved(BuildContext context, {String? message}) async {
    showToast(context, title: context.l10n.saved, message: message);
  }

  // Confirms a finished action with a banner that hides itself, so the
  // user doesn't have to tap anything. Returns right away.
  static Future<void> showSuccessDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    showToast(context, title: title, message: message);
  }

  static OverlayEntry? _toast;

  // Slides a small banner down from the top, above sheets and dialogs.
  static void showToast(
    BuildContext context, {
    required String title,
    String? message,
    bool success = true,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final previous = _toast;
    if (previous != null && previous.mounted) previous.remove();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Toast(
        title: title,
        message: message,
        success: success,
        onDismissed: () {
          if (entry.mounted) entry.remove();
          if (_toast == entry) _toast = null;
        },
      ),
    );
    _toast = entry;
    overlay.insert(entry);
  }

  // Shows a blocking error popup using the same card and button style.
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? buttonLabel,
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
            buttonLabel: buttonLabel ?? context.l10n.gotIt,
            icon: Icons.event_busy_rounded,
            iconBackground: const Color(0x24FF7A36),
            iconColor: SynkColors.orangeDark,
          ),
        );
      },
    );
  }

  static void showError(BuildContext context, String message) {
    showToast(context, title: message, success: false);
  }
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.title,
    required this.message,
    required this.success,
    required this.onDismissed,
  });

  final String title;
  final String? message;
  final bool success;
  final VoidCallback onDismissed;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -1.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    // Longer messages stay a bit longer.
    final length = widget.title.length + (widget.message?.length ?? 0);
    final ms = (1800 + length * 35).clamp(2500, 5000);
    Future.delayed(Duration(milliseconds: ms), _close);
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.success ? SynkColors.teal : const Color(0xFFE53935);
    final message = widget.message;

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _controller,
          child: GestureDetector(
            onTap: _close,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) < 0) _close();
            },
            child: Material(
              color: Colors.white,
              elevation: 0,
              borderRadius: BorderRadius.circular(18),
              shadowColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 16, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.success
                            ? Icons.check_rounded
                            : Icons.priority_high_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: SynkColors.textPrimary,
                            ),
                          ),
                          if (message != null && message.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              message,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                color: SynkColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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
