import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/interest_emojis.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../models/activities_model.dart';
import '../../../models/avatar_uploader.dart';

// Read-only profile of another user (e.g. someone asking to join), opened
// as a bottom sheet. Shows what's passed in right away, then fills in the
// bio, interests and stats once they load.
Future<void> showUserProfileSheet({
  required BuildContext context,
  required String userId,
  required String name,
  String? username,
  String? avatarUrl,
  String? gender,
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
  });

  final String userId;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? gender;

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
      // All columns, so a column missing from the table (age, rating)
      // can't fail the query; only the ones shown below are read.
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
      if (age != null) '$age yrs',
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
              const SizedBox(height: 20),
              ClipOval(
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
              const SizedBox(height: 12),
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
                      label: 'Activities',
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
                      label: 'Rating',
                    ),
                  ),
                ],
              ),
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
                  title: 'About',
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
                  title: 'Interests',
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
                            [?kInterestEmojis[interest], interest].join(' '),
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
          style: const TextStyle(
            fontSize: 12,
            color: SynkColors.textSecondary,
          ),
        ),
      ],
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
