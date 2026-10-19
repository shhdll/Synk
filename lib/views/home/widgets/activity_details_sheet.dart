import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../controllers/activity_leave_controller.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../models/activities_model.dart';
import '../../../models/activity_model.dart';
import '../../../models/activity_participation_model.dart';
import '../../../models/avatar_uploader.dart';
import '../../../models/user_profile_model.dart';
import '../../../utils/custom_widgets/synk_dialog.dart';
import '../../../utils/custom_widgets/synk_feedback.dart';
import '../../../utils/maps_launcher.dart';
import '../../widgets/anonymous_avatar.dart';
import '../../widgets/crown_icon.dart';
import 'activity_thumbnail.dart';
import 'activity_status_chip.dart';
import 'host_transfer_sheet.dart';
import 'user_profile_sheet.dart';

Future<void> showActivityDetailsSheet({
  required BuildContext context,
  required Activity activity,
  required ActivityStore activityStore,
  VoidCallback? onParticipationChanged,
  VoidCallback? onDelete,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ActivityDetailsSheet(
      activity: activity,
      activityStore: activityStore,
      onParticipationChanged: onParticipationChanged,
      onDelete: onDelete,
    ),
  );
}

class ActivityDetailsSheet extends StatefulWidget {
  const ActivityDetailsSheet({
    super.key,
    required this.activity,
    required this.activityStore,
    this.onParticipationChanged,
    this.onDelete,
  });

  final Activity activity;
  final ActivityStore activityStore;

  // Called after the viewer joins, so the opening page can refresh.
  final VoidCallback? onParticipationChanged;

  final VoidCallback? onDelete;

  @override
  State<ActivityDetailsSheet> createState() => _ActivityDetailsSheetState();
}

class _ActivityDetailsSheetState extends State<ActivityDetailsSheet> {
  final ActivitiesModel _activitiesModel = ActivitiesModel();
  final ActivityParticipationModel _participationModel =
      ActivityParticipationModel();
  final ActivityLeaveController _leaveController = ActivityLeaveController();

  // Green used for the "Joined" state across the app.
  static const Color _joinedColor = Color(0xFF3D8B5A);

  late Activity _currentActivity;

  // The viewer's status for this activity: joined, pending, waitlisted,
  // or null when they have not joined.
  String? _participationStatus;
  bool _isJoining = false;
  String? _joinError;
  bool _isLeaving = false;
  String? _leaveError;

  // Blocks a second leave, transfer, or delete before its dialog opens.
  bool _actionInProgress = false;

  bool _isLoadingParticipants = true;
  List<Map<String, dynamic>> _participants = [];

  // Only the newest participants request may update the sheet.
  int _participantsRequestId = 0;

  // The viewer's own profile, for their locally saved photo.
  Map<String, dynamic>? _ownProfile;

  @override
  void initState() {
    super.initState();
    _currentActivity = widget.activity;
    _participationStatus = _storedParticipationStatus();
    _loadParticipants();
    _loadOwnProfile();
    _loadHostProfile();
  }

  // Our own activities come without the host profile.
  Future<void> _loadHostProfile() async {
    final hostId = _currentActivity.hostId;
    if (_currentActivity.hostName != null || hostId == null) return;
    try {
      final host = await Supabase.instance.client
          .from('users')
          .select('full_name, username, avatar_url, gender')
          .eq('id', hostId)
          .maybeSingle();
      if (!mounted || host == null) return;
      setState(() {
        _currentActivity = _currentActivity.copyWith(
          hostName: host['full_name'] as String?,
          hostUsername: host['username'] as String?,
          hostAvatarUrl: host['avatar_url'] as String?,
          hostGender: host['gender'] as String?,
        );
      });
    } catch (_) {
    }
  }

  @override
  void dispose() {
    _leaveController.dispose();
    super.dispose();
  }

  Future<void> _loadOwnProfile() async {
    try {
      final profile = await UserProfileModel().fetchProfile();
      if (mounted) setState(() => _ownProfile = profile);
    } catch (_) {
      // Without it the viewer's row uses their uploaded photo or default.
    }
  }

  String? get _viewerId => _activitiesModel.currentUserId;

  bool get _isViewerHost =>
      _viewerId != null && _currentActivity.hostId == _viewerId;

  // Discovery feed activities carry no participation data, so look up the
  // viewer's joined, pending, or waitlisted record in the store.
  String? _storedParticipationStatus() {
    for (final activity in widget.activityStore.participating) {
      if (activity.id == _currentActivity.id) {
        return activity.participationStatus;
      }
    }
    return _currentActivity.participationStatus;
  }

