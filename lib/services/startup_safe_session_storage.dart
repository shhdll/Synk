import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps a slow or unavailable Android preference store from blocking app
/// startup. When preferences cannot respond, auth sessions remain in memory
/// for the current process and normal persistence resumes on the next launch.
class StartupSafeSessionStorage extends LocalStorage {
  StartupSafeSessionStorage({required String persistSessionKey})
    : _preferences = SharedPreferencesLocalStorage(
        persistSessionKey: persistSessionKey,
      );

  static const _operationTimeout = Duration(seconds: 5);

  final SharedPreferencesLocalStorage _preferences;
  bool _preferencesAvailable = false;
  String? _memorySession;

  @override
  Future<void> initialize() async {
    try {
      await _preferences.initialize().timeout(_operationTimeout);
      _preferencesAvailable = true;
    } catch (error) {
      _useMemoryOnly(error);
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    if (!_preferencesAvailable) return _memorySession != null;
    try {
      return await _preferences.hasAccessToken().timeout(_operationTimeout);
    } catch (error) {
      _useMemoryOnly(error);
      return _memorySession != null;
    }
  }

  @override
  Future<String?> accessToken() async {
    if (!_preferencesAvailable) return _memorySession;
    try {
      final session = await _preferences.accessToken().timeout(
        _operationTimeout,
      );
      _memorySession = session;
      return session;
    } catch (error) {
      _useMemoryOnly(error);
      return _memorySession;
    }
  }

  @override
  Future<void> removePersistedSession() async {
    _memorySession = null;
    if (!_preferencesAvailable) return;
    try {
      await _preferences.removePersistedSession().timeout(_operationTimeout);
    } catch (error) {
      _useMemoryOnly(error);
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    _memorySession = persistSessionString;
    if (!_preferencesAvailable) return;
    try {
      await _preferences
          .persistSession(persistSessionString)
          .timeout(_operationTimeout);
    } catch (error) {
      _useMemoryOnly(error);
    }
  }

  void _useMemoryOnly(Object error) {
    _preferencesAvailable = false;
    debugPrint(
      'Supabase session preferences unavailable; using memory for this run: $error',
    );
  }
}
