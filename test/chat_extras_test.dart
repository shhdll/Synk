import 'package:flutter_test/flutter_test.dart';
import 'package:synk/models/chat_model.dart';
import 'package:synk/utils/emoji_only.dart';

void main() {
  group('emojiOnlyCount', () {
    test('counts up to three emoji, spaces aside', () {
      expect(emojiOnlyCount('😂'), 1);
      expect(emojiOnlyCount('😂 ❤️'), 2);
      expect(emojiOnlyCount('👍🏽🇸🇦👨‍👩‍👧'), 3);
    });

    test('is 0 for text, numbers, or more than three emoji', () {
      expect(emojiOnlyCount('hi 😂'), 0);
      expect(emojiOnlyCount('1'), 0);
      expect(emojiOnlyCount('#'), 0);
      expect(emojiOnlyCount('😂😂😂😂'), 0);
      expect(emojiOnlyCount(''), 0);
      expect(emojiOnlyCount('هلا'), 0);
    });
  });

  group('ChatPoll', () {
    test('round-trips through its JSON', () {
      const poll = ChatPoll(
        question: 'Where?',
        options: ['Park', 'Cafe'],
        multiple: true,
      );
      final parsed = ChatPoll.tryParse(poll.toJson())!;
      expect(parsed.question, 'Where?');
      expect(parsed.options, ['Park', 'Cafe']);
      expect(parsed.multiple, isTrue);
    });

    test('is null for text that is not a poll', () {
      expect(ChatPoll.tryParse('hello'), isNull);
      expect(ChatPoll.tryParse('{"question":"Q","options":["one"]}'), isNull);
    });
  });

  test('a poll message keeps its JSON out of the text', () {
    final message = ChatMessage.fromMap({
      'id': 'm1',
      'chat_id': 'c1',
      'sender_id': 'u1',
      'body': const ChatPoll(question: 'Q', options: ['a', 'b']).toJson(),
      'created_at': '2026-11-12T10:00:00Z',
      'kind': 'poll',
    });
    expect(message.isPoll, isTrue);
    expect(message.text, isEmpty);
  });

  test('voice messages read their length and waveform', () {
    final message = ChatMessage.fromMap({
      'id': 'm1',
      'chat_id': 'c1',
      'sender_id': 'u1',
      'body': '',
      'created_at': '2026-11-12T10:00:00Z',
      'kind': 'voice',
      'audio_path': 'c1/1.m4a',
      'audio_duration_ms': 7500,
      'audio_waveform': [10, 50, 100],
    });
    expect(message.isVoice, isTrue);
    expect(message.audioDuration, const Duration(milliseconds: 7500));
    expect(message.audioWaveform, [10, 50, 100]);
  });

  test('view-once messages and who opened them', () {
    final message = ChatMessage.fromMap({
      'id': 'm1',
      'chat_id': 'c1',
      'sender_id': 'u1',
      'body': '',
      'created_at': '2026-11-13T10:00:00Z',
      'kind': 'photo',
      'image_path': 'c1/1.jpg',
      'view_once': true,
    });
    expect(message.viewOnce, isTrue);
    expect(message.hasPhoto, isTrue);

    final extras = ChatMessageExtras.fromMap({
      'opens': [
        {'message_id': 'm1', 'user_id': 'u2'},
      ],
    });
    expect(extras.opens['m1'], {'u2'});
    // Keeps the opens when only votes change.
    expect(extras.copyWith(votes: {}).opens['m1'], {'u2'});
  });

  test('extras skip votes that were taken back', () {
    final extras = ChatMessageExtras.fromMap({
      'votes': [
        {
          'message_id': 'p1',
          'user_id': 'u1',
          'option_indexes': [0, 2],
        },
        {'message_id': 'p1', 'user_id': 'u2', 'option_indexes': <int>[]},
      ],
      'plays': [
        {'message_id': 'v1', 'user_id': 'u2'},
      ],
    });
    expect(extras.votes['p1'], {
      'u1': [0, 2],
    });
    expect(extras.plays['v1'], {'u2'});
  });
}
