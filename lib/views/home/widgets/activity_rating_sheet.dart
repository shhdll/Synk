import 'package:flutter/material.dart';

import '../../../controllers/activity_rating_controller.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activity_rating_model.dart';
import '../../../models/avatar_uploader.dart';
import '../../../utils/custom_widgets/synk_feedback.dart';
import 'activity_thumbnail.dart';
import 'half_star_rating_input.dart';

// Offers to rate the attendees of one ended activity. Skip stops offering
// it; closing with Back leaves it for a later app opening.
Future<void> showActivityRatingSheet({
  required BuildContext context,
  required PendingActivityRating pending,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => ActivityRatingSheet(pending: pending),
  );

  if (saved == true && context.mounted) {
    await SynkFeedback.showSuccessDialog(
      context,
      title: context.l10n.ratingsSavedTitle,
      message: context.l10n.ratingsSavedMessage,
    );
  }
}

class ActivityRatingSheet extends StatefulWidget {
  const ActivityRatingSheet({super.key, required this.pending});

  final PendingActivityRating pending;

  @override
  State<ActivityRatingSheet> createState() => _ActivityRatingSheetState();
}

class _ActivityRatingSheetState extends State<ActivityRatingSheet> {
  late final ActivityRatingController _controller = ActivityRatingController(
    pending: widget.pending,
  );

  bool _isClosing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Pops at most once, so repeated taps cannot close the page underneath.
  void _close(bool saved) {
    if (_isClosing || !mounted) return;
    _isClosing = true;
    Navigator.of(context).pop(saved);
  }

  Future<void> _submit() async {
    final saved = await _controller.submit();
    if (saved) _close(true);
  }

  Future<void> _skip() async {
    await _controller.skip();
    _close(false);
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.pending.activity;
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.45;

    return SafeArea(
      bottom: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: SynkColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final error = _controller.errorMessage;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ActivityThumbnail(activity: activity, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.rateActivityTitle(activity.title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: SynkColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.rateActivitySubtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: SynkColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxListHeight),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.pending.participants.length,
                    itemBuilder: (context, index) {
                      return _buildParticipantRow(
                        widget.pending.participants[index],
                      );
                    },
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    error,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFFE85D5D),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _buildButtons(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildParticipantRow(RatingParticipant participant) {
    final halfStars = _controller.halfStarsFor(participant.userId);
    final name = participant.name?.trim();
    final username = participant.username?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildAvatar(participant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name == null || name.isEmpty
                            ? context.l10n.communityMember
                            : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SynkColors.textPrimary,
                        ),
                      ),
                    ),
                    if (participant.isHost) ...[
                      const SizedBox(width: 6),
                      _buildHostChip(),
                    ],
                  ],
                ),
                if (username != null && username.isNotEmpty)
                  Text(
                    '@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: SynkColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    HalfStarRatingInput(
                      halfStars: halfStars,
                      enabled: !_controller.isBusy,
                      starSize: 28,
                      onChanged: (value) => _controller.setHalfStars(
                        participant.userId,
                        value,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        halfStars == 0
                            ? context.l10n.tapToRate
                            : formatHalfStars(halfStars),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: halfStars == 0 ? 12 : 14,
                          fontWeight: halfStars == 0
                              ? FontWeight.w500
                              : FontWeight.w800,
                          color: halfStars == 0
                              ? SynkColors.textSecondary
                              : SynkColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: SynkColors.orangeDark.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.l10n.host,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: SynkColors.orangeDark,
        ),
      ),
    );
  }

  // Uploaded photo, or the app's default avatar for the participant.
  Widget _buildAvatar(RatingParticipant participant) {
    const size = 42.0;
    final fallback = AvatarUploader.defaultImageForGender(participant.gender);
    final url = participant.avatarUrl?.trim();
    final photo = url != null && url.startsWith('http')
        ? NetworkImage(url)
        : fallback;

    return ClipOval(
      child: Image(
        image: photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image(
          image: fallback,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildButtons() {
    final isBusy = _controller.isBusy;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: isBusy ? null : _skip,
              style: OutlinedButton.styleFrom(
                foregroundColor: SynkColors.textSecondary,
                side: BorderSide(
                  color: SynkColors.textSecondary.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                context.l10n.skip,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _controller.canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: SynkColors.orangeDark,
                disabledBackgroundColor: SynkColors.orangeDark.withValues(
                  alpha: 0.5,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      context.l10n.submitRatings,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
