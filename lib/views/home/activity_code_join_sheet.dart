import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/activity_join_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/activities_model.dart';
import '../../models/activity_model.dart';
import '../../models/activity_participation_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import '../widgets/schedule_conflict_text.dart';
import 'widgets/activity_details_sheet.dart';
import 'widgets/activity_thumbnail.dart';
import 'widgets/discovery_activity_card.dart';
import 'widgets/overlapping_activity_notice.dart';

// Shared by Home and Activities.
Future<void> joinActivityWithCode(
  BuildContext context, {
  required ActivityStore activityStore,
  ActivitiesModel? activitiesModel,
  VoidCallback? onJoined,
  String? initialCode,
}) async {
  final result = await showActivityCodeJoinSheet(
    context,
    initialCode: initialCode,
  );

  // The user closed the sheet without completing a join.
  if (!context.mounted || result == null) return;

  if (result.result == 'time_conflict') {
    // Find which of the user's activities is in the way, to link to it.
    Activity? conflict;
    final targetId = result.activityId;
    if (targetId != null) {
      try {
        final target = await (activitiesModel ?? ActivitiesModel()).fetchById(
          targetId,
        );
        if (target != null) {
          conflict = activityStore.conflictingActivity(
            target.dateTime,
            target.endsAt,
            excludeId: target.id,
          );
        }
      } catch (_) {
        // Falls back to the message without a link.
      }
    }
    if (!context.mounted) return;

    var openConflict = false;
    final found = conflict;
    await SynkFeedback.showErrorDialog(
      context,
      title: context.l10n.unableToJoin,
      message: context.l10n.conflictJoinUnknown,
      messageBuilder: found == null
          ? null
          : (dialogContext) => ScheduleConflictText(
              title: found.title,
              message: found.isHostedBy(activityStore.currentUserId)
                  ? context.l10n.conflictJoinHosting
                  : context.l10n.conflictJoinJoined,
              onTitleTap: () {
                openConflict = true;
                Navigator.of(dialogContext).pop();
              },
            ),
    );
    // Opens the other activity where the user already is.
    if (openConflict && found != null && context.mounted) {
      await showActivityDetailsSheet(
        context: context,
        activity: activityStore.byId(found.id) ?? found,
        activityStore: activityStore,
      );
    }
    return;
  }

  try {
    // Refresh joined, pending, and waitlisted activities
    final participating = await (activitiesModel ?? ActivitiesModel())
        .fetchParticipating();

    if (!context.mounted) return;
    activityStore.setParticipating(participating);
    onJoined?.call();
  } catch (_) {
    // The join succeeded in Supabase, so the confirmation
    // still appears if refreshing temporarily fails.
  }

  if (!context.mounted) return;

  final title = switch (result.result) {
    'joined' => context.l10n.joinedTitle,
    'already_joined' => context.l10n.alreadyJoined,
    'pending' => context.l10n.requestSent,
    'already_pending' => context.l10n.requestAlreadySent,
    'waitlisted' => context.l10n.addedToWaitlist,
    'already_waitlisted' => context.l10n.alreadyWaitlisted,
    _ => context.l10n.doneTitle,
  };

  await SynkFeedback.showSuccessDialog(
    context,
    title: title,
    message: result.message,
  );
}

// Opens the code sheet and returns the successful join result.
// A null result means the user closed the sheet without joining.
Future<ActivityJoinResult?> showActivityCodeJoinSheet(
  BuildContext context, {
  String? initialCode,
}) {
  return showModalBottomSheet<ActivityJoinResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return ActivityCodeJoinSheet(initialCode: initialCode);
    },
  );
}

class ActivityCodeJoinSheet extends StatefulWidget {
  const ActivityCodeJoinSheet({super.key, this.initialCode});

  // Filled in from a shared link.
  final String? initialCode;

  @override
  State<ActivityCodeJoinSheet> createState() {
    return _ActivityCodeJoinSheetState();
  }
}

class _ActivityCodeJoinSheetState extends State<ActivityCodeJoinSheet> {
  late final ActivityJoinController _controller;
  final ActivitiesModel _activitiesModel = ActivitiesModel();
  Activity? _resolvedActivity;
  bool _hasPendingScheduleOverlap = false;
  bool _isResolvingCode = false;
  int _resolveRequestId = 0;

