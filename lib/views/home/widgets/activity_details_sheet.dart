import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../models/activities_model.dart';
import '../../../models/activity_model.dart';
import '../../../models/avatar_uploader.dart';
import '../../../models/user_profile_model.dart';
import '../../../utils/maps_launcher.dart';
import '../../widgets/crown_icon.dart';
import 'activity_thumbnail.dart';

Future<void> showActivityDetailsSheet({
  required BuildContext context,
  required Activity activity,
  required ActivityStore activityStore,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) =>
        ActivityDetailsSheet(activity: activity, activityStore: activityStore),
  );
}

class ActivityDetailsSheet extends StatefulWidget {
  const ActivityDetailsSheet({
    super.key,
    required this.activity,
    required this.activityStore,
  });

  final Activity activity;
  final ActivityStore activityStore;

  @override
  State<ActivityDetailsSheet> createState() => _ActivityDetailsSheetState();
}

class _ActivityDetailsSheetState extends State<ActivityDetailsSheet> {
  final ActivitiesModel _activitiesModel = ActivitiesModel();

  late Activity _currentActivity;
  bool _isLoadingParticipants = true;
  List<Map<String, dynamic>> _participants = [];

  // The viewer's own profile, for their locally saved photo.
  Map<String, dynamic>? _ownProfile;

  @override
  void initState() {
    super.initState();
    _currentActivity = widget.activity;
    _loadParticipants();
    _loadOwnProfile();
  }

  Future<void> _loadOwnProfile() async {
    try {
      final profile = await UserProfileModel().fetchProfile();
      if (mounted) setState(() => _ownProfile = profile);
    } catch (_) {
      // Without it the viewer's row uses their uploaded photo or default.
    }
  }

  Future<void> _loadParticipants() async {
    try {
      final list = await _activitiesModel.fetchParticipantsList(
        _currentActivity.id,
      );
      if (mounted) {
        setState(() {
          _participants = list
              .where((p) => p['user_id'] != _currentActivity.hostId)
              .toList();
          _isLoadingParticipants = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingParticipants = false;
        });
      }
    }
  }

  // The host counts as the first participant, as on the home card.
  int get _joinedCount => _participants.isNotEmpty
      ? 1 + _participants.length
      : _currentActivity.joinedCount;

  int get _spotsLeft => (_currentActivity.maxParticipants - _joinedCount).clamp(
    0,
    _currentActivity.maxParticipants,
  );

