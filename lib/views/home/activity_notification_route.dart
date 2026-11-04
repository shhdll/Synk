import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/activities_model.dart';
import '../../models/activity_model.dart';
import 'activity_code_join_sheet.dart';
import 'widgets/activity_details_sheet.dart';

// Loads an activity opened from a push notification and presents the existing
// activity details sheet on top of a small route that can be dismissed cleanly.
class ActivityNotificationRoute extends StatefulWidget {
  const ActivityNotificationRoute({
    super.key,
    required this.activityId,
    this.code,
  });

  final String activityId;

  // From a shared link to a private activity.
  final String? code;

  @override
  State<ActivityNotificationRoute> createState() =>
      _ActivityNotificationRouteState();
}

class _ActivityNotificationRouteState extends State<ActivityNotificationRoute> {
  final ActivitiesModel _activitiesModel = ActivitiesModel();
  final ActivityStore _activityStore = ActivityStore();
  String? _error;

  @override
  void initState() {
    super.initState();
    _activityStore.currentUserId =
        Supabase.instance.client.auth.currentUser?.id;
    unawaited(_openActivity());
  }

  Future<void> _openActivity() async {
    try {
      final participating = await _activitiesModel.fetchParticipating();
      _activityStore.setParticipating(participating);

      Activity? activity;
      for (final item in participating) {
        if (item.id == widget.activityId) {
          // Only asked to join a private one: it stays closed.
          if (!(item.isPending && !item.isPublic)) activity = item;
          break;
        }
      }
      activity ??= await _activitiesModel.fetchById(widget.activityId);

      if (!mounted) return;
      final code = widget.code;
      if (activity == null && code != null && code.isNotEmpty) {
        // A private activity the user isn't in yet: same as typing its code.
        await joinActivityWithCode(
          context,
          activityStore: _activityStore,
          activitiesModel: _activitiesModel,
          initialCode: code,
        );
        if (mounted) Navigator.of(context).pop();
        return;
      }
      if (activity == null) {
        setState(() => _error = context.l10n.thisActivityIsNoLongerAvailable);
        return;
      }

      _activityStore.upsert(activity);
      await showActivityDetailsSheet(
        context: context,
        activity: activity,
        activityStore: _activityStore,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.unableToOpenThisActivity);
      }
    }
  }

  @override
  void dispose() {
    _activityStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SynkColors.background,
      appBar: AppBar(
        backgroundColor: SynkColors.background,
        foregroundColor: SynkColors.textPrimary,
      ),
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator(color: SynkColors.orange)
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SynkColors.textSecondary),
                ),
              ),
      ),
    );
  }
}
