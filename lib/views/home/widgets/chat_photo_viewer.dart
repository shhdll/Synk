import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../utils/custom_widgets/synk_feedback.dart';
import '../../../utils/text_direction.dart';

// One photo message, as the viewer shows it.
class ChatPhoto {
  const ChatPhoto({
    required this.id,
    required this.link,
    required this.sender,
    required this.sentAt,
    this.caption = '',
  });

  final String id;
  final String link;
  final String sender;
  final DateTime sentAt;
  final String caption;
}

// "Fri, Nov 13, 2026 · 12:20 AM" / "الجمعة، 13 نوفمبر 2026 · 12:20 ص"
String chatPhotoSentAt(BuildContext context, DateTime date) =>
    context.l10n.photoSentAt(
      formatShortDate(date),
      date.year.toString(),
      formatTime(date.hour, date.minute),
    );

// Opens the chat's photos full screen at [initialIndex]; swipe between them.
Future<void> showChatPhotoViewer(
  BuildContext context, {
  required List<ChatPhoto> photos,
  required int initialIndex,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, _, _) =>
          ChatPhotoViewer(photos: photos, initialIndex: initialIndex),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class ChatPhotoViewer extends StatefulWidget {
  const ChatPhotoViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  final List<ChatPhoto> photos;
  final int initialIndex;

  @override
  State<ChatPhotoViewer> createState() => _ChatPhotoViewerState();
}

class _ChatPhotoViewerState extends State<ChatPhotoViewer> {
  static const double _thumb = 44;
  static const double _thumbGap = 8;
  static const double _stripEdge = 16;
  static const Color _thumbBorder = Color(0xFFFAC39A);

  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  final ScrollController _strip = ScrollController();
  final Map<int, TransformationController> _zoom = {};
  late int _index = widget.initialIndex;

  // Tapping the photo hides the bars, like other galleries.
  bool _chrome = true;
  bool _saving = false;

  // While zoomed in, a swipe pans the photo instead of changing it.
  bool _zoomed = false;
  Offset _doubleTapAt = Offset.zero;

  ChatPhoto get _photo => widget.photos[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerThumb(false));
  }

  @override
  void dispose() {
    _pages.dispose();
    _strip.dispose();
    for (final controller in _zoom.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TransformationController _zoomFor(int index) =>
      _zoom.putIfAbsent(index, TransformationController.new);

  // Side padding of the strip: centers a few thumbnails, or leaves a small
  // edge when there are enough to scroll.
  double _stripPadding(double width) {
    final count = widget.photos.length;
    final content = count * _thumb + (count - 1) * _thumbGap;
    return math.max(_stripEdge, (width - content) / 2);
  }

  // Scrolls the strip so the current photo's thumbnail is in view, centered
  // where the strip can scroll that far.
  void _centerThumb(bool animate) {
    if (!_strip.hasClients) return;
    final viewport = _strip.position.viewportDimension;
    final target =
        (_stripPadding(viewport) +
                _index * (_thumb + _thumbGap) +
                _thumb / 2 -
                viewport / 2)
            .clamp(0.0, _strip.position.maxScrollExtent);
    if (animate) {
      _strip.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else {
      _strip.jumpTo(target);
    }
  }

  void _onPageChanged(int index) {
    _zoom[_index]?.value = Matrix4.identity();
    setState(() {
      _index = index;
      _zoomed = false;
    });
    _centerThumb(true);
  }

  void _jumpTo(int index) {
    if (index == _index) return;
    _pages.jumpToPage(index);
  }

  void _toggleZoom() {
    final controller = _zoomFor(_index);
    if (_zoomed) {
      controller.value = Matrix4.identity();
      setState(() => _zoomed = false);
      return;
    }
    const scale = 2.5;
    final point = _doubleTapAt;
    controller.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(
        -point.dx * (scale - 1),
        -point.dy * (scale - 1),
        0,
      );
    setState(() => _zoomed = true);
  }

  Future<void> _save() async {
    if (_saving) return;
    final photo = _photo;
    final l10n = context.l10n;
    setState(() => _saving = true);
    var saved = false;
    var denied = false;
    try {
      final allowed =
          await Gal.hasAccess(toAlbum: true) ||
          await Gal.requestAccess(toAlbum: true);
      if (!allowed) {
        denied = true;
      } else {
        final response = await http.get(Uri.parse(photo.link));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          await Gal.putImageBytes(response.bodyBytes, album: 'Synk');
          saved = true;
        }
      }
    } catch (error) {
      debugPrint('SYNK: saving a chat photo failed: $error');
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) unawaited(HapticFeedback.lightImpact());
    SynkFeedback.showToast(
      context,
      title: saved ? l10n.photoSaved : l10n.couldntSavePhoto,
      message: denied ? l10n.allowPhotosToSave : null,
      success: saved,
    );
  }

  Future<void> _openGrid() async {
    final picked = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) =>
            ChatPhotosGridView(photos: widget.photos, currentIndex: _index),
      ),
    );
    if (picked != null && mounted) _jumpTo(picked);
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final caption = _photo.caption.trim();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pages,
                itemCount: photos.length,
                onPageChanged: _onPageChanged,
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                itemBuilder: (context, index) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _chrome = !_chrome),
                  onDoubleTapDown: (details) =>
                      _doubleTapAt = details.localPosition,
                  onDoubleTap: _toggleZoom,
                  child: InteractiveViewer(
                    transformationController: _zoomFor(index),
                    maxScale: 4,
                    // Panning only once zoomed, so a swipe changes photos.
                    panEnabled: _zoomed,
                    onInteractionEnd: (_) {
                      final zoomed =
                          _zoomFor(index).value.getMaxScaleOnAxis() > 1.01;
                      if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                    },
                    child: Center(
                      child: Image.network(
                        photos[index].link,
                        fit: BoxFit.contain,
                        semanticLabel: context.l10n.photo,
                        loadingBuilder: (_, child, progress) =>
                            progress == null
                            ? child
                            : const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  color: Colors.white,
                                ),
                              ),
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _fade(
              alignment: Alignment.topCenter,
              child: _buildTopBar(context),
            ),
            _fade(
              alignment: Alignment.bottomCenter,
              child: _buildBottom(context, caption),
            ),
          ],
        ),
      ),
    );
  }

  // The bars slide away together when the photo is tapped.
  Widget _fade({required Alignment alignment, required Widget child}) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        ignoring: !_chrome,
        child: AnimatedOpacity(
          opacity: _chrome ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 18),
          child: Row(
            children: [
              IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: const BackButtonIcon(),
                color: Colors.white,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _photo.sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chatPhotoSentAt(context, _photo.sentAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.photos.length > 1)
                IconButton(
                  tooltip: l10n.allPhotos,
                  onPressed: _openGrid,
                  icon: const Icon(Icons.grid_view_rounded),
                  color: Colors.white,
                ),
              IconButton(
                tooltip: l10n.savePhoto,
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded),
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottom(BuildContext context, String caption) {
    final photos = widget.photos;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (caption.isNotEmpty)
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                child: SingleChildScrollView(
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    textDirection: textDirectionOf(caption),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (photos.length > 1)
              Padding(
                // A little space above the bottom safe area.
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  height: _thumb + 20,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = _stripPadding(constraints.maxWidth);
                      return ListView.separated(
                        controller: _strip,
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.fromLTRB(side, 10, side, 10),
                        itemCount: photos.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: _thumbGap),
                        itemBuilder: (context, index) {
                          final selected = index == _index;
                          return GestureDetector(
                            onTap: () => _jumpTo(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: _thumb,
                              height: _thumb,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? _thumbBorder
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 160),
                                opacity: selected ? 1 : 0.55,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: _Thumbnail(link: photos[index].link),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Every photo in the chat, newest first, grouped by the day it was sent.
// Tapping one returns its index to the viewer.
class ChatPhotosGridView extends StatelessWidget {
  const ChatPhotosGridView({
    super.key,
    required this.photos,
    required this.currentIndex,
  });

  final List<ChatPhoto> photos;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Indexes, newest first, split into days.
    final days = <List<int>>[];
    for (var i = photos.length - 1; i >= 0; i--) {
      final last = days.isEmpty ? null : photos[days.last.first].sentAt;
      if (last == null || !DateUtils.isSameDay(last, photos[i].sentAt)) {
        days.add([i]);
      } else {
        days.last.add(i);
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.allPhotos,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                l10n.photoCount(photos.length),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
        body: CustomScrollView(
          slivers: [
            for (final day in days) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                  child: Text(
                    l10n.photoDay(
                      formatShortDate(photos[day.first].sentAt),
                      photos[day.first].sentAt.year.toString(),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 3,
                    crossAxisSpacing: 3,
                  ),
                  itemCount: day.length,
                  itemBuilder: (context, i) {
                    final index = day[i];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).pop(index),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _Thumbnail(link: photos[index].link),
                          if (index == currentIndex)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: SynkColors.orange,
                                  width: 3,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.link});

  final String link;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(color: Color(0xFF26242B));
    return Image.network(
      link,
      fit: BoxFit.cover,
      cacheWidth: 300,
      frameBuilder: (_, child, frame, sync) =>
          sync || frame != null ? child : placeholder,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFF26242B),
        child: Icon(Icons.broken_image_outlined, color: Colors.white38),
      ),
    );
  }
}
