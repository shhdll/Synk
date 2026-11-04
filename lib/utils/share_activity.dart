import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../models/activity_model.dart';

// Opens the phone's share menu with a ready-made invite in the app's
// language, so people don't have to type the details themselves.
// [buttonContext] is the tapped button's context; iPads point the menu at it.
// The synk.cc page that opens the activity in the app. A private one
// carries its code, so people who aren't in it yet can join.
Uri activityLink(Activity activity) => Uri.https('synk.cc', '/activity.html', {
  'id': activity.id,
  if (!activity.isPublic && activity.hasActivityCode)
    'code': activity.activityCode!,
});

// Opens the phone's share menu with the activity, a link to it and its code.
Future<void> shareActivityLink(
  BuildContext buttonContext,
  Activity activity,
) async {
  final l10n = buttonContext.l10n;
  final title = activity.title.trim();
  final date = activity.dateTime;
  final name = title.isEmpty ? l10n.untitledActivity : title;
  final when =
      '${formatShortDate(date)} · ${formatTime(date.hour, date.minute)}';
  final link = activityLink(activity).toString();
  // The code too, when there is one, for people who'd rather type it.
  final message = activity.hasActivityCode
      ? l10n.shareLinkCodeMessage(name, when, link, activity.activityCode!)
      : l10n.shareLinkMessage(name, when, link);

  final box = buttonContext.findRenderObject() as RenderBox?;
  final messenger = ScaffoldMessenger.maybeOf(buttonContext);
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: message,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } catch (_) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.couldntOpenTheShareMenu)));
  }
}

// Same invite as the link, which already has the code.
Future<void> shareActivityCode(
  BuildContext buttonContext,
  Activity activity,
  String code,
) => shareActivityLink(buttonContext, activity);
