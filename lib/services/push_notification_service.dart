import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> waitlistPromotionBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint('Firebase background setup failed: $error');
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const String _channelId = 'waitlist_promotions';
  static const String _channelName = 'Waitlist promotions';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefresh;
  String? _registeredUserId;
  String? _registeredToken;
  String? _pendingActivityId;
  void Function(String activityId)? _onActivityTap;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized || !Platform.isAndroid) return;

    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(waitlistPromotionBackgroundHandler);

      await _localNotifications.initialize(
        settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_launcher_foreground'),
        ),
        onDidReceiveNotificationResponse: (response) {
          _dispatchActivityTap(response.payload);
        },
      );

      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Updates when a spot opens in a waitlisted activity.',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      FirebaseMessaging.onMessage.listen(
        (message) => unawaited(_showForegroundNotification(message)),
      );
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _dispatchActivityTap(message.data['activity_id']),
      );

      _initialized = true;

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _dispatchActivityTap(initialMessage.data['activity_id']);
      }

      final localLaunch = await _localNotifications
          .getNotificationAppLaunchDetails();
      if (localLaunch?.didNotificationLaunchApp ?? false) {
        _dispatchActivityTap(localLaunch?.notificationResponse?.payload);
      }
    } catch (error) {
      // Missing Firebase project configuration must not prevent Synk startup.
      debugPrint('Push notifications are unavailable: $error');
    }
  }

  void setActivityTapHandler(void Function(String activityId) handler) {
    _onActivityTap = handler;
    final pending = _pendingActivityId;
    if (pending != null) {
      _pendingActivityId = null;
      handler(pending);
    }
  }

  Future<void> registerForCurrentUser() async {
    if (!_initialized) return;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    if (_registeredUserId != userId) {
      await _tokenRefresh?.cancel();
      _registeredUserId = userId;
      _registeredToken = null;
      _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => unawaited(_saveToken(client, userId, token)),
        onError: (Object error) {
          debugPrint('FCM token refresh failed: $error');
        },
      );
    }

    try {
      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: false,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(client, userId, token);
    } catch (error) {
      debugPrint('FCM device registration failed: $error');
    }
  }

  Future<void> unregisterCurrentDevice({SupabaseClient? client}) async {
    if (!_initialized) return;
    final supabase = client ?? Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    try {
      final token =
          _registeredToken ?? await FirebaseMessaging.instance.getToken();
      if (userId != null && token != null) {
        await supabase
            .from('push_device_tokens')
            .delete()
            .eq('user_id', userId)
            .eq('fcm_token', token);
      }
    } catch (error) {
      debugPrint('FCM device cleanup failed: $error');
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint('Could not invalidate the FCM device token: $error');
    }

    _registeredToken = null;
    _registeredUserId = null;
  }

  Future<void> _saveToken(
    SupabaseClient client,
    String userId,
    String token,
  ) async {
    try {
      final oldToken = _registeredToken;
      if (oldToken != null && oldToken != token) {
        await client
            .from('push_device_tokens')
            .delete()
            .eq('user_id', userId)
            .eq('fcm_token', oldToken);
      }

      await client.from('push_device_tokens').upsert({
        'fcm_token': token,
        'user_id': userId,
        'platform': 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'fcm_token');
      _registeredToken = token;
    } catch (error) {
      debugPrint('Could not save the FCM device token: $error');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (message.data['type'] != 'waitlist_promotion') return;
    final activityId = message.data['activity_id'] as String?;
    if (activityId == null || activityId.isEmpty) return;

    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription:
              'Updates when a spot opens in a waitlisted activity.',
          icon: 'ic_launcher_foreground',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      await _localNotifications.show(
        id: (message.data['event_id'] as String?)?.hashCode ??
            (DateTime.now().millisecondsSinceEpoch & 0x7fffffff),
        title: message.notification?.title ?? "You're In! \u{1F389}",
        body: message.notification?.body ?? 'A spot opened up in your activity.',
        notificationDetails: details,
        payload: activityId,
      );
    } catch (error) {
      debugPrint('Could not display the foreground notification: $error');
    }
  }

  void _dispatchActivityTap(String? activityId) {
    if (activityId == null || activityId.isEmpty) return;
    final handler = _onActivityTap;
    if (handler == null) {
      _pendingActivityId = activityId;
    } else {
      handler(activityId);
    }
  }
}
