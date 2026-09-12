import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupController extends ChangeNotifier {
  // Fields
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  String? selectedGender;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  // Inline error states
  String? nameError;
  String? ageError;
  String? genderError;
  String? emailError;
  String? passwordError;
  String? confirmPasswordError;
  String? generalError;

  void clearErrors() {
    nameError = null;
    ageError = null;
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

  bool validatePersonalDetails() {
    clearErrors();
    bool isValid = true;

    if (nameController.text.trim().isEmpty) {
      nameError = 'Full name is required';
      isValid = false;
    }

    final ageText = ageController.text.trim();
    final age = int.tryParse(ageText);
    if (ageText.isEmpty) {
      ageError = 'Age is required';
      isValid = false;
    } else if (age == null || age < 10 || age > 100) {
      ageError = 'Enter a valid age (10-100)';
      isValid = false;
    }

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
    if (email.isEmpty) {
      emailError = 'Email address is required';
      isValid = false;
    } else if (!emailRegex.hasMatch(email)) {
      emailError = 'Please enter a valid email address';
      isValid = false;
    }

    if (password.isEmpty) {
      passwordError = 'Password is required';
      isValid = false;
    } else if (password.length < 6) {
      passwordError = 'Password must be at least 6 characters';
      isValid = false;
    }

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
      final response = await Supabase.instance.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        data: {
          'full_name': nameController.text.trim(),
          'age': int.tryParse(ageController.text.trim()),
          'gender': selectedGender,
          ...onboardingPreferences,
        },
      );
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
    ageController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
