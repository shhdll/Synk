import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/support_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';

// Shown when login fails because the account was suspended from the admin
// dashboard. They can't sign in, so the message goes to support by email.
Future<void> showSuspendedAccountSheet({
  required BuildContext context,
  required String email,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SuspendedAccountSheet(email: email),
  );
}

class _SuspendedAccountSheet extends StatefulWidget {
  const _SuspendedAccountSheet({required this.email});

  final String email;

  @override
  State<_SuspendedAccountSheet> createState() => _SuspendedAccountSheetState();
}

class _SuspendedAccountSheetState extends State<_SuspendedAccountSheet> {
  final SupportModel _support = SupportModel();
  final TextEditingController _message = TextEditingController();
  bool _isSending = false;

  bool get _canSend =>
      !_isSending && widget.email.isNotEmpty && _message.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_canSend) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSending = true);

    String? version;
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version} (${info.buildNumber})';
    } catch (_) {}

    final sent = await _support.sendAppeal(
      email: widget.email,
      message: _message.text,
      appVersion: version,
    );
    if (!mounted) return;

    final l10n = context.l10n;
    if (!sent) {
      setState(() => _isSending = false);
      SynkFeedback.showError(context, l10n.somethingWentWrongPleaseTryAgain);
      return;
    }
    SynkFeedback.showToast(context, title: l10n.suspendedSent);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: SynkColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + media.padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: SynkColors.textSecondary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.suspendedTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: SynkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.suspendedMessage(widget.email),
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: SynkColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _message,
              enabled: !_isSending,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: SynkColors.textPrimary,
              ),
              cursorColor: SynkColors.orangeDark,
              decoration: InputDecoration(
                hintText: l10n.suspendedMessageHint,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.78),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: SynkColors.orangeDark,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _canSend ? _send : null,
                style: FilledButton.styleFrom(
                  backgroundColor: SynkColors.orangeDark,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: SynkColors.orangeDark.withValues(
                    alpha: 0.45,
                  ),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l10n.contactSupport,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
