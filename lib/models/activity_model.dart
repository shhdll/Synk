import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import 'weekly_streak.dart';

export 'weekly_streak.dart';

// Whether people can still join an activity, from how many spots are open.
enum ActivityAvailability {
  available,
  oneMoreNeeded,
  full;

  String get label => switch (this) {
    available => appL10n.available,
    oneMoreNeeded => appL10n.oneMoreNeeded,
    full => appL10n.full,
  };

  static ActivityAvailability fromSpotsOpen(int spotsOpen) {
    if (spotsOpen <= 0) return full;
    if (spotsOpen == 1) return oneMoreNeeded;
    return available;
  }
}

// Whether an activity happens indoors or outdoors.
enum ActivitySetting {
  indoor,
  outdoor;

  String get label => switch (this) {
    indoor => appL10n.settingIndoor,
    outdoor => appL10n.settingOutdoor,
  };

  static ActivitySetting? fromName(String? value) => switch (value) {
    'indoor' => indoor,
    'outdoor' => outdoor,
    _ => null,
  };
}

class Activity {
  Activity({
    required this.id,
    required this.title,
    required this.dateTime,
    DateTime? endsAt,
    required this.location,
    this.description = '',
    this.categoryEmoji = '',
    this.categoryLabel = '',
    this.hostId,
    this.hostName,
    this.hostUsername,
    this.hostAvatarUrl,
    this.hostGender,
    this.participantsCount,
    this.locationAddress,
    this.latitude,
    this.longitude,
    this.maxParticipants = 2,
    this.isPublic = true,
    this.setting,
    this.photoUrl,
    this.createdAt,
    this.activityCode,
    this.participationId,
    this.participationStatus,
  }) : endsAt = endsAt ?? dateTime.add(const Duration(hours: 2));

  final String id;
  final String title;
  final String description;

  final String categoryEmoji;
  final String categoryLabel;

  final DateTime dateTime;
  final DateTime endsAt;

  final String location;
  final String? locationAddress;

  final double? latitude;
  final double? longitude;

  final String? hostId;
  final String? hostName;
  final String? hostUsername;
  final String? hostAvatarUrl;
  final String? hostGender;
  final int? participantsCount;

  final int maxParticipants;

  final bool isPublic;

  // Null for activities created before the setting existed.
  final ActivitySetting? setting;

  final String? photoUrl;

  final DateTime? createdAt;

  // Unique six-digit code shown only to the activity host.
  final String? activityCode;

  // Identifies the signed-in user's participation record.
  final String? participationId;

  // Possible values: joined, pending, or waitlisted.
  final String? participationStatus;

  bool get isPast => dateTime.isBefore(DateTime.now());

  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get hasActivityCode => activityCode != null && activityCode!.isNotEmpty;

  bool get isPending => participationStatus == 'pending';

  bool get isWaitlisted => participationStatus == 'waitlisted';

  bool get isJoined => participationStatus == 'joined';

  bool isHostedBy(String? userId) {
    return userId != null && hostId != null && hostId == userId;
  }

  // The host currently counts as the first participant.
  int get joinedCount => participantsCount ?? 1;

  int get spotsOpen {
    return (maxParticipants - joinedCount).clamp(0, maxParticipants);
  }

  ActivityAvailability get availability =>
      ActivityAvailability.fromSpotsOpen(spotsOpen);

  String get status => availability.label;

