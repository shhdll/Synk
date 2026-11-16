import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/activity_categories.dart';
import '../../core/constants/badges.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/badges_model.dart';
import 'widgets/badge_widgets.dart';
import '../widgets/synk_blob_background.dart';

// Every badge, one row per group with the levels in order. Someone else's
// list shows only what they earned, one after another.
class BadgesView extends StatefulWidget {
  const BadgesView({
    super.key,
    this.userId,
    this.earned,
    this.name,
    this.gender,
    this.model,
  });

  // Null for the signed-in user.
  final String? userId;

  // Someone else's badges, when the profile already loaded them.
  final List<EarnedBadge>? earned;

  // Someone else's name and gender, for "Shahad attended ...".
  final String? name;
  final String? gender;

  // Injectable for tests.
  final BadgesModel? model;

  @override
  State<BadgesView> createState() => _BadgesViewState();
}

class _BadgesViewState extends State<BadgesView> {
  MyBadges? _badges;
  bool _failed = false;

  // The viewer's own badges, to hide secret ones they haven't earned.
  Set<String> _mine = const {};

  BadgesModel get _model => widget.model ?? BadgesModel();

  bool get _isMine => widget.userId == null;

  @override
  void initState() {
    super.initState();
    if (widget.earned case final earned?) {
      _badges = MyBadges(earned: earned, stats: const {});
    } else {
      _load();
    }
    if (!_isMine) _loadMine();
  }

  Future<void> _loadMine() async {
    try {
      final mine = await _model.fetchMine();
      if (mounted) {
        setState(() => _mine = {for (final b in mine.earned) b.id});
      }
    } catch (_) {
      // Secret badges stay hidden.
    }
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final badges = _isMine
          ? await _model.fetchMine()
          : MyBadges(
              earned: await _model.fetchFor(widget.userId!),
              stats: const {},
            );
      if (mounted) setState(() => _badges = badges);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  // One row per group, easiest first. Someone else's rows hold only what
  // they earned.
  List<List<Widget>> _rows(MyBadges badges) {
    final earnedAt = {for (final b in badges.earned) b.id: b.earnedAt};
    final rows = <List<Widget>>[];
    for (final group in BadgeGroup.values) {
      final row = <Widget>[];
      if (group == BadgeGroup.category) {
        final fans =
            badges.earned
                .where((b) => b.id.startsWith(kCategoryFanPrefix))
                .toList()
              ..sort((a, b) => a.earnedAt.compareTo(b.earnedAt));
        for (final fan in fans) {
          row.add(
            badgeTile(
              badge: badgeInfo(fan.id)!,
              id: fan.id,
              earnedAt: fan.earnedAt,
              isMine: _isMine,
              ownerName: widget.name,
              ownerGender: widget.gender,
            ),
          );
        }
        if (_isMine) {
          // Fills the row with the categories closest to a badge.
          final counts = <String, int>{
            for (final MapEntry(:key, :value)
                in (badges.stats['category_counts'] as Map? ?? const {})
                    .entries)
              if (value is num) key as String: value.toInt(),
          };
          final candidates = [
            ...counts.keys.where(kActivityCategories.containsKey).toList()
              ..sort((a, b) => counts[b]!.compareTo(counts[a]!)),
            ...kActivityCategories.keys.where((c) => !counts.containsKey(c)),
          ];
          for (final category in candidates) {
            if (row.length >= 4 && row.length % 4 == 0) break;
            final id = '$kCategoryFanPrefix$category';
            if (badges.has(id)) continue;
            row.add(
              badgeTile(
                badge: badgeInfo(id)!,
                id: id,
                current: counts[category] ?? 0,
              ),
            );
          }
        }
      } else {
        // Only the next level shows; the ones after it stay locked.
        var nextShown = false;
        for (final badge in kBadges.where((b) => b.group == group)) {
          final at = earnedAt[badge.id];
          if (at == null && !_isMine) continue;
          final sealed = at == null && nextShown && !badge.isSecret;
          if (at == null) nextShown = true;
          row.add(
            badgeTile(
              badge: badge,
              id: badge.id,
              earnedAt: at,
              current: at == null ? badges.progressOf(badge) : null,
              sealed: sealed,
              isMine: _isMine,
              ownerName: widget.name,
              ownerGender: widget.gender,
              concealed: !_isMine && !_mine.contains(badge.id),
            ),
          );
        }
      }
      if (row.isNotEmpty) rows.add(row);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final badges = _badges;
    final earnedCount =
        badges?.earned
            .where((b) => !b.id.startsWith(kCategoryFanPrefix))
            .length ??
        0;
    return SynkBlobPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: Text(
            l.badgesTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: SynkColors.textPrimary,
            ),
          ),
        ),
        body: badges == null
            ? Center(
                child: _failed
                    ? TextButton(onPressed: _load, child: Text(l.tryAgain))
                    : const CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    if (_isMine) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          l.badgesEarnedCount(earnedCount, kBadges.length),
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: SynkColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: earnedCount / kBadges.length,
                            minHeight: 8,
                            color: SynkColors.orangeDark,
                            backgroundColor: SynkColors.backgroundDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_isMine)
                      for (final row in _rows(badges))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: BadgeGrid(columns: 4, children: row),
                        )
                    else
                      // Someone else's: what they earned, one after another.
                      BadgeGrid(
                        columns: 4,
                        children: [for (final row in _rows(badges)) ...row],
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
