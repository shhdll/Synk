import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SwipeAction {
  join('join'),
  openDetails('open_details');

  const SwipeAction(this.value);
  final String value;
}

// What the user did with the For you cards: joined or opened one. Failures are only
// logged: the deck works the same without them.
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
}
