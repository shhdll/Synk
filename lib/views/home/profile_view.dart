import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/profile_controller.dart';
import '../../core/constants/interest_emojis.dart';
import '../../core/constants/synk_colors.dart';
import '../../core/constants/synk_icons.dart';
import '../../l10n/l10n.dart';
import '../../models/activity_model.dart';
import '../../models/avatar_uploader.dart';
import 'edit_interests_view.dart';
import 'edit_profile_view.dart';
import 'logout_view.dart';
import 'settings_view.dart';
import 'widgets/app_header.dart';
import 'widgets/field_editor_sheet.dart';
import 'widgets/option_picker_sheet.dart';
import 'widgets/profile_info_row.dart';
import 'widgets/section_label.dart';
import '../../utils/text_direction.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key, this.activityStore});

  // Source of the completed activities count.
  final ActivityStore? activityStore;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final ProfileController _controller = ProfileController();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _controller.loadProfile();

    try {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((data) {
            if (!mounted) return;
            if (data.event == AuthChangeEvent.userUpdated) {
              _controller.loadProfile();
            } else if (data.event == AuthChangeEvent.tokenRefreshed) {
              // The email is read from the session, so a rebuild shows it.
              setState(() {});
            }
          });
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openLogout() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const LogoutView()));
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const EditProfileView()));
    // Picks up whatever changed while Edit Profile was open.
    await _controller.loadProfile();
  }

  Future<void> _openEditInterests(List<String> currentInterests) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            EditInterestsView(initialInterests: currentInterests),
      ),
    );
    // Picks up whatever changed while Edit Interests was open.
    await _controller.loadProfile();
  }

  Future<void> _editBio(String? currentBio) async {
    final controller = TextEditingController(text: currentBio ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FieldEditorSheet(
        title: context.l10n.bio,
        controller: controller,
        hint: context.l10n.addAShortBioSoPeople,
        formKey: formKey,
        maxLines: 4,
        maxLength: 160,
      ),
    );

    if (saved == true && mounted) {
      try {
        await _controller.updateBio(controller.text);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(context.l10n.unableToSaveBioPleaseTry)),
            );
        }
      }
    }
  }

  Future<void> _editActivityType(String? current) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => OptionPickerSheet(
        title: context.l10n.activityType,
        initialValue: current,
        options: [
          PickerOption(emoji: '🏠', label: 'Indoor'),
          PickerOption(emoji: '🌳', label: 'Outdoor'),
          PickerOption(emoji: '🤙🏻', label: 'I don’t mind'),
        ],
      ),
    );

    if (result == null || !mounted) return;

    try {
      await _controller.updateActivityType(result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(context.l10n.unableToSavePleaseTryAgain)),
          );
      }
    }
  }

  Future<void> _editLocationPreference(String? current) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => OptionPickerSheet(
        title: context.l10n.preferredLocation,
        initialValue: current,
        options: [
          PickerOption(emoji: '🏙️', label: 'In the city'),
          PickerOption(emoji: '🛣️', label: 'Away from the city'),
          PickerOption(emoji: '🤙🏻', label: 'I don’t mind'),
        ],
      ),
    );

    if (result == null || !mounted) return;

    try {
      await _controller.updateLocationPreference(result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(context.l10n.unableToSavePleaseTryAgain)),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, ?widget.activityStore]),
      builder: (context, _) {
        if (_controller.isLoading && _controller.profile.isEmpty) {
          return const Scaffold(
            backgroundColor: SynkColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildScaffold(context);
      },
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final profile = _controller.profile;
    final fullName = (profile['full_name'] as String?)?.trim();
    final bio = (profile['bio'] as String?)?.trim();
    final age = profile['age'];
    final gender = (profile['gender'] as String?)?.trim();
    final activityType = (profile['activity_type'] as String?)?.trim();
    final locationPreference = (profile['location_preference'] as String?)
        ?.trim();
    final interests =
        (profile['interests'] as List?)?.cast<String>() ?? const [];
    final username = _controller.username;
    final avatarImage = AvatarUploader.imageFor(profile);
    final displayImage =
        avatarImage ?? AvatarUploader.defaultImageForGender(gender);
    final friendsCount = profile['friends_count'] as int? ?? 0;
    final activitiesCount = widget.activityStore?.completedCount ?? 0;
    final ratingValue = profile['rating'];
    final ratingText = ratingValue is num
        ? ratingValue.toStringAsFixed(1)
        : '—';
    final handle = (username != null && username.isNotEmpty)
        ? '@$username'
        : _controller.email;
    final subtitle = [
      ?handle,
      if (age != null) context.l10n.ageYears(age),
    ].join(' · ');

    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Row(
              children: [
                const Expanded(child: AppHeader()),
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 1,
                  shadowColor: Colors.black12,
                  child: IconButton(
                    tooltip: context.l10n.settings,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsView(),
                      ),
                    ),
                    icon: const Icon(
                      Icons.settings_rounded,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: SynkColors.textSecondary.withValues(alpha: 0.10),
                ),
              ),
              child: Column(
                children: [
                  // Synk-gradient banner, framed by the card's own white
                  // padding rather than flush with its edges, with the
                  // avatar hanging off its bottom edge.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    // Photo on the left and Edit on the right in both
                    // languages, matching the English layout.
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomLeft,
                      children: [
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            // Warm, blurred lava-glow gradient for the header.
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFB6350F),
                                Color(0xFFFF8A1E),
                                Color(0xFFFFE3B0),
                                Color(0xFFFF7A1A),
                                Color(0xFFB6350F),
                              ],
                              stops: [0.0, 0.3, 0.55, 0.78, 1.0],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                        ),
                        Positioned(
                          left: 4,
                          bottom: -40,
                          child: Container(
                            width: 84,
                            height: 84,
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: displayImage,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _EditInfoButton(onTap: _openEditProfile),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left-aligned under the photo in both languages, and
                        // left to right so "@user · 21" doesn't get reordered.
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (fullName?.isNotEmpty ?? false)
                                      ? fullName!
                                      : context.l10n.synkMember,
                                  style: const TextStyle(
                                    fontSize: 19,
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
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _StatItem(
                                icon: Icons.people_alt_rounded,
                                value: '$friendsCount',
                                label: context.l10n.friends,
                              ),
                            ),
                            const _StatDivider(),
                            Expanded(
                              child: _StatItem(
                                icon: Icons.local_activity_rounded,
                                value: '$activitiesCount',
                                label: context.l10n.activities,
                              ),
                            ),
                            const _StatDivider(),
                            Expanded(
                              child: _StatItem(
                                icon: Icons.star_rounded,
                                value: ratingText,
                                label: context.l10n.rating,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _editBio(bio),
                          child: SizedBox(
                            width: double.infinity,
                            child: Text(
                              (bio?.isNotEmpty ?? false)
                                  ? bio!
                                  : context.l10n.addAShortBioSoPeople,
                              // Follows the bio's own language, not the app's.
                              textDirection: textDirectionOf(bio ?? ''),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                fontStyle: (bio?.isNotEmpty ?? false)
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                                height: 1.4,
                                color: (bio?.isNotEmpty ?? false)
                                    ? SynkColors.textPrimary
                                    : SynkColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _ExpandableSection(
              title: context.l10n.interests,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (interests.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: interests
                          .map(
                            (interest) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: SynkColors.textSecondary.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (kInterestEmojis[interest] != null) ...[
                                    Text(
                                      kInterestEmojis[interest]!,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    valueLabel(interest),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: SynkColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    )
                  else
                    Text(
                      context.l10n.addInterestsSoPeopleGetTo,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _EditInfoButton(
                      onTap: () => _openEditInterests(interests),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ExpandableSection(
              title: context.l10n.preferences,
              child: Column(
                children: [
                  ProfileInfoRow(
                    icon: Icons.local_activity_rounded,
                    label: context.l10n.activityType,
                    value: (activityType?.isNotEmpty ?? false)
                        ? valueLabel(activityType!)
                        : context.l10n.notSet,
                    onEdit: () => _editActivityType(activityType),
                  ),
                  const Divider(height: 20),
                  ProfileInfoRow(
                    icon: Icons.place_rounded,
                    label: context.l10n.preferredLocation,
                    value: (locationPreference?.isNotEmpty ?? false)
                        ? valueLabel(locationPreference!)
                        : context.l10n.notSet,
                    onEdit: () => _editLocationPreference(locationPreference),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _openLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: SynkColors.orangeDark,
                  side: const BorderSide(color: SynkColors.orangeDark),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(SynkIcons.logout),
                label: Text(
                  context.l10n.logOut,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card with its title and an expand/collapse arrow inside; [child] is shown
/// below the header only while expanded.
class _ExpandableSection extends StatefulWidget {
  const _ExpandableSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.10),
        ),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  SectionLabel(widget.title),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: SynkColors.textSecondary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_expanded) ...[const SizedBox(height: 14), widget.child],
          ],
        ),
      ),
    );
  }
}

class _EditInfoButton extends StatelessWidget {
  const _EditInfoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: SynkColors.textSecondary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.edit_rounded,
          size: 16,
          color: SynkColors.textSecondary,
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: SynkColors.textSecondary.withValues(alpha: 0.15),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: SynkColors.orangeDark),
            const SizedBox(width: 4),
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
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: SynkColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
