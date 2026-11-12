import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synk/l10n/app_localizations.dart';
import 'package:synk/models/chat_model.dart';
import 'package:synk/views/home/widgets/chat_poll.dart';
import 'package:synk/views/home/widgets/chat_view_once.dart';
import 'package:synk/views/home/widgets/chat_voice.dart';

// The chat's new pieces fit on small phones, in both languages, with
// larger text: no "overflowed" errors.
void main() {
  final voice = ChatMessage.fromMap({
    'id': 'v1',
    'chat_id': 'c1',
    'sender_id': 'u1',
    'body': '',
    'created_at': '2026-11-13T10:00:00Z',
    'kind': 'voice',
    'audio_path': 'c1/1.m4a',
    'audio_duration_ms': 65000,
    'audio_waveform': List.filled(48, 60),
  });

  final pieces = <String, Widget Function(bool isMine)>{
    'voice bubble': (isMine) => VoiceMessageContent(
      model: ChatModel(),
      message: voice,
      isMine: isMine,
      heard: false,
    ),
    'poll': (isMine) => PollMessageContent(
      poll: const ChatPoll(
        question: 'Where should we meet on Saturday evening?',
        options: ['The park by the lake', 'Cafe', 'Mall food court'],
        multiple: true,
      ),
      votes: const {
        'a': [0],
        'b': [0, 2],
      },
      me: 'a',
      isMine: isMine,
      onVote: (_) {},
      onViewVotes: () {},
    ),
    'view once photo': (isMine) =>
        ViewOnceMessageContent(isPhoto: true, isMine: isMine, opened: true),
    'view once voice': (isMine) =>
        ViewOnceMessageContent(isPhoto: false, isMine: isMine, opened: true),
    'recording bar': (_) => const VoiceRecordingBar(
      elapsed: Duration(seconds: 75),
      slide: 0,
      cancelDistance: 110,
    ),
    'locked recording bar': (_) => LockedRecordingBar(
      elapsed: const Duration(seconds: 75),
      levels: List.filled(40, 0.5),
      onDelete: () {},
      viewOnceToggle: ViewOnceToggle(on: false, size: 34, onChanged: (_) {}),
    ),
  };

  for (final width in const [320.0, 375.0]) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final scale in const [1.0, 1.3]) {
        for (final entry in pieces.entries) {
          for (final isMine in const [true, false]) {
            testWidgets(
              '${entry.key} fits: ${width.toInt()}w ${locale.languageCode} '
              '${scale}x ${isMine ? 'mine' : 'theirs'}',
              (tester) async {
                tester.view.physicalSize = Size(width, 700);
                tester.view.devicePixelRatio = 1;
                addTearDown(tester.view.reset);
                await tester.pumpWidget(
                  MaterialApp(
                    locale: locale,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: Builder(
                      builder: (context) => MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: TextScaler.linear(scale)),
                        child: Scaffold(
                          body: Center(
                            // Same room a bubble gets in the chat.
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: entry.key.contains('bar')
                                    ? width - 70
                                    : width * 0.72 - 16,
                              ),
                              child: entry.value(isMine),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pump();
                expect(tester.takeException(), isNull);
              },
            );
          }
        }
      }
    }
  }
}
