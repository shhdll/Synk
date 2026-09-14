import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupController extends ChangeNotifier {
  // Fields
  final TextEditingController nameController = TextEditingController();
  final TextEditingController birthdayController = TextEditingController();
  String? selectedGender;

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
  String? emailError;
  String? passwordError;
  String? confirmPasswordError;
  String? generalError;

  void clearErrors() {
    nameError = null;
    birthdayError = null;
    genderError = null;
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
          (today.month == birthday.month &&
              today.day < birthday.day)) {
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
    emailError = null;
    passwordError = null;
    confirmPasswordError = null;
    generalError = null;

    bool isValid = true;

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    // Validate email
    if (email.isEmpty) {
      emailError = 'Email address is required';
      isValid = false;
    } else if (!emailRegex.hasMatch(email)) {
      emailError = 'Please enter a valid email address';
      isValid = false;
    }

    // Validate password
    if (password.isEmpty) {
      passwordError = 'Password is required';
      isValid = false;
    } else if (password.length < 6) {
      passwordError = 'Password must be at least 6 characters';
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

    try {
      final age = _calculateAge(birthdayController.text.trim());

      final response = await Supabase.instance.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        data: {
          'full_name': nameController.text.trim(),
          'age': age,
          'gender': selectedGender,
          ...onboardingPreferences,
        },
      );

      return response;
    } on AuthWeakPasswordException {
      passwordError =
          'Password is too weak. Please use at least 6 characters.';
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
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}