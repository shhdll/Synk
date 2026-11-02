import 'package:flutter/foundation.dart';

import '../models/notification_preferences_model.dart';

class NotificationPreferencesController extends ChangeNotifier {
  NotificationPreferencesController({NotificationPreferencesModel? model})
    : _model = model ?? NotificationPreferencesModel();

  final NotificationPreferencesModel _model;

  Map<NotificationKind, bool> _values = {};
  bool _isLoading = true;
  bool _loadFailed = false;

  bool get isLoading => _isLoading;
  bool get loadFailed => _loadFailed;
  bool isEnabled(NotificationKind kind) => _values[kind] ?? true;

  Future<void> load() async {
    _isLoading = true;
    _loadFailed = false;
    notifyListeners();
    try {
      _values = await _model.fetch();
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
}
