import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activity_model.dart';
import '../../../models/avatar_uploader.dart';
import '../../../models/top_picks.dart';
import 'activity_status_chip.dart';
import 'activity_thumbnail.dart';
import 'discovery_activity_card.dart';
import 'friends_going.dart';

// One card in the Top picks carousel, laid out like DiscoveryActivityCard:
// thumbnail with the rank, title, when and where, host and spots, plus why
// it was picked. Tapping opens the details sheet.
class TopPickCard extends StatelessWidget {
  const TopPickCard({super.key, required this.pick, required this.onTap});

  static const double width = 300;
  static const BorderRadius radius = BorderRadius.all(Radius.circular(20));

  // Card height for the user's text size: fixed spacing plus text that
  // scales. Matches the layout below.
  static double heightFor(TextScaler scaler) => 56 + scaler.scale(128);

  final TopPick pick;
  final VoidCallback onTap;

  static String reasonText(TopPickReason reason) => switch (reason) {
    FriendsGoing(:final friends) => friendsGoingText(friends),
    SharedInterest(:final interest) => appL10n.topPickYouLike(
      valueLabel(interest),
    ),
    PreferredSetting(setting: ActivitySetting.indoor) =>
      appL10n.topPickLikesIndoor,
    PreferredSetting(setting: ActivitySetting.outdoor) =>
      appL10n.topPickLikesOutdoor,
    PopularNearYou() => appL10n.topPickPopularNearYou,
  };

  @override
  Widget build(BuildContext context) {
    final activity = pick.activity;
    final l10n = context.l10n;
    final title = activity.title.trim().isEmpty
        ? l10n.untitledActivity
        : activity.title.trim();
    final when = DiscoveryActivityCard.formatWhen(activity.dateTime);
    final km = pick.distanceKm?.toStringAsFixed(1);
    final reason = reasonText(pick.reason);

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: l10n.topPickSemanticLabel(
        pick.rank,
        [
          title,
          when,
          if (km != null) l10n.topPickDistanceAway(km),
          reason,
        ].join(', '),
      ),
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: SynkColors.orangeDark.withValues(alpha: 0.07),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ActivityThumbnail(
                              activity: activity,
                              size: 80,
                              radius: 14,
                            ),
                            PositionedDirectional(
                              top: 6,
                              start: 6,
                              child: _RankBadge(rank: pick.rank),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _Details(
                            title: title,
                            when: when,
                            place: activity.location.trim(),
                            km: km,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _HostRow(activity: activity),
                    const SizedBox(height: 10),
                    _ReasonPill(reason: pick.reason, text: reason),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.title,
    required this.when,
    required this.place,
    required this.km,
  });

  final String title;
  final String when;
  final String place;
  final String? km;

  @override
  Widget build(BuildContext context) {
    final where = [
      if (place.isNotEmpty) place,
      if (km != null) context.l10n.topPickDistanceKm(km!),
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: -0.2,
            color: SynkColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        _MetaLine(
          icon: Icons.schedule_rounded,
          text: when,
          color: SynkColors.orangeDark,
        ),
        if (where.isNotEmpty) ...[
          const SizedBox(height: 4),
          _MetaLine(
            icon: Icons.place_outlined,
            text: where,
            color: SynkColors.textSecondary,
          ),
        ],
      ],
    );
  }
}

// Host and spots, as in DiscoveryActivityCard's footer.
class _HostRow extends StatelessWidget {
  const _HostRow({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final handle = activity.hostUsername?.trim();
    final hostLabel = handle != null && handle.isNotEmpty
        ? '@$handle'
        : (activity.hostName?.trim().isNotEmpty ?? false)
        ? activity.hostName!.trim()
        : context.l10n.synkMember;
    final avatarUrl = activity.hostAvatarUrl?.trim();

    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: SynkColors.backgroundLight,
          backgroundImage: avatarUrl != null && avatarUrl.startsWith('http')
              ? NetworkImage(avatarUrl)
              : AvatarUploader.defaultImageForGender(activity.hostGender),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            hostLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: SynkColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ActivityStatusChip.count(
          availability: activity.availability,
          label:
              '${activity.joinedCount}/${activity.maxParticipants} '
              '${activity.availability.label}',
        ),
      ],
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SynkColors.orangeDark,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        '$rank',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// Why it was picked; friends going also show their photos, as on the feed.
class _ReasonPill extends StatelessWidget {
  const _ReasonPill({required this.reason, required this.text});

  final TopPickReason reason;
  final String text;

  @override
  Widget build(BuildContext context) {
    final reason = this.reason;

    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        reason is FriendsGoing ? 4 : 10,
        4,
        10,
        4,
      ),
      decoration: BoxDecoration(
        color: SynkColors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reason is FriendsGoing) ...[
            FriendAvatarStack(friends: reason.friends, size: 20),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SynkColors.tealText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Same size as [TopPickCard], shown while the picks load.
class TopPickCardSkeleton extends StatefulWidget {
  const TopPickCardSkeleton({super.key});

  @override
  State<TopPickCardSkeleton> createState() => _TopPickCardSkeletonState();
}

class _TopPickCardSkeletonState extends State<TopPickCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        // Same colors as ActivityCardSkeleton.
        final color = Color.lerp(
          const Color(0xFFEFE8DB),
          Colors.white.withValues(alpha: 0.65),
          _shimmer.value,
        )!;

        Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        );

        return Container(
          width: TopPickCard.width,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: TopPickCard.radius,
            border: Border.all(
              color: SynkColors.textSecondary.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        bar(double.infinity, 14),
                        const SizedBox(height: 12),
                        bar(120, 11),
                        const SizedBox(height: 8),
                        bar(150, 11),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  CircleAvatar(radius: 10, backgroundColor: color),
                  const SizedBox(width: 6),
                  bar(80, 11),
                  const Spacer(),
                  bar(36, 11),
                ],
              ),
              const SizedBox(height: 10),
              bar(110, 22),
            ],
          ),
        );
      },
    );
  }
}
