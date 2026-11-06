import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/notification_preferences_model.dart';

class NotificationPreferencesController extends ChangeNotifier {
  NotificationPreferencesController({NotificationPreferencesModel? model})
    : _model = model ?? NotificationPreferencesModel();

  final NotificationPreferencesModel _model;

  Map<NotificationKind, bool> _values = {};
  String? _ntfyTopic;

  // The user's topic, kept while ntfy is off.
  String? _savedNtfyTopic;
  bool _telegramLinked = false;
  bool _isLoading = true;
  bool _loadFailed = false;

  bool get isLoading => _isLoading;
  bool get loadFailed => _loadFailed;
  bool isEnabled(NotificationKind kind) => _values[kind] ?? true;
  String? get ntfyTopic => _ntfyTopic;
  bool get telegramLinked => _telegramLinked;

  Future<void> load() async {
    _isLoading = true;
    _loadFailed = false;
    notifyListeners();
    try {
      final result = await _model.fetch();
      _values = result.values;
      _ntfyTopic = result.ntfyTopic;
      _savedNtfyTopic = result.savedNtfyTopic ?? result.ntfyTopic;
      _telegramLinked = result.telegramLinked;
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

  // Each user keeps one topic: turning ntfy on again reuses it, so the ntfy
  // app stays subscribed. A random one is made the first time.
  Future<bool> setNtfyEnabled(bool enabled) async {
    // Without the saved topic a new one would replace it.
    if (_loadFailed) await load();
    if (_loadFailed) return false;
    final previous = _ntfyTopic;
    _ntfyTopic = enabled ? (_savedNtfyTopic ?? _randomTopic()) : null;
    notifyListeners();
    try {
      await _model.saveNtfyTopic(_ntfyTopic);
      _savedNtfyTopic = _ntfyTopic ?? _savedNtfyTopic;
      return true;
    } catch (_) {
      _ntfyTopic = previous;
      notifyListeners();
      return false;
    }
  }

  // Code for opening the Synk bot, or null if it could not be made.
  Future<String?> telegramLinkCode(String language) async {
    try {
      return await _model.telegramLinkCode(language);
    } catch (_) {
      return null;
    }
  }

  // The link is saved by the bot, so check again when the user comes back.
  // Connecting also turns ntfy off, so its topic is read again too.
  Future<void> refreshTelegram() async {
    try {
      final result = await _model.fetch();
      _telegramLinked = result.telegramLinked;
      _ntfyTopic = result.ntfyTopic;
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> disconnectTelegram() async {
    try {
      await _model.unlinkTelegram();
      _telegramLinked = false;
      notifyListeners();
      return true;
    } catch (_) {
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
