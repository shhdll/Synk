import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';

// The synk.cc page that opens this profile in the app.
Uri profileLink(String userId) =>
    Uri.https('synk.cc', '/profile.html', {'id': userId});

// Opens the phone's share menu (WhatsApp, Copy and so on) with a link to a
// profile. [name] is the person's name when it isn't your own profile.
// [buttonContext] is the tapped button's context; iPads point the menu at it.
Future<void> shareProfileLink(
  BuildContext buttonContext, {
  required String userId,
  String? name,
}) async {
  final l10n = buttonContext.l10n;
  final link = profileLink(userId).toString();
  final first = name?.trim().split(' ').first ?? '';
  final message = first.isEmpty
      ? l10n.shareMyProfileMessage(link)
      : l10n.shareProfileMessage(first, link);

  final box = buttonContext.findRenderObject() as RenderBox?;
  final messenger = ScaffoldMessenger.maybeOf(buttonContext);
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: message,
        sharePositionOrigin: box == null || !box.hasSize
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
