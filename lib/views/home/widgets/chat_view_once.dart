import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/text_direction.dart';

// View-once photos and voice messages, like WhatsApp: the ① toggle, the
// preview before sending a photo, and how the message shows in the chat.

// The round "1" button. Filled when on.
class ViewOnceToggle extends StatelessWidget {
  const ViewOnceToggle({
    super.key,
    required this.on,
    required this.onChanged,
    this.onDark = false,
    this.size = 40,
  });

  final bool on;
  final ValueChanged<bool> onChanged;

  // On the black photo preview rather than the beige composer.
  final bool onDark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final idle = onDark ? Colors.white : SynkColors.textSecondary;
    return Semantics(
      button: true,
      toggled: on,
      label: context.l10n.viewOnce,
      child: Tooltip(
        message: context.l10n.viewOnce,
        child: InkResponse(
          radius: size / 2 + 4,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(!on);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? SynkColors.orangeDark : Colors.transparent,
              border: Border.all(
                color: on ? SynkColors.orangeDark : idle,
                width: 1.8,
              ),
            ),
            child: Text(
              '1',
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w900,
                color: on ? Colors.white : idle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// What to send with a picked photo; null when cancelled.
typedef PhotoSendChoice = ({bool viewOnce, String caption});

// Full screen, before a photo is sent: the photo, a caption box, the ①
// toggle and send.
Future<PhotoSendChoice?> showPhotoSendPreview(
  BuildContext context,
  XFile photo,
) {
  return Navigator.of(context).push<PhotoSendChoice>(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => _PhotoSendPreview(photo: photo),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _PhotoSendPreview extends StatefulWidget {
  const _PhotoSendPreview({required this.photo});

  final XFile photo;

  @override
  State<_PhotoSendPreview> createState() => _PhotoSendPreviewState();
}

class _PhotoSendPreviewState extends State<_PhotoSendPreview> {
  final TextEditingController _caption = TextEditingController();
  bool _viewOnce = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _toggle(bool on) {
    setState(() => _viewOnce = on);
    if (on) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            content: Text(context.l10n.viewOnceHint),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                tooltip: l.cancel,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: Image.file(
                    File(widget.photo.path),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      // A view-once photo has no caption: the text would
                      // show in notifications and the chats list.
                      opacity: _viewOnce ? 0.35 : 1,
                      child: TextField(
                        controller: _caption,
                        enabled: !_viewOnce,
                        maxLength: 2000,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _viewOnce ? l.viewOnce : l.addCaption,
                          hintStyle: const TextStyle(color: Colors.white70),
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.14),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(23),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ViewOnceToggle(
                    on: _viewOnce,
                    onChanged: _toggle,
                    onDark: true,
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: l.send,
                    onPressed: () => Navigator.pop<PhotoSendChoice>(context, (
                      viewOnce: _viewOnce,
                      caption: _viewOnce ? '' : _caption.text.trim(),
                    )),
                    style: IconButton.styleFrom(
                      backgroundColor: SynkColors.orangeDark,
                      foregroundColor: Colors.white,
                      fixedSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A view-once message in the chat. Theirs, not yet opened: tap to open.
// Afterwards, and always for the sender: "Opened" once it has been.
class ViewOnceMessageContent extends StatelessWidget {
  const ViewOnceMessageContent({
    super.key,
    required this.isPhoto,
    required this.isMine,
    required this.opened,
    this.onOpen,
    this.loading = false,
  });

  final bool isPhoto;
  final bool isMine;

  // Theirs: I opened it. Mine: someone did.
  final bool opened;

  // Null when it can't be opened (mine, or already opened).
  final VoidCallback? onOpen;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fg = isMine ? Colors.white : SynkColors.textPrimary;
    final muted = isMine
        ? Colors.white.withValues(alpha: 0.75)
        : SynkColors.textSecondary;
    // Theirs and waiting: the bright one.
    final fresh = !isMine && !opened;
    final kind = isPhoto ? l.photo : l.voiceMessage;
    final label = !isMine && opened ? l.opened : kind;

    final badge = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fresh ? SynkColors.orangeDark : Colors.transparent,
        border: Border.all(
          color: fresh ? SynkColors.orangeDark : muted,
          width: 1.6,
        ),
      ),
      child: loading
          ? SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: fresh ? Colors.white : muted,
              ),
            )
          : Text(
              '1',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: fresh ? Colors.white : muted,
              ),
            ),
    );

    return InkWell(
      onTap: loading ? null : onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            badge,
            const SizedBox(width: 10),
            Icon(
              isPhoto ? Icons.photo_outlined : Icons.mic_none_rounded,
              size: 18,
              color: opened && !isMine ? muted : fg,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                textDirection: textDirectionOf(label),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontStyle: !isMine && opened
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: !isMine && opened ? muted : fg,
                ),
              ),
            ),
            // The sender sees when it was opened.
            if (isMine && opened) ...[
              const SizedBox(width: 8),
              Text(
                l.opened,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
