import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/reset_password_controller.dart';
import '../core/constants/auth_constants.dart';
import '../core/constants/synk_colors.dart';
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

  // Live form status used by the indicators, the tile and the button.
  bool get _lengthOk => _controller.meetsMinimumLength(_passwordController.text);
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

    if (!_formKey.currentState!.validate()) {
      _shakeController.forward(from: 0);
      return;
    }

    final result = await _controller.updatePassword(_passwordController.text);
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
          _controller.errorMessage ?? 'Unable to update your password.',
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
      _showSnackBar('Password not changed.', success: false, neutral: true);
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
                          alignment: Alignment.centerLeft,
                          child: _linkExpired
                              ? const PuzzlePieceTile(
                                  state: PieceState.missing,
                                  badgeIcon: Icons.link_off_rounded,
                                  badgeColor: Color(0xFFE85D5D),
                                )
                              : PuzzlePieceTile(
                                  state: PieceState.almost,
                                  fit: _formReady ? 1.0 : (_lengthOk ? 0.5 : 0.0),
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
        const Text(
          'Create a new password',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: SynkColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Choose something you'll remember — and nobody else could guess.",
          style: TextStyle(fontSize: 15, color: SynkColors.textSecondary),
        ),
        const SizedBox(height: 36),

        // New password.
        _buildPasswordField(
          controller: _passwordController,
          hint: 'New password',
          icon: Icons.lock_outline,
          obscure: _obscurePassword,
          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          validator: _controller.validatePassword,
          autofillHint: AutofillHints.newPassword,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        _buildStatusLine(
          ok: _lengthOk,
          okText: 'At least ${AuthConstants.minPasswordLength} characters',
          pendingText: 'At least ${AuthConstants.minPasswordLength} characters',
        ),

        const SizedBox(height: 16),

        // Confirm password (shakes on mismatch).
        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final t = _shakeController.value;
            final dx = math.sin(t * math.pi * 4) * 4 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: _buildPasswordField(
            controller: _confirmController,
            hint: 'Confirm password',
            icon: Icons.lock_reset_rounded,
            obscure: _obscureConfirm,
            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
            validator: (value) => _controller.validateConfirmPassword(
              value,
              _passwordController.text,
            ),
            autofillHint: AutofillHints.newPassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleUpdate(),
          ),
        ),
        const SizedBox(height: 12),
        if (_confirmController.text.isNotEmpty)
          _buildStatusLine(
            ok: _matchOk,
            okText: 'Passwords match',
            pendingText: "Passwords don't match yet",
          ),

        const SizedBox(height: 28),

        // Enabled only once both fields are valid and matching.
        ElevatedButton(
          onPressed: (_controller.isLoading || !_formReady) ? null : _handleUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: SynkColors.orangeDark,
            disabledBackgroundColor:
                SynkColors.orangeDark.withValues(alpha: 0.6),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: _controller.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Update password',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),

        const SizedBox(height: 16),

        Center(
          child: TextButton(
            onPressed: _controller.isLoading ? null : () => _cancelToLogin(),
            child: const Text(
              'Back to Log In',
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
    required FormFieldValidator<String> validator,
    required String autofillHint,
    required TextInputAction textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      enabled: !_controller.isLoading,
      autofillHints: [autofillHint],
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      // Rebuilds the live indicators and the tile as the user types.
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: SynkColors.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: SynkColors.textSecondary),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: SynkColors.textSecondary),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: SynkColors.textSecondary,
          ),
          onPressed: onToggle,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: SynkColors.orange, width: 1.5),
        ),
      ),
    );
  }

  // Teal check when satisfied, quiet grey while still typing (never red).
  Widget _buildStatusLine({
    required bool ok,
    required String okText,
    required String pendingText,
  }) {
    final color = ok ? SynkColors.teal : SynkColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            ok ? okText : pendingText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
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
        const Text(
          'This link has expired',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: SynkColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Reset links can only be used once and expire after a short time. Request a fresh one and we'll get you back in.",
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
          child: const Text(
            'Request a new link',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 16),

        Center(
          child: TextButton(
            onPressed: () => _cancelToLogin(notify: false),
            child: const Text(
              'Back to Log In',
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