import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'forgot_password_view.dart';
import 'home/main_shell.dart';

import '../controllers/login_controller.dart';
import '../core/constants/auth_constants.dart';
import '../core/constants/synk_colors.dart';
import '../screens/auth/email_verification_screen.dart';
import 'widgets/synk_blob_background.dart';
import 'widgets/synk_input_decoration.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  // Identifies the form and provides access to its validation state.
  final _formKey = GlobalKey<FormState>();

  // Handles login requests and authentication state.
  final LoginController _loginController = LoginController();

  // Controls whether user logs in via username or email.
  bool _loginWithUsernameMode = true;

  // Stores the values entered in the respective input fields.
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Controls whether the password is hidden or visible.
  bool _obscurePassword = true;

  // Errors from the server, shown under the field they belong to until the
  // user edits it.
  String? _identifierServerError;
  String? _passwordServerError;

  @override
  void dispose() {
    // Releases the controllers when the screen is removed.
    _loginController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearServerErrors() {
    if (_identifierServerError == null && _passwordServerError == null) {
      return;
    }
    setState(() {
      _identifierServerError = null;
      _passwordServerError = null;
    });
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    _identifierServerError = null;
    _passwordServerError = null;

    // Stops the login request when any field is invalid.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final bool success;
    // An email typed into the username tab still works.
    if (_loginWithUsernameMode && !username.contains('@')) {
      success = await _loginController.loginWithUsername(
        username: username,
        password: password,
      );
    } else {
      success = await _loginController.loginWithEmail(
        email: _loginWithUsernameMode ? username : _emailController.text.trim(),
        password: password,
      );
    }

    // Prevents the screen from updating after it has been removed.
    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainShell()),
        (route) => false,
      );
      return;
    }

    switch (_loginController.errorType) {
      case LoginErrorType.noAccount:
        setState(() => _identifierServerError = _loginController.errorMessage);
        _formKey.currentState!.validate();
        return;
      case LoginErrorType.wrongCredentials:
        setState(() => _passwordServerError = _loginController.errorMessage);
        _formKey.currentState!.validate();
        return;
      case LoginErrorType.emailNotConfirmed:
        // Signed up but never confirmed: continue verification instead.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(
              email: _loginController.accountEmail ?? '',
              password: password,
              sendEmailOnOpen: true,
            ),
          ),
        );
        return;
      case LoginErrorType.other:
      case null:
        break;
    }

    // Displays the login error.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _loginController.errorMessage ?? context.l10n.unableToLogIn,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFE85D5D),
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
                // Shows each field's error as soon as the user leaves it.
                autovalidateMode: AutovalidateMode.onUnfocus,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),

                            // Back button and application branding.
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    _loginController.goBack(context);
                                  },
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
                                        color: Colors.black.withValues(
                                          alpha: 0.06,
                                        ),
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
                            ),

                            const SizedBox(height: 40),

                            Text(
                              context.l10n.welcomeBack,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: SynkColors.textPrimary,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              context.l10n.logInToConnectAndJoin,
                              style: TextStyle(
                                fontSize: 15,
                                color: SynkColors.textSecondary,
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Mode Toggle: Username vs Email
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (!_loginWithUsernameMode) {
                                          setState(() {
                                            _loginWithUsernameMode = true;
                                          });
                                          _loginController.clearError();
                                          _clearServerErrors();
                                        }
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _loginWithUsernameMode
                                              ? SynkColors.orangeDark
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          context.l10n.username,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: _loginWithUsernameMode
                                                ? Colors.white
                                                : SynkColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (_loginWithUsernameMode) {
                                          setState(() {
                                            _loginWithUsernameMode = false;
                                          });
                                          _loginController.clearError();
                                          _clearServerErrors();
                                        }
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: !_loginWithUsernameMode
                                              ? SynkColors.orangeDark
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          context.l10n.email,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: !_loginWithUsernameMode
                                                ? Colors.white
                                                : SynkColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Dedicated Username input field
                            if (_loginWithUsernameMode)
                              TextFormField(
                                controller: _usernameController,
                                style: synkInputTextStyle,
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => _clearServerErrors(),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return context.l10n.pleaseEnterYourUsername;
                                  }
                                  return _identifierServerError;
                                },
                                decoration: synkInputDecoration(
                                  label: context.l10n.username,
                                  hint: context.l10n.username,
                                  icon: Icons.alternate_email_rounded,
                                ),
                              )
                            // Dedicated Email input field
                            else
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: synkInputTextStyle,
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => _clearServerErrors(),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return context.l10n.pleaseEnterYourEmail;
                                  }
                                  if (!AuthConstants.emailRegex.hasMatch(
                                    value.trim(),
                                  )) {
                                    return context.l10n.pleaseEnterAValidEmail;
                                  }
                                  return _identifierServerError;
                                },
                                decoration: synkInputDecoration(
                                  label: context.l10n.email,
                                  hint: context.l10n.emailAddress,
                                  icon: Icons.email_outlined,
                                ),
                              ),

                            const SizedBox(height: 16),

                            // Password input field.
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: synkInputTextStyle,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => _clearServerErrors(),
                              onFieldSubmitted: (_) {
                                if (!_loginController.isLoading) _handleLogin();
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return context.l10n.pleaseEnterYourPassword;
                                }
                                return _passwordServerError;
                              },
                              decoration: synkInputDecoration(
                                label: context.l10n.password,
                                hint: context.l10n.password,
                                icon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: SynkColors.textSecondary,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Password recovery navigation.
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ForgotPasswordView(
                                        initialEmail: _emailController.text
                                            .trim(),
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  context.l10n.forgotPassword,
                                  style: TextStyle(
                                    color: SynkColors.orangeDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Pinned to the bottom; rises above the keyboard.
                    const SizedBox(height: 12),

                    // Rebuilds the button when authentication state changes.
                    AnimatedBuilder(
                      animation: _loginController,
                      builder: (context, _) {
                        return ElevatedButton(
                          onPressed: _loginController.isLoading
                              ? null
                              : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SynkColors.orangeDark,
                            disabledBackgroundColor: SynkColors.orangeDark
                                .withValues(alpha: 0.6),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: _loginController.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  context.l10n.logIn,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    // Account registration navigation.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.l10n.dontHaveAnAccount,
                          style: TextStyle(color: SynkColors.textSecondary),
                        ),
                        TextButton(
                          onPressed: () {
                            _loginController.onSignUp(context);
                          },
                          child: Text(
                            context.l10n.signUp,
                            style: TextStyle(
                              color: SynkColors.orangeDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
