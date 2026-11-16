import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/chat_controller.dart';
import '../l10n/l10n.dart';
import '../views/home/widgets/chat_share_sheets.dart';

// Pictures and links shared to Synk from the phone's share menu. Android
// keeps them in ShareActivity.kt, iOS in the ShareExtension's folder.
const _channel = MethodChannel('synk/shared');

bool _asking = false;

// Android calls [onAdded] when something is shared while the app is open.
void listenForSharedToSynk(VoidCallback? onAdded) {
  _channel.setMethodCallHandler(
    onAdded == null
        ? null
        : (call) async {
            if (call.method == 'added') onAdded();
          },
  );
}

// Asks which chats the waiting pictures or links go to, if there are any.
Future<void> sendSharedToSynk(BuildContext context) async {
  if (_asking || !(Platform.isAndroid || Platform.isIOS)) return;
  _asking = true;
  try {
    var photos = const <String>[];
    var texts = const <String>[];
    try {
      final taken = await _channel.invokeMapMethod<String, Object?>('take');
      photos = (taken?['photos'] as List?)?.cast<String>() ?? const [];
      texts = (taken?['texts'] as List?)?.cast<String>() ?? const [];
    } catch (error) {
      debugPrint('SYNK: reading what was shared failed: $error');
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
  }
}