  Future<void> _loadParticipants() async {
    final requestId = ++_participantsRequestId;

    try {
      final list = await _activitiesModel.fetchParticipantsList(
        _currentActivity.id,
      );
      if (mounted && requestId == _participantsRequestId) {
        setState(() {
          _participants = list
              .where((p) => p['user_id'] != _currentActivity.hostId)
              .toList();
          _isLoadingParticipants = false;

          // The viewer appears in the list once joined.
          if (_participants.any((p) => p['user_id'] == _viewerId)) {
            _participationStatus = 'joined';
          }
        });
      }
    } catch (_) {
      if (mounted && requestId == _participantsRequestId) {
        setState(() {
          _isLoadingParticipants = false;
        });
      }
    }
  }

  // The host counts as the first participant, as on the home card.
  int get _joinedCount => _participants.isNotEmpty
      ? 1 + _participants.length
      : _currentActivity.joinedCount;

  int get _spotsLeft => (_currentActivity.maxParticipants - _joinedCount).clamp(
    0,
    _currentActivity.maxParticipants,
  );

  bool get _hideMembers => _participationStatus == 'pending' && !_isViewerHost;

  int get _anonymousCount =>
      (_joinedCount - 1).clamp(0, _currentActivity.maxParticipants);

  // Public activities that have not started can be joined from here.
  // Participants of private activities can withdraw from here.
  bool get _showJoinBar =>
      !_isViewerHost &&
      !_currentActivity.isPast &&
      (_currentActivity.isPublic || _participationStatus != null);

  bool get _showHostBar => _isViewerHost && !_currentActivity.isPast;

