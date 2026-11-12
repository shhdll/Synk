import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';

// The built-in sticker pack (assets/sticker-pack/): stickers.json lists each
// sticker's id, name and file, with every file in 512/ (for the picker) and
// 1024/ (for messages). A message only stores the sticker's id.

class ChatSticker {
  const ChatSticker({required this.id, required this.name, required this.file});

  final String id;
  final String name;
  final String file;

  static const _folder = 'assets/sticker-pack';

  String get smallAsset => '$_folder/512/$file';
  String get largeAsset => '$_folder/1024/$file';
}

class StickerPack {
  StickerPack._(this.stickers)
    : _byId = {for (final s in stickers) s.id: s};

  final List<ChatSticker> stickers;
  final Map<String, ChatSticker> _byId;

  ChatSticker? byId(String id) => _byId[id];

  static Future<StickerPack>? _loading;

  // Loaded once, the first time a chat needs it.
  static Future<StickerPack> load() => _loading ??= _read();

  static Future<StickerPack> _read() async {
    try {
      final raw = await rootBundle.loadString(
        '${ChatSticker._folder}/stickers.json',
      );
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return StickerPack._([
        for (final s in (map['stickers'] as List? ?? const []))
          if (s is Map && s['id'] is String && s['file'] is String)
            ChatSticker(
              id: s['id'] as String,
              name: s['name'] as String? ?? s['id'] as String,
              file: s['file'] as String,
            ),
      ]);
    } catch (error) {
      debugPrint('SYNK: sticker pack failed to load: $error');
      _loading = null;
      return StickerPack._(const []);
    }
  }
}

// Where the keyboard would be: a grid of the pack's stickers. Tapping one
// calls [onPick].
class StickerPickerPanel extends StatelessWidget {
  const StickerPickerPanel({
    super.key,
    required this.height,
    required this.onPick,
  });

  final double height;
  final ValueChanged<ChatSticker> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: SynkColors.backgroundDark,
        border: Border(
          top: BorderSide(
            color: SynkColors.textSecondary.withValues(alpha: 0.14),
          ),
        ),
      ),
      child: FutureBuilder<StickerPack>(
        future: StickerPack.load(),
        builder: (context, snapshot) {
          final pack = snapshot.data;
          if (pack == null) {
            return const Center(
              child: CircularProgressIndicator(color: SynkColors.orangeDark),
            );
          }
          if (pack.stickers.isEmpty) {
            return Center(
              child: Text(
                context.l10n.somethingWentWrongPleaseTryAgain,
                style: const TextStyle(color: SynkColors.textSecondary),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: pack.stickers.length,
            itemBuilder: (context, i) {
              final sticker = pack.stickers[i];
              return Semantics(
                button: true,
                label: sticker.name,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onPick(sticker);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      sticker.smallAsset,
                      fit: BoxFit.contain,
                      // The 512 files, drawn small: decode them small too.
                      cacheWidth: 256,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// A sticker in the chat: the 1024 image, no bubble.
class StickerImage extends StatelessWidget {
  const StickerImage({super.key, required this.stickerId, this.size = 150});

  final String stickerId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StickerPack>(
      future: StickerPack.load(),
      builder: (context, snapshot) {
        final sticker = snapshot.data?.byId(stickerId);
        if (sticker == null) {
          // Still loading, or from a newer pack than this app has.
          return SizedBox.square(
            dimension: size,
            child: snapshot.connectionState == ConnectionState.done
                ? const Icon(
                    Icons.emoji_emotions_outlined,
                    size: 48,
                    color: SynkColors.textSecondary,
                  )
                : null,
          );
        }
        return Image.asset(
          sticker.largeAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          semanticLabel: sticker.name,
        );
      },
    );
  }
}
