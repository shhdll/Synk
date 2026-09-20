import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  SignupController() {
    nameController.addListener(_onFieldChanged);
    birthdayController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    notifyListeners();
  }

  bool get isPersonalDetailsValid {
    final name = nameController.text.trim();
    final birthday = birthdayController.text.trim();
    if (name.isEmpty || birthday.isEmpty || selectedGender == null) {
      return false;
    }
    final age = _calculateAge(birthday);
    if (age == null || age < 16 || age > 90) {
      return false;
    }
    return true;
  }

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

    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    final usernameRegex = RegExp(r'^[a-zA-Z0-9._]{3,30}$');
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    // Validate username format
    if (username.isEmpty) {
      usernameError = 'Username is required';
      isValid = false;
    } else if (!usernameRegex.hasMatch(username)) {
      usernameError = '3-30 characters: letters, numbers, dots, or underscores';
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

  // Checks if the username is taken immediately when user leaves the field
  Future<void> checkUsernameAvailability() async {
    final username = usernameController.text.trim().toLowerCase();

    if (username.isEmpty) {
      usernameError = 'Username is required';
      notifyListeners();
      return;
    }

    final usernameRegex = RegExp(r'^[a-zA-Z0-9._]{3,30}$');
    if (!usernameRegex.hasMatch(username)) {
      usernameError = '3-30 characters: letters, numbers, dots, or underscores';
      notifyListeners();
      return;
    }

    try {
      final existingUser = await Supabase.instance.client
          .from('users')
          .select('id')
          .ilike('username', username)
          .maybeSingle();

      if (existingUser != null) {
        usernameError = 'This username is already taken';
      } else {
        usernameError = null;
      }
    } catch (_) {
      // Ignore network dropouts here; full validation will catch it on register
    }

    notifyListeners();
  }

  Future<AuthResponse?> registerUser({
    required Map<String, dynamic> onboardingPreferences,
    required BuildContext context,
  }) async {
    final personalValid = validatePersonalDetails();
    final credentialsValid = validateCredentials();
    if (!personalValid || !credentialsValid) return null;

    isLoading = true;
    notifyListeners();

    try {
      final cleanUsername = usernameController.text.trim().toLowerCase();

      // Check whether this username is already taken
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
          'username': cleanUsername,
          'full_name': nameController.text.trim(),
          'age': age,
          'gender': selectedGender,
          ...onboardingPreferences,
        },
      );

      // If user profile row is created explicitly or updated:
      if (response.user != null) {
        try {
          await Supabase.instance.client.from('users').upsert({
            'id': response.user!.id,
            'username': cleanUsername,
            'email': emailController.text.trim(),
            'full_name': nameController.text.trim(),
            'age': age,
            'gender': selectedGender,
          });
        } catch (e) {
          debugPrint(
            'Notice: public.users upsert skipped or handled by trigger: $e',
          );
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
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException during signup: ${e.message}');
      generalError = e.message;
    } catch (e) {
      debugPrint('Unexpected signup error: $e');
      final errorStr = e.toString().replaceFirst('Exception: ', '');
      generalError = errorStr.isNotEmpty
          ? errorStr
          : 'An unexpected error occurred. Please try again.';
    } finally {
      isLoading = false;
      notifyListeners();
    }

    return null;
  }

  @override
  void dispose() {
    nameController.removeListener(_onFieldChanged);
    birthdayController.removeListener(_onFieldChanged);

    nameController.dispose();
    birthdayController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
