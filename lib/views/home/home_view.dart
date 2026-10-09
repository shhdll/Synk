import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';
import '../../models/activities_model.dart';
import '../../models/activity_model.dart';
import '../../models/user_profile_model.dart';
import 'activity_code_join_sheet.dart';
import 'widgets/activity_card.dart';
import 'widgets/app_header.dart';
import 'widgets/empty_state.dart';
import 'widgets/section_label.dart';
import '../../utils/custom_widgets/synk_feedback.dart';

class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
    required this.activityStore,
    this.isNewUser = false,
  });

  final ActivityStore activityStore;
  final bool isNewUser;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final UserProfileModel _profileModel = UserProfileModel();
  final ActivitiesModel _activitiesModel = ActivitiesModel();

  String _firstName = 'there';

  @override
  void initState() {
    super.initState();
    _loadFirstName();
  }

  Future<void> _loadFirstName() async {
    final profile = await _profileModel.fetchProfile();
    final fullName = (profile['full_name'] as String?)?.trim();

    if (mounted && (fullName?.isNotEmpty ?? false)) {
      setState(() {
        _firstName = fullName!.split(' ').first;
      });
    }
  }

  Future<void> _openActivityCodeSheet() async {
  final result =
      await showActivityCodeJoinSheet(context);

  // The user closed the sheet without completing a join.
  if (!mounted || result == null) return;

  try {
    // Refresh joined, pending, and waitlisted activities
    // before displaying the confirmation.
    final participating =
        await _activitiesModel.fetchParticipating();

    if (!mounted) return;

    widget.activityStore.setParticipating(
      participating,
    );
  } catch (_) {
    // The join succeeded in Supabase, so the confirmation
    // still appears if refreshing temporarily fails.
  }

  if (!mounted) return;

  final title = switch (result.result) {
    'joined' => 'Joined!',
    'already_joined' => 'Already Joined',
    'pending' => 'Request Sent!',
    'already_pending' => 'Request Already Sent',
    'waitlisted' => 'Added to Waitlist!',
    'already_waitlisted' => 'Already Waitlisted',
    _ => 'Done!',
  };

  await SynkFeedback.showSuccessDialog(
    context,
    title: title,
    message: result.message,
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.activityStore,
          builder: (context, _) {
            final upcoming = widget.activityStore.homeUpcoming;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppHeader(),
                        const SizedBox(height: 20),
                        _buildSearchBar(),
                        const SizedBox(height: 14),

                        // Opens the activity code entry sheet.
                        _buildQuickJoinCard(),

                        const SizedBox(height: 24),
                        Text(
                          widget.isNewUser
                              ? 'Welcome, $_firstName 👋'
                              : 'Hey, $_firstName 👋',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            color: SynkColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.isNewUser
                              ? "You're all set. Discover what's happening around you."
                              : "Discover what's happening around you.",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: SynkColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (upcoming.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.event_available_rounded,
                      title: 'No activities yet',
                      message: 'Tap the + button to plan your first one.',
                    ),
                  )
                else ...[
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(24, 8, 24, 4),
                    sliver: SliverToBoxAdapter(child: SectionLabel('Upcoming')),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    sliver: SliverList.separated(
                      itemCount: upcoming.length,
                      separatorBuilder: (_, _) {
                        return const SizedBox(height: 14);
                      },
                      itemBuilder: (context, index) {
                        final activity = upcoming[index];

                        return ActivityCard(
                          activity: activity,

                          // Only the host can view the activity code.
                          showActivityCode: activity.isHostedBy(
                            widget.activityStore.currentUserId,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 22,
            color: SynkColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Text(
            'Search activities...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: SynkColors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickJoinCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openActivityCodeSheet,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: SynkColors.textSecondary.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: SynkColors.orangeDark.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.key_rounded,
                  color: SynkColors.orangeDark,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Have an activity code?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Enter a 6-digit code to join.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: SynkColors.orangeDark.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 19,
                  color: SynkColors.orangeDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