  // ---------------------------------------------------------------------------
  // Supabase mapping
  // ---------------------------------------------------------------------------

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      id: map['id'] as String,
      hostId: map['host_id'] as String?,
      hostName:
          map['host_name'] as String? ??
          (map['host'] is Map ? (map['host']['full_name'] as String?) : null),
      hostUsername:
          map['host_username'] as String? ??
          (map['host'] is Map ? (map['host']['username'] as String?) : null),
      hostAvatarUrl:
          map['host_avatar_url'] as String? ??
          (map['host'] is Map ? (map['host']['avatar_url'] as String?) : null),
      hostGender:
          map['host_gender'] as String? ??
          (map['host'] is Map ? (map['host']['gender'] as String?) : null),
      participantsCount: map['participants_count'] as int?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      dateTime: DateTime.parse(map['starts_at'] as String).toLocal(),
      endsAt: map['ends_at'] == null
          ? DateTime.parse(map['starts_at'] as String).toLocal().add(const Duration(hours: 2))
          : DateTime.parse(map['ends_at'] as String).toLocal(),
      location: map['location_name'] as String? ?? '',
      locationAddress: map['location_address'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      maxParticipants: map['max_participants'] as int? ?? 2,
      isPublic: map['is_public'] as bool? ?? true,
      setting: ActivitySetting.fromName(map['setting'] as String?),
      photoUrl: map['photo_url'] as String?,
      categoryEmoji: map['category_emoji'] as String? ?? '',
      categoryLabel: map['category_label'] as String? ?? '',
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String).toLocal(),
      activityCode: map['activity_code'] as String?,
      participationId: map['participation_id'] as String?,
      participationStatus: map['participation_status'] as String?,
    );
  }

  // Generated database values are not included in the insert payload.
  Map<String, dynamic> toInsertMap() {
    return {
      'host_id': hostId,
      'title': title.trim(),
      'description': description.trim().isEmpty ? null : description.trim(),
      'starts_at': dateTime.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'location_name': location.trim(),
      'location_address': locationAddress?.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'max_participants': maxParticipants,
      'is_public': isPublic,
      'setting': setting?.name,
      'category_emoji': categoryEmoji.isEmpty ? null : categoryEmoji,
      'category_label': categoryLabel.isEmpty ? null : categoryLabel,
    };
  }

  Activity copyWith({
    String? photoUrl,
    String? participationId,
    String? participationStatus,
    String? hostName,
    String? hostUsername,
    String? hostAvatarUrl,
    String? hostGender,
    int? participantsCount,
    String? activityCode,
  }) {
    return Activity(
      id: id,
      hostId: hostId,
      hostName: hostName ?? this.hostName,
      hostUsername: hostUsername ?? this.hostUsername,
      hostAvatarUrl: hostAvatarUrl ?? this.hostAvatarUrl,
      hostGender: hostGender ?? this.hostGender,
      participantsCount: participantsCount ?? this.participantsCount,
      title: title,
      description: description,
      dateTime: dateTime,
      endsAt: endsAt,
      location: location,
      locationAddress: locationAddress,
      latitude: latitude,
      longitude: longitude,
      maxParticipants: maxParticipants,
      isPublic: isPublic,
      setting: setting,
      photoUrl: photoUrl ?? this.photoUrl,
      categoryEmoji: categoryEmoji,
      categoryLabel: categoryLabel,
      createdAt: createdAt,
      activityCode: activityCode ?? this.activityCode,
      participationId: participationId ?? this.participationId,
      participationStatus: participationStatus ?? this.participationStatus,
    );
  }
}

// Stores hosted, participating, and public activities.
class ActivityStore extends ChangeNotifier {
  final List<Activity> _mine = [];

  final List<Activity> _participating = [];

  final List<Activity> _feed = [];

  String? _currentUserId;

  String? get currentUserId => _currentUserId;

  set currentUserId(String? value) {
    if (_currentUserId == value) {
      return;
    }

    _currentUserId = value;
    notifyListeners();
  }

  // Changes only when the user leaves an activity or stops hosting one.
  int _participationVersion = 0;

  int get participationVersion => _participationVersion;

  // Set by "View on map"; the shell switches tabs and the map takes it.
  Activity? _mapFocus;

  Activity? get mapFocus => _mapFocus;

  void showOnMap(Activity activity) {
    _mapFocus = activity;
    notifyListeners();
  }

  Activity? takeMapFocus() {
    final focus = _mapFocus;
    _mapFocus = null;
    return focus;
  }

  // Set after creating an activity; the shell switches to Activities and
  // that page opens it.
  Activity? _detailsFocus;

  Activity? get detailsFocus => _detailsFocus;

  void showInActivities(Activity activity) {
    _detailsFocus = activity;
    notifyListeners();
  }

  Activity? takeDetailsFocus() {
    final focus = _detailsFocus;
    _detailsFocus = null;
    return focus;
  }

  int _pendingRequestCount = 0;

  int get pendingRequestCount => _pendingRequestCount;

  set pendingRequestCount(int value) {
    if (_pendingRequestCount == value) return;
    _pendingRequestCount = value;
    notifyListeners();
  }

  List<Activity> get mine => List.unmodifiable(_mine);

  List<Activity> get participating => List.unmodifiable(_participating);

  // The hosted or joined activity that overlaps [start, end), if any. Same
  // rule as public.activity_schedule_conflicts; null when it isn't loaded.
  Activity? conflictingActivity(
    DateTime start,
    DateTime end, {
    String? excludeId,
  }) {
    final now = DateTime.now();
    for (final activity in [..._mine, ...joined]) {
      if (activity.id == excludeId || !activity.endsAt.isAfter(now)) continue;
      if (activity.dateTime.isBefore(end) && start.isBefore(activity.endsAt)) {
        return activity;
      }
    }
    return null;
  }

  // Returns only activities with an accepted participation.
  List<Activity> get joined =>
      List.unmodifiable(_participating.where((activity) => activity.isJoined));

  List<Activity> get feed => List.unmodifiable(_feed);

  // Includes hosted, joined, pending, and waitlisted activities.
  List<Activity> get all => List.unmodifiable(_personalActivities);

  List<Activity> get upcoming =>
      _personalActivities.where((activity) => !activity.isPast).toList()
        ..sort((first, second) => first.dateTime.compareTo(second.dateTime));

