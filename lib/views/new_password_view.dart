import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/reset_password_controller.dart';
import '../core/constants/synk_colors.dart';
import '../l10n/l10n.dart';
import '../utils/custom_widgets/puzzle_piece_tile.dart';
import 'forgot_password_view.dart';
import 'login_view.dart';
import 'reset_success_view.dart';

class NewPasswordView extends StatefulWidget {
  const NewPasswordView({super.key, this.linkExpired = false});

  /// Opens directly in the "link expired" state (set by the auth listener
  /// when the recovery link could not be exchanged for a session).
  final bool linkExpired;

  @override
  State<NewPasswordView> createState() => _NewPasswordViewState();
}

class _NewPasswordViewState extends State<NewPasswordView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ResetPasswordController _controller = ResetPasswordController();

  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  late bool _linkExpired;

  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _linkExpired = widget.linkExpired;
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  String? _passwordError;
  String? _confirmPasswordError;

  // Live form status used by the tile.
  bool get _lengthOk =>
      _controller.meetsMinimumLength(_passwordController.text);
  bool get _matchOk => _controller.passwordsMatch(
    _passwordController.text,
    _confirmController.text,
  );
  bool get _formReady => _lengthOk && _matchOk;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _handleUpdate() async {
    FocusScope.of(context).unfocus();

    final password = _passwordController.text;
    final confirm = _confirmController.text;

    final pErr = _controller.validatePassword(password);
    final cErr = _controller.validateConfirmPassword(confirm, password);

    setState(() {
      _passwordError = pErr;
      _confirmPasswordError = cErr;
    });

    if (pErr != null || cErr != null) {
      _shakeController.forward(from: 0);
      return;
    }

    final result = await _controller.updatePassword(password);
    if (!mounted) return;

    switch (result) {
      case UpdatePasswordResult.success:
        // Ends the recovery session so the user logs in with the new password.
        await _controller.endRecoverySession();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ResetSuccessView()),
          (route) => route.isFirst,
        );
        break;

      case UpdatePasswordResult.sessionMissing:
        setState(() => _linkExpired = true);
        break;

      case UpdatePasswordResult.failure:
        _showSnackBar(
          _controller.errorMessage ?? context.l10n.unableToUpdateYourPassword,
          success: false,
        );
        break;
    }
  }

  // Leaves without changing the password (hardware back / "Back to Log In").
  Future<void> _cancelToLogin({bool notify = true}) async {
    await _controller.endRecoverySession();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginView()),
      (route) => route.isFirst,
    );

    if (notify) {
      // The root ScaffoldMessenger survives navigation, so this shows on Login.
      _showSnackBar(
        context.l10n.passwordNotChanged,
        success: false,
        neutral: true,
      );
    }
  }

  void _requestNewLink() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ForgotPasswordView()),
    );
  }

  void _showSnackBar(
    String message, {
    required bool success,
    bool neutral = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success
                    ? Icons.check_circle_outline
                    : neutral
                    ? Icons.info_outline
                    : Icons.error_outline,
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
          backgroundColor: success
              ? SynkColors.teal
              : neutral
              ? SynkColors.textSecondary
              : const Color(0xFFE85D5D),
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelToLogin();
      },
      child: Scaffold(
        backgroundColor: SynkColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        _buildHeader(),
                        const SizedBox(height: 40),

                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _linkExpired
                              ? const PuzzlePieceTile(
                                  state: PieceState.missing,
                                  badgeIcon: Icons.link_off_rounded,
                                  badgeColor: Color(0xFFE85D5D),
                                )
                              : PuzzlePieceTile(
                                  state: PieceState.almost,
                                  fit: _formReady
                                      ? 1.0
                                      : (_lengthOk ? 0.5 : 0.0),
                                ),
                        ),
                        const SizedBox(height: 20),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _linkExpired
                              ? _buildExpired(key: const ValueKey('expired'))
                              : _buildForm(key: const ValueKey('form')),
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
      ),
    );
  }

  // Logo tile + wordmark. No back arrow: back is handled by PopScope.
  Widget _buildHeader() {
    return Row(
      children: [
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
  // State C: new password form
  // ---------------------------------------------------------------------------

  Widget _buildForm({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.createANewPassword,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: SynkColors.textPrimary,
          ),
        ),

        const SizedBox(height: 28),

        // New password
        _buildField(
          controller: _passwordController,
          label: context.l10n.password,
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          errorText: _passwordError,
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            if (_passwordError != null) {
              setState(() => _passwordError = null);
            }
          },
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: const Color(0xFF6B7280),
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 14),

        // Confirm password (shakes on mismatch or error)
        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final t = _shakeController.value;
            final dx = math.sin(t * math.pi * 4) * 4 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: _buildField(
            controller: _confirmController,
            label: context.l10n.confirmPassword,
            hint: context.l10n.reTypePassword,
            icon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirm,
            errorText: _confirmPasswordError,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleUpdate(),
            onChanged: (_) {
              if (_confirmPasswordError != null) {
                setState(() => _confirmPasswordError = null);
              }
            },
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: const Color(0xFF6B7280),
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Update password button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _controller.isLoading ? null : _handleUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6F43),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _controller.isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    context.l10n.updatePassword,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 16),

        Center(
          child: TextButton(
            onPressed: _controller.isLoading ? null : () => _cancelToLogin(),
            child: Text(
              context.l10n.backToLogIn,
              style: TextStyle(
                color: SynkColors.orangeDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? errorText,
    ValueChanged<String>? onChanged,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: errorText != null
                ? Border.all(color: const Color(0xFFE53935), width: 1.2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            onChanged: onChanged,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1E1E),
            ),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
                child: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              labelText: label,
              labelStyle: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              errorText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: Color(0xFFE53935),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // State D: link expired / invalid
  // ---------------------------------------------------------------------------

  Widget _buildExpired({required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.thisLinkHasExpired,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: SynkColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.resetLinksCanOnlyBeUsed,
          style: TextStyle(fontSize: 15, color: SynkColors.textSecondary),
        ),
        const SizedBox(height: 36),

        ElevatedButton(
          onPressed: _requestNewLink,
          style: ElevatedButton.styleFrom(
            backgroundColor: SynkColors.orangeDark,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Text(
            context.l10n.requestANewLink,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 16),

        Center(
          child: TextButton(
            onPressed: () => _cancelToLogin(notify: false),
            child: Text(
              context.l10n.backToLogIn,
              style: TextStyle(
                color: SynkColors.orangeDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
