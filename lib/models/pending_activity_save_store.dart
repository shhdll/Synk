import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_save_model.dart';

// The save that was sent but hasn't had a final answer yet, one per user.
//
// It's written before the request goes out and removed only once the
// server decides (saved, rejected, conflict, ...). If the app is closed in
// between, it's offered again on the next start, and resending it with the
// same request id either gets the stored answer or finishes the save; it
// can never create a second activity.
class PendingActivitySaveStore {
  const PendingActivitySaveStore();

  static String _key(String userId) => 'pending_activity_save.$userId';

  Future<ActivitySaveRequest?> load(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null) return null;
      final request = ActivitySaveRequest.fromJson(jsonDecode(raw));
      if (request == null) await prefs.remove(_key(userId));
      return request;
    } catch (error) {
      debugPrint(
        'SYNK: pending activity save unreadable: ${error.runtimeType}',
      );
      return null;
    }
  }

  Future<void> save(String userId, ActivitySaveRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), jsonEncode(request.toJson()));
  }

  // Removes the pending save, only if it's still [requestId]. Its photo
  // goes too unless [deletePhoto] is false (the open form still uses it).
  Future<void> clear(
    String userId, {
    required String requestId,
    bool deletePhoto = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await load(userId);
    if (current == null || current.requestId != requestId) return;
    await prefs.remove(_key(userId));
    if (deletePhoto) {
      await PendingActivitySaveStore.deletePhoto(current.photoPath);
    }
  }

  static Future<void> deletePhoto(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A leftover file in the app's own folder; harmless.
    }
  }
}
