import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/auth_constants.dart';
import '../../../core/constants/synk_colors.dart';

import '../../../l10n/l10n.dart';
import '../../../models/auth_model.dart';

/// Modal bottom sheet allowing users to request a change of their email address,
/// resend confirmation for a pending email change, or cancel a pending request.
class ChangeEmailBottomSheet extends StatefulWidget {
  final String currentEmail;
  final String? pendingEmail;
  final AuthModel? authModel;

  const ChangeEmailBottomSheet({
    super.key,
    required this.currentEmail,
    this.pendingEmail,
    this.authModel,
  });

  /// Convenient helper to present the bottom sheet modal.
  static Future<bool?> show(
    BuildContext context, {
    required String currentEmail,
    String? pendingEmail,
    AuthModel? authModel,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChangeEmailBottomSheet(
        currentEmail: currentEmail,
        pendingEmail: pendingEmail,
        authModel: authModel,
      ),
    );
  }

  @override
  State<ChangeEmailBottomSheet> createState() => _ChangeEmailBottomSheetState();
}

class _ChangeEmailBottomSheetState extends State<ChangeEmailBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _newEmailController;
  late final AuthModel _authModel;

  bool _isLoading = false;
  bool _isEditingNew = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authModel = widget.authModel ?? AuthModel();
    _newEmailController = TextEditingController();
    _isEditingNew = widget.pendingEmail == null || widget.pendingEmail!.isEmpty;
  }

  @override
  void dispose() {
    _newEmailController.dispose();
    super.dispose();
  }

  // Closes the sheet and shows [message] on the page underneath.
  void _closeWith(String message) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(true);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: SynkColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Runs [action] with the loading state, showing [fallbackError] if it
  // fails with anything other than an AuthException.
  Future<void> _run(
    Future<void> Function() action,
    String fallbackError,
  ) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await action();
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = fallbackError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSendLink() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final newEmail = _newEmailController.text.trim();
    await _run(() async {
      await _authModel.updateEmail(newEmail);
      if (mounted) _closeWith(context.l10n.linkSentCheckYourNewEmail);
    }, context.l10n.unableToUpdateEmailPleaseTry);
  }

  Future<void> _handleResend() async {
    final targetEmail = widget.pendingEmail;
    if (targetEmail == null || targetEmail.isEmpty) return;

    await _run(() async {
      await _authModel.updateEmail(targetEmail);
      if (mounted) _closeWith(context.l10n.linkSentAgain);
    }, context.l10n.failedToResendConfirmationEmail);
  }

  Future<void> _handleCancelRequest() async {
    final targetToCancel = widget.pendingEmail ??
        Supabase.instance.client.auth.currentUser?.newEmail ??
        '';

    await _run(() async {
      await _authModel.cancelEmailChange(targetToCancel);
      if (mounted) _closeWith(context.l10n.pendingEmailChangeCancelled);
    }, context.l10n.failedToCancelEmailChangeRequest);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasPending = widget.pendingEmail != null &&
        widget.pendingEmail!.isNotEmpty &&
        !_isEditingNew;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: const BoxDecoration(
          color: SynkColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag indicator
                Center(
                  child: Container(
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: SynkColors.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  hasPending
                      ? context.l10n.confirmYourNewEmail
                      : context.l10n.changeEmail,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: SynkColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                if (hasPending)
                  _buildPendingContent()
                else
                  _buildNewEmailForm(),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: SynkColors.orangeDark,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  Widget _buildPendingContent() {
    // Split the sentence around the address so it can be bold.
    const marker = '\u0000';
    final parts = context.l10n.openTheLinkWeSentTo(marker).split(marker);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: SynkColors.textPrimary,
            ),
            children: [
              TextSpan(text: parts.first),
              TextSpan(
                // Isolated so the address reads left to right
                // inside an Arabic sentence.
                text: '\u2068${widget.pendingEmail}\u2069',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (parts.length > 1) TextSpan(text: parts.last),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildPrimaryButton(context.l10n.resendLink, _handleResend),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _isEditingNew = true),
                style: TextButton.styleFrom(
                  foregroundColor: SynkColors.textSecondary,
                ),
                child: Text(
                  context.l10n.useADifferentEmailAddress,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: _isLoading ? null : _handleCancelRequest,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                ),
                child: Text(
                  context.l10n.cancelEmailChange,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNewEmailForm() {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _newEmailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleSendLink(),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return context.l10n.pleaseEnterANewEmailAddress;
              }
              if (!AuthConstants.emailRegex.hasMatch(trimmed)) {
                return context.l10n.profileEmailInvalid;
              }
              if (trimmed.toLowerCase() == widget.currentEmail.toLowerCase()) {
                return context.l10n.newEmailMustBeDifferentFrom;
              }
              return null;
            },
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: SynkColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: context.l10n.enterNewEmailAddress,
              hintStyle: TextStyle(
                color: SynkColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              border: border(Colors.transparent, 0),
              enabledBorder: border(Colors.transparent, 0),
              focusedBorder: border(SynkColors.orange, 1.5),
              errorBorder: border(Colors.redAccent, 1.2),
              focusedErrorBorder: border(Colors.redAccent, 1.5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Outside the field so it lines up with the text above, not the
          // field's inner padding.
          Text(
            context.l10n.weWillSendALinkToConfirm,
            style: const TextStyle(
              fontSize: 13,
              color: SynkColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          _buildPrimaryButton(context.l10n.sendLink, _handleSendLink),
        ],
      ),
    );
  }
}
