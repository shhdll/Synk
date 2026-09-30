import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synk/screens/auth/email_verification_screen.dart';

void main() {
  testWidgets('EmailVerificationScreen renders email address and actions', (
    WidgetTester tester,
  ) async {
    const testEmail = 'alex.doe@example.com';

    await tester.pumpWidget(
      const MaterialApp(home: EmailVerificationScreen(email: testEmail)),
    );

    // Initial pump
    await tester.pump();

    // Verify key UI elements are present
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.text(testEmail), findsOneWidget);
    expect(find.text('Resend verification email'), findsOneWidget);
    expect(find.text('Back to Sign In'), findsOneWidget);
  });
}