  // Pending and waitlisted requests never became a seat, so they don't
  // belong in history.
  List<Activity> get past =>
      _personalActivities
          .where(
            (activity) =>
                activity.isPast &&
                !activity.isWaitlisted &&
                !activity.isPending,
          )
          .toList()
        ..sort((first, second) => second.dateTime.compareTo(first.dateTime));

  // Activities the user hosted or was accepted into whose time has passed.
  // Pending and waitlisted requests don't count.
  int get completedCount => _attended.length;

  // Weeks in a row with at least one attended activity, by the same rule as
  // [completedCount].
  WeeklyStreak get weeklyStreak =>
      WeeklyStreak.from(_attended.map((activity) => activity.dateTime));

  // Start times of attended activities, for the streak sheet.
  List<DateTime> get attendedTimes =>
      _attended.map((activity) => activity.dateTime).toList();

  // True near the end of the week when the streak will break unless the
  // user books something. Pending and waitlisted requests aren't bookings.
  bool get streakFading => WeeklyStreak.isFading(
    weeklyStreak,
    _personalActivities
        .where(
          (activity) =>
              !activity.isPast &&
              (activity.isHostedBy(_currentUserId) || activity.isJoined),
        )
        .map((activity) => activity.dateTime),
  );

  Iterable<Activity> get _attended => _personalActivities.where(
    (activity) =>
        activity.isPast &&
        (activity.isHostedBy(_currentUserId) || activity.isJoined),
  );

  List<Activity> get feedUpcoming =>
      _feed.where((activity) => !activity.isPast).toList()
        ..sort((first, second) => first.dateTime.compareTo(second.dateTime));

  // Home shows the public feed, hosted private activities, and private
  // activities that the user has already been accepted into.
  // Home displays upcoming public activities only.
  // Participation data is merged so joined and waitlisted cards
  // can display the correct status.
  List<Activity> get homeUpcoming {
    final participationByActivityId = {
      for (final activity in _participating) activity.id: activity,
    };

    return feedUpcoming.map((activity) {
      final participation = participationByActivityId[activity.id];

      if (participation == null) {
        return activity;
      }

      return activity.copyWith(
        participationId: participation.participationId,
        participationStatus: participation.participationStatus,
      );
    }).toList();
  }

  List<Activity> get _personalActivities {
    final activities = <String, Activity>{
      for (final activity in _participating) activity.id: activity,
      for (final activity in _mine) activity.id: activity,
    };

    return activities.values.toList();
  }

  void setMine(List<Activity> activities) {
    _mine
      ..clear()
      ..addAll(activities);

    notifyListeners();
  }

  // Stores joined, pending, and waitlisted activities.
  void setParticipating(List<Activity> activities) {
    _participating
      ..clear()
      ..addAll(activities);

    notifyListeners();
  }

  // Kept temporarily for callers that still use the previous method name.
  void setJoined(List<Activity> activities) {
    setParticipating(activities);
  }

  void setFeed(List<Activity> activities) {
    _feed
      ..clear()
      ..addAll(activities);

    notifyListeners();
  }

  void upsert(Activity activity) {
    if (activity.isHostedBy(_currentUserId)) {
      _replaceOrAdd(_mine, activity);
    } else {
      _mine.removeWhere(
        (existingActivity) => existingActivity.id == activity.id,
      );
    }

    if (activity.isPublic) {
      _replaceOrAdd(_feed, activity);
    } else {
      _feed.removeWhere(
        (existingActivity) => existingActivity.id == activity.id,
      );
    }

    notifyListeners();
  }

  void add(Activity activity) {
    upsert(activity);
  }

  void removeById(String id) {
    _mine.removeWhere((activity) => activity.id == id);

    _participating.removeWhere((activity) => activity.id == id);

    _feed.removeWhere((activity) => activity.id == id);

    notifyListeners();
  }

  // Removes the user's participation entry; the activity stays in other lists.
  void removeParticipation(String id) {
    final previousLength = _participating.length;

    _participating.removeWhere((activity) => activity.id == id);

    if (_participating.length == previousLength) {
      return;
    }

    _participationVersion++;
    notifyListeners();
  }

  // Removes an activity the user no longer hosts from the hosted list only.
  void removeHosted(String id) {
    final previousLength = _mine.length;

    _mine.removeWhere((activity) => activity.id == id);

    if (_mine.length == previousLength) {
      return;
    }

    _participationVersion++;
    notifyListeners();
  }

  Activity? byId(String id) {
    for (final activity in _mine) {
      if (activity.id == id) {
        return activity;
      }
    }

    for (final activity in _participating) {
      if (activity.id == id) {
        return activity;
      }
    }

    for (final activity in _feed) {
      if (activity.id == id) {
        return activity;
      }
    }

    return null;
  }

  void _replaceOrAdd(List<Activity> activities, Activity activity) {
    final index = activities.indexWhere(
      (existingActivity) => existingActivity.id == activity.id,
    );

    if (index == -1) {
      activities.add(activity);
    } else {
      activities[index] = activity;
    }
  }
}
