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

  Future<void> _handleSendVerification() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newEmail = _newEmailController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authModel.updateEmail(newEmail);

      if (!mounted) return;

      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.confirmationLinkSentPleaseCheckBoth,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: SynkColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 5),
        ),
      );
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = context.l10n.unableToUpdateEmailPleaseTry;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResendConfirmation() async {
    final targetEmail = widget.pendingEmail;
    if (targetEmail == null || targetEmail.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authModel.updateEmail(targetEmail);

      if (!mounted) return;

      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.confirmationLinksResentCheckYourInboxes,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: SynkColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 4),
        ),
      );
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = context.l10n.failedToResendConfirmationEmail;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleCancelRequest() async {
    final targetToCancel = widget.pendingEmail ??
        Supabase.instance.client.auth.currentUser?.newEmail ??
        '';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authModel.cancelEmailChange(targetToCancel);

      if (!mounted) return;

      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.pendingEmailChangeCancelled,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: SynkColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      setState(() {
        _errorMessage = context.l10n.failedToCancelEmailChangeRequest;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        decoration: const BoxDecoration(
          color: SynkColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
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
              const SizedBox(height: 18),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBD4B4).withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.alternate_email_rounded,
                      size: 22,
                      color: SynkColors.orangeDark,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasPending ? context.l10n.pendingEmailChange : context.l10n.changeEmail,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: SynkColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasPending
                              ? context.l10n.confirmationIsCurrentlyInProgress
                              : context.l10n.updateYourLoginAndContactEmail,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: SynkColors.textSecondary.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Current Email Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: SynkColors.textSecondary.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.mail_outline_rounded,
                      size: 18,
                      color: SynkColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.l10n.currentEmailLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.currentEmail,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: SynkColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 18, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              if (hasPending)
                _buildPendingContent()
              else
                _buildNewEmailForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pending Status Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFBD4B4).withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFFF9F5C).withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: SynkColors.orangeDark,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.awaitingConfirmation,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  // Split the sentence around the address so it can be bold.
                  const marker = '\u0000';
                  final parts = context.l10n
                      .changeLinkSentTo(marker)
                      .split(marker);
                  return Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: SynkColors.textPrimary.withValues(alpha: 0.9),
                        height: 1.4,
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
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Resend confirmation action
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleResendConfirmation,
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
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        context.l10n.resendConfirmationLinks,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),

        // Cancel Request button
        SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _handleCancelRequest,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: BorderSide(
                color: Colors.redAccent.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              context.l10n.cancelEmailChange,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Or enter a different email address
        TextButton(
          onPressed: () {
            setState(() {
              _isEditingNew = true;
            });
          },
          style: TextButton.styleFrom(
            foregroundColor: SynkColors.textSecondary,
          ),
          child: Text(
            context.l10n.useADifferentEmailAddress,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewEmailForm() {
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
              prefixIcon: const Icon(
                Icons.mark_email_unread_outlined,
                color: SynkColors.textSecondary,
                size: 20,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: SynkColors.orange,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Helper note
          Text(
            context.l10n.confirmationEmailsWillBeSentTo,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: SynkColors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 22),

          // Actions
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SynkColors.textSecondary,
                      side: BorderSide(
                        color: SynkColors.textSecondary.withValues(alpha: 0.25),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      context.l10n.cancel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSendVerification,
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
                            context.l10n.sendVerification,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
