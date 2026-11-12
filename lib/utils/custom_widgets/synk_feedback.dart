import 'dart:async';
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
    return SynkDialog.confirm(
      context,
      icon: Icons.edit_off_rounded,
      title: context.l10n.discardChanges,
      action: context.l10n.discard,
    );
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

  // Lets a toast that a newer one replaces still say it ended.
  static VoidCallback? _toastEnded;

  // Slides a small banner down from the top, above sheets and dialogs.
  static void showToast(
    BuildContext context, {
    required String title,
    String? message,
    bool success = true,
  }) {
    _insertToast(context, title: title, message: message, success: success);
  }

  // The same banner with an Undo button. [UndoToast.closed] is true when
  // Undo was tapped, false when it went away any other way.
  static UndoToast showUndoToast(
    BuildContext context, {
    required String title,
    required String undoLabel,
  }) {
    final toast = UndoToast._();
    _insertToast(
      context,
      title: title,
      success: true,
      actionLabel: undoLabel,
      onAction: () => toast._finish(true),
      onEnded: () => toast._finish(false),
      register: (close) => toast._closer = close,
    );
    return toast;
  }

  static void _insertToast(
    BuildContext context, {
    required String title,
    String? message,
    required bool success,
    String? actionLabel,
    VoidCallback? onAction,
    VoidCallback? onEnded,
    ValueChanged<VoidCallback>? register,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      onEnded?.call();
      return;
    }

    final previous = _toast;
    final previousEnded = _toastEnded;
    _toast = null;
    _toastEnded = null;
    if (previous != null && previous.mounted) previous.remove();
    previousEnded?.call();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Toast(
        title: title,
        message: message,
        success: success,
        actionLabel: actionLabel,
        onAction: onAction,
        register: register,
        onDismissed: () {
          if (entry.mounted) entry.remove();
          if (_toast == entry) {
            _toast = null;
            _toastEnded = null;
          }
          onEnded?.call();
        },
      ),
    );
    _toast = entry;
    _toastEnded = onEnded;
    overlay.insert(entry);
  }

  // Shows a blocking error popup using the same card and button style.
  // [messageBuilder] replaces the plain [message], e.g. to add a link.
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? buttonLabel,
    Widget Function(BuildContext dialogContext)? messageBuilder,
    IconData icon = Icons.event_busy_rounded,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x6B1E1C24),
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: _SuccessDialog(
            title: title,
            message: message,
            messageWidget: messageBuilder?.call(dialogContext),
            buttonLabel: buttonLabel ?? context.l10n.gotIt,
            icon: icon,
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

// What [SynkFeedback.showUndoToast] returns.
class UndoToast {
  UndoToast._();

  final Completer<bool> _done = Completer();
  VoidCallback? _closer;

  Future<bool> get closed => _done.future;

  // Hides it now; counts as not undone.
  void close() {
    _finish(false);
    _closer?.call();
  }

  void _finish(bool undone) {
    if (!_done.isCompleted) _done.complete(undone);
  }
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.title,
    required this.message,
    required this.success,
    required this.onDismissed,
    this.actionLabel,
    this.onAction,
    this.register,
  });

  final String title;
  final String? message;
  final bool success;
  final VoidCallback onDismissed;
  final String? actionLabel;
  final VoidCallback? onAction;
  final ValueChanged<VoidCallback>? register;

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
    widget.register?.call(_close);
    // Longer messages stay a bit longer; Undo gets a steady 4 seconds.
    final length = widget.title.length + (widget.message?.length ?? 0);
    final ms = widget.actionLabel != null
        ? 4000
        : (1800 + length * 35).clamp(2500, 5000);
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
                    if (widget.actionLabel case final label?)
                      TextButton(
                        onPressed: () {
                          widget.onAction?.call();
                          _close();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: SynkColors.orangeDark,
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: Text(label),
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
    this.messageWidget,
    required this.buttonLabel,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
  });

  final String title;
  final String message;
  final Widget? messageWidget;
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
              child: DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: SynkColors.textSecondary,
                ),
                child: messageWidget ?? Text(message),
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
