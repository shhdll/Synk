import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../controllers/friends_controller.dart';
import '../../../core/constants/interest_emojis.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activities_model.dart';
import '../../../models/avatar_uploader.dart';
import '../../../models/friends_model.dart';
import '../../../models/weekly_streak.dart';
import '../../../utils/custom_widgets/synk_feedback.dart';
import '../../widgets/avatar_preview.dart';
import '../../widgets/profile_header_banner.dart';
import '../chats_view.dart';
import '../user_friends_view.dart';
import 'friend_action_button.dart';
import 'friend_options_sheet.dart';
import 'recent_activities_section.dart';
import 'report_user_sheet.dart';
import 'streak_widgets.dart';

Future<void> showUserProfileSheet({
  required BuildContext context,
  required String userId,
  required String name,
  String? username,
  String? avatarUrl,
  String? gender,
  bool showMessageButton = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Drag it up to fill the screen; down past half closes it.
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 1,
      snap: true,
      snapSizes: const [0.85],
      builder: (context, scrollController) => UserProfileSheet(
        userId: userId,
        name: name,
        username: username,
        avatarUrl: avatarUrl,
        gender: gender,
        showMessageButton: showMessageButton,
        scrollController: scrollController,
      ),
    ),
  );
}

class UserProfileSheet extends StatefulWidget {
  const UserProfileSheet({
    super.key,
    required this.userId,
    required this.name,
    this.username,
    this.avatarUrl,
    this.gender,
    this.showMessageButton = true,
    this.scrollController,
  });

  final String userId;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? gender;

  // Off when opened from your chat with this person.
  final bool showMessageButton;

  // From the draggable sheet around it.
  final ScrollController? scrollController;

  @override
  State<UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<UserProfileSheet> {
  Map<String, dynamic>? _profile;
  int? _completedCount;
  List<FriendUser>? _friends;
  WeeklyStreak? _streak;
  bool _loading = true;

  // The profile row came back empty, not failed: the person blocked the
  // viewer, or the account is gone. Shown the same way, without a reason.
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    var profileFailed = false;
    final results = await Future.wait<Object?>([
      // select() so a missing column can't break it.
      client
          .from('users')
          .select()
          .eq('id', widget.userId)
          .maybeSingle()
          .then<Object?>(
            (row) => row,
            onError: (_) {
              profileFailed = true;
              return null;
            },
          ),
      ActivitiesModel()
          .fetchCompletedCount(userId: widget.userId)
          .then<Object?>((count) => count, onError: (_) => null),
      FriendsModel()
          .fetchFriendsOf(widget.userId)
          .then<Object?>((friends) => friends, onError: (_) => null),
      ActivitiesModel()
          .fetchStreakTimes(widget.userId)
          .then<Object?>((times) => times, onError: (_) => null),
    ]);
    if (!mounted) return;
    setState(() {
      _profile = results[0] as Map<String, dynamic>?;
      _unavailable = !profileFailed && _profile == null;
      _completedCount = results[1] as int?;
      _friends = results[2] as List<FriendUser>?;
      final times = results[3] as List<DateTime>?;
      _streak = times == null ? null : WeeklyStreak.from(times);
      _loading = false;
    });
  }

