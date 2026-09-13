import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../models/avatar_uploader.dart';
import '../welcome_view.dart';
import 'edit_profile_view.dart';
import 'widgets/app_header.dart';
import 'widgets/section_label.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final ProfileController _controller = ProfileController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final success = await _controller.logout();
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeView()),
        (route) => false,
      );
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_controller.errorMessage ?? 'Unable to log out.'),
        ),
      );
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const EditProfileView()));
    // The edited fields live on the Supabase user session, so simply
    // rebuilding picks up whatever changed.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final metadata = _controller.metadata;
    final fullName = (metadata['full_name'] as String?)?.trim();
    final bio = (metadata['bio'] as String?)?.trim();
    final age = metadata['age'];
    final gender = (metadata['gender'] as String?)?.trim();
    final activityType = (metadata['activityType'] as String?)?.trim();
    final locationPreference =
        (metadata['locationPreference'] as String?)?.trim();
    final interests =
        (metadata['interests'] as List?)?.cast<String>() ?? const [];
    final email = _controller.email;
    final avatarImage = AvatarUploader.imageFor(metadata);

    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            const AppHeader(),
            const SizedBox(height: 20),
            const SectionLabel('Profile'),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _openEditProfile,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: avatarImage == null
                                    ? const LinearGradient(
                                        colors: [
                                          SynkColors.orange,
                                          SynkColors.orangeDark,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                image: avatarImage != null
                                    ? DecorationImage(
                                        image: avatarImage,
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: avatarImage == null
                                  ? Text(
                                      (fullName?.isNotEmpty ?? false)
                                          ? fullName![0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: SynkColors.orangeDark,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (fullName?.isNotEmpty ?? false)
                                    ? fullName!
                                    : 'Synk member',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: SynkColors.textPrimary,
                                ),
                              ),
                              if (email != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: SynkColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (age != null ||
                                  (gender?.isNotEmpty ?? false)) ...[
                                const SizedBox(height: 6),
                                Text(
                                  [
                                    if (age != null) '$age yrs',
                                    if (gender?.isNotEmpty ?? false) gender!,
                                  ].join(' · '),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: SynkColors.orangeDark,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: SynkColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    Text(
                      (bio?.isNotEmpty ?? false)
                          ? bio!
                          : 'Add a short bio so people get to know you.',
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
                  ],
                ),
              ),
            ),
            if (interests.isNotEmpty) ...[
              const SizedBox(height: 24),
              const SectionLabel('Interests'),
              const SizedBox(height: 10),
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
                          color: SynkColors.teal.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          interest,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: SynkColors.teal,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if ((activityType?.isNotEmpty ?? false) ||
                (locationPreference?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 24),
              const SectionLabel('Preferences'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (activityType?.isNotEmpty ?? false)
                      _InfoRow(
                        icon: Icons.local_activity_rounded,
                        label: 'Preferred activity type',
                        value: activityType!,
                      ),
                    if ((activityType?.isNotEmpty ?? false) &&
                        (locationPreference?.isNotEmpty ?? false))
                      const Divider(height: 20),
                    if (locationPreference?.isNotEmpty ?? false)
                      _InfoRow(
                        icon: Icons.place_rounded,
                        label: 'Preferred location',
                        value: locationPreference!,
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final isLoggingOut = _controller.isLoggingOut;
                return SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: isLoggingOut ? null : _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SynkColors.orangeDark,
                      side: const BorderSide(color: SynkColors.orangeDark),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: isLoggingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.logout_rounded),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: SynkColors.orangeDark),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SynkColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
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
    );
  }
}
