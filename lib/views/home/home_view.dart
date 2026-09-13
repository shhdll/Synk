import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/synk_colors.dart';
import '../../models/activity_model.dart';
import 'widgets/activity_card.dart';
import 'widgets/app_header.dart';
import 'widgets/empty_state.dart';
import 'widgets/section_label.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.activityStore});

  final ActivityStore activityStore;

  String get _firstName {
    final fullName =
        Supabase.instance.client.auth.currentUser?.userMetadata?['full_name']
            as String?;
    if (fullName == null || fullName.trim().isEmpty) return 'there';
    return fullName.trim().split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: activityStore,
          builder: (context, _) {
            final upcoming = activityStore.upcoming;
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
                          'Hey, $_firstName 👋',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            color: SynkColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Here's what's coming up for you.",
                          style: TextStyle(
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
                    sliver: SliverToBoxAdapter(
                      child: SectionLabel('Upcoming'),
                    ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
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
