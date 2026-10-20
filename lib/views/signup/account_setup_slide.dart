import 'package:flutter/material.dart';

import '../../controllers/signup_controller.dart';
import '../../controllers/onboarding_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../screens/auth/email_verification_screen.dart';
import '../home/main_shell.dart';

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
    final onboardingController = widget.onboardingController;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: ListenableBuilder(
          listenable: signupController,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Create your\naccount.',
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
                  label: 'Username',
                  hint: 'Username',
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
                  label: 'Email',
                  hint: 'Email address',
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
                  label: 'Password',
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
                  label: 'Confirm Password',
                  hint: 'Re-type password',
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
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildPasswordRequirements(signupController),

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

                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6F43),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: signupController.isLoading
                        ? null
                        : () async {
                            final res = await signupController.registerUser(
                              onboardingPreferences:
                                  onboardingController.onboardingData,
                              context: context,
                            );
                            if (res == null || !context.mounted) {
                              return;
                            }
                            if (res.user != null) {
                              final user = res.user;
                              final isConfirmed =
                                  res.session != null &&
                                  user != null &&
                                  user.emailConfirmedAt != null &&
                                  user.emailConfirmedAt!.isNotEmpty;

                              if (isConfirmed) {
                                // Direct entry if confirmation is turned off or auto-confirmed
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const MainShell(isNewUser: true),
                                  ),
                                  (route) => false,
                                );
                              } else {
                                // Email confirmation is required
                                final cleanEmail = signupController
                                    .emailController
                                    .text
                                    .trim();
                                final password =
                                    signupController.passwordController.text;
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        EmailVerificationScreen(
                                          email: cleanEmail,
                                          password: password,
                                        ),
                                  ),
                                  (route) => false,
                                );
                              }
                            }
                          },
                    child: signupController.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Complete Registration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPasswordRequirements(SignupController signupController) {
    final password = signupController.passwordController.text;
    final rules = [
      _PasswordRequirement(text: '8+ characters', met: password.length >= 8),
      _PasswordRequirement(
        text: 'Uppercase letter',
        met: RegExp(r'[A-Z]').hasMatch(password),
      ),
      _PasswordRequirement(
        text: 'Lowercase letter',
        met: RegExp(r'[a-z]').hasMatch(password),
      ),
      _PasswordRequirement(
        text: 'A number',
        met: RegExp(r'[0-9]').hasMatch(password),
      ),
      _PasswordRequirement(
        text: 'Special character',
        met: RegExp(r'[@$!%*?&_\-#^~+=<>.,:;/\\]|[^a-zA-Z0-9]')
            .hasMatch(password),
      ),
    ];

    // Two columns so the button fits without scrolling.
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 8),
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          children: [
            for (final rule in rules)
              SizedBox(width: constraints.maxWidth / 2, child: rule),
          ],
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
                padding: const EdgeInsets.only(left: 14, right: 8),
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

class _PasswordRequirement extends StatelessWidget {
  const _PasswordRequirement({required this.text, required this.met});

  final String text;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met ? SynkColors.teal : const Color(0xFF9CA3AF);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
