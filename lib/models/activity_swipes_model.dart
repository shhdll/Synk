import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'top_picks.dart';

enum SwipeAction {
  join('join'),
  openDetails('open_details'),
  skip('skip');

  const SwipeAction(this.value);
  final String value;
}

// What the user did with the For you cards: joined, opened or skipped one.
// Failures are only logged: the deck works the same without them.
class ActivitySwipesModel {
  ActivitySwipesModel({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> record(String activityId, SwipeAction action) async {
    try {
      await _client.from('activity_swipes').insert({
        'activity_id': activityId,
        'action': action.value,
      });
    } catch (error) {
      debugPrint('SYNK: saving a swipe failed: $error');
    }
  }

  // What the user hosted, joined, opened and skipped lately, newest first.
  // Empty if it fails: top picks then go by the profile only.
  Future<List<TasteEvent>> fetchHistory() async {
    try {
      final rows = await _client.rpc('get_my_for_you_history') as List;
      return [
        for (final row in rows.cast<Map<String, dynamic>>())
          ?TasteEvent.fromMap(row),
      ];
    } catch (error) {
      debugPrint('SYNK: loading For you history failed: $error');
      return const [];
    }
  }
}
