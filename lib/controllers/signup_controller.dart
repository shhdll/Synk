import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/auth_constants.dart';

class SignupController extends ChangeNotifier {
  // Fields
  final TextEditingController nameController = TextEditingController();
  final TextEditingController birthdayController = TextEditingController();
  final FocusNode nameFocusNode = FocusNode();
  final FocusNode birthdayFocusNode = FocusNode();
  String? selectedGender;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final FocusNode usernameFocusNode = FocusNode();
  final FocusNode emailFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();
  final FocusNode confirmPasswordFocusNode = FocusNode();

  Timer? _emailDebounceTimer;
  Timer? _usernameDebounceTimer;

  bool obscurePassword = true;
  bool isLoading = false;

  SignupController() {
    nameController.addListener(_onFieldChanged);
    birthdayController.addListener(_onFieldChanged);
    nameFocusNode.addListener(() {
      if (!nameFocusNode.hasFocus) validateName();
    });
    birthdayFocusNode.addListener(() {
      if (!birthdayFocusNode.hasFocus) validateBirthday();
    });
    usernameFocusNode.addListener(() {
      if (!usernameFocusNode.hasFocus) {
        _usernameDebounceTimer?.cancel();
        checkUsernameAvailability();
      }
    });
    emailFocusNode.addListener(() {
      if (!emailFocusNode.hasFocus) {
        _emailDebounceTimer?.cancel();
        checkEmailAvailability();
      }
    });
    passwordFocusNode.addListener(() {
      if (!passwordFocusNode.hasFocus) validatePassword();
    });
    confirmPasswordFocusNode.addListener(() {
      if (!confirmPasswordFocusNode.hasFocus) validateConfirmPassword();
    });
  }

  void _onFieldChanged() {
    notifyListeners();
  }

