import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';
import '../../models/activity_model.dart';
import '../../models/user_profile_model.dart';
import 'widgets/activity_card.dart';
import 'widgets/app_header.dart';
import 'widgets/empty_state.dart';
import 'widgets/section_label.dart';

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
      setState(() => _firstName = fullName!.split(' ').first);
    }
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
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) =>
                          ActivityCard(activity: upcoming[index]),
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
}
