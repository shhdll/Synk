import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/auth_constants.dart';

class SignupController extends ChangeNotifier {
  // Fields
  final TextEditingController nameController = TextEditingController();
  final TextEditingController birthdayController = TextEditingController();
  String? selectedGender;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  // Inline error states
  String? nameError;
  String? birthdayError;
  String? genderError;
  String? usernameError;
  String? emailError;
  String? passwordError;
  String? confirmPasswordError;
  String? generalError;

  void clearErrors() {
    nameError = null;
    birthdayError = null;
    genderError = null;
    usernameError = null;
    emailError = null;
    passwordError = null;
    confirmPasswordError = null;
    generalError = null;
    notifyListeners();
  }

  void setGender(String? gender) {
    selectedGender = gender;
    genderError = null;
    notifyListeners();
  }

  void clearNameError() {
    if (nameError == null) return;
    nameError = null;
    notifyListeners();
  }

  void clearBirthdayError() {
    if (birthdayError == null) return;
    birthdayError = null;
    notifyListeners();
  }

  void clearUsernameError() {
    if (usernameError == null) return;
    usernameError = null;
    notifyListeners();
  }

  void clearEmailError() {
    if (emailError == null) return;
    emailError = null;
    notifyListeners();
  }

  void clearPasswordError() {
    if (passwordError == null) return;
    passwordError = null;
    notifyListeners();
  }

  void clearConfirmPasswordError() {
    if (confirmPasswordError == null) return;
    confirmPasswordError = null;
    notifyListeners();
  }

  void toggleObscurePassword() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  // Calculate age from birthday
  int? _calculateAge(String birthdayText) {
    try {
      final parts = birthdayText.split('/');

      if (parts.length != 3) return null;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      final birthday = DateTime(year, month, day);
      final today = DateTime.now();

      // Make sure the date itself is valid.
      if (birthday.year != year ||
          birthday.month != month ||
          birthday.day != day) {
        return null;
      }

      int age = today.year - birthday.year;

      // Birthday has not happened yet this year.
      if (today.month < birthday.month ||
          (today.month == birthday.month && today.day < birthday.day)) {
        age--;
      }

      return age;
    } catch (_) {
      return null;
    }
  }

  bool validatePersonalDetails() {
    clearErrors();
    bool isValid = true;

    // Validate name
    if (nameController.text.trim().isEmpty) {
      nameError = 'Full name is required';
      isValid = false;
    }

    // Validate birthday
    final birthdayText = birthdayController.text.trim();

    if (birthdayText.isEmpty) {
      birthdayError = 'Birthday is required';
      isValid = false;
    } else {
      final age = _calculateAge(birthdayText);

      if (age == null) {
        birthdayError = 'Please enter a valid birthday';
        isValid = false;
      } else if (age < 16 || age > 90) {
        birthdayError = 'Adult must be between 16 and 90 years old';
        isValid = false;
      }
    }

    // Validate gender
    if (selectedGender == null) {
      genderError = 'Please select your gender';
      isValid = false;
    }

    notifyListeners();
    return isValid;
  }

  bool validateCredentials() {
    usernameError = null;
    emailError = null;
    passwordError = null;
    confirmPasswordError = null;
    generalError = null;

    bool isValid = true;

    final username = usernameController.text.trim().replaceAll('@', '');
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    final usernameRegex = RegExp(r'^[a-zA-Z0-9_.]+$');
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    // Validate username
    if (username.isEmpty) {
      usernameError = 'Username is required';
      isValid = false;
    } else if (username.length < 3) {
      usernameError = 'Username must be at least 3 characters';
      isValid = false;
    } else if (username.length > 30) {
      usernameError = 'Username must be 30 characters or less';
      isValid = false;
    } else if (!usernameRegex.hasMatch(username)) {
      usernameError =
          'Username can only contain letters, numbers, underscores, and dots';
      isValid = false;
    }

    // Validate email
    if (email.isEmpty) {
      emailError = 'Email address is required';
      isValid = false;
    } else if (!emailRegex.hasMatch(email)) {
      emailError = 'Please enter a valid email address';
      isValid = false;
    }

    // Validate password
    final passwordValidation = AuthConstants.validatePassword(password);
    if (passwordValidation != null) {
      passwordError = passwordValidation;
      isValid = false;
    }

    // Validate confirm password
    if (confirmPassword.isEmpty) {
      confirmPasswordError = 'Please confirm your password';
      isValid = false;
    } else if (password != confirmPassword) {
      confirmPasswordError = 'Passwords do not match';
      isValid = false;
    }

    notifyListeners();
    return isValid;
  }

  Future<AuthResponse?> registerUser({
    required Map<String, dynamic> onboardingPreferences,
    required BuildContext context,
  }) async {
    if (!validateCredentials()) return null;

    isLoading = true;
    notifyListeners();

    final cleanUsername = usernameController.text
        .trim()
        .replaceAll('@', '')
        .toLowerCase();

    try {
      // Check if username is already taken in the users table
      final existingUser = await Supabase.instance.client
          .from('users')
          .select('id')
          .ilike('username', cleanUsername)
          .maybeSingle();

      if (existingUser != null) {
        usernameError = 'This username is already taken';
        isLoading = false;
        notifyListeners();
        return null;
      }

      final age = _calculateAge(birthdayController.text.trim());

      final response = await Supabase.instance.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        data: {
          'full_name': nameController.text.trim(),
          'username': cleanUsername,
          'email': emailController.text.trim().toLowerCase(),
          'age': age,
          'gender': selectedGender,
          ...onboardingPreferences,
        },
      );

      if (response.user != null) {
        try {
          await Supabase.instance.client.from('users').upsert({
            'id': response.user!.id,
            'username': cleanUsername,
            'email': emailController.text.trim().toLowerCase(),
            'full_name': nameController.text.trim(),
            'age': age,
            'gender': selectedGender,
            ...onboardingPreferences,
          });
        } catch (_) {
          try {
            await Supabase.instance.client
                .from('users')
                .update({
                  'username': cleanUsername,
                  'email': emailController.text.trim().toLowerCase(),
                })
                .eq('id', response.user!.id);
          } catch (_) {}
        }
      }

      return response;
    } on AuthWeakPasswordException {
      passwordError = 'Password is too weak. Please use at least 6 characters.';
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();

      if (msg.contains('already registered') ||
          msg.contains('user already exists')) {
        emailError = 'An account with this email already exists';
      } else if (msg.contains('email')) {
        emailError = e.message;
      } else if (msg.contains('password')) {
        passwordError = e.message;
      } else {
        generalError = e.message;
      }
    } catch (_) {
      generalError = 'An unexpected error occurred. Please try again.';
    } finally {
      isLoading = false;
      notifyListeners();
    }

    return null;
  }

  @override
  void dispose() {
    nameController.dispose();
    birthdayController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
