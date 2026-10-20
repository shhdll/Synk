import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/reset_password_controller.dart';
import '../core/constants/synk_colors.dart';
import '../l10n/l10n.dart';
import '../utils/custom_widgets/puzzle_piece_tile.dart';
import 'widgets/reset_link_info_row.dart';
import 'widgets/synk_blob_background.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key, this.initialEmail = ''});

  /// Pre-fills the email field with whatever the user typed on Login.
  final String initialEmail;

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView>
    with SingleTickerProviderStateMixin {
  // Identifies the form and provides access to its validation state.
  final _formKey = GlobalKey<FormState>();

  // Handles reset requests and their state.
  final ResetPasswordController _controller = ResetPasswordController();

  late final TextEditingController _emailController;

  // Drives the small horizontal shake shown on a validation error.
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _handleSend() async {
    FocusScope.of(context).unfocus();

    // Stops the request when the email is empty or malformed.
    if (!_formKey.currentState!.validate()) {
      _shakeController.forward(from: 0);
      return;
    }

    final success = await _controller.sendResetLink(_emailController.text);

    // Prevents the screen from updating after it has been removed.
    if (!mounted) return;

    if (!success) {
      _showSnackBar(
        _controller.errorMessage ?? context.l10n.unableToSendTheLink,
        success: false,
      );
    }
  }

  Future<void> _handleResend() async {
    final success = await _controller.resendLink();
    if (!mounted) return;

    _showSnackBar(
      success
          ? context.l10n.aNewLinkIsOnIts
          : _controller.errorMessage ?? context.l10n.unableToSendTheLink,
      success: success,
    );
  }

  void _showSnackBar(String message, {required bool success}) {
    // Same floating snackbar style as the Login screen.
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SynkColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: SynkBlobBackground()),
          SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final sent = _controller.emailSent;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      _buildHeader(),
                      const SizedBox(height: 40),

                      // Motif: missing → sending → sent.
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: PuzzlePieceTile(
                          state: sent
                              ? PieceState.sent
                              : _controller.isLoading
                              ? PieceState.sending
                              : PieceState.missing,
                          badgeIcon: sent
                              ? Icons.mark_email_read_rounded
                              : null,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Heading + supporting copy cross-fade between states.
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: sent ? _buildSentIntro() : _buildFormIntro(),
                      ),
                      const SizedBox(height: 36),

                      // Body morphs between the form and the sent card.
                      AnimatedSize(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.04),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: sent
                              ? _buildSentBody(key: const ValueKey('sent'))
                              : _buildFormBody(key: const ValueKey('form')),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }

  // Back button and application branding (same as Login).
  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: SynkColors.textPrimary,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/synk_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.all_inclusive_rounded,
                color: SynkColors.orange,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Synk',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            color: SynkColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // State A: email form
  // ---------------------------------------------------------------------------

  Widget _buildFormIntro() {
    return Column(
      key: ValueKey('form-intro'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.forgotYourPassword,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: SynkColors.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          context.l10n.itHappensEnterYourEmailAnd,
          style: TextStyle(fontSize: 15, color: SynkColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildFormBody({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Email input field (shakes on a validation error).
        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final t = _shakeController.value;
            final dx = math.sin(t * math.pi * 4) * 4 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            enabled: !_controller.isLoading,
            onFieldSubmitted: (_) => _handleSend(),
            style: const TextStyle(color: SynkColors.textPrimary),
            validator: _controller.validateEmail,
            decoration: InputDecoration(
              hintText: context.l10n.emailAddress,
              hintStyle: const TextStyle(color: SynkColors.textSecondary),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(
                Icons.alternate_email_rounded,
                color: SynkColors.textSecondary,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 18,
                horizontal: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(
                  color: SynkColors.orange,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 28),

        _buildPrimaryButton(label: context.l10n.sendResetLink, onPressed: _handleSend),

        const SizedBox(height: 16),

        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.l10n.backToLogIn,
              style: TextStyle(
                color: SynkColors.orangeDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Explains why we never confirm whether an account exists.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            context.l10n.forYourSecurityWellSendA,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: SynkColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // State B: email sent
  // ---------------------------------------------------------------------------

  Widget _buildSentIntro() {
    return Column(
      key: const ValueKey('sent-intro'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.checkYourInbox,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: SynkColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.weSentAResetLinkTo,
          style: TextStyle(fontSize: 15, color: SynkColors.textSecondary),
        ),
        Text(
          _controller.sentToEmail,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: SynkColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSentBody({required Key key}) {
    final seconds = _controller.resendSecondsLeft;
    final canResend = _controller.canResend;

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // What to expect next.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              ResetLinkInfoRow(
                icon: Icons.link_rounded,
                text: context.l10n.theLinkCanOnlyBeUsed,
              ),
              SizedBox(height: 16),
              ResetLinkInfoRow(
                icon: Icons.phone_android_rounded,
                text: context.l10n.openItOnThisDeviceSo,
              ),
              SizedBox(height: 16),
              ResetLinkInfoRow(
                icon: Icons.forward_to_inbox_rounded,
                text: context.l10n.notThereCheckYourSpamFolder,
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        _buildPrimaryButton(
          label: context.l10n.backToLogIn,
          onPressed: () => Navigator.pop(context),
        ),

        const SizedBox(height: 16),

        // Resend, gated by the cooldown.
        Center(
          child: TextButton(
            onPressed: canResend ? _handleResend : null,
            child: Text(
              canResend
                  ? context.l10n.resendLink
                  : context.l10n.resendLinkCountdown(
                      seconds.toString().padLeft(2, '0'),
                    ),
              style: TextStyle(
                color: canResend
                    ? SynkColors.orangeDark
                    : SynkColors.textSecondary,
                fontWeight: canResend ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ),

        Center(
          child: TextButton(
            onPressed: _controller.editEmail,
            child: Text(
              context.l10n.wrongEmailEditIt,
              style: TextStyle(
                fontSize: 13,
                color: SynkColors.orangeDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Shared pieces
  // ---------------------------------------------------------------------------

  // Same button as Login: flat orangeDark pill, spinner while loading.
  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    final loading = _controller.isLoading;

    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: SynkColors.orangeDark,
        disabledBackgroundColor: SynkColors.orangeDark.withValues(alpha: 0.6),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}
