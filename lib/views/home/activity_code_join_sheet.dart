import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/activity_join_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/activities_model.dart';
import '../../models/activity_model.dart';
import '../../models/activity_participation_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'widgets/overlapping_activity_notice.dart';

// Shared by Home and Activities.
Future<void> joinActivityWithCode(
  BuildContext context, {
  required ActivityStore activityStore,
  ActivitiesModel? activitiesModel,
  VoidCallback? onJoined,
}) async {
  final result = await showActivityCodeJoinSheet(context);

  // The user closed the sheet without completing a join.
  if (!context.mounted || result == null) return;

  if (result.result == 'time_conflict') {
    await SynkFeedback.showErrorDialog(
      context,
      title: context.l10n.unableToJoin,
      message: context.l10n.thisActivityConflictsWithOneYouve,
    );
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
Future<ActivityJoinResult?> showActivityCodeJoinSheet(BuildContext context) {
  return showModalBottomSheet<ActivityJoinResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return const ActivityCodeJoinSheet();
    },
  );
}

class ActivityCodeJoinSheet extends StatefulWidget {
  const ActivityCodeJoinSheet({super.key});

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
                  IconButton(
                    onPressed: _controller.isLoading
                        ? null
                        : () {
                            Navigator.pop(context);
                          },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller.codeController,
                autofocus: true,
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
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    _resolvedActivity!.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ),
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