  @override
  void initState() {
    super.initState();

    _controller = ActivityJoinController();
    _controller.addListener(_refresh);

    final code = widget.initialCode;
    if (code != null && RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      _controller.codeController.text = code;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _codeChanged(code);
      });
    }
  }

  Future<void> _codeChanged(String code) async {
    final requestId = ++_resolveRequestId;
    _controller.clearFeedback();
    setState(() {
      _resolvedActivity = null;
      _hasPendingScheduleOverlap = false;
      _isResolvingCode = RegExp(r'^[0-9]{6}$').hasMatch(code);
    });
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) return;
    try {
      final activity = await _activitiesModel.resolveActivityCode(code);
      if (!mounted ||
          requestId != _resolveRequestId ||
          _controller.codeController.text.trim() != code) {
        return;
      }
      if (activity == null) {
        setState(() => _isResolvingCode = false);
        return;
      }
      final participating = await _activitiesModel.fetchParticipating();
      if (!mounted ||
          requestId != _resolveRequestId ||
          _controller.codeController.text.trim() != code) {
        return;
      }
      setState(() {
        _resolvedActivity = activity;
        _isResolvingCode = false;
        _hasPendingScheduleOverlap =
            ActivitiesModel.hasPendingOverlap(activity, participating);
      });
    } catch (_) {
      // The existing join action remains available if the preview lookup fails.
      if (mounted && requestId == _resolveRequestId) {
        setState(() => _isResolvingCode = false);
      }
    }
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  // Submits the code and closes the sheet only when the result
  // represents a successful or existing participation state.
  Future<void> _submitCode() async {
    if (_controller.isLoading || _isResolvingCode) return;

    await _controller.joinByCode();

    if (!mounted) return;

    final result = _controller.result;

    // Invalid codes and other errors remain visible inside the sheet.
    if (result == null) return;

    FocusScope.of(context).unfocus();

    // Return the result to Home after closing the sheet.
    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        decoration: const BoxDecoration(
          color: SynkColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: SynkColors.textSecondary.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: SynkColors.orangeDark.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.key_rounded,
                      color: SynkColors.orangeDark,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.joinWithACode,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: SynkColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          context.l10n.enterThe6DigitActivityCode,
                          style: TextStyle(
                            fontSize: 14,
                            color: SynkColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller.codeController,
                autofocus: widget.initialCode == null,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: _codeChanged,
                onSubmitted: (_) {
                  _submitCode();
                },
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                  color: SynkColors.textPrimary,
                ),
                cursorColor: SynkColors.orangeDark,
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: TextStyle(
                    color: SynkColors.textSecondary.withValues(alpha: 0.45),
                  ),
                  counterText: '',
                  errorText: _controller.errorMessage,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.78),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: SynkColors.textSecondary.withValues(alpha: 0.14),
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                    borderSide: BorderSide(
                      color: SynkColors.orangeDark,
                      width: 2,
                    ),
                  ),
                  errorBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                    borderSide: BorderSide(color: Colors.redAccent),
                  ),
                  focusedErrorBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                    borderSide: BorderSide(color: Colors.redAccent, width: 2),
                  ),
                ),
              ),
              if (_resolvedActivity != null) ...[
                const SizedBox(height: 16),
                _ActivityPreview(activity: _resolvedActivity!),
                if (_hasPendingScheduleOverlap) ...[
                  const SizedBox(height: 10),
                  const OverlappingActivityNotice(),
                ],
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _controller.isLoading || _isResolvingCode
                      ? null
                      : _submitCode,
                  style: FilledButton.styleFrom(
                    backgroundColor: SynkColors.orangeDark,
                    disabledBackgroundColor: SynkColors.orangeDark.withValues(
                      alpha: 0.45,
                    ),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _controller.isLoading
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          context.l10n.joinActivityButton,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The activity a code belongs to, before joining.
class _ActivityPreview extends StatelessWidget {
  const _ActivityPreview({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final title = activity.title.trim();
    final place = activity.location.trim();
    // A private activity shows only its photo and title before joining.
    final private = !activity.isPublic;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ActivityThumbnail(activity: activity, size: 72, radius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? context.l10n.untitledActivity : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: SynkColors.textPrimary,
                  ),
                ),
                if (!private) ...[
                  const SizedBox(height: 4),
                  Text(
                    DiscoveryActivityCard.formatWhen(activity.dateTime),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SynkColors.orangeDark,
                    ),
                  ),
                  if (place.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
