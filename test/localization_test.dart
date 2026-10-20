import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synk/controllers/language_controller.dart';
import 'package:synk/l10n/l10n.dart';
import 'package:synk/views/home/widgets/change_email_bottom_sheet.dart';

Map<String, dynamic> readArb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => LanguageController.instance.setLocale(const Locale('en')));

  final en = readArb('app_en.arb');
  final ar = readArb('app_ar.arb');
  final arabicTexts = ar.entries
      .where((e) => !e.key.startsWith('@'))
      .map((e) => MapEntry(e.key, e.value as String));

  group('Arabic translations', () {
    test('cover every English message', () {
      final keys = en.keys.where((k) => !k.startsWith('@'));
      expect(keys.where((k) => !ar.containsKey(k)), isEmpty);
    });

    test('follow the agreed style', () {
      for (final MapEntry(:key, :value) in arabicTexts) {
        expect(
          value,
          isNot(matches(RegExp('[ً-ْ]'))),
          reason: '$key has harakat',
        );
        expect(
          value,
          isNot(matches(RegExp('[٠-٩]'))),
          reason: '$key uses Arabic-Indic digits',
        );
        expect(value, isNot(contains('كود')), reason: '$key says كود');
        final text = value.trimRight();
        expect(
          text.endsWith('.') && !text.endsWith('...'),
          isFalse,
          reason: '$key ends with a full stop',
        );
      }
    });
  });

  group('in Arabic', () {
    setUp(() => LanguageController.instance.setLocale(const Locale('ar')));

    test('dates use Arabic day and month names', () {
      expect(formatShortDate(DateTime(2026, 10, 21)), 'الأربعاء، 21 أكتوبر');
      expect(formatTime(19, 30), '7:30 م');
      expect(formatTime(9, 5), '9:05 ص');
    });

    test('saved English values get Arabic labels', () {
      expect(valueLabel('Padel'), 'بادل');
      expect(valueLabel('I don’t mind'), 'لا يهم');
      expect(valueLabel('Female'), 'أنثى');
      expect(valueLabel('Something new'), 'Something new');
    });

    test('database messages are translated', () {
      expect(
        serverMessage('No activity was found with this code.'),
        'لا يوجد نشاط بهذا الرمز',
      );
      expect(serverMessage('Unknown message'), 'Unknown message');
    });

    test('share message matches the approved wording', () {
      expect(
        appL10n.shareMessage(
          'بادل',
          'الثلاثاء، 21 أكتوبر · 7:30 م',
          'Padel In',
          '482913',
        ),
        'ودك تجي معنا بادل!\n'
        '📅 الثلاثاء، 21 أكتوبر · 7:30 م\n'
        '📍 Padel In\n'
        '\n'
        'اكتب الرمز في Synk: 482913',
      );
    });

    testWidgets('screens lay out right to left', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChangeEmailBottomSheet(currentEmail: 'user@example.com'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('تغيير البريد'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('تغيير البريد'))),
        TextDirection.rtl,
      );
    });
  });

  test('English stays as it was', () {
    expect(formatShortDate(DateTime(2026, 10, 21)), 'Wed, Oct 21');
    expect(formatTime(19, 30), '7:30 PM');
    expect(appL10n.spotsLeft(1), '1 spot available');
    expect(appL10n.spotsLeft(3), '3 spots available');
  });

  test('the language choice is saved on the device', () async {
    await LanguageController.instance.setLocale(const Locale('ar'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language'), 'ar');
  });
}
