import 'package:flutter/foundation.dart';

import '../models/notifications_model.dart';

// Keeps the notification list and unread count for the bell.
class NotificationCenterController extends ChangeNotifier {
  NotificationCenterController({NotificationsModel? model})
    : _model = model ?? NotificationsModel();

  final NotificationsModel _model;

  List<AppNotification> _items = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _refreshing = false;
  String? _error;
  int _unreadCount = 0;

  List<AppNotification> get items => _items;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  // Quiet by default; the list shows a spinner only on its first load.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    if (!_hasLoaded) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _items = await _model.fetch();
      _unreadCount = _items.where((n) => n.isUnread).length;
      _error = null;
      _hasLoaded = true;
    } catch (error) {
      debugPrint('SYNK: notifications failed to load: $error');
      _error = error.toString();
    } finally {
      _isLoading = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  // Opening the list counts as reading everything in it.
  Future<void> markAllSeen() async {
    if (_unreadCount == 0) return;
    _unreadCount = 0;
    _items = [for (final n in _items) n.asRead()];
    notifyListeners();
    try {
      await _model.markSeen();
    } catch (error) {
      debugPrint('SYNK: marking notifications seen failed: $error');
    }
  }
}
