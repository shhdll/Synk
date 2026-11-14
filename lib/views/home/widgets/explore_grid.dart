import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activity_model.dart';
import '../../../models/friends_model.dart';
import 'activity_thumbnail.dart';
import 'for_you_deck.dart';
import 'friends_going.dart';

class ExploreHeader extends StatelessWidget {
  const ExploreHeader({super.key, required this.open, required this.onToggle});

  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return SectionFoldHeader(
      title: context.l10n.explore,
      open: open,
      onToggle: onToggle,
    );
  }
}

class ExploreTile extends StatelessWidget {
  const ExploreTile({
    super.key,
    required this.activity,
    required this.distanceKm,
    required this.onTap,
    this.friends = const [],
    this.joined = false,
  });

  final Activity activity;
  final double? distanceKm;
  final VoidCallback onTap;

  // You're in it: the corner says "Joined" instead of the spots left.
  final bool joined;

  // Friends hosting or going, shown as small photos in the corner.
  final List<FriendUser> friends;

  static const double height = 200;

  @override
  Widget build(BuildContext context) {
    final title = activity.title.trim().isEmpty
        ? context.l10n.untitledActivity
        : activity.title.trim();
    final left = activity.spotsOpen;
    final line = [
      weekdayShort(activity.dateTime),
      if (distanceKm != null)
        context.l10n.topPickDistanceKm(distanceKm!.toStringAsFixed(1)),
    ].join(' · ');
    final visual = ActivityVisual.of(activity);
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          visual.tint.withValues(alpha: 0.30),
          Colors.white,
        ),
      ),
      child: Align(
        alignment: const Alignment(0, -0.35),
        child: Icon(
          visual.icon,
          size: 72,
          color: visual.tint.withValues(alpha: 0.45),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: [
        title,
        line,
        if (friends.isNotEmpty) friendsGoingText(friends),
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (activity.hasPhoto)
                Image.network(
                  activity.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                )
              else
                fallback,
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Color(0xC7000000),
                    ],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),
              PositionedDirectional(
                top: 8,
                start: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: joined ? SynkColors.tealText : Colors.white,
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Text(
                    joined
                        ? '✓ ${context.l10n.joined}'
                        : left == 0
                        ? context.l10n.full
                        : context.l10n.spotsLeftShort(left),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: joined ? Colors.white : SynkColors.ink,
                    ),
                  ),
                ),
              ),
              if (friends.isNotEmpty)
                PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: FriendAvatarStack(friends: friends, size: 20),
                ),
              PositionedDirectional(
                start: 10,
                end: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExploreTileSkeleton extends StatelessWidget {
  const ExploreTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const SkeletonBlock(radius: 16);
}
