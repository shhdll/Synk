import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/chat_model.dart';
import '../../../utils/custom_widgets/synk_feedback.dart';

// Voice messages: recording one while the mic is held, and playing them in
// the chat with a waveform, like WhatsApp.

// "0:07", "1:42".
String formatVoiceLength(Duration d) {
  final seconds = d.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

// A finished recording, ready to upload.
typedef VoiceRecording = ({String path, Duration duration, List<int> waveform});

// How pressing the mic went.
enum VoiceStart {
  started,
  // The system just asked for the microphone; hold again once allowed.
  askedPermission,
  denied,
}

// Records one voice message at a time into a temporary .m4a file, and keeps
// how loud each moment was for the waveform.
class VoiceRecorder {
  // Bars stored with each message.
  static const waveformBars = 48;

  final AudioRecorder _recorder = AudioRecorder();
  final List<double> _levels = [];
  StreamSubscription<Amplitude>? _amplitude;
  String? _path;
  DateTime? _startedAt;

  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  // The latest loudness, 0 to 1, for the live meter.
  double get level => _levels.isEmpty ? 0 : _levels.last;

  // The last [count] loudness readings, oldest first, for the live waveform.
  List<double> recentLevels(int count) => _levels.length <= count
      ? List.of(_levels)
      : _levels.sublist(_levels.length - count);

  // Without microphone permission this asks for it instead of recording,
  // since the finger has usually let go by the time it's answered.
  Future<VoiceStart> start() async {
    if (!await _recorder.hasPermission(request: false)) {
      return await _recorder.hasPermission()
          ? VoiceStart.askedPermission
          : VoiceStart.denied;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
    _levels.clear();
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
    _path = path;
    _startedAt = DateTime.now();
    _amplitude = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((a) => _levels.add(_toLevel(a.current)));
    return VoiceStart.started;
  }

  // dBFS (about -60 for quiet to 0 for loudest) to 0-1.
  static double _toLevel(double db) {
    if (db.isNaN || db.isInfinite) return 0;
    return ((db + 50) / 50).clamp(0.0, 1.0);
  }

  Future<VoiceRecording?> stop() async {
    final duration = elapsed;
    await _amplitude?.cancel();
    _amplitude = null;
    _startedAt = null;
    final path = await _recorder.stop() ?? _path;
    _path = null;
    if (path == null) return null;
    return (path: path, duration: duration, waveform: _waveform());
  }

  Future<void> cancel() async {
    await _amplitude?.cancel();
    _amplitude = null;
    _startedAt = null;
    final path = _path;
    _path = null;
    try {
      await _recorder.cancel();
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {
      // Only a temporary file.
    }
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }

  // The recording's loudness squeezed into [waveformBars] bars, 0 to 100.
  List<int> _waveform() {
    if (_levels.isEmpty) return List.filled(waveformBars, 8);
    return [
      for (var i = 0; i < waveformBars; i++)
        () {
          final from = (i * _levels.length / waveformBars).floor();
          final to = math.max(
            from + 1,
            ((i + 1) * _levels.length / waveformBars).floor(),
          );
          var loudest = 0.0;
          for (var j = from; j < to && j < _levels.length; j++) {
            loudest = math.max(loudest, _levels[j]);
          }
          return (loudest * 100).round().clamp(4, 100);
        }(),
    ];
  }
}

// Replaces the message box while recording: a pulsing red mic, the time,
// and "< Slide to cancel", which follows the finger.
class VoiceRecordingBar extends StatefulWidget {
  const VoiceRecordingBar({
    super.key,
    required this.elapsed,
    required this.slide,
    required this.cancelDistance,
  });

  final Duration elapsed;

  // How far the finger has slid toward cancelling.
  final double slide;
  final double cancelDistance;

  @override
  State<VoiceRecordingBar> createState() => _VoiceRecordingBarState();
}

class _VoiceRecordingBarState extends State<VoiceRecordingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final progress = (widget.slide / widget.cancelDistance).clamp(0.0, 1.0);
    return Container(
      height: 46,
      padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.25, end: 1).animate(_pulse),
            child: const Icon(
              Icons.mic_rounded,
              color: Color(0xFFE5484D),
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatVoiceLength(widget.elapsed),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
              color: SynkColors.textPrimary,
            ),
          ),
          Expanded(
            child: Opacity(
              opacity: 1 - progress * 0.8,
              child: Transform.translate(
                offset: Offset(rtl ? widget.slide : -widget.slide, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      rtl
                          ? Icons.chevron_right_rounded
                          : Icons.chevron_left_rounded,
                      size: 20,
                      color: SynkColors.textSecondary,
                    ),
                    Flexible(
                      child: Text(
                        context.l10n.slideToCancel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: SynkColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Floats above the mic while recording: slide up to it to lock, like
// WhatsApp. [progress] (0 to 1) is how far the finger has slid up.
class VoiceLockHint extends StatelessWidget {
  const VoiceLockHint({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final closing = progress > 0.85;
    return IgnorePointer(
      child: Container(
        width: 40,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              closing ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 20,
              color: Color.lerp(
                SynkColors.textSecondary,
                SynkColors.orangeDark,
                progress,
              ),
            ),
            const SizedBox(height: 4),
            Opacity(
              opacity: 1 - progress,
              child: const Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 20,
                color: SynkColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Locked, so the finger can let go: 🗑, the time with a live waveform,
// and ① to make it view once. Send sits beside it, where the mic was.
class LockedRecordingBar extends StatelessWidget {
  const LockedRecordingBar({
    super.key,
    required this.elapsed,
    required this.levels,
    required this.onDelete,
    required this.viewOnceToggle,
  });

  final Duration elapsed;

  // Recent loudness, 0 to 1, oldest first.
  final List<double> levels;
  final VoidCallback onDelete;

  // The ① button, built by the caller so it matches the photo preview.
  final Widget viewOnceToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsetsDirectional.only(start: 2, end: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: context.l10n.deleteLabel,
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFE5484D),
            ),
          ),
          Text(
            formatVoiceLength(elapsed),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
              color: SynkColors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 26),
              painter: _LiveWavePainter(
                levels: levels,
                color: SynkColors.orangeDark,
                rtl: Directionality.of(context) == TextDirection.rtl,
              ),
            ),
          ),
          const SizedBox(width: 8),
          viewOnceToggle,
        ],
      ),
    );
  }
}

// The newest readings at the end of the line, scrolling in as they come.
class _LiveWavePainter extends CustomPainter {
  _LiveWavePainter({
    required this.levels,
    required this.color,
    required this.rtl,
  });

  final List<double> levels;
  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 2.6;
    const gap = 1.8;
    final count = math.max(1, (size.width / (barWidth + gap)).floor());
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth
      ..color = color;
    final shown = levels.length > count
        ? levels.sublist(levels.length - count)
        : levels;
    final offset = count - shown.length;
    for (var i = 0; i < shown.length; i++) {
      final slot = offset + i;
      final height = math.max(3.0, size.height * shown[i]);
      final x = rtl
          ? size.width - (slot * (barWidth + gap) + barWidth / 2)
          : slot * (barWidth + gap) + barWidth / 2;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LiveWavePainter old) => true;
}

// Plays one voice message at a time across the app, at 1x, 1.5x or 2x.
// The speed stays for the next message, like WhatsApp.
class VoicePlayback extends ChangeNotifier {
  VoicePlayback._();

  static final VoicePlayback instance = VoicePlayback._();

  static const speeds = [1.0, 1.5, 2.0];

  AudioPlayer? _player;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  String? _messageId;
  bool _playing = false;
  bool _loading = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  double _speed = 1;

  // Links already fetched, by storage path.
  final Map<String, String> _links = {};

  String? get messageId => _messageId;
  bool get isPlaying => _playing;
  bool get isLoading => _loading;
  Duration get position => _position;
  double get speed => _speed;

  bool isActive(String messageId) => _messageId == messageId;

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _subscriptions
      ..add(
        player.positionStream.listen((p) {
          _position = p;
          notifyListeners();
        }),
      )
      ..add(
        player.durationStream.listen((d) {
          if (d != null) _duration = d;
        }),
      )
      ..add(
        player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            // Back to the start, ready to play again.
            _playing = false;
            _position = Duration.zero;
            unawaited(player.pause());
            unawaited(player.seek(Duration.zero));
          } else {
            _playing = state.playing;
          }
          notifyListeners();
        }),
      );
    _player = player;
    return player;
  }

  // Plays or pauses [message]. Starting a new one stops the last. [from]
  // starts it part way through (0 to 1). [onStarted] runs when it first
  // plays, e.g. to tell the sender it was heard.
  Future<bool> toggle(
    ChatModel model,
    ChatMessage message, {
    double? from,
    VoidCallback? onStarted,
  }) async {
    final player = _ensurePlayer();
    if (_messageId == message.id && from == null) {
      if (_playing) {
        await player.pause();
      } else {
        unawaited(player.play());
      }
      return true;
    }
    if (_messageId == message.id && from != null) {
      await seek(message, from);
      if (!_playing) unawaited(player.play());
      return true;
    }

    await player.stop();
    _messageId = message.id;
    _position = Duration.zero;
    _duration = message.audioDuration;
    _loading = true;
    notifyListeners();
    try {
      final path = message.audioPath!;
      final link = _links[path] ?? await model.voiceLink(path);
      if (link == null || _messageId != message.id) {
        throw StateError('no link');
      }
      _links[path] = link;
      final length = await player.setUrl(link);
      if (length != null) _duration = length;
      await player.setSpeed(_speed);
      if (from != null) await seek(message, from);
      _loading = false;
      notifyListeners();
      unawaited(player.play());
      onStarted?.call();
      return true;
    } catch (error) {
      debugPrint('SYNK: voice message failed to play: $error');
      if (_messageId == message.id) {
        _messageId = null;
        _loading = false;
        notifyListeners();
      }
      return false;
    }
  }

  // Jumps to [fraction] (0 to 1) of the playing message.
  Future<void> seek(ChatMessage message, double fraction) async {
    final player = _player;
    if (player == null || _messageId != message.id) return;
    final total = _duration ?? message.audioDuration ?? Duration.zero;
    final to = total * fraction.clamp(0.0, 1.0);
    _position = to;
    notifyListeners();
    await player.seek(to);
  }

  // 1x -> 1.5x -> 2x -> 1x.
  Future<void> cycleSpeed() async {
    final next = speeds[(speeds.indexOf(_speed) + 1) % speeds.length];
    _speed = next;
    notifyListeners();
    await _player?.setSpeed(next);
  }

  // Leaving the chat stops whatever is playing.
  Future<void> stop() async {
    _messageId = null;
    _playing = false;
    _loading = false;
    _position = Duration.zero;
    notifyListeners();
    await _player?.stop();
  }
}