  Future<void> _joinActivity() async {
    setState(() {
      _isJoining = true;
      _joinError = null;
    });

    try {
      final result = await _participationModel.joinPublicActivity(
        _currentActivity.id,
      );

      if (!mounted) return;

      final status = switch (result.result) {
        'joined' || 'already_joined' => 'joined',
        'waitlisted' || 'already_waitlisted' => 'waitlisted',
        'pending' || 'already_pending' => 'pending',
        _ => null,
      };

      if (status == null) {
        // Started activity, host-owned activity, or missing activity.
        setState(() => _joinError = result.message);
        return;
      }

      setState(() => _participationStatus = status);

      // Show the viewer in the participants list and update the count.
      await _loadParticipants();

      try {
        final participating = await _activitiesModel.fetchParticipating();
        widget.activityStore.setParticipating(participating);
      } catch (_) {
        // The join succeeded, so a failed refresh is not shown as an error.
      }

      widget.onParticipationChanged?.call();

      if (!mounted) return;

      final title = switch (result.result) {
        'joined' => 'Joined!',
        'already_joined' => 'Already Joined',
        'waitlisted' => 'Added to Waitlist!',
        'already_waitlisted' => 'Already Waitlisted',
        'pending' => 'Request Sent!',
        'already_pending' => 'Request Already Sent',
        _ => 'Done!',
      };

      await SynkFeedback.showSuccessDialog(
        context,
        title: title,
        message: result.message,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _joinError = 'Unable to join the activity. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  String get _formattedDateTime {
    final date = _currentActivity.dateTime;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$weekday, $month ${date.day}, ${date.year} · $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: SynkColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderVisual(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        // The join bar handles the bottom safe area itself.
                        24 +
                            (_showJoinBar || _showHostBar
                                ? 0
                                : MediaQuery.paddingOf(context).bottom),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleAndBadges(),
                          const SizedBox(height: 18),
                          _buildScheduleAndLocationSection(),
                          if (_currentActivity.description.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _buildDescriptionSection(),
                          ],
                          const SizedBox(height: 22),
                          _buildParticipantsSection(),
                          if (_isViewerHost && !_currentActivity.isPast) ...[
                            const SizedBox(height: 22),
                            _buildHostTools(),
                          ],
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showJoinBar) _buildJoinBar(),
            if (_showHostBar) _buildHostBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHostTools() {
    final code = _currentActivity.activityCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (code != null && code.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(
              color: SynkColors.orangeDark.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: SynkColors.orangeDark.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.password_rounded,
                  size: 19,
                  color: SynkColors.orangeDark,
                ),
                const SizedBox(width: 9),
                const Text(
                  'Activity code',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SynkColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: SynkColors.orangeDark,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy code',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(content: Text('Activity code copied')),
                      );
                  },
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: SynkColors.orangeDark,
                  ),
                ),
              ],
            ),
          ),
        if (widget.onDelete != null) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete!();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE85D5D),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            label: const Text(
              'Delete activity',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }

  // Join button, or the viewer's status once they have joined.
  Widget _buildJoinBar() {
    final Widget content;

    if (_participationStatus != null) {
      final (
        IconData icon,
        String label,
        Color color,
      ) = switch (_participationStatus) {
        'waitlisted' => (
          Icons.hourglass_top_rounded,
          "You're on the waitlist",
          const Color(0xFF8A6D3B),
        ),
        'pending' => (
          Icons.schedule_rounded,
          'Waiting for host approval',
          const Color(0xFFD9822B),
        ),
        _ => (
          Icons.check_circle_rounded,
          "You've joined this activity",
          _joinedColor,
        ),
      };

      final statusPill = Container(
        height: 52,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      );

      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          statusPill,
          const SizedBox(height: 10),
          _buildLeaveButton(),
          if (_leaveError != null) _buildBarError(_leaveError!),
        ],
      );
    } else {
      final isFull = _spotsLeft == 0;

      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _isJoining ? null : _joinActivity,
              style: FilledButton.styleFrom(
                backgroundColor: SynkColors.orangeDark,
                disabledBackgroundColor: SynkColors.orangeDark.withValues(
                  alpha: 0.6,
                ),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              icon: _isJoining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isFull
                          ? Icons.hourglass_top_rounded
                          : Icons.person_add_alt_1_rounded,
                      size: 20,
                    ),
              label: Text(isFull ? 'Join waitlist' : 'Join activity'),
            ),
          ),
          if (_joinError != null) ...[
            const SizedBox(height: 8),
            Text(
              _joinError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE85D5D),
              ),
            ),
          ],
        ],
      );
    }

    return _buildBarContainer(content);
  }

  Widget _buildBarContainer(Widget content) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: SynkColors.background,
        border: Border(
          top: BorderSide(
            color: SynkColors.textSecondary.withValues(alpha: 0.10),
          ),
        ),
      ),
      child: content,
    );
  }

  Widget _buildBarError(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE85D5D),
        ),
      ),
    );
  }

  // Outlined action for Leave, Leave Waitlist, Cancel Request, and the
  // host's Leave.
  Widget _buildBarAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        icon: _isLeaving
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(icon, size: 19),
        label: Text(label),
      ),
    );
  }

  Widget _buildLeaveButton() {
    final copy = _leaveCopy(_participationStatus);

    return SizedBox(
      width: double.infinity,
      child: _buildBarAction(
        icon: copy.icon,
        label: copy.action,
        color: _destructiveColor,
        onPressed: _isLeaving ? null : () => _runAction(_leaveActivity),
      ),
    );
  }

  // Host action: hand the activity to a joined participant and leave.
  // Deleting is offered in the host tools above.
  Widget _buildHostBar() {
    return _buildBarContainer(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: _buildBarAction(
              icon: Icons.logout_rounded,
              label: 'Leave Activity',
              color: SynkColors.orangeDark,
              onPressed: _isLeaving
                  ? null
                  : () => _runAction(_transferHostAndLeave),
            ),
          ),
          if (_leaveError != null) _buildBarError(_leaveError!),
        ],
      ),
    );
  }

  static const Color _destructiveColor = Color(0xFFE85D5D);

  ({
    IconData icon,
    String title,
    String message,
    String stay,
    String action,
    String successTitle,
    String successMessage,
  })
  _leaveCopy(String? status) {
    return switch (status) {
      'waitlisted' => (
        icon: Icons.logout_rounded,
        title: 'Leave waitlist?',
        message:
            'Are you sure you want to leave the waitlist for this activity?',
        stay: 'Stay on Waitlist',
        action: 'Leave Waitlist',
        successTitle: 'You Left the Waitlist',
        successMessage: 'You have been removed from the waitlist.',
      ),
      'pending' => (
        icon: Icons.close_rounded,
        title: 'Cancel request?',
        message:
            'Are you sure you want to cancel your request to join this '
            'activity?',
        stay: 'Keep Request',
        action: 'Cancel Request',
        successTitle: 'Request Cancelled',
        successMessage: 'Your join request has been cancelled.',
      ),
      _ => (
        icon: Icons.logout_rounded,
        title: 'Leave activity?',
        message: 'Are you sure you want to leave this activity?',
        stay: 'Stay',
        action: 'Leave Activity',
        successTitle: 'You Left the Activity',
        successMessage: 'You have successfully left this activity.',
      ),
    };
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_actionInProgress) return;

    _actionInProgress = true;
    try {
      await action();
    } finally {
      _actionInProgress = false;
    }
  }

  // Leaves, leaves the waitlist, or cancels the request after confirmation.
  Future<void> _leaveActivity() async {
    final status = _participationStatus;
    if (status == null || _isLeaving) return;

    // Captured so a confirmed result is applied even if the sheet closes.
    final store = widget.activityStore;
    final activityId = _currentActivity.id;
    final isPublic = _currentActivity.isPublic;
    final copy = _leaveCopy(status);

    final action = await SynkDialog.destructive(
      icon: copy.icon,
      title: copy.title,
      message: copy.message,
      primaryLabel: copy.stay,
      secondaryLabel: copy.action,
    ).show(context, barrierDismissible: false);

    // The withdrawal is the secondary button.
    if (action != SynkDialogAction.secondary || !mounted) return;

    setState(() {
      _isLeaving = true;
      _leaveError = null;
    });

    final result = await _leaveController.leaveActivity(activityId);

    if (result != null) {
      store.removeParticipation(activityId);
      _refreshParticipating(store);
    }

    if (result == null) {
      final message = _leaveController.errorMessage;
      final failure = _leaveController.failureResult;

      if (failure == 'not_participating') {
        await _refreshParticipating(store);
      } else if (failure == 'host') {
        // The viewer was made host on another device.
        await _refreshHostedAndParticipating(store);
      }

      if (!mounted) return;

      setState(() {
        _isLeaving = false;
        _leaveError = message;

        if (failure == 'not_participating') {
          _participationStatus = _savedParticipationStatus();
        } else if (failure == 'host') {
          _currentActivity = _hostedActivity() ?? _currentActivity;
          _participationStatus = null;
          _leaveError = 'You are now the host of this activity.';
        }
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLeaving = false;
      _participationStatus = null;

      // The viewer's joined place is no longer counted.
      if (status == 'joined') {
        final countAfterLeave = _joinedCount - 1;
        _participants = _participants
            .where((p) => p['user_id'] != _viewerId)
            .toList();
        _currentActivity = _currentActivity.copyWith(
          participantsCount: countAfterLeave < 1 ? 1 : countAfterLeave,
        );
      }
    });

    if (isPublic) {
      _loadParticipants();
    }

    await SynkFeedback.showSuccessDialog(
      context,
      title: copy.successTitle,
      message: copy.successMessage,
    );

    // A private activity is no longer visible after leaving it.
    if (mounted && !isPublic) {
      Navigator.of(context).pop();
    }
  }

  // Lets the host choose a joined participant, confirm, and leave.
  Future<void> _transferHostAndLeave() async {
    final hostId = _currentActivity.hostId;
    if (hostId == null || _isLeaving) return;

    final store = widget.activityStore;
    final activityId = _currentActivity.id;

    setState(() => _leaveError = null);

    final candidate = await showHostTransferSheet(
      context: context,
      activityId: activityId,
      hostId: hostId,
    );

    if (candidate == null || !mounted) return;

    final action = await SynkDialog.destructive(
      icon: Icons.swap_horiz_rounded,
      title: 'Transfer hosting and leave?',
      message:
          '${candidate.name} will become the host of this activity. '
          'You will no longer be able to manage it.',
      primaryLabel: 'Stay',
      secondaryLabel: 'Transfer & Leave',
    ).show(context, barrierDismissible: false);

    if (action != SynkDialogAction.secondary || !mounted) return;

    setState(() => _isLeaving = true);

    final result = await _leaveController.transferHostAndLeave(
      activityId: activityId,
      newHostUserId: candidate.userId,
    );

    if (result != null) {
      store.removeHosted(activityId);
      _refreshAfterTransfer(store);
    } else if (_leaveController.failureResult == 'not_host') {
      // Hosting already moved elsewhere; reload what the viewer still hosts.
      _refreshAfterTransfer(store);
    }

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isLeaving = false;
        _leaveError = _leaveController.errorMessage;
      });
      return;
    }

    setState(() => _isLeaving = false);

    await SynkFeedback.showSuccessDialog(
      context,
      title: 'You Left the Activity',
      message: '${candidate.name} is now the host.',
    );

    if (mounted) Navigator.of(context).pop();
  }

  String? _savedParticipationStatus() {
    for (final activity in widget.activityStore.participating) {
      if (activity.id == _currentActivity.id) {
        return activity.participationStatus;
      }
    }
    return null;
  }

  Activity? _hostedActivity() {
    for (final activity in widget.activityStore.mine) {
      if (activity.id == _currentActivity.id) {
        return activity;
      }
    }
    return null;
  }

  // Refreshes never throw; the database change already succeeded.
  Future<void> _refreshParticipating(ActivityStore store) async {
    try {
      store.setParticipating(await _activitiesModel.fetchParticipating());
    } catch (_) {}
  }

  Future<void> _refreshHostedAndParticipating(ActivityStore store) async {
    try {
      store.setMine(await _activitiesModel.fetchMine());
    } catch (_) {}

    await _refreshParticipating(store);
  }

  Future<void> _refreshAfterTransfer(ActivityStore store) async {
    try {
      store.setMine(await _activitiesModel.fetchMine());
    } catch (_) {}

    try {
      store.setFeed(await _activitiesModel.fetchPublicFeed());
    } catch (_) {}
  }

  Widget _buildHeaderVisual() {
    final photoUrl = _currentActivity.photoUrl;

    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: SynkColors.backgroundLight,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                SynkColors.orange.withValues(alpha: 0.25),
                SynkColors.beige.withValues(alpha: 0.40),
                SynkColors.pink.withValues(alpha: 0.20),
              ],
            ),
          ),
          child: photoUrl != null && photoUrl.isNotEmpty
              ? Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                  errorBuilder: (_, _, _) => _buildFallbackHeaderAsset(),
                )
              : _buildFallbackHeaderAsset(),
        ),

        // Drag handle, floating on the image so the image reaches the
        // top edge of the sheet.
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),

        // Top controls: Close button
        Positioned(
          top: 20,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: SynkColors.orangeDark.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: SynkColors.textPrimary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Category Tag at bottom of cover
        if (_currentActivity.categoryLabel.isNotEmpty)
          Positioned(
            bottom: 12,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_currentActivity.categoryEmoji.isNotEmpty) ...[
                    Text(
                      _currentActivity.categoryEmoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    _currentActivity.categoryLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFallbackHeaderAsset() {
    final visual = ActivityVisual.of(_currentActivity);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            visual.tint.withValues(alpha: 0.14),
            visual.tint.withValues(alpha: 0.30),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          visual.icon,
          size: 64,
          color: Color.lerp(visual.tint, SynkColors.textPrimary, 0.35),
        ),
      ),
    );
  }

  Widget _buildTitleAndBadges() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _currentActivity.title,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            color: SynkColors.textPrimary,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        ActivityStatusChip(
          availability: ActivityAvailability.fromSpotsOpen(_spotsLeft),
        ),
      ],
    );
  }

  Widget _buildScheduleAndLocationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        children: [
          // Date & Time
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SynkColors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 20,
                  color: SynkColors.orangeDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date & Time',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formattedDateTime,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              height: 1,
              color: SynkColors.textSecondary.withValues(alpha: 0.12),
            ),
          ),

          // Location
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SynkColors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 20,
                  color: SynkColors.teal,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentActivity.location,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                    if (_currentActivity.locationAddress != null &&
                        _currentActivity.locationAddress!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _currentActivity.locationAddress!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: SynkColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_currentActivity.hasCoordinates ||
              MapsLauncher.canOpen(_currentActivity)) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (_currentActivity.hasCoordinates)
                  Expanded(child: _buildViewOnMapButton()),
                if (_currentActivity.hasCoordinates &&
                    MapsLauncher.canOpen(_currentActivity))
                  const SizedBox(width: 10),
                if (MapsLauncher.canOpen(_currentActivity))
                  _buildOpenInMapsButton(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static final _mapButtonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
    side: BorderSide(color: SynkColors.textSecondary.withValues(alpha: 0.18)),
  );

  // Closes this sheet (and any page under it) and shows the pin on our map.
  Widget _buildViewOnMapButton() {
    return SizedBox(
      height: 48,
      child: TextButton.icon(
        onPressed: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          widget.activityStore.showOnMap(_currentActivity);
        },
        icon: const Icon(
          Icons.map_rounded,
          size: 20,
          color: SynkColors.orangeDark,
        ),
        label: const Text('View on map'),
        style: TextButton.styleFrom(
          foregroundColor: SynkColors.textPrimary,
          backgroundColor: Colors.white,
          shape: _mapButtonShape,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // Square Google Maps button: opens the place in the Google Maps app.
  Widget _buildOpenInMapsButton() {
    return SizedBox.square(
      dimension: 48,
      child: TextButton(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          bool opened;
          try {
            opened = await MapsLauncher.open(_currentActivity);
          } catch (_) {
            opened = false;
          }
          if (!opened) {
            messenger.showSnackBar(
              const SnackBar(content: Text("Couldn't open Google Maps.")),
            );
          }
        },
        style: TextButton.styleFrom(
          backgroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: _mapButtonShape,
        ),
        child: Tooltip(
          message: 'Open in Google Maps',
          child: Image.asset(
            'assets/google_maps_logo.png',
            height: 24,
            errorBuilder: (_, _, _) => const Icon(Icons.map_rounded, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About This Activity',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: SynkColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: SynkColors.textSecondary.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            _currentActivity.description,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
              color: SynkColors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Participants',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SynkColors.textPrimary,
              ),
            ),
            Text(
              '$_joinedCount / ${_currentActivity.maxParticipants} spots',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: SynkColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingParticipants)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SynkColors.orange,
              ),
            ),
          )
        else ...[
          _buildParticipantsList(),
          if (_hideMembers && _anonymousCount > 0)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  "You'll see who's going once the host accepts you.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: SynkColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildParticipantsList() {
    // Collect attendees: starting with host
    final hostName = _currentActivity.hostName ?? 'Host';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          // Host entry
          _buildParticipantRow(
            name: hostName,
            username: _currentActivity.hostUsername,
            userId: _currentActivity.hostId,
            avatarUrl: _currentActivity.hostAvatarUrl,
            gender: _currentActivity.hostGender,
            isHost: true,
          ),

          // Server doesn't send pending users the list, so use the count.
          if (_hideMembers)
            for (var i = 0; i < _anonymousCount; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  height: 1,
                  color: SynkColors.textSecondary.withValues(alpha: 0.08),
                ),
              ),
              _buildAnonymousRow(),
            ]
          else
            for (final p in _participants) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  height: 1,
                  color: SynkColors.textSecondary.withValues(alpha: 0.08),
                ),
              ),
              _buildParticipantRow(
                name: (p['full_name'] as String?) ?? 'Community Member',
                username: p['username'] as String?,
                userId: p['user_id'] as String?,
                avatarUrl: p['avatar_url'] as String?,
                gender: p['gender'] as String?,
                isHost: false,
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildAnonymousRow() {
    return const Row(
      children: [
        AnonymousAvatar(size: 38),
        SizedBox(width: 12),
        // w800 so grey reads the same weight as the black names.
        Text(
          'Anonymous',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: SynkColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantRow({
    required String name,
    required String? username,
    required String? userId,
    required String? avatarUrl,
    required String? gender,
    required bool isHost,
  }) {
    final canOpen = userId != null && userId != _viewerId;

    return InkWell(
      onTap: canOpen
          ? () => showUserProfileSheet(
              context: context,
              userId: userId,
              name: name,
              username: username,
              avatarUrl: avatarUrl,
              gender: gender,
            )
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          _buildAvatar(
            userId: userId,
            avatarUrl: avatarUrl,
            gender: gender,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SynkColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (username != null && username.isNotEmpty)
                  Text(
                    '@$username',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: SynkColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (!isHost && userId != null && userId == _viewerId)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _joinedColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'You',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _joinedColor,
                ),
              ),
            ),
          if (isHost)
            Container(
              padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
              decoration: BoxDecoration(
                color: SynkColors.orangeDark.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CrownIcon(size: 14, color: SynkColors.orangeDark),
                  SizedBox(width: 4),
                  Text(
                    'Host',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: SynkColors.orangeDark,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // The participant's uploaded photo; for the viewer's own row, also the
  // photo saved on this device. Falls back to the app's default avatar.
  Widget _buildAvatar({
    required String? userId,
    required String? avatarUrl,
    required String? gender,
    required double size,
  }) {
    final fallback = AvatarUploader.defaultImageForGender(gender);
    final url = avatarUrl?.trim();

    ImageProvider? photo;
    if (url != null && url.startsWith('http')) {
      photo = NetworkImage(url);
    } else if (userId != null &&
        userId == widget.activityStore.currentUserId &&
        _ownProfile != null) {
      photo = AvatarUploader.imageFor(_ownProfile!);
    }

    return ClipOval(
      child: Image(
        image: photo ?? fallback,
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
}
