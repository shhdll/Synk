import 'package:flutter_test/flutter_test.dart';
import 'package:synk/core/constants/auth_constants.dart';
import 'package:synk/controllers/signup_controller.dart';

void main() {
  group('SignupController Username Validation Tests', () {
    late SignupController controller;

    setUp(() {
      controller = SignupController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Empty username fails validation', () {
      controller.nameController.text = 'Test User';
      controller.birthdayController.text = '01/01/2000';
      controller.setGender('Female');
      controller.usernameController.text = '';
      controller.emailController.text = 'test@example.com';
      controller.passwordController.text = 'Password123!';
      controller.confirmPasswordController.text = 'Password123!';

      final isValid = controller.validateCredentials();
      expect(isValid, isFalse);
      expect(controller.usernameError, 'Username is required');
    });

    test('Short username fails validation', () {
      controller.usernameController.text = 'ab';
      controller.emailController.text = 'test@example.com';
      controller.passwordController.text = 'Password123!';
      controller.confirmPasswordController.text = 'Password123!';

      final isValid = controller.validateCredentials();
      expect(isValid, isFalse);
      expect(
        controller.usernameError,
        'Username must be at least 3 characters',
      );
    });

    test('Username with invalid characters fails validation', () {
      controller.usernameController.text = 'user!#*';
      controller.emailController.text = 'test@example.com';
      controller.passwordController.text = 'Password123!';
      controller.confirmPasswordController.text = 'Password123!';

      final isValid = controller.validateCredentials();
      expect(isValid, isFalse);
      expect(
        controller.usernameError,
        'Username can only contain letters, numbers, underscores, and dots',
      );
    });

    test('Valid username passes credentials validation', () {
      controller.usernameController.text = 'sarah_99';
      controller.emailController.text = 'test@example.com';
      controller.passwordController.text = 'Password123!';
      controller.confirmPasswordController.text = 'Password123!';

      final isValid = controller.validateCredentials();
      expect(isValid, isTrue);
      expect(controller.usernameError, isNull);
    });
  });

  group('Password Security Rules Tests', () {
    test('Password shorter than 8 characters fails', () {
      expect(
        AuthConstants.validatePassword('Pass1!'),
        'Password must be at least 8 characters',
      );
    });

    test('Password without uppercase fails', () {
      expect(
        AuthConstants.validatePassword('password123!'),
        'Password must contain at least 1 uppercase letter',
      );
    });

    test('Password without lowercase fails', () {
      expect(
        AuthConstants.validatePassword('PASSWORD123!'),
        'Password must contain at least 1 lowercase letter',
      );
    });

    test('Password without number fails', () {
      expect(
        AuthConstants.validatePassword('Password!@#'),
        'Password must contain at least 1 number',
      );
    });

    test('Password without special character fails', () {
      expect(
        AuthConstants.validatePassword('Password123'),
        'Password must contain at least 1 special character (e.g., @\$!%*?&)',
      );
    });

    test('Valid password meeting all rules passes', () {
      expect(AuthConstants.validatePassword('SecurePass123!'), isNull);
      expect(AuthConstants.validatePassword('MyP@ssw0rd'), isNull);
      expect(AuthConstants.validatePassword('Str0ng_Pass'), isNull);
    });
  });

  group('SignupController Email Validation Tests', () {
    late SignupController controller;

    setUp(() {
      controller = SignupController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Empty email fails validation', () {
      controller.emailController.text = '';
      controller.validateEmail();
      expect(controller.emailError, 'Email address is required');
    });

    test('Invalid email format fails validation', () {
      controller.emailController.text = 'invalid-email';
      controller.validateEmail();
      expect(controller.emailError, 'Please enter a valid email address');
    });

    test('Valid email passes validation', () {
      controller.emailController.text = 'user@example.com';
      controller.validateEmail();
      expect(controller.emailError, isNull);
    });

    test('Preserves existing email error if email is not changed to invalid', () {
      controller.emailController.text = 'existing@example.com';
      controller.emailError = 'An account with this email already exists';
      controller.validateEmail();
      expect(controller.emailError, 'An account with this email already exists');
    });
  });
}

