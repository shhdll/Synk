import 'package:flutter/material.dart';

import '../../controllers/signup_controller.dart';
import '../../controllers/onboarding_controller.dart';
import '../../core/constants/synk_colors.dart';
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
  final FocusNode _usernameFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _usernameFocusNode.addListener(_onUsernameFocusChange);
  }

  void _onUsernameFocusChange() {
    if (!_usernameFocusNode.hasFocus) {
      widget.signupController.checkUsernameAvailability();
    }
  }

  @override
  void dispose() {
    _usernameFocusNode.removeListener(_onUsernameFocusChange);
    _usernameFocusNode.dispose();
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
                const SizedBox(height: 16),
                const Text(
                  'Create your\naccount.',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -1.5,
                    color: SynkColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter your credentials to complete sign up.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 28),

                // Username
                _buildField(
                  controller: signupController.usernameController,
                  focusNode: _usernameFocusNode,
                  label: 'Username',
                  hint: 'Username',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.text,
                  errorText: signupController.usernameError,
                  onChanged: (_) => signupController.clearUsernameError(),
                ),
                const SizedBox(height: 14),

                // Email
                _buildField(
                  controller: signupController.emailController,
                  label: 'Email',
                  hint: 'Email address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  errorText: signupController.emailError,
                  onChanged: (_) => signupController.clearEmailError(),
                ),
                const SizedBox(height: 14),

                // Password
                _buildField(
                  controller: signupController.passwordController,
                  label: 'Password',
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  errorText: signupController.passwordError,
                  onChanged: (_) => signupController.clearPasswordError(),
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
                const SizedBox(height: 14),

                // Confirm Password
                _buildField(
                  controller: signupController.confirmPasswordController,
                  label: 'Confirm Password',
                  hint: 'Re-type password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirmPassword,
                  errorText: signupController.confirmPasswordError,
                  onChanged: (_) =>
                      signupController.clearConfirmPasswordError(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
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

                const SizedBox(height: 28),

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
                            if (res?.user != null && context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const MainShell(isNewUser: true),
                                ),
                                (route) => false,
                              );
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
                const SizedBox(height: 120),
              ],
            );
          },
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
}
