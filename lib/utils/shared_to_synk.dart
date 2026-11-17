import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_links/app_links.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/chat_controller.dart';
import '../l10n/l10n.dart';
import '../views/home/widgets/chat_share_sheets.dart';

// Pictures and links shared to Synk from the phone's share menu. Android
// keeps them in ShareActivity.kt. On iOS the ShareExtension opens a
// synk-share:// link that carries them, and saves them as a backup.
const _channel = MethodChannel('synk/shared');

bool _asking = false;
StreamSubscription<Uri>? _links;
Uri? _link;
final Set<int> _seenLinks = {};

// Android calls [onAdded] when something is shared while the app is open.
// iOS calls it when a synk-share:// link opens the app.
void listenForSharedToSynk(VoidCallback? onAdded) {
  _channel.setMethodCallHandler(
    onAdded == null
        ? null
        : (call) async {
            if (call.method == 'added') onAdded();
          },
  );
  unawaited(_links?.cancel());
  _links = null;
  if (onAdded == null || !Platform.isIOS) return;
  void got(Uri? uri) {
    if (uri == null || uri.scheme != 'synk-share') return;
    if (!_seenLinks.add(uri.toString().hashCode)) return;
    _link = uri;
    onAdded();
  }

  _links = AppLinks().uriLinkStream.listen(got, onError: (Object _) {});
  // The link that started the app, which the stream may have given out
  // before this listened.
  unawaited(AppLinks().getInitialLink().then(got, onError: (Object _) {}));
}

// What the link carries: texts as they are, pictures saved to temp files.
Future<({List<String> photos, List<String> texts})> _fromLink(Uri link) async {
  final texts = (link.queryParametersAll['text'] ?? const <String>[])
      .where((text) => text.trim().isNotEmpty)
      .toList();
  final photos = <String>[];
  final stamp = DateTime.now().millisecondsSinceEpoch;
  for (final (i, data)
      in (link.queryParametersAll['photo'] ?? const <String>[]).indexed) {
    try {
      final file = File('${Directory.systemTemp.path}/shared_${stamp}_$i.jpg');
      await file.writeAsBytes(base64Url.decode(base64Url.normalize(data)));
      photos.add(file.path);
    } catch (error) {
      debugPrint('SYNK: reading a shared picture failed: $error');
    }
  }
  return (photos: photos, texts: texts);
}

// Asks which chats the waiting pictures or links go to, if there are any.
Future<void> sendSharedToSynk(BuildContext context) async {
  if (_asking || !(Platform.isAndroid || Platform.isIOS)) return;
  _asking = true;
  try {
    // On iOS the link can come a moment after the app is back.
    if (Platform.isIOS && _link == null) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    var photos = const <String>[];
    var texts = const <String>[];
    try {
      final taken = await _channel.invokeMapMethod<String, Object?>('take');
      photos = (taken?['photos'] as List?)?.cast<String>() ?? const [];
      texts = (taken?['texts'] as List?)?.cast<String>() ?? const [];
    } catch (error) {
      debugPrint('SYNK: reading what was shared failed: $error');
    }
    // The link has the same things as the backup, so it wins when it has any.
    final link = _link;
    _link = null;
    if (link != null) {
      final carried = await _fromLink(link);
      if (carried.photos.isNotEmpty || carried.texts.isNotEmpty) {
        photos = carried.photos;
        texts = carried.texts;
      }
    }
    if ((photos.isEmpty && texts.isEmpty) || !context.mounted) return;
    final model = ChatController.instance.model;
    await showSendToChatSheet(
      context,
      title: context.l10n.sharedSendTo,
      send: (chatId) async {
        for (final file in photos) {
          final path = await model.uploadPhoto(chatId, XFile(file));
          final (:result, message: _) = await model.send(
            chatId,
            '',
            imagePath: path,
          );
          if (result != 'sent') return result;
        }
        for (final text in texts) {
          final (:result, message: _) = await model.send(chatId, text);
          if (result != 'sent') return result;
        }
        return 'sent';
      },
    );
  } finally {
    _asking = false;
    // A link that came while this was busy.
    if (_link != null && context.mounted) unawaited(sendSharedToSynk(context));
  }
}
