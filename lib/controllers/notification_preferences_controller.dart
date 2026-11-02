import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/notification_preferences_model.dart';

class NotificationPreferencesController extends ChangeNotifier {
  NotificationPreferencesController({NotificationPreferencesModel? model})
    : _model = model ?? NotificationPreferencesModel();

  final NotificationPreferencesModel _model;

  Map<NotificationKind, bool> _values = {};
  String? _ntfyTopic;
  bool _isLoading = true;
  bool _loadFailed = false;

  bool get isLoading => _isLoading;
  bool get loadFailed => _loadFailed;
  bool isEnabled(NotificationKind kind) => _values[kind] ?? true;
  String? get ntfyTopic => _ntfyTopic;

  Future<void> load() async {
    _isLoading = true;
    _loadFailed = false;
    notifyListeners();
    try {
      final result = await _model.fetch();
      _values = result.values;
      _ntfyTopic = result.ntfyTopic;
    } catch (_) {
      _loadFailed = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Flips the switch right away and puts it back if saving fails.
  Future<bool> toggle(NotificationKind kind, bool enabled) async {
    final previous = isEnabled(kind);
    _values = {..._values, kind: enabled};
    notifyListeners();
    try {
      await _model.save(kind, enabled);
      return true;
    } catch (_) {
      _values = {..._values, kind: previous};
      notifyListeners();
      return false;
    }
  }

  // Turning ntfy on makes a new random topic, so old subscribers stop
  // getting this user's notifications.
  Future<bool> setNtfyEnabled(bool enabled) async {
    final previous = _ntfyTopic;
    _ntfyTopic = enabled ? _randomTopic() : null;
    notifyListeners();
    try {
      await _model.saveNtfyTopic(_ntfyTopic);
      return true;
    } catch (_) {
      _ntfyTopic = previous;
      notifyListeners();
      return false;
    }
  }

  static String _randomTopic() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final suffix = List.generate(
      24,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return 'synk-$suffix';
  }
}