  String get _formattedDateTime {
    final date = _currentActivity.dateTime;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$weekday, $month ${date.day}, ${date.year} · $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: SynkColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderVisual(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        24 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleAndBadges(),
                          const SizedBox(height: 18),
                          _buildScheduleAndLocationSection(),
                          if (_currentActivity.description.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _buildDescriptionSection(),
                          ],
                          const SizedBox(height: 22),
                          _buildParticipantsSection(),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderVisual() {
    final photoUrl = _currentActivity.photoUrl;

    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: SynkColors.backgroundLight,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                SynkColors.orange.withValues(alpha: 0.25),
                SynkColors.beige.withValues(alpha: 0.40),
                SynkColors.pink.withValues(alpha: 0.20),
              ],
            ),
          ),
          child: photoUrl != null && photoUrl.isNotEmpty
              ? Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                  errorBuilder: (_, _, _) => _buildFallbackHeaderAsset(),
                )
              : _buildFallbackHeaderAsset(),
        ),

        // Drag handle, floating on the image so the image reaches the
        // top edge of the sheet.
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),

        // Top controls: Close button & Spots badge
        Positioned(
          top: 20,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: SynkColors.orangeDark.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: SynkColors.textPrimary,
                    size: 20,
                  ),
                ),
              ),
              _buildSpotsBadge(),
            ],
          ),
        ),

        // Category Tag at bottom of cover
        if (_currentActivity.categoryLabel.isNotEmpty)
          Positioned(
            bottom: 12,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_currentActivity.categoryEmoji.isNotEmpty) ...[
                    Text(
                      _currentActivity.categoryEmoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    _currentActivity.categoryLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFallbackHeaderAsset() {
    final visual = ActivityVisual.of(_currentActivity);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            visual.tint.withValues(alpha: 0.14),
            visual.tint.withValues(alpha: 0.30),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          visual.icon,
          size: 64,
          color: Color.lerp(visual.tint, SynkColors.textPrimary, 0.35),
        ),
      ),
    );
  }

  Widget _buildSpotsBadge() {
    final spots = _spotsLeft;
    final isFull = spots == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: SynkColors.orangeDark.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFull ? Icons.lock_outline_rounded : Icons.group_rounded,
            size: 13,
            color: isFull ? SynkColors.textSecondary : SynkColors.orangeDark,
          ),
          const SizedBox(width: 5),
          Text(
            isFull
                ? 'Full ($_joinedCount/${_currentActivity.maxParticipants})'
                : '$spots ${_spotsLeft == 1 ? "spot" : "spots"} left',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isFull ? SynkColors.textSecondary : SynkColors.orangeDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleAndBadges() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _currentActivity.title,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            color: SynkColors.textPrimary,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleAndLocationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        children: [
          // Date & Time
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SynkColors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 20,
                  color: SynkColors.orangeDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date & Time',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formattedDateTime,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              height: 1,
              color: SynkColors.textSecondary.withValues(alpha: 0.12),
            ),
          ),

          // Location
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SynkColors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 20,
                  color: SynkColors.teal,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentActivity.location,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                    if (_currentActivity.locationAddress != null &&
                        _currentActivity.locationAddress!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _currentActivity.locationAddress!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: SynkColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (MapsLauncher.canOpen(_currentActivity)) ...[
            const SizedBox(height: 14),
            _buildOpenInMapsButton(),
          ],
        ],
      ),
    );
  }

  // Opens the activity's location in Google Maps (app or browser).
  Widget _buildOpenInMapsButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          bool opened;
          try {
            opened = await MapsLauncher.open(_currentActivity);
          } catch (_) {
            opened = false;
          }
          if (!opened) {
            messenger.showSnackBar(
              const SnackBar(content: Text("Couldn't open Google Maps.")),
            );
          }
        },
        // Official Google Maps pin (assets/google_maps_logo.png).
        icon: Image.asset(
          'assets/google_maps_logo.png',
          height: 20,
          errorBuilder: (_, _, _) => const Icon(Icons.map_rounded, size: 18),
        ),
        label: const Text('Open in Google Maps'),
        style: TextButton.styleFrom(
          foregroundColor: SynkColors.textPrimary,
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: SynkColors.textSecondary.withValues(alpha: 0.18),
            ),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About This Activity',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: SynkColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: SynkColors.textSecondary.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            _currentActivity.description,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
              color: SynkColors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Participants',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SynkColors.textPrimary,
              ),
            ),
            Text(
              '$_joinedCount / ${_currentActivity.maxParticipants} spots',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: SynkColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingParticipants)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SynkColors.orange,
              ),
            ),
          )
        else
          _buildParticipantsList(),
      ],
    );
  }

  Widget _buildParticipantsList() {
    // Collect attendees: starting with host
    final hostName = _currentActivity.hostName ?? 'Host';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          // Host entry
          _buildParticipantRow(
            name: hostName,
            username: _currentActivity.hostUsername,
            userId: _currentActivity.hostId,
            avatarUrl: _currentActivity.hostAvatarUrl,
            gender: _currentActivity.hostGender,
            isHost: true,
          ),

          // Joined members
          for (final p in _participants) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                height: 1,
                color: SynkColors.textSecondary.withValues(alpha: 0.08),
              ),
            ),
            _buildParticipantRow(
              name: (p['full_name'] as String?) ?? 'Community Member',
              username: p['username'] as String?,
              userId: p['user_id'] as String?,
              avatarUrl: p['avatar_url'] as String?,
              gender: p['gender'] as String?,
              isHost: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantRow({
    required String name,
    required String? username,
    required String? userId,
    required String? avatarUrl,
    required String? gender,
    required bool isHost,
  }) {
    return Row(
      children: [
        _buildAvatar(
          userId: userId,
          avatarUrl: avatarUrl,
          gender: gender,
          size: 38,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: SynkColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (username != null && username.isNotEmpty)
                Text(
                  '@$username',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: SynkColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        if (isHost)
          Container(
            padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
            decoration: BoxDecoration(
              color: SynkColors.orangeDark.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CrownIcon(size: 14, color: SynkColors.orangeDark),
                SizedBox(width: 4),
                Text(
                  'Host',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SynkColors.orangeDark,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // The participant's uploaded photo; for the viewer's own row, also the
  // photo saved on this device. Falls back to the app's default avatar.
  Widget _buildAvatar({
    required String? userId,
    required String? avatarUrl,
    required String? gender,
    required double size,
  }) {
    final fallback = AvatarUploader.defaultImageForGender(gender);
    final url = avatarUrl?.trim();

    ImageProvider? photo;
    if (url != null && url.startsWith('http')) {
      photo = NetworkImage(url);
    } else if (userId != null &&
        userId == widget.activityStore.currentUserId &&
        _ownProfile != null) {
      photo = AvatarUploader.imageFor(_ownProfile!);
    }

    return ClipOval(
      child: Image(
        image: photo ?? fallback,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image(
          image: fallback,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
