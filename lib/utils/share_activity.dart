import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../models/activity_model.dart';

// Opens the phone's share menu with a ready-made invite in the app's
// language, so people don't have to type the details themselves.
// [buttonContext] is the tapped button's context; iPads point the menu at it.
Future<void> shareActivityCode(
  BuildContext buttonContext,
  Activity activity,
  String code,
) async {
  final l10n = buttonContext.l10n;
  final title = activity.title.trim();
  final date = activity.dateTime;
  final message = l10n.shareMessage(
    title.isEmpty ? l10n.untitledActivity : title,
    '${formatShortDate(date)} · ${formatTime(date.hour, date.minute)}',
    activity.location.trim().isNotEmpty
        ? activity.location.trim()
        : (activity.locationAddress ?? '').trim(),
    code,
  );

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