  String? _text(String key) {
    final value = (_profile?[key] as String?)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final name = _text('full_name') ?? widget.name;
    final username = _text('username') ?? widget.username;
    final gender = _text('gender') ?? widget.gender;
    final avatarUrl = _text('avatar_url') ?? widget.avatarUrl?.trim();
    final bio = _text('bio');
    final age = _profile?['age'];
    final interests =
        (_profile?['interests'] as List?)?.cast<String>() ?? const <String>[];
    final rating = _profile?['rating'];
    final ratingCount = _profile?['rating_count'];
    final friends = _friends;
    final streak = _streak;

    final subtitle = [
      if (username != null && username.isNotEmpty) '@$username',
      if (age != null) context.l10n.ageYears(age),
    ].join(' · ');

    final fallback = AvatarUploader.defaultImageForGender(gender);
    final photo = avatarUrl != null && avatarUrl.startsWith('http')
        ? NetworkImage(avatarUrl)
        : fallback;

    final media = MediaQuery.of(context);

    // Nothing passed in by the opener (name, photo) is shown until the
    // lookup finishes: an old link or notification may point to someone
    // whose profile is no longer available.
    if (_loading) {
      return _buildStatusSheet(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 36),
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: SynkColors.orangeDark,
            ),
          ),
        ),
      );
    }
    if (_unavailable) return _buildUnavailable(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 0 at the usual height, 1 at full screen: the corners square off
        // and the content moves below the status bar.
        final full = ((constraints.maxHeight / media.size.height - 0.85) / 0.15)
            .clamp(0.0, 1.0);
        return Container(
          decoration: BoxDecoration(
            color: SynkColors.background,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28 * (1 - full)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: EdgeInsets.fromLTRB(
                24,
                12 + media.padding.top * full,
                24,
                24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: SynkColors.textSecondary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Their header, with the photo hanging off its bottom edge.
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Built only after loading (see build()), so the
                      // default color never flashes.
                      ProfileHeaderBanner.forProfile(_profile, height: 100),
                      Positioned(
                        bottom: -50,
                        child: GestureDetector(
                          onTap: () => showAvatarPreview(context, photo),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: SynkColors.background,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: Image(
                                image: photo,
                                width: 92,
                                height: 92,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Image(
                                  image: fallback,
                                  width: 92,
                                  height: 92,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 62),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: SynkColors.textPrimary,
                          ),
                        ),
                      ),
                      // Friends only; the times aren't shared with anyone else.
                      if (streak != null &&
                          FriendsController.instance.statusFor(widget.userId) ==
                              FriendshipStatus.friends) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: context.l10n.streakTitle,
                          child: StreakPill(
                            weeks: streak.weeks,
                            active: streak.weeks > 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: friends == null
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => UserFriendsView(
                                      name: name,
                                      friends: friends,
                                    ),
                                  ),
                                ),
                          child: _Stat(
                            icon: Icons.people_alt_rounded,
                            value: friends?.length.toString() ?? '—',
                            label: context.l10n.friends,
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 34,
                        color: SynkColors.textSecondary.withValues(alpha: 0.15),
                      ),
                      Expanded(
                        child: _Stat(
                          icon: Icons.local_activity_rounded,
                          value: _completedCount?.toString() ?? '—',
                          label: context.l10n.activities,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 34,
                        color: SynkColors.textSecondary.withValues(alpha: 0.15),
                      ),
                      Expanded(
                        child: _Stat(
                          icon: Icons.star_rounded,
                          value: rating is num
                              ? rating.toStringAsFixed(1)
                              : '—',
                          // "12 reviews" under the stars once rated.
                          label: ratingCount is int && ratingCount > 0
                              ? context.l10n.reviewsCount(ratingCount)
                              : context.l10n.rating,
                        ),
                      ),
                    ],
                  ),
                  if (widget.userId !=
                      Supabase.instance.client.auth.currentUser?.id) ...[
                    const SizedBox(height: 20),
                    _FriendActions(
                      showMessageButton: widget.showMessageButton,
                      user: FriendUser(
                        id: widget.userId,
                        name: name,
                        username: username,
                        avatarUrl: avatarUrl,
                        gender: gender,
                      ),
                    ),
                  ],
                  if (bio != null) ...[
                    const SizedBox(height: 20),
                    _Card(
                      title: context.l10n.about,
                      child: Text(
                        bio,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: SynkColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                  if (interests.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    FoldCard(
                      title: context.l10n.interests,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final interest in interests)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: SynkColors.textSecondary.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Text(
                                [
                                  ?kInterestEmojis[interest],
                                  valueLabel(interest),
                                ].join(' '),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: SynkColors.textPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (widget.userId !=
                      Supabase.instance.client.auth.currentUser?.id)
                    // Reloads when the friendship changes.
                    ListenableBuilder(
                      listenable: FriendsController.instance,
                      builder: (context, _) => RecentActivitiesSection(
                        key: ValueKey(
                          FriendsController.instance.statusFor(widget.userId),
                        ),
                        userId: widget.userId,
                        userName: name,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Only this line, nothing about who it is or why.
  Widget _buildUnavailable(BuildContext context) {
    return _buildStatusSheet(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 28),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: SynkColors.textSecondary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_off_outlined,
              size: 32,
              color: SynkColors.labelGrey,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.l10n.thisProfileIsUnavailable,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: SynkColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // The sheet's frame and handle, around a loading or unavailable state.
  Widget _buildStatusSheet(Widget child) {
    return Container(
      decoration: const BoxDecoration(
        color: SynkColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SynkColors.textSecondary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: SynkColors.orangeDark),
            const SizedBox(width: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SynkColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: SynkColors.textSecondary),
        ),
      ],
    );
  }
}

// Add friend (or Requested / Accept / Following), plus a ⋯ menu to report
// or block. Friends also get Message. A blocked user only gets Unblock.
class _FriendActions extends StatelessWidget {
  const _FriendActions({required this.user, this.showMessageButton = true});

  final FriendUser user;
  final bool showMessageButton;

  @override
  Widget build(BuildContext context) {
    final friends = FriendsController.instance;

    return ListenableBuilder(
      listenable: friends,
      builder: (context, _) {
        final status = friends.statusFor(user.id);

        if (status == FriendshipStatus.blocked) {
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final ok = await friends.unblock(user.id);
                if (!ok && context.mounted) {
                  SynkFeedback.showError(
                    context,
                    context.l10n.somethingWentWrongPleaseTryAgain,
                  );
                }
              },
              icon: const Icon(Icons.block_rounded, size: 20),
              label: Text(context.l10n.unblock),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: SynkColors.textPrimary,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                side: BorderSide(
                  color: SynkColors.textSecondary.withValues(alpha: 0.30),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          );
        }

        return Row(
          children: [
            Expanded(child: FriendActionButton(user: user)),
            const SizedBox(width: 10),
            if (showMessageButton && status == FriendshipStatus.friends) ...[
              Expanded(child: _MessageButton(user: user)),
              const SizedBox(width: 10),
            ],
            PopupMenuButton<VoidCallback>(
              tooltip: context.l10n.moreOptions,
              onSelected: (action) => action(),
              position: PopupMenuPosition.under,
              offset: const Offset(0, 6),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: () =>
                      showReportUserSheet(context: context, user: user),
                  child: Text(
                    context.l10n.reportName(user.name.split(' ').first),
                  ),
                ),
                PopupMenuItem(
                  value: () => confirmBlockUser(context, user),
                  child: Text(
                    context.l10n.blockName(user.name.split(' ').first),
                    style: const TextStyle(color: SynkColors.badge),
                  ),
                ),
              ],
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: SynkColors.textSecondary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.more_horiz_rounded,
                  color: SynkColors.textPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Opens the chat with a friend, or starts it. The sheet stays underneath,
// so going back returns to the profile.
class _MessageButton extends StatefulWidget {
  const _MessageButton({required this.user});

  final FriendUser user;

  @override
  State<_MessageButton> createState() => _MessageButtonState();
}

class _MessageButtonState extends State<_MessageButton> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    await openDirectChatWith(context, widget.user);
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    // The main action once you're friends: filled, same corners as
    // Following beside it.
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return Material(
      color: SynkColors.orangeDark,
      shape: shape,
      child: InkWell(
        onTap: _open,
        customBorder: shape,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _opening
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.sms_outlined,
                      size: 20,
                      color: Colors.white,
                    ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: SynkColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
