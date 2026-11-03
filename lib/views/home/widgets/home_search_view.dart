import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activity_model.dart';
import 'activity_thumbnail.dart';
import 'for_you_deck.dart';
import 'recent_searches_list.dart';

// Shown in place of For you and Explore while the search field is in use:
// recent searches, or the results.
class HomeSearchView extends StatelessWidget {
  const HomeSearchView({
    super.key,
    required this.query,
    required this.results,
    required this.bestMatchId,
    required this.distanceOf,
    required this.recent,
    required this.onRecentTap,
    required this.onRecentRemove,
    required this.onOpen,
    this.onCreate,
  });

  final String query;
  final List<Activity> results;

  // The top result when it matches the user, labeled "Best match for you".
  final String? bestMatchId;
  final double? Function(Activity) distanceOf;
  final List<String> recent;
  final ValueChanged<String> onRecentTap;
  final ValueChanged<String> onRecentRemove;
  final ValueChanged<Activity> onOpen;
  final ValueChanged<String>? onCreate;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (query.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: RecentSearchesList(
              recent: recent,
              onTap: onRecentTap,
              onRemove: onRecentRemove,
            ),
          )
        else if (results.isEmpty)
          _buildNothing(context)
        else ...[
          const SizedBox(height: 20),
          Text(
            l.activitiesForQuery(results.length, query),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SynkColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          for (final activity in results)
            _ResultRow(
              activity: activity,
              distanceKm: distanceOf(activity),
              bestMatch: activity.id == bestMatchId,
              onTap: () => onOpen(activity),
            ),
        ],
      ],
    );
  }

  Widget _buildNothing(BuildContext context) {
    final l = context.l10n;
    final text = l.nothingForQueryYet(query);
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: SynkColors.ink,
            ),
          ),
          if (onCreate != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => onCreate!(query),
              style: FilledButton.styleFrom(
                backgroundColor: SynkColors.orangeDeep,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: const StadiumBorder(),
              ),
              child: Text(
                l.createQuery(query),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.activity,
    required this.distanceKm,
    required this.bestMatch,
    required this.onTap,
  });

  final Activity activity;
  final double? distanceKm;
  final bool bestMatch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = activity.title.trim().isEmpty
        ? l.untitledActivity
        : activity.title.trim();
    final left = activity.spotsOpen;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ActivityThumbnail(activity: activity, size: 56, radius: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bestMatch)
                    Text(
                      l.bestMatchForYou,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: SynkColors.tealText,
                      ),
                    ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: SynkColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    deckMeta(activity, distanceKm),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: SynkColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              left == 0 ? l.full : l.spotsLeftShort(left),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SynkColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
