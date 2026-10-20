import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../l10n/l10n.dart';

// iPhone-style "Move and Scale": the photo moves and zooms behind a fixed
// frame. Pops with the cropped JPEG's path, or null on Cancel.
class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({
    super.key,
    required this.imagePath,
    this.aspectRatio = 1,
    this.circle = false,
    this.maxOutputWidth = 1024,
  });

  final String imagePath;
  final double aspectRatio;
  final bool circle;
  final int maxOutputWidth;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen>
    with SingleTickerProviderStateMixin {
  static const double _maxZoom = 5;

  ui.Image? _image;
  bool _saving = false;

  // Zoom on top of the "just covers the frame" size, and the image centre's
  // offset from the frame centre, in screen pixels.
  double _zoom = 1;
  Offset _offset = Offset.zero;

  double _startZoom = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;

  Size _frame = Size.zero;

  late final AnimationController _settle;
  Animation<double>? _zoomAnim;
  Animation<Offset>? _offsetAnim;

  @override
  void initState() {
    super.initState();
    _settle =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          setState(() {
            _zoom = _zoomAnim!.value;
            _offset = _offsetAnim!.value;
          });
        });
    _load();
  }

  Future<void> _load() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _image = frame.image);
  }

  @override
  void dispose() {
    _settle.dispose();
    _image?.dispose();
    super.dispose();
  }

  // Scale at which the image exactly covers the frame.
  double get _baseScale {
    final image = _image!;
    return math.max(
      _frame.width / image.width,
      _frame.height / image.height,
    );
  }

  Size _displaySize(double zoom) => Size(
    _image!.width * _baseScale * zoom,
    _image!.height * _baseScale * zoom,
  );

  // Keeps the frame fully covered by the photo.
  Offset _clampOffset(Offset offset, double zoom) {
    final size = _displaySize(zoom);
    final maxX = math.max(0.0, (size.width - _frame.width) / 2);
    final maxY = math.max(0.0, (size.height - _frame.height) / 2);
    return Offset(offset.dx.clamp(-maxX, maxX), offset.dy.clamp(-maxY, maxY));
  }

  void _onScaleStart(ScaleStartDetails details, Offset center) {
    _settle.stop();
    _startZoom = _zoom;
    _startOffset = _offset;
    _startFocal = details.localFocalPoint - center;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Offset center) {
    // A little give past the limits, like iOS, then it springs back.
    final zoom = (_startZoom * details.scale).clamp(0.85, _maxZoom * 1.15);
    final focal = details.localFocalPoint - center;
    final imagePoint = (_startFocal - _startOffset) / _startZoom;
    final raw = focal - imagePoint * zoom;
    final clamped = _clampOffset(raw, math.max(zoom, 1));
    setState(() {
      _zoom = zoom;
      _offset = clamped + (raw - clamped) * 0.25;
    });
  }

  void _onScaleEnd() {
    final zoom = _zoom.clamp(1.0, _maxZoom);
    _animateTo(zoom, _clampOffset(_offset, zoom));
  }

  void _animateTo(double zoom, Offset offset) {
    final curve = CurvedAnimation(parent: _settle, curve: Curves.easeOut);
    _zoomAnim = Tween(begin: _zoom, end: zoom).animate(curve);
    _offsetAnim = Tween(begin: _offset, end: offset).animate(curve);
    _settle.forward(from: 0);
  }

  void _onDoubleTap() {
    HapticFeedback.selectionClick();
    if (_zoom > 1.01) {
      _animateTo(1, Offset.zero);
    } else {
      _animateTo(2, _clampOffset(_offset * 2, 2));
    }
  }

  Future<void> _choose() async {
    final image = _image;
    if (image == null || _saving) return;
    setState(() => _saving = true);

    // Frame position in the image's own pixels.
    final scale = _baseScale * _zoom;
    final display = _displaySize(_zoom);
    final left = (display.width - _frame.width) / 2 - _offset.dx;
    final top = (display.height - _frame.height) / 2 - _offset.dy;
    final source = Rect.fromLTWH(
      left / scale,
      top / scale,
      _frame.width / scale,
      _frame.height / scale,
    );

    final outWidth = math.min(widget.maxOutputWidth, source.width.round());
    final outHeight = (outWidth / widget.aspectRatio).round();

    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      source,
      Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final cropped = await recorder.endRecording().toImage(outWidth, outHeight);
    final rgba = await cropped.toByteData(format: ui.ImageByteFormat.rawRgba);
    cropped.dispose();

    final jpg = await compute(_encodeJpg, (
      rgba!.buffer.asUint8List(),
      outWidth,
      outHeight,
    ));

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/crop_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(jpg);
    if (mounted) Navigator.of(context).pop(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 14),
              Text(
                context.l10n.moveAndScale,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(child: _buildCropArea()),
              _buildButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCropArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth - (widget.circle ? 24 : 16);
        var frameWidth = side;
        var frameHeight = side / widget.aspectRatio;
        if (frameHeight > constraints.maxHeight - 40) {
          frameHeight = constraints.maxHeight - 40;
          frameWidth = frameHeight * widget.aspectRatio;
        }
        _frame = Size(frameWidth, frameHeight);
        final center = Offset(
          constraints.maxWidth / 2,
          constraints.maxHeight / 2,
        );

        final image = _image;
        if (image == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final display = _displaySize(_zoom);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (d) => _onScaleStart(d, center),
          onScaleUpdate: (d) => _onScaleUpdate(d, center),
          onScaleEnd: (_) => _onScaleEnd(),
          onDoubleTap: _onDoubleTap,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: center.dx + _offset.dx - display.width / 2,
                top: center.dy + _offset.dy - display.height / 2,
                width: display.width,
                height: display.height,
                child: RawImage(image: image, fit: BoxFit.fill),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _FramePainter(
                      frame: Rect.fromCenter(
                        center: center,
                        width: frameWidth,
                        height: frameHeight,
                      ),
                      circle: widget.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildButtons() {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 17,
      fontWeight: FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel, style: style),
          ),
          TextButton(
            onPressed: _image == null || _saving ? null : _choose,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    context.l10n.choose,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

Uint8List _encodeJpg((Uint8List, int, int) args) {
  final (bytes, width, height) = args;
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: bytes.buffer,
    numChannels: 4,
  );
  return img.encodeJpg(image, quality: 88);
}

// Dims everything outside the frame and outlines it.
class _FramePainter extends CustomPainter {
  _FramePainter({required this.frame, required this.circle});

  final Rect frame;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Path();
    if (circle) {
      hole.addOval(frame);
    } else {
      hole.addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(4)));
    }
    final dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      hole,
    );
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawPath(
      hole,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.frame != frame || old.circle != circle;
}
