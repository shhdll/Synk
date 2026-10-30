import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../controllers/friends_controller.dart';
import '../../../core/constants/interest_emojis.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activities_model.dart';
import '../../../models/avatar_uploader.dart';
import '../../../models/friends_model.dart';
import '../../../utils/custom_widgets/synk_feedback.dart';
import '../../widgets/avatar_preview.dart';
import '../../widgets/profile_header_banner.dart';
import '../chats_view.dart';
import 'friend_action_button.dart';
import 'friend_options_sheet.dart';

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
    builder: (_) => UserProfileSheet(
      userId: userId,
      name: name,
      username: username,
      avatarUrl: avatarUrl,
      gender: gender,
      showMessageButton: showMessageButton,
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
  });

  final String userId;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? gender;

  // Off when opened from your chat with this person.
  final bool showMessageButton;

  @override
  State<UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<UserProfileSheet> {
  Map<String, dynamic>? _profile;
  int? _completedCount;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final results = await Future.wait<Object?>([
      // select() so a missing column can't break it.
      client
          .from('users')
          .select()
          .eq('id', widget.userId)
          .maybeSingle()
          .then<Object?>((row) => row, onError: (_) => null),
      ActivitiesModel()
          .fetchCompletedCount(userId: widget.userId)
          .then<Object?>((count) => count, onError: (_) => null),
    ]);
    if (!mounted) return;
    setState(() {
      _profile = results[0] as Map<String, dynamic>?;
      _completedCount = results[1] as int?;
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

    final subtitle = [
      if (username != null && username.isNotEmpty) '@$username',
      if (age != null) context.l10n.ageYears(age),
    ].join(' · ');

    final fallback = AvatarUploader.defaultImageForGender(gender);
    final photo = avatarUrl != null && avatarUrl.startsWith('http')
        ? NetworkImage(avatarUrl)
        : fallback;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: SynkColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
                  // Plain while loading, so the default color doesn't flash.
                  _loading
                      ? Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: SynkColors.beige.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        )
                      : ProfileHeaderBanner.forProfile(_profile, height: 100),
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
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: SynkColors.textPrimary,
                ),
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
                      value: rating is num ? rating.toStringAsFixed(1) : '—',
                      label: context.l10n.rating,
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
              if (_loading) ...[
                const SizedBox(height: 24),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: SynkColors.orangeDark,
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
                _Card(
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

// Add friend (or Requested / Accept / Friends), plus a ⋯ menu to unfriend or
// block. Friends also get Message. A blocked user only gets Unblock.
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
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              itemBuilder: (_) => [
                if (status == FriendshipStatus.friends)
                  PopupMenuItem(
                    value: () => confirmRemoveFriend(context, user),
                    child: Text(context.l10n.removeFriend),
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
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: SynkColors.textSecondary.withValues(alpha: 0.30),
                    width: 1.5,
                  ),
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
    // White with an orange outline, pill-shaped like Following beside it.
    final shape = StadiumBorder(
      side: BorderSide(
        color: SynkColors.orangeDeep.withValues(alpha: 0.4),
        width: 1.5,
      ),
    );
    return Material(
      color: Colors.white,
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
                        color: SynkColors.orangeDeep,
                      ),
                    )
                  : const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 20,
                      color: SynkColors.orangeDeep,
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
                    color: SynkColors.orangeDeep,
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
