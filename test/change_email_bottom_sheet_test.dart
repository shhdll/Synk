import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synk/l10n/app_localizations.dart';
import 'package:synk/views/home/widgets/change_email_bottom_sheet.dart';

void main() {
  testWidgets('ChangeEmailBottomSheet renders current email and input in edit mode',
      (WidgetTester tester) async {
    const currentEmail = 'user@example.com';

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChangeEmailBottomSheet(
            currentEmail: currentEmail,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Change Email'), findsOneWidget);
    expect(find.text(currentEmail), findsOneWidget);
    expect(find.text('Send Verification'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('ChangeEmailBottomSheet renders pending UI when pendingEmail is set',
      (WidgetTester tester) async {
    const currentEmail = 'user@example.com';
    const pendingEmail = 'newuser@example.com';

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChangeEmailBottomSheet(
            currentEmail: currentEmail,
            pendingEmail: pendingEmail,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Pending Email Change'), findsOneWidget);
    expect(find.text(currentEmail), findsOneWidget);
    expect(find.text('Resend Confirmation Links'), findsOneWidget);
    expect(find.text('Cancel Email Change'), findsOneWidget);
  });
}
