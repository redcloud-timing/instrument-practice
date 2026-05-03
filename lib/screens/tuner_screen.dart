import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/tuner_controller.dart';
import '../models/tuner_reading.dart';
import '../services/tuner_service.dart';

const _noteNames = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];

const _minMidi = 60.0;
const _maxMidi = 84.0;
const _visibleDurationMs = 8000.0;
const _globalMinMidi = 36.0;
const _globalMaxMidi = 108.0;
const _noteMargin = 38.0;

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});
  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  double _scrollOffsetMs = 0;
  double _verticalOffsetSemitones = 0;
  bool _autoFollow = true;
  int? _recordingStartMs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TunerController>().loadRecordings();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TunerController>();
    final reading = controller.reading;
    final colorScheme = Theme.of(context).colorScheme;

    final hasLoadedRecording = controller.loadedRecordingHistory.isNotEmpty;
    final displayHistory = hasLoadedRecording
        ? controller.loadedRecordingHistory
        : controller.history;
    final history = displayHistory;

    final hasActivePitch =
        (controller.isRunning && (reading?.hasPitch ?? false)) ||
        (hasLoadedRecording && history.isNotEmpty);

    int? latestTs;
    if (history.isNotEmpty) {
      latestTs = history.last.timestampMillis;
    } else if (reading != null && reading.hasPitch) {
      latestTs = reading.timestampMillis;
    }

    if (controller.isRunning) {
      _recordingStartMs ??= DateTime.now().millisecondsSinceEpoch;
    } else if (!hasLoadedRecording) {
      _recordingStartMs = null;
    }

    if (!controller.isPaused &&
        !controller.isRecordingPaused &&
        (_autoFollow || controller.isPlaying)) {
      _scrollOffsetMs = 0;
    }

    int? playbackCursorTs;
    if (controller.isPlaying && hasLoadedRecording && history.isNotEmpty) {
      playbackCursorTs =
          history.first.timestampMillis + controller.playbackPositionMs;
    }

    final baseCursorMs = playbackCursorTs ?? latestTs;
    final cursorTs = baseCursorMs != null
        ? baseCursorMs - _scrollOffsetMs.toInt()
        : null;

    int? recordingStartForAxis = _recordingStartMs;
    if (hasLoadedRecording && history.isNotEmpty) {
      recordingStartForAxis = history.first.timestampMillis;
    }

    final hasLatestRecording = controller.latestRecordingPath != null;
    final recordings = controller.recordings;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _TopBar(
            noteLabel: hasActivePitch
                ? (reading?.hasPitch ?? false ? reading!.noteLabel : '--')
                : '--',
            cents: (reading?.hasPitch ?? false) ? reading!.cents : 0,
            frequency: (reading?.hasPitch ?? false) ? reading!.frequency : 0,
            hasPitch: hasActivePitch,
            isRunning: controller.isRunning,
            hasLoadedRecording: hasLoadedRecording,
            recordingDuration: hasLoadedRecording && history.isNotEmpty
                ? _formatDuration(
                    ((history.last.timestampMillis -
                                history.first.timestampMillis) /
                            1000)
                        .round(),
                  )
                : null,
            onSettingsTap: () => _openSettings(context),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: const Color(0xFFF8F8F8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final canvasH = constraints.maxHeight;
                      final canvasW = constraints.maxWidth;
                      final pixelsPerMs =
                          (canvasW - _noteMargin) / _visibleDurationMs;
                      final semitonesPerPixel = (_maxMidi - _minMidi) / canvasH;
                      final historyNotEmpty = history.isNotEmpty;

                      return Stack(
                        children: [
                          GestureDetector(
                            onPanUpdate: (details) {
                              if (!historyNotEmpty ||
                                  (controller.isPlaying &&
                                      !controller.isPaused) ||
                                  (controller.isRunning &&
                                      !controller.isRecordingPaused)) {
                                return;
                              }
                              setState(() {
                                _autoFollow = false;
                                _scrollOffsetMs -=
                                    details.delta.dx / pixelsPerMs;
                                final isFrozen =
                                    controller.isPaused ||
                                    controller.isRecordingPaused;
                                _scrollOffsetMs = _scrollOffsetMs.clamp(
                                  _minScrollMs(history, baseCursorMs, isFrozen),
                                  _maxScrollMs(history, baseCursorMs, isFrozen),
                                );
                                _verticalOffsetSemitones +=
                                    details.delta.dy * semitonesPerPixel;
                                _verticalOffsetSemitones =
                                    _verticalOffsetSemitones.clamp(
                                      _globalMinMidi - _minMidi,
                                      _globalMaxMidi - _maxMidi,
                                    );
                              });
                            },
                            onPanEnd: (details) {
                              if (_scrollOffsetMs < 1) {
                                setState(() {
                                  _scrollOffsetMs = 0;
                                  _autoFollow = true;
                                });
                              }
                            },
                            child: CustomPaint(
                              painter: _PitchCanvasPainter(
                                history: history,
                                cursorTimestamp: cursorTs,
                                visibleDurationMs: _visibleDurationMs.toInt(),
                                verticalOffsetSemitones:
                                    _verticalOffsetSemitones,
                                isRunning: controller.isRunning,
                                scale: controller.scale,
                                centerMidi: controller.centerMidi,
                                hasLoadedRecording: hasLoadedRecording,
                                isPlaying: controller.isPlaying,
                                playbackPositionMs:
                                    controller.playbackPositionMs,
                                recordingFirstMs: history.isNotEmpty
                                    ? history.first.timestampMillis
                                    : null,
                              ),
                              size: Size.infinite,
                            ),
                          ),
                          if (!_autoFollow &&
                              historyNotEmpty &&
                              !controller.isPlaying)
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: _FloatingButton(
                                icon: Icons.skip_next,
                                label: '最新',
                                onTap: () {
                                  setState(() {
                                    _scrollOffsetMs = 0;
                                    _autoFollow = true;
                                  });
                                },
                              ),
                            ),
                          if (_verticalOffsetSemitones.abs() > 0.5)
                            Positioned(
                              right: 12,
                              top: 12,
                              child: _FloatingButton(
                                icon: Icons.vertical_align_center,
                                label: '居中',
                                onTap: () {
                                  setState(() {
                                    _verticalOffsetSemitones = 0;
                                  });
                                },
                              ),
                            ),
                          if (hasLoadedRecording && history.isEmpty)
                            const Center(
                              child: Text(
                                '该录音没有音高数据',
                                style: TextStyle(
                                  color: Color(0xFF999999),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          if (controller.isPlaying &&
                              hasLoadedRecording &&
                              history.isNotEmpty)
                            IgnorePointer(
                              ignoring: controller.isPaused,
                              child: _PlaybackPositionLine(
                                playbackPositionMs:
                                    controller.playbackPositionMs,
                                recordingFirstMs: history.first.timestampMillis,
                                cursorTimestamp: cursorTs!,
                                visibleDurationMs: _visibleDurationMs.toInt(),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          _TimeAxis(
            cursorTimestamp: cursorTs,
            visibleDurationMs: _visibleDurationMs.toInt(),
            scrollOffsetMs: _scrollOffsetMs,
            autoFollow: _autoFollow,
            historyNotEmpty: history.isNotEmpty,
            recordingStartMs: recordingStartForAxis,
          ),
          if (controller.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Text(
                controller.errorMessage!,
                style: TextStyle(color: colorScheme.error, fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildRecordingArea(
                    controller,
                    hasLatestRecording,
                    hasLoadedRecording,
                    recordings,
                  ),
                ),
                if (!controller.isRunning) const SizedBox(width: 12),
                if (controller.isRunning) ...[
                  _PauseRecordButton(
                    isPaused: controller.isRecordingPaused,
                    onTap: () {
                      final ctrl = context.read<TunerController>();
                      if (controller.isRecordingPaused) {
                        ctrl.resumeRecording();
                        setState(() {
                          _scrollOffsetMs = 0;
                          _autoFollow = true;
                        });
                      } else {
                        ctrl.pauseRecording();
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                ],
                _MicButton(
                  isRunning: controller.isRunning,
                  isBusy: controller.isBusy,
                  onTap: () => context.read<TunerController>().toggle(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingArea(
    TunerController controller,
    bool hasLatestRecording,
    bool hasLoadedRecording,
    List<TunerRecording> recordings,
  ) {
    if (controller.isPlaying && !controller.isRunning) {
      final totalMs =
          hasLoadedRecording && controller.loadedRecordingHistory.isNotEmpty
          ? controller.loadedRecordingHistory.last.timestampMillis -
                controller.loadedRecordingHistory.first.timestampMillis
          : 0;
      return _RecordingPlaybackBar(
        name: controller.playingName ?? '录音',
        isPaused: controller.isPaused,
        positionMs: controller.playbackPositionMs,
        totalMs: totalMs,
        hasPitchData: hasLoadedRecording,
        onPause: () => controller.pausePlayingRecording(),
        onResume: () => controller.resumePlayingRecording(),
        onStop: () => controller.stopPlayback(),
        onSeek: (v) => controller.seekPlayback(v.round()),
      );
    }

    if (!controller.isRunning && hasLatestRecording && !controller.isPlaying) {
      return _LatestRecordingChip(
        name: controller.latestRecordingPath?.split('/').last ?? '录音',
        isPlaying: controller.isPlaying,
        playingPath: controller.playingPath,
        latestPath: controller.latestRecordingPath ?? '',
        onPlay: () => controller.playRecording(controller.latestRecordingPath!),
        onStop: () => controller.stopPlayback(),
        onViewAll: recordings.isNotEmpty
            ? () => _showRecordingsList(context)
            : null,
      );
    }

    if (!controller.isRunning && recordings.isNotEmpty && !hasLatestRecording) {
      return OutlinedButton.icon(
        onPressed: () => _showRecordingsList(context),
        icon: const Icon(Icons.library_music_outlined, size: 16),
        label: const Text('录音记录', style: TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  double _maxScrollMs(
    List<TunerReading> history,
    int? baseCursorMs,
    bool isPaused,
  ) {
    if (history.length < 2) return 0;
    if (isPaused && baseCursorMs != null) {
      return (baseCursorMs - history.first.timestampMillis).toDouble();
    }
    return (history.last.timestampMillis -
            history.first.timestampMillis -
            _visibleDurationMs)
        .toDouble()
        .clamp(0, double.infinity);
  }

  double _minScrollMs(
    List<TunerReading> history,
    int? baseCursorMs,
    bool isPaused,
  ) {
    if (isPaused && baseCursorMs != null && history.isNotEmpty) {
      return (baseCursorMs - history.last.timestampMillis).toDouble();
    }
    return 0.0;
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0) return '$mins 分 $secs 秒';
    return '$secs 秒';
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _TunerSettingsScreen()),
    );
  }

  void _showRecordingsList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => const _RecordingsListSheet(),
    );
  }
}

class _PlaybackPositionLine extends StatelessWidget {
  const _PlaybackPositionLine({
    required this.playbackPositionMs,
    required this.recordingFirstMs,
    required this.cursorTimestamp,
    required this.visibleDurationMs,
  });

  final int playbackPositionMs;
  final int recordingFirstMs;
  final int cursorTimestamp;
  final int visibleDurationMs;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PlaybackPositionPainter(
        playbackPositionMs: playbackPositionMs,
        recordingFirstMs: recordingFirstMs,
        cursorTimestamp: cursorTimestamp,
        visibleDurationMs: visibleDurationMs,
      ),
      size: Size.infinite,
    );
  }
}

class _PlaybackPositionPainter extends CustomPainter {
  const _PlaybackPositionPainter({
    required this.playbackPositionMs,
    required this.recordingFirstMs,
    required this.cursorTimestamp,
    required this.visibleDurationMs,
  });

  final int playbackPositionMs;
  final int recordingFirstMs;
  final int cursorTimestamp;
  final int visibleDurationMs;

  @override
  void paint(Canvas canvas, Size size) {
    final noteMargin = _noteMargin;
    final plotWidth = size.width - noteMargin;
    final playbackTs = recordingFirstMs + playbackPositionMs;
    final age = (cursorTimestamp - playbackTs) / visibleDurationMs;
    final x = noteMargin + plotWidth * (1 - age);

    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = const Color(0xFFFF5722)
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant _PlaybackPositionPainter oldDelegate) {
    return oldDelegate.playbackPositionMs != playbackPositionMs;
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.isRunning,
    required this.isBusy,
    required this.onTap,
  });

  final bool isRunning;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Material(
        color: isRunning ? const Color(0xFFE53935) : const Color(0xFF4CAF50),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          onTap: isBusy ? null : onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: isBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isRunning ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 26,
                  ),
          ),
        ),
      ),
    );
  }
}

class _PauseRecordButton extends StatelessWidget {
  const _PauseRecordButton({required this.isPaused, required this.onTap});

  final bool isPaused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: isPaused ? const Color(0xFF4CAF50) : const Color(0xFFFFC107),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              isPaused ? Icons.play_arrow : Icons.pause,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingPlaybackBar extends StatelessWidget {
  const _RecordingPlaybackBar({
    required this.name,
    required this.isPaused,
    required this.positionMs,
    required this.totalMs,
    required this.hasPitchData,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onSeek,
  });

  final String name;
  final bool isPaused;
  final int positionMs;
  final int totalMs;
  final bool hasPitchData;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final posSec = positionMs ~/ 1000;
    final totalSec = totalMs ~/ 1000;
    final posStr =
        '${posSec ~/ 60}:${(posSec % 60).toString().padLeft(2, '0')}';
    final totalStr = hasPitchData
        ? '${totalSec ~/ 60}:${(totalSec % 60).toString().padLeft(2, '0')}'
        : '--:--';
    final sliderMax = totalMs > 0 ? totalMs.toDouble() : 1.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: isPaused ? onResume : onPause,
                  icon: Icon(
                    isPaused ? Icons.play_arrow : Icons.pause,
                    size: 22,
                    color: const Color(0xFF4CAF50),
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$posStr / $totalStr',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF999999),
                  ),
                ),
                IconButton(
                  onPressed: onStop,
                  icon: const Icon(
                    Icons.stop,
                    size: 20,
                    color: Color(0xFFE57373),
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: const SliderThemeData(
                trackHeight: 3,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Color(0xFF4CAF50),
                inactiveTrackColor: Color(0xFFDDDDDD),
                thumbColor: Color(0xFF4CAF50),
                overlayColor: Color(0x334CAF50),
              ),
              child: Slider(
                value: positionMs.toDouble().clamp(0.0, sliderMax),
                max: sliderMax,
                onChanged: onSeek,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestRecordingChip extends StatelessWidget {
  const _LatestRecordingChip({
    required this.name,
    required this.isPlaying,
    required this.playingPath,
    required this.latestPath,
    required this.onPlay,
    required this.onStop,
    required this.onViewAll,
  });

  final String name;
  final bool isPlaying;
  final String? playingPath;
  final String latestPath;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final isCurrentPlaying = isPlaying && playingPath == latestPath;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.mic, size: 18, color: Color(0xFFE57373)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: isCurrentPlaying ? onStop : onPlay,
              icon: Icon(
                isCurrentPlaying ? Icons.stop : Icons.play_arrow,
                size: 20,
              ),
              style: IconButton.styleFrom(
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
              ),
            ),
            if (onViewAll != null)
              IconButton(
                onPressed: onViewAll,
                icon: const Icon(Icons.list, size: 20),
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimeAxis extends StatelessWidget {
  const _TimeAxis({
    required this.cursorTimestamp,
    required this.visibleDurationMs,
    required this.scrollOffsetMs,
    required this.autoFollow,
    required this.historyNotEmpty,
    required this.recordingStartMs,
  });

  final int? cursorTimestamp;
  final int visibleDurationMs;
  final double scrollOffsetMs;
  final bool autoFollow;
  final bool historyNotEmpty;
  final int? recordingStartMs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CustomPaint(
          painter: _TimeAxisPainter(
            cursorTimestamp: cursorTimestamp,
            visibleDurationMs: visibleDurationMs,
            scrollOffsetMs: scrollOffsetMs,
            recordingStartMs: recordingStartMs,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _TimeAxisPainter extends CustomPainter {
  const _TimeAxisPainter({
    required this.cursorTimestamp,
    required this.visibleDurationMs,
    required this.scrollOffsetMs,
    required this.recordingStartMs,
  });

  final int? cursorTimestamp;
  final int visibleDurationMs;
  final double scrollOffsetMs;
  final int? recordingStartMs;

  @override
  void paint(Canvas canvas, Size size) {
    final cursor = cursorTimestamp;
    if (cursor == null) return;

    final w = size.width;
    final h = size.height;
    final noteMargin = _noteMargin;
    final plotWidth = w - noteMargin;
    final recStart = recordingStartMs;
    final leftEdge = cursor - visibleDurationMs;

    canvas.drawLine(
      Offset(noteMargin, 0),
      Offset(w, h - 1),
      Paint()
        ..color = const Color(0xFFDDDDDD)
        ..strokeWidth = 0.5,
    );

    final majorIntervalMs = 1000;
    final minorCount = 3;
    final minorStep = majorIntervalMs ~/ (minorCount + 1);

    int firstTickMs;
    if (recStart != null) {
      final relLeft = leftEdge - recStart;
      final firstRelTick = (relLeft / majorIntervalMs).ceil() * majorIntervalMs;
      firstTickMs = recStart + firstRelTick;
    } else {
      firstTickMs = (leftEdge / majorIntervalMs).ceil() * majorIntervalMs;
    }

    var t = firstTickMs;
    while (t <= cursor) {
      final age = (cursor - t) / visibleDurationMs;
      final x = noteMargin + plotWidth * (1 - age);

      if (recStart != null) {
        final elapsedSec = (t - recStart) ~/ 1000;
        if (elapsedSec > 0) {
          final tp = TextPainter(
            text: TextSpan(
              text: '${elapsedSec}s',
              style: const TextStyle(color: Color(0xFF999999), fontSize: 10),
            ),
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          tp.paint(canvas, Offset(x - tp.width / 2, h - tp.height - 2));

          canvas.drawLine(
            Offset(x, 0),
            Offset(x, 8),
            Paint()
              ..color = const Color(0xFFBBBBBB)
              ..strokeWidth = 1.0,
          );

          for (var minor = 1; minor <= minorCount; minor++) {
            final minorT = t + minor * minorStep;
            if (minorT > cursor) break;
            final minorAge = (cursor - minorT) / visibleDurationMs;
            final minorX = noteMargin + plotWidth * (1 - minorAge);
            canvas.drawLine(
              Offset(minorX, 0),
              Offset(minorX, 3),
              Paint()
                ..color = const Color(0xFFDDDDDD)
                ..strokeWidth = 0.5,
            );
          }
        }
      }

      t += majorIntervalMs;
    }

    if (recStart != null && recStart >= leftEdge && recStart <= cursor) {
      final zeroAge = (cursor - recStart) / visibleDurationMs;
      final zeroX = noteMargin + plotWidth * (1 - zeroAge);
      canvas.drawLine(
        Offset(zeroX, 0),
        Offset(zeroX, h),
        Paint()
          ..color = const Color(0xFFE57373)
          ..strokeWidth = 1.5,
      );
      final tp = TextPainter(
        text: const TextSpan(
          text: '0s',
          style: TextStyle(
            color: Color(0xFFE57373),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(zeroX - tp.width / 2, h - tp.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant _TimeAxisPainter oldDelegate) {
    return oldDelegate.cursorTimestamp != cursorTimestamp ||
        oldDelegate.visibleDurationMs != visibleDurationMs ||
        oldDelegate.scrollOffsetMs != scrollOffsetMs ||
        oldDelegate.recordingStartMs != recordingStartMs;
  }
}

class _RecordingsListSheet extends StatefulWidget {
  const _RecordingsListSheet();
  @override
  State<_RecordingsListSheet> createState() => _RecordingsListSheetState();
}

class _RecordingsListSheetState extends State<_RecordingsListSheet> {
  @override
  void initState() {
    super.initState();
    context.read<TunerController>().loadRecordings();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TunerController>();
    final recordings = controller.recordings;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        if (recordings.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.mic_off, size: 40, color: Color(0xFFBBBBBB)),
                SizedBox(height: 12),
                Text('暂无录音', style: TextStyle(color: Color(0xFF999999))),
              ],
            ),
          );
        }

        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: recordings.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final rec = recordings[index];
            final isPlaying =
                controller.isPlaying && controller.playingPath == rec.path;
            final date = DateTime.fromMillisecondsSinceEpoch(rec.lastModified);
            final dateStr =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-'
                '${date.day.toString().padLeft(2, '0')} '
                '${date.hour.toString().padLeft(2, '0')}:'
                '${date.minute.toString().padLeft(2, '0')}';
            final durStr = _fmtDuration(rec.durationSeconds);

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isPlaying ? Icons.volume_up : Icons.mic,
                color: isPlaying
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFFE57373),
                size: 22,
              ),
              title: Text(
                dateStr,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: Text(
                durStr,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      if (isPlaying) {
                        controller.stopPlayback();
                      } else {
                        controller.playRecording(rec.path);
                      }
                    },
                    icon: Icon(
                      isPlaying ? Icons.stop : Icons.play_arrow,
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  IconButton(
                    onPressed: () => controller.deleteRecording(rec.path),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '$m 分 $s 秒' : '$s 秒';
  }
}

class _FloatingButton extends StatelessWidget {
  const _FloatingButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.noteLabel,
    required this.cents,
    required this.frequency,
    required this.hasPitch,
    required this.isRunning,
    required this.hasLoadedRecording,
    required this.recordingDuration,
    required this.onSettingsTap,
  });
  final String noteLabel;
  final int cents;
  final double frequency;
  final bool hasPitch;
  final bool isRunning;
  final bool hasLoadedRecording;
  final String? recordingDuration;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final centsText = hasPitch
        ? '${cents > 0 ? '+' : ''}$cents \u{00A2}'
        : '--';
    final freqText = hasPitch ? '${frequency.toStringAsFixed(1)} Hz' : '--';

    final statusColor = !isRunning && !hasLoadedRecording
        ? colorScheme.outline
        : !hasPitch
        ? Colors.grey
        : cents.abs() <= 5
        ? const Color(0xFF4CAF50)
        : cents.abs() <= 15
        ? const Color(0xFFFFC107)
        : const Color(0xFFFF7043);

    final controller = context.watch<TunerController>();
    String subtitle;
    if (isRunning && controller.isRecordingPaused) {
      subtitle = '录音已暂停';
    } else if (isRunning) {
      subtitle = hasPitch ? freqText : '等待声音输入...';
    } else if (hasLoadedRecording) {
      subtitle = recordingDuration != null
          ? '录音时长: $recordingDuration'
          : '查看录音音高数据';
    } else {
      subtitle = '点击下方按钮开始调音';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      noteLabel,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                    ),
                    const SizedBox(width: 8),
                    if (hasPitch)
                      Text(
                        centsText,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSettingsTap,
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: '调音器设置',
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _PitchCanvasPainter extends CustomPainter {
  _PitchCanvasPainter({
    required this.history,
    required this.cursorTimestamp,
    required this.visibleDurationMs,
    required this.verticalOffsetSemitones,
    required this.isRunning,
    required this.scale,
    required this.centerMidi,
    required this.hasLoadedRecording,
    required this.isPlaying,
    required this.playbackPositionMs,
    required this.recordingFirstMs,
  });

  final List<TunerReading> history;
  final int? cursorTimestamp;
  final int visibleDurationMs;
  final double verticalOffsetSemitones;
  final bool isRunning;
  final MusicalScale scale;
  final int centerMidi;
  final bool hasLoadedRecording;
  final bool isPlaying;
  final int playbackPositionMs;
  final int? recordingFirstMs;

  double get _effMinMidi => _minMidi + verticalOffsetSemitones;
  double get _effMaxMidi => _maxMidi + verticalOffsetSemitones;
  double get _effSemitones => _effMaxMidi - _effMinMidi;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _drawBackground(canvas, w, h);

    if (history.isEmpty) {
      _drawEmptyMessage(canvas, w, h);
      return;
    }
    final cursor = cursorTimestamp;
    if (cursor == null) {
      _drawEmptyMessage(canvas, w, h);
      return;
    }

    _drawGrid(canvas, w, h);
    _drawPitchDots(canvas, w, h, cursor);
    _drawScaleLabel(canvas, w);
  }

  void _drawBackground(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = hasLoadedRecording
            ? const Color(0xFFF0F4FF)
            : const Color(0xFFF8F8F8),
    );
  }

  void _drawEmptyMessage(Canvas canvas, double w, double h) {
    _drawGrid(canvas, w, h);
    final tp = TextPainter(
      text: TextSpan(
        text: isRunning
            ? '等待声音输入...'
            : hasLoadedRecording
            ? '该录音没有音高数据'
            : '点击下方按钮开始调音',
        style: const TextStyle(color: Color(0xFF999999), fontSize: 15),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(w / 2 - tp.width / 2, h / 2 - tp.height / 2));
  }

  void _drawGrid(Canvas canvas, double w, double h) {
    final noteMargin = _noteMargin;
    final noteHeight = h / _effSemitones;
    final firstVisibleMidi = _effMinMidi.ceil();
    final lastVisibleMidi = _effMaxMidi.floor();
    final scaleNotes = scale.noteIndices();
    final rootIdx = _noteNames.indexOf(scale.root);

    for (var midi = firstVisibleMidi; midi <= lastVisibleMidi; midi++) {
      final y = h - (midi - _effMinMidi + 0.5) * noteHeight;
      if (y < -20 || y > h + 20) continue;
      final isRoot = midi % 12 == rootIdx;
      final inScale = scaleNotes.contains(midi % 12);

      Color lineColor;
      double strokeWidth;
      if (isRoot) {
        lineColor = const Color(0xFFCCCCCC);
        strokeWidth = 1.0;
      } else if (inScale) {
        lineColor = const Color(0xFFDDDDDD);
        strokeWidth = 0.5;
      } else {
        lineColor = const Color(0xFFEEEEEE);
        strokeWidth = 0.3;
      }

      canvas.drawLine(
        Offset(0, y),
        Offset(w, y),
        Paint()
          ..color = lineColor
          ..strokeWidth = strokeWidth,
      );
    }

    for (var midi = firstVisibleMidi; midi <= lastVisibleMidi; midi++) {
      final y = h - (midi - _effMinMidi + 0.5) * noteHeight;
      if (y < -20 || y > h + 20) continue;
      final name = '${_noteNames[midi % 12]}${midi ~/ 12 - 1}';
      final isRoot = midi % 12 == rootIdx;
      final inScale = scaleNotes.contains(midi % 12);

      final tp = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            color: isRoot
                ? const Color(0xFF666666)
                : inScale
                ? const Color(0xFF444444)
                : const Color(0xFFCCCCCC),
            fontSize: isRoot ? 11 : (inScale ? 10 : 9),
            fontWeight: isRoot
                ? FontWeight.w700
                : inScale
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: noteMargin - 4);
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }

    canvas.drawLine(
      Offset(noteMargin, 0),
      Offset(noteMargin, h),
      Paint()
        ..color = const Color(0xFFDDDDDD)
        ..strokeWidth = 0.5,
    );
  }

  void _drawScaleLabel(Canvas canvas, double w) {
    final tp = TextPainter(
      text: TextSpan(
        text: scale.label,
        style: const TextStyle(
          color: Color(0x66000000),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(w - tp.width - 6, 4));
  }

  void _drawPitchDots(Canvas canvas, double w, double h, int cursor) {
    final noteMargin = _noteMargin;
    final plotWidth = w - noteMargin;
    final leftEdge = cursor - visibleDurationMs;

    for (final reading in history) {
      if (!reading.hasPitch) continue;
      if (reading.timestampMillis < leftEdge) continue;
      if (reading.timestampMillis > cursor) continue;

      final age = (cursor - reading.timestampMillis) / visibleDurationMs;
      final x = noteMargin + plotWidth * (1 - age);
      final midi = 69 + 12 * math.log(reading.frequency / 440) / math.ln2;
      final normalized =
          (midi - _effMinMidi).clamp(0.0, _effSemitones) / _effSemitones;
      final y = h - normalized * h;

      final dotColor = _dotColor(
        reading.cents.abs().toDouble(),
        reading.clarity,
      );
      canvas.drawCircle(Offset(x, y), 2.5, Paint()..color = dotColor);
    }
  }

  Color _dotColor(double absCents, double clarity) {
    if (clarity < 0.3) return const Color(0xFFCCCCCC);
    if (absCents <= 5) return const Color(0xFF4CAF50);
    if (absCents <= 15) return const Color(0xFFFFC107);
    if (absCents <= 25) return const Color(0xFFFF9800);
    return const Color(0xFFFF5252);
  }

  @override
  bool shouldRepaint(covariant _PitchCanvasPainter oldDelegate) {
    return oldDelegate.history != history ||
        oldDelegate.cursorTimestamp != cursorTimestamp ||
        oldDelegate.isRunning != isRunning ||
        oldDelegate.visibleDurationMs != visibleDurationMs ||
        oldDelegate.verticalOffsetSemitones != verticalOffsetSemitones ||
        oldDelegate.scale != scale ||
        oldDelegate.centerMidi != centerMidi ||
        oldDelegate.hasLoadedRecording != hasLoadedRecording ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.playbackPositionMs != playbackPositionMs;
  }
}

class _TunerSettingsScreen extends StatefulWidget {
  const _TunerSettingsScreen();
  @override
  State<_TunerSettingsScreen> createState() => _TunerSettingsScreenState();
}

class _TunerSettingsScreenState extends State<_TunerSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TunerController>();
    final allScales = MusicalScale.allScales();

    final centerNoteOptions = <int, String>{};
    for (var midi = 60; midi <= 84; midi += 1) {
      final noteName = _noteNames[midi % 12];
      final octave = midi ~/ 12 - 1;
      centerNoteOptions[midi] = '$noteName$octave';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('调音器设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '音阶选择',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '选择调音时左侧音高显示的基准音阶',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          _buildScaleSelector(controller, allScales),
          const SizedBox(height: 28),
          const Text(
            '居中音名',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '选择音高显示区域中心位置的音名',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          _buildCenterSelector(controller, centerNoteOptions),
        ],
      ),
    );
  }

  Widget _buildScaleSelector(
    TunerController controller,
    List<MusicalScale> allScales,
  ) {
    final currentLabel = controller.scale.label;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDDDDD)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.music_note,
                  size: 16,
                  color: Color(0xFF666666),
                ),
                const SizedBox(width: 6),
                Text(
                  '当前: $currentLabel',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 200,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: allScales.length,
              itemBuilder: (context, index) {
                final scale = allScales[index];
                final isSelected = scale.label == controller.scale.label;
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    scale.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => controller.setScale(scale),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterSelector(
    TunerController controller,
    Map<int, String> options,
  ) {
    final currentMidi = controller.centerMidi;
    final entries = options.entries.toList();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDDDDD)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.center_focus_strong,
                  size: 16,
                  color: Color(0xFF666666),
                ),
                const SizedBox(width: 6),
                Text(
                  '当前: ${options[currentMidi] ?? 'C5'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 200,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isSelected = entry.key == controller.centerMidi;
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => controller.setCenterMidi(entry.key),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
