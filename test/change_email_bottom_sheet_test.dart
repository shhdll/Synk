import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synk/l10n/app_localizations.dart';
import 'package:synk/views/home/widgets/change_email_bottom_sheet.dart';

void main() {
  testWidgets('ChangeEmailBottomSheet shows the new email form',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChangeEmailBottomSheet(currentEmail: 'user@example.com'),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Change email'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text("We'll send a link to confirm it."), findsOneWidget);
    expect(find.text('Send link'), findsOneWidget);
  });

  testWidgets('ChangeEmailBottomSheet shows the pending change',
      (WidgetTester tester) async {
    const pendingEmail = 'newuser@example.com';

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChangeEmailBottomSheet(
            currentEmail: 'user@example.com',
            pendingEmail: pendingEmail,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Confirm your new email'), findsOneWidget);
    expect(
      find.textContaining(pendingEmail, findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Resend link'), findsOneWidget);
    expect(find.text('Use a different email'), findsOneWidget);
    expect(find.text('Cancel change'), findsOneWidget);
  });
}
