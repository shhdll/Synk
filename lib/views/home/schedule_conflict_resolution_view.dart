import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';
import '../../models/activities_model.dart';
import '../../models/activity_participation_model.dart';
import '../../services/push_notification_service.dart';

Future<bool?>? _activeConflictDialog;

Future<bool?> showScheduleConflictResolutionDialog(BuildContext context) {
  final active = _activeConflictDialog;
  if (active != null) return active;
  final result = showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (_) => const Dialog.fullscreen(
      child: ScheduleConflictResolutionView(),
    ),
  );
  _activeConflictDialog = result;
  result.whenComplete(() {
    if (identical(_activeConflictDialog, result)) {
      _activeConflictDialog = null;
    }
  });
  return result;
}

class ScheduleConflictResolutionView extends StatefulWidget {
  const ScheduleConflictResolutionView({super.key});

  @override
  State<ScheduleConflictResolutionView> createState() =>
      _ScheduleConflictResolutionViewState();
}

class _ScheduleConflictResolutionViewState
    extends State<ScheduleConflictResolutionView> {
  final ActivitiesModel _model = ActivitiesModel();
  final ActivityParticipationModel _participationModel =
      ActivityParticipationModel();
  List<Map<String, dynamic>> _conflicts = const [];
  final Set<String> _keepIds = {};
  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;
  String? _error;

  List<Map<String, dynamic>> get _activities {
    final byId = <String, Map<String, dynamic>>{};
    for (final conflict in _conflicts) {
      for (final side in ['first', 'second']) {
        final id = conflict['${side}_activity_id'] as String?;
        if (id == null) continue;
        final existing = byId[id];
        if (existing == null) {
          byId[id] = {
            'id': id,
            'title': conflict['${side}_title'] as String? ?? 'Activity',
            'starts': DateTime.parse(conflict['${side}_starts_at'] as String).toLocal(),
            'ends': DateTime.parse(conflict['${side}_ends_at'] as String).toLocal(),
            'isHost': conflict['${side}_is_host'] == true,
            'changed': conflict['changed_activity_id'] == id,
          };
        } else if (conflict['changed_activity_id'] == id) {
          existing['changed'] = true;
        }
      }
    }
    final result = byId.values.toList()
      ..sort((a, b) => (a['starts'] as DateTime).compareTo(b['starts'] as DateTime));
    return result;
  }

  bool get _selectionValid {
    final selected = _activities.where((item) => _keepIds.contains(item['id'])).toList();
    if (selected.isEmpty) return false;
    for (var first = 0; first < selected.length; first++) {
      for (var second = first + 1; second < selected.length; second++) {
        final a = selected[first];
        final b = selected[second];
        if ((a['starts'] as DateTime).isBefore(b['ends'] as DateTime) &&
            (b['starts'] as DateTime).isBefore(a['ends'] as DateTime)) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final conflicts = await _model.fetchScheduleConflicts();
      if (!mounted) return;
      setState(() {
        _conflicts = conflicts;
        _keepIds
          ..clear()
          ..addAll(_activities.map((item) => item['id'] as String));
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Could not load your current schedule conflicts.';
        _loading = false;
      });
    }
  }

  Future<void> _resolve() async {
    if (_saving || !_selectionValid) return;
    final leaving = _activities
        .where((activity) => !_keepIds.contains(activity['id']))
        .toList();
    final hostedToDelete = leaving
        .where((activity) => activity['isHost'] == true)
        .toList();
    final joinedToLeave = leaving
        .where((activity) => activity['isHost'] != true)
        .toList();
    if (leaving.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Resolve schedule conflicts?'),
          content: Text([
            if (hostedToDelete.isNotEmpty)
              'Delete activities you host: ${hostedToDelete.map((activity) => activity['title']).join(', ')}.',
            if (joinedToLeave.isNotEmpty)
              'Leave activities you joined: ${joinedToLeave.map((activity) => activity['title']).join(', ')}.',
          ].join('\n\n')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      for (final activity in joinedToLeave) {
        final result = await _participationModel.leaveActivity(
          activity['id'] as String,
        );
        if (result.result != 'left' && result.result != 'not_participating') {
          throw StateError(result.message);
        }
      }
      for (final activity in hostedToDelete) {
        await _model.delete(activity['id'] as String);
      }

      // Deleting a hosted activity can remove its conflict rows, so only
      // pass the activities that still appear in unresolved conflicts.
      final remainingConflicts = await _model.fetchScheduleConflicts();
      final remainingIds = <String>{
        for (final conflict in remainingConflicts) ...[
          conflict['first_activity_id'] as String,
          conflict['second_activity_id'] as String,
        ],
      };
      final keepIds = _keepIds.where(remainingIds.contains).toList();
      final result = await _model.resolveScheduleConflicts(keepIds);
      if (!mounted) return;
      if (result['result'] == 'resolved' || result['result'] == 'no_conflicts') {
        final activityId = _activities.isEmpty
            ? null
            : _activities.first['id'] as String?;
        if (activityId != null) {
          PushNotificationService.instance.refreshActivity(activityId);
        }
        setState(() => _allowPop = true);
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _error = result['message'] as String? ?? 'Could not resolve conflicts.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not resolve conflicts. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _when(DateTime value) =>
      '${value.toLocal().toString().substring(0, 16)}';

  Widget _tag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
  );

  Widget _activityCard(Map<String, dynamic> activity) {
    final id = activity['id'] as String;
    final keep = _keepIds.contains(id);
    final isHost = activity['isHost'] == true;
    final color = keep ? SynkColors.tealText : SynkColors.orangeDark;
    final start = activity['starts'] as DateTime;
    final end = activity['ends'] as DateTime;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.4),
        boxShadow: [BoxShadow(color: SynkColors.textPrimary.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 7))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _saving ? null : () => setState(() {
          if (keep) { _keepIds.remove(id); } else { _keepIds.add(id); }
        }),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(15)),
              child: Icon(isHost ? Icons.event_available_rounded : Icons.event_rounded, color: color, size: 23),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(activity['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: SynkColors.textPrimary)),
              const SizedBox(height: 5),
              Text('${_when(start)} – ${TimeOfDay.fromDateTime(end).format(context)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SynkColors.textSecondary)),
              const SizedBox(height: 9),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (activity['changed'] == true) _tag('Rescheduled', SynkColors.orangeDark),
                _tag(isHost ? 'You host' : 'You joined', SynkColors.ink),
                _tag(keep ? 'Keeping' : isHost ? 'Will delete' : 'Will leave', color),
              ]),
            ])),
            const SizedBox(width: 10),
            Icon(keep ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: color, size: 27),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      child: Scaffold(
      backgroundColor: SynkColors.background,
      appBar: AppBar(
        title: const Text('Schedule conflict'),
        automaticallyImplyLeading: false,
        backgroundColor: SynkColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _conflicts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : _activities.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 52, color: SynkColors.tealText),
                    const SizedBox(height: 12),
                    const Text('You have no unresolved schedule conflicts.'),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        setState(() => _allowPop = true);
                        Navigator.of(context).pop(true);
                      },
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [SynkColors.orange, SynkColors.orangeDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.event_busy_rounded, color: Colors.white, size: 30),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('You have overlapping plans', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                            SizedBox(height: 6),
                            Text('Choose what to keep. We’ll leave or delete the other activities after you confirm.', style: TextStyle(fontSize: 14, height: 1.35, color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'YOUR ACTIVITIES',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w900,
                    color: SynkColors.labelGrey,
                  ),
                ),
                const SizedBox(height: 10),
                for (final conflict in _conflicts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${conflict['first_title']} overlaps ${conflict['second_title']}.',
                      style: const TextStyle(
                        color: SynkColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                for (final activity in _activities) _activityCard(activity),
                if (!_selectionValid)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'The selected activities overlap. Change your selection to continue.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving || !_selectionValid ? null : _resolve,
                  child: Text(_saving ? 'Saving…' : 'Confirm selection'),
                ),
              ],
            ),
      ),
    );
  }
}