// What a voice message shows inside its bubble: play/pause, the waveform
// (tap or drag to jump), the time, and either the playback speed (while
// it's the one playing) or a mic that says whether it's been heard.
class VoiceMessageContent extends StatelessWidget {
  const VoiceMessageContent({
    super.key,
    required this.model,
    required this.message,
    required this.isMine,
    required this.heard,
    this.onStarted,
  });

  final ChatModel model;
  final ChatMessage message;
  final bool isMine;

  // Mine: everyone else has listened. Theirs: I have.
  final bool heard;

  // Runs when it starts playing, e.g. to mark it as heard.
  final VoidCallback? onStarted;

  static const double width = 236;

  // WhatsApp's blue for "played".
  static const Color heardBlue = Color(0xFF53BDEB);

  Future<void> _play(BuildContext context, {double? from}) async {
    final ok = await VoicePlayback.instance.toggle(
      model,
      message,
      from: from,
      onStarted: onStarted,
    );
    if (!ok && context.mounted) {
      SynkFeedback.showToast(
        context,
        title: context.l10n.voiceNotAvailable,
        success: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = VoicePlayback.instance;
    final foreground = isMine ? Colors.white : SynkColors.textPrimary;
    final muted = isMine
        ? Colors.white.withValues(alpha: 0.75)
        : SynkColors.textSecondary;

    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final active = playback.isActive(message.id);
        final playing = active && playback.isPlaying;
        final loading = active && playback.isLoading;
        final total = message.audioDuration ?? Duration.zero;
        final position = active ? playback.position : Duration.zero;
        final progress = total.inMilliseconds == 0
            ? 0.0
            : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

        return SizedBox(
          width: width,
          child: Row(
            children: [
              SizedBox.square(
                dimension: 40,
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: foreground,
                        ),
                      )
                    : IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: context.l10n.voiceMessage,
                        onPressed: () => _play(context),
                        icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 34,
                          color: foreground,
                        ),
                      ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    _Waveform(
                      bars: message.audioWaveform,
                      progress: progress,
                      played: isMine
                          ? Colors.white
                          : (heard
                                ? SynkColors.tealText
                                : SynkColors.orangeDark),
                      unplayed: isMine
                          ? Colors.white.withValues(alpha: 0.4)
                          : SynkColors.textSecondary.withValues(alpha: 0.35),
                      onSeek: (fraction) => active
                          ? playback.seek(message, fraction)
                          : _play(context, from: fraction),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatVoiceLength(
                        active && position > Duration.zero ? position : total,
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (active)
                _SpeedChip(
                  speed: playback.speed,
                  isMine: isMine,
                  onTap: playback.cycleSpeed,
                )
              else
                Icon(
                  Icons.mic_rounded,
                  size: 22,
                  color: isMine
                      ? (heard
                            ? heardBlue
                            : Colors.white.withValues(alpha: 0.6))
                      : (heard
                            ? SynkColors.textSecondary
                            : SynkColors.orangeDark),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.speed,
    required this.isMine,
    required this.onTap,
  });

  final double speed;
  final bool isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = speed == speed.roundToDouble()
        ? '${speed.toInt()}×'
        : '$speed×';
    return Material(
      color: isMine
          ? Colors.white.withValues(alpha: 0.25)
          : SynkColors.textSecondary.withValues(alpha: 0.14),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 26,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: isMine ? Colors.white : SynkColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// Bars as tall as the recording was loud; the part already played is
// coloured. Tap or drag to jump.
class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.bars,
    required this.progress,
    required this.played,
    required this.unplayed,
    required this.onSeek,
  });

  final List<int> bars;
  final double progress;
  final Color played;
  final Color unplayed;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double fractionAt(Offset local) {
          final x = (local.dx / width).clamp(0.0, 1.0);
          return rtl ? 1 - x : x;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => onSeek(fractionAt(d.localPosition)),
          onHorizontalDragUpdate: (d) => onSeek(fractionAt(d.localPosition)),
          child: CustomPaint(
            size: Size(width, 26),
            painter: _WaveformPainter(
              bars: bars.isEmpty
                  ? List.filled(VoiceRecorder.waveformBars, 8)
                  : bars,
              progress: progress,
              played: played,
              unplayed: unplayed,
              rtl: rtl,
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.played,
    required this.unplayed,
    required this.rtl,
  });

  final List<int> bars;
  final double progress;
  final Color played;
  final Color unplayed;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    // As many bars as fit, sampled from the stored ones.
    const barWidth = 2.6;
    const gap = 1.8;
    final count = math.max(1, (size.width / (barWidth + gap)).floor());
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    for (var i = 0; i < count; i++) {
      final value = bars[(i * bars.length / count).floor()];
      final height = math.max(3.0, size.height * value / 100);
      final along = (i + 0.5) / count;
      final x = rtl
          ? size.width - (i * (barWidth + gap) + barWidth / 2)
          : i * (barWidth + gap) + barWidth / 2;
      paint.color = along <= progress ? played : unplayed;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
    // The playhead.
    if (progress > 0) {
      final x = rtl ? size.width * (1 - progress) : size.width * progress;
      canvas.drawCircle(Offset(x, size.height / 2), 5, Paint()..color = played);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.bars != bars ||
      old.played != played ||
      old.unplayed != unplayed ||
      old.rtl != rtl;
}
