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

  @override
  void initState() {
    super.initState();
    // Checks uniqueness the moment the user finishes typing and leaves the box
    _usernameFocusNode.addListener(() {
      if (!_usernameFocusNode.hasFocus) {
        widget.signupController.checkUsernameAvailability();
      }
    });
  }

  @override
  void dispose() {
    _usernameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: ListenableBuilder(
          listenable: widget.signupController,
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
                  controller: widget.signupController.usernameController,
                  focusNode: _usernameFocusNode,
                  label: 'Username',
                  hint: 'e.g. johndoe',
                  icon: Icons.person_outline_rounded,
                  errorText: widget.signupController.usernameError,
                  onChanged: (_) =>
                      widget.signupController.clearUsernameError(),
                ),
                const SizedBox(height: 14),

                // Email
                _buildField(
                  controller: widget.signupController.emailController,
                  label: 'Email',
                  hint: 'name@example.com',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  errorText: widget.signupController.emailError,
                  onChanged: (_) => widget.signupController.clearEmailError(),
                ),
                const SizedBox(height: 14),

                // Password
                _buildField(
                  controller: widget.signupController.passwordController,
                  label: 'Password',
                  hint: 'Min. 6 characters',
                  icon: Icons.lock_outline_rounded,
                  obscureText: widget.signupController.obscurePassword,
                  errorText: widget.signupController.passwordError,
                  onChanged: (_) =>
                      widget.signupController.clearPasswordError(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      widget.signupController.obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: widget.signupController.toggleObscurePassword,
                  ),
                ),
                const SizedBox(height: 14),

                // Confirm Password
                _buildField(
                  controller: widget.signupController.confirmPasswordController,
                  label: 'Confirm Password',
                  hint: 'Re-type password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: widget.signupController.obscurePassword,
                  errorText: widget.signupController.confirmPasswordError,
                  onChanged: (_) =>
                      widget.signupController.clearConfirmPasswordError(),
                ),

                if (widget.signupController.generalError != null) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      widget.signupController.generalError!,
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
                    onPressed: widget.signupController.isLoading
                        ? null
                        : () async {
                            final res = await widget.signupController
                                .registerUser(
                                  onboardingPreferences: widget
                                      .onboardingController
                                      .onboardingData,
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
                    child: widget.signupController.isLoading
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
              prefixIcon: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
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
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE53935),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