  bool get isPersonalDetailsValid {
    final name = nameController.text.trim();
    final birthday = birthdayController.text.trim();
    if (_nameValidationError(name) != null ||
        birthday.isEmpty ||
        selectedGender == null) {
      return false;
    }
    final age = _calculateAge(birthday);
    if (age == null || age < 16 || age > 50) {
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

  void onUsernameChanged() {
    _usernameDebounceTimer?.cancel();
    if (usernameError != null) {
      usernameError = null;
      notifyListeners();
    }
    final username = usernameController.text.trim();
    if (username.length >= 3) {
      _usernameDebounceTimer = Timer(const Duration(milliseconds: 400), () {
        checkUsernameAvailability();
      });
    }
  }

  void onEmailChanged() {
    _emailDebounceTimer?.cancel();
    if (emailError != null) {
      emailError = null;
      notifyListeners();
    }
    final email = emailController.text.trim();
    if (email.isNotEmpty && AuthConstants.emailRegex.hasMatch(email)) {
      _emailDebounceTimer = Timer(const Duration(milliseconds: 400), () {
        checkEmailAvailability();
      });
    }
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

  void validateName() {
    nameError = _nameValidationError(nameController.text.trim());
    notifyListeners();
  }

  String? _nameValidationError(String name) {
    if (name.isEmpty) return 'Full name is required';
    if (!RegExp(r'^[\p{L}\p{M} ]+$', unicode: true).hasMatch(name)) {
      return 'Name can only contain letters and spaces';
    }
    return null;
  }

  void validateBirthday() {
    final text = birthdayController.text.trim();
    if (text.isEmpty) {
      birthdayError = 'Birthday is required';
    } else {
      final age = _calculateAge(text);
      if (age == null) {
        birthdayError = 'Please enter a valid birthday';
      } else if (age < 16 || age > 50) {
        birthdayError = 'Age must be between 16 and 50 years';
      } else {
        birthdayError = null;
      }
    }
    notifyListeners();
  }

  void validateEmail() {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      emailError = 'Email address is required';
    } else if (!AuthConstants.emailRegex.hasMatch(email)) {
      emailError = 'Please enter a valid email address';
    } else if (emailError != 'An account with this email already exists') {
      emailError = null;
    }
    notifyListeners();
  }

  void validatePassword() {
    passwordError = AuthConstants.validatePassword(
      passwordController.text.trim(),
    );
    notifyListeners();
  }

  void validateConfirmPassword() {
    final confirmation = confirmPasswordController.text.trim();
    confirmPasswordError = confirmation.isEmpty
        ? 'Please confirm your password'
        : confirmation != passwordController.text.trim()
        ? 'Passwords do not match'
        : null;
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
    final name = nameController.text.trim();
    final nameValidationError = _nameValidationError(name);
    if (nameValidationError != null) {
      nameError = nameValidationError;
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
      } else if (age < 16 || age > 50) {
        birthdayError = 'Age must be between 16 and 50 years';
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

    // Validate username format
    if (username.isEmpty) {
      usernameError = 'Username is required';
      isValid = false;
    } else if (username.length < 3) {
      usernameError = 'Username must be at least 3 characters';
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
    } else if (!AuthConstants.emailRegex.hasMatch(email)) {
      emailError = 'Please enter a valid email address';
      isValid = false;
    }

    // Validate password using AuthConstants
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
      usernameError = 'Username must be 3–30 characters and can only include letters, numbers, dots, and underscores.';
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

  // Checks if the email is taken immediately when user leaves the field
  Future<void> checkEmailAvailability() async {
    final email = emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      emailError = 'Email address is required';
      notifyListeners();
      return;
    }

    if (!AuthConstants.emailRegex.hasMatch(email)) {
      emailError = 'Please enter a valid email address';
      notifyListeners();
      return;
    }

    try {
      final existingUser = await Supabase.instance.client
          .from('users')
          .select('id')
          .ilike('email', email)
          .maybeSingle();

      if (existingUser != null) {
        emailError = 'An account with this email already exists';
      } else if (emailError == 'An account with this email already exists') {
        emailError = null;
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
      final cleanEmail = emailController.text.trim().toLowerCase();

      // Check whether username or email is already taken in public.users
      final checkResults = await Future.wait([
        Supabase.instance.client
            .from('users')
            .select('id')
            .ilike('username', cleanUsername)
            .maybeSingle(),
        Supabase.instance.client
            .from('users')
            .select('id')
            .ilike('email', cleanEmail)
            .maybeSingle(),
      ]);

      final existingUser = checkResults[0];
      final existingEmail = checkResults[1];

      bool hasConflict = false;
      if (existingUser != null) {
        usernameError = 'This username is already taken';
        hasConflict = true;
      }
      if (existingEmail != null) {
        emailError = 'An account with this email already exists';
        hasConflict = true;
      }

      if (hasConflict) {
        isLoading = false;
        notifyListeners();
        return null;
      }

      final age = _calculateAge(birthdayController.text.trim());

      final response = await Supabase.instance.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        emailRedirectTo: AuthConstants.emailRedirectUrl,
        data: {
          'username': cleanUsername,
          'full_name': nameController.text.trim(),
          'age': age,
          'gender': selectedGender,
          ...onboardingPreferences,
        },
      );

      final user = response.user;

      // Detect if user already exists based on Supabase response
      bool isExistingUser = false;
      if (user != null) {
        // 1. With email enumeration protection, identities is empty or null
        if (user.identities == null || user.identities!.isEmpty) {
          isExistingUser = true;
        }

        // 2. If the user was already confirmed, it is an existing account
        if (user.emailConfirmedAt != null &&
            user.emailConfirmedAt!.isNotEmpty) {
          isExistingUser = true;
        }

        // 3. If createdAt is older than 15 seconds, account already existed in Supabase
        if (user.createdAt.isNotEmpty) {
          final createdAt = DateTime.tryParse(user.createdAt);
          if (createdAt != null) {
            final ageDifference = DateTime.now()
                .toUtc()
                .difference(createdAt.toUtc())
                .abs();
            if (ageDifference.inSeconds > 15) {
              isExistingUser = true;
            }
          }
        }
      }

      if (isExistingUser) {
        emailError = 'An account with this email already exists';
        isLoading = false;
        notifyListeners();
        return null;
      }

      // Only attempt authenticated client-side upsert if user is already confirmed
      // (otherwise, unauthenticated RLS will reject it; the Postgres trigger or
      // EmailVerificationScreen handles profile creation).
      final isConfirmed =
          user != null &&
          user.emailConfirmedAt != null &&
          user.emailConfirmedAt!.isNotEmpty;

      if (response.session != null && isConfirmed) {
        try {
          await Supabase.instance.client.from('users').upsert({
            'id': user.id,
            'username': cleanUsername,
            'email': emailController.text.trim(),
            'full_name': nameController.text.trim(),
            'age': age,
            'gender': selectedGender,
            'interests': onboardingPreferences['interests'],
            'activity_type': onboardingPreferences['activity_type'],
            'location_preference': onboardingPreferences['location_preference'],
          });
        } catch (e) {
          debugPrint(
            'Notice: public.users upsert skipped or handled by trigger: $e',
          );
        }
      } else {
        debugPrint(
          'Email confirmation required: user metadata stored in auth.users, public.users handled by database trigger or post-confirmation sync.',
        );
      }

      return response;
    } on AuthWeakPasswordException {
      passwordError =
          'Password is too weak. Please use at least ${AuthConstants.minPasswordLength} characters with a mix of letters, numbers, and symbols.';
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();

      if (msg.contains('already registered') ||
          msg.contains('user already exists') ||
          msg.contains('already exists') ||
          msg.contains('already in use')) {
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
    _emailDebounceTimer?.cancel();
    _usernameDebounceTimer?.cancel();

    nameController.removeListener(_onFieldChanged);
    birthdayController.removeListener(_onFieldChanged);

    nameController.dispose();
    birthdayController.dispose();
    nameFocusNode.dispose();
    birthdayFocusNode.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    usernameFocusNode.dispose();
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    confirmPasswordFocusNode.dispose();
    super.dispose();
  }
}
