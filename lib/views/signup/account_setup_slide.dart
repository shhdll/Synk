import 'package:flutter/material.dart';

import '../../controllers/signup_controller.dart';
import '../../controllers/onboarding_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../widgets/password_requirements.dart';
import '../widgets/bottom_fade.dart';

class AccountSetupSlide extends StatefulWidget {
  final SignupController signupController;
  final OnboardingController onboardingController;

  const AccountSetupSlide({
    super.key,
    required this.signupController,
    required this.onboardingController,
  });

  @override
  State<AccountSetupSlide> createState() => _AccountSetupSlideState();
}

class _AccountSetupSlideState extends State<AccountSetupSlide> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signupController = widget.signupController;

    return SafeArea(
      child: BottomFade(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            28,
            0,
            28,
            BottomFade.scrollPadding,
          ),
          child: ListenableBuilder(
            listenable: signupController,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.createYourAccount,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      letterSpacing: -1.3,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Username
                  _buildField(
                    controller: signupController.usernameController,
                    focusNode: signupController.usernameFocusNode,
                    label: context.l10n.username,
                    hint: context.l10n.username,
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.text,
                    errorText: signupController.usernameError,
                    onChanged: (_) => signupController.onUsernameChanged(),
                  ),
                  const SizedBox(height: 10),

                  // Email
                  _buildField(
                    controller: signupController.emailController,
                    focusNode: signupController.emailFocusNode,
                    label: context.l10n.email,
                    hint: context.l10n.emailAddress,
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    errorText: signupController.emailError,
                    onChanged: (_) => signupController.onEmailChanged(),
                  ),
                  const SizedBox(height: 10),

                  // Password
                  _buildField(
                    controller: signupController.passwordController,
                    focusNode: signupController.passwordFocusNode,
                    label: context.l10n.password,
                    hint: '••••••••',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    errorText: signupController.passwordError,
                    onChanged: (_) {
                      signupController.clearPasswordError();
                      setState(() {});
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Confirm Password
                  _buildField(
                    controller: signupController.confirmPasswordController,
                    focusNode: signupController.confirmPasswordFocusNode,
                    label: context.l10n.confirmPassword,
                    hint: context.l10n.reTypePassword,
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscureConfirmPassword,
                    errorText: signupController.confirmPasswordError,
                    onChanged: (_) {
                      signupController.clearConfirmPasswordError();
                      setState(() {});
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  PasswordRequirements(
                    password: signupController.passwordController.text,
                  ),

                  if (signupController.generalError != null) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        signupController.generalError!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE53935),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
    bool obscureText = false,
    Widget? suffixIcon,
    String? errorText,
    ValueChanged<String>? onChanged,
    TextInputType keyboardType = TextInputType.text,
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
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            onChanged: onChanged,
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
              label: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: label),
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: Color(0xFFE53935)),
                    ),
                  ],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
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
}
