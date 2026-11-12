import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synk/l10n/app_localizations.dart';
import 'package:synk/views/home/widgets/chat_share_sheets.dart';

// The chat's + options fit on a small phone, in both languages, with large
// text, and tapping one reports it.
void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final textScale in const [1.0, 1.4]) {
      testWidgets('fits: ${locale.languageCode} at ${textScale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        ChatAttachment? picked;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 568),
                textScaler: TextScaler.linear(textScale),
              ),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: AttachmentPanel(onPick: (a) => picked = a),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byIcon(Icons.person_rounded));
        expect(picked, ChatAttachment.contact);
      });
    }
  }
}
