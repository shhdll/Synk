import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/language_controller.dart';
import '../l10n/l10n.dart';

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
  static String get _channelName => appL10n.waitlistPromotions;
  static const String _activityUpdatesChannelId = 'activity_updates';
  static String get _activityUpdatesChannelName => appL10n.activityUpdates;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefresh;
  String? _registeredUserId;
  String? _registeredToken;
  String? _pendingActivityId;
  void Function(String activityId)? _onActivityTap;
  bool _pendingJoinRequestsTap = false;
  VoidCallback? _onJoinRequestsTap;
  bool _pendingFriendRequestsTap = false;
  VoidCallback? _onFriendRequestsTap;
  bool _pendingFriendsTap = false;
  VoidCallback? _onFriendsTap;
  bool _pendingScheduleConflictsTap = false;
  VoidCallback? _onScheduleConflictsTap;
  void Function(String activityId)? _onActivityUpdated;
  VoidCallback? _onMessageReceived;
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
          _dispatchNotificationTap(response.payload);
        },
      );

      final channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: appL10n.updatesWhenASpotOpensIn,
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      final activityUpdatesChannel = AndroidNotificationChannel(
        _activityUpdatesChannelId,
        _activityUpdatesChannelName,
        description: 'Updates to activities you have joined.',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(activityUpdatesChannel);

      FirebaseMessaging.onMessage.listen((message) {
        _onMessageReceived?.call();
        if (message.data['type'] == 'activity_conflict') {
          // Show the conflict alert and immediately require the user to
          // resolve it while the app is open.
          unawaited(() async {
            await _showForegroundNotification(message);
            _dispatchNotificationTap('schedule_conflict');
          }());
        } else {
          unawaited(_showForegroundNotification(message));
        }
        const refreshTypes = {
          'activity_updated',
          'activity_deleted',
          'join_request_accepted',
          'join_request_received',
          'waitlist_promotion',
          'host_assigned',
          'activity_conflict',
          'activity_full',
        };
        if (refreshTypes.contains(message.data['type'])) {
          final activityId = message.data['activity_id'] as String?;
          if (activityId != null && activityId.isNotEmpty) {
            _onActivityUpdated?.call(activityId);
          }
        }
      });
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _dispatchMessageTap(message),
      );

      _initialized = true;

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _dispatchMessageTap(initialMessage);
      }

      final localLaunch = await _localNotifications
          .getNotificationAppLaunchDetails();
      if (localLaunch?.didNotificationLaunchApp ?? false) {
        _dispatchNotificationTap(localLaunch?.notificationResponse?.payload);
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

  void setJoinRequestsTapHandler(VoidCallback handler) {
    _onJoinRequestsTap = handler;
    if (_pendingJoinRequestsTap) {
      _pendingJoinRequestsTap = false;
      handler();
    }
  }

  void setFriendRequestsTapHandler(VoidCallback handler) {
    _onFriendRequestsTap = handler;
    if (_pendingFriendRequestsTap) {
      _pendingFriendRequestsTap = false;
      handler();
    }
  }

  void setFriendsTapHandler(VoidCallback handler) {
    _onFriendsTap = handler;
    if (_pendingFriendsTap) {
      _pendingFriendsTap = false;
      handler();
    }
  }

  void setScheduleConflictsTapHandler(VoidCallback handler) {
    _onScheduleConflictsTap = handler;
    if (_pendingScheduleConflictsTap) {
      _pendingScheduleConflictsTap = false;
      handler();
    }
  }

  void setActivityUpdatedHandler(void Function(String activityId)? handler) {
    _onActivityUpdated = handler;
  }

  // Called for every push that arrives while the app is open.
  void setMessageReceivedHandler(VoidCallback? handler) {
    _onMessageReceived = handler;
  }

  void refreshActivity(String activityId) {
    _onActivityUpdated?.call(activityId);
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
        'language': LanguageController.instance.locale.languageCode,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'fcm_token');
      _registeredToken = token;
    } catch (error) {
      debugPrint('Could not save the FCM device token: $error');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final type = message.data['type'] as String?;
    if (type != 'waitlist_promotion' &&
        type != 'activity_updated' &&
        type != 'activity_deleted' &&
        type != 'join_request_accepted' &&
        type != 'join_request_rejected' &&
        type != 'join_request_received' &&
        type != 'friend_request_received' &&
        type != 'friend_request_accepted' &&
        type != 'host_assigned' &&
        type != 'activity_conflict' &&
        type != 'activity_full') return;
    final activityId = message.data['activity_id'] as String?;
    final isFriendRequest = type == 'friend_request_received';
    final isFriendAccepted = type == 'friend_request_accepted';
    if (!isFriendRequest &&
        !isFriendAccepted &&
        (activityId == null || activityId.isEmpty)) {
      return;
    }

    final activityUpdate = type == 'activity_updated' ||
        type == 'activity_deleted' ||
        type == 'join_request_accepted' ||
        type == 'join_request_rejected' ||
        type == 'join_request_received' ||
        isFriendRequest ||
        isFriendAccepted ||
        type == 'host_assigned' ||
        type == 'activity_conflict' ||
        type == 'activity_full';
    final channelId = activityUpdate
        ? _activityUpdatesChannelId
        : _channelId;
    final channelName = activityUpdate
        ? _activityUpdatesChannelName
        : _channelName;
    final channelDescription = activityUpdate
        ? appL10n.updatesToActivitiesYouHaveJoined
        : appL10n.updatesWhenASpotOpensIn;

    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          icon: 'ic_launcher_foreground',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      await _localNotifications.show(
        id: (message.data['event_id'] as String?)?.hashCode ??
            (DateTime.now().millisecondsSinceEpoch & 0x7fffffff),
        title:
            message.notification?.title ??
            (isFriendRequest
                ? appL10n.friendRequestNotificationTitle
                : isFriendAccepted
                ? appL10n.friendRequestAcceptedNotificationTitle
                : activityUpdate
                ? appL10n.activityUpdated
                : appL10n.youreIn),
        body:
            message.notification?.body ??
            (isFriendRequest
                ? appL10n.notifFriendRequestReceived(
                    (message.data['requester_name'] as String?) ??
                        appL10n.communityMember,
                  )
                : isFriendAccepted
                ? appL10n.notifFriendRequestAccepted(
                    (message.data['friend_name'] as String?) ??
                        appL10n.communityMember,
                  )
                : activityUpdate
                ? appL10n.anActivityYouJoinedHasNew
                : appL10n.aSpotOpenedUpInYour),
        notificationDetails: details,
        payload: type == 'join_request_received'
            ? 'join_request_received'
            : isFriendRequest
            ? 'friend_request_received'
            : isFriendAccepted
            ? 'friend_request_accepted'
            : type == 'activity_conflict'
            ? 'schedule_conflict'
            : activityId,
      );
    } catch (error) {
      debugPrint('Could not display the foreground notification: $error');
    }
  }

  void _dispatchMessageTap(RemoteMessage message) {
    if (message.data['type'] == 'join_request_received') {
      _dispatchNotificationTap('join_request_received');
    } else if (message.data['type'] == 'friend_request_received') {
      _dispatchNotificationTap('friend_request_received');
    } else if (message.data['type'] == 'friend_request_accepted') {
      _dispatchNotificationTap('friend_request_accepted');
    } else if (message.data['type'] == 'activity_conflict') {
      _dispatchNotificationTap('schedule_conflict');
    } else {
      _dispatchActivityTap(message.data['activity_id'] as String?);
    }
  }

  void _dispatchNotificationTap(String? payload) {
    if (payload == 'schedule_conflict') {
      final handler = _onScheduleConflictsTap;
      if (handler == null) {
        _pendingScheduleConflictsTap = true;
      } else {
        handler();
      }
      return;
    }
    if (payload == 'join_request_received') {
      final handler = _onJoinRequestsTap;
      if (handler == null) {
        _pendingJoinRequestsTap = true;
      } else {
        handler();
      }
      return;
    }
    if (payload == 'friend_request_received') {
      final handler = _onFriendRequestsTap;
      if (handler == null) {
        _pendingFriendRequestsTap = true;
      } else {
        handler();
      }
      return;
    }
    if (payload == 'friend_request_accepted') {
      final handler = _onFriendsTap;
      if (handler == null) {
        _pendingFriendsTap = true;
      } else {
        handler();
      }
      return;
    }
    _dispatchActivityTap(payload);
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
