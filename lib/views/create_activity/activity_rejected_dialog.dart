import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'create_activity_widgets.dart';

// Shown when the content check rejects an activity. It names the fields to
// review and lists the guidelines, but never the detected word, category or
// score: the server doesn't send them. The list is the same general reasons
// whatever was flagged.
//
// [fields] holds the flagged field names: title, location, description and
// photo. The form keeps everything; the button only closes this.
Future<void> showActivityRejectedDialog(
  BuildContext context, {
  required List<String> fields,
}) {
  return SynkFeedback.showErrorDialog(
    context,
    icon: Icons.shield_outlined,
    title: context.l10n.activityRejectedTitle,
    message: context.l10n.activityRejectedMessage,
    buttonLabel: context.l10n.reviewActivity,
    messageBuilder: (_) => ActivityRejectedMessage(fields: fields),
  );
}

class ActivityRejectedMessage extends StatelessWidget {
  const ActivityRejectedMessage({super.key, required this.fields});

  final List<String> fields;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = [for (final field in fields) ?_label(l10n, field)];
    // Scrolls on short screens instead of overflowing the popup.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.activityRejectedMessage),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.activityRejectedGuidelines,
                textAlign: TextAlign.start,
              ),
            ),
            if (labels.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                l10n.activityNeedsReview,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SynkColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [for (final label in labels) _FieldChip(label)],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String? _label(AppLocalizations l10n, String field) => switch (field) {
    'title' => l10n.activityTitle,
    'location' => l10n.location,
    'description' => l10n.description,
    'photo' => l10n.photo,
    _ => null,
  };
}

class _FieldChip extends StatelessWidget {
  const _FieldChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: kFieldErrorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kFieldErrorColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: kFieldErrorColor,
        ),
      ),
    );
  }
}
