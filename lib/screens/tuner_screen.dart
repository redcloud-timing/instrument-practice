import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/tuner_controller.dart';
import '../models/tuner_reading.dart';
import '../models/tuner_recording.dart';
import 'tuner/pitch_canvas.dart';
import 'tuner/recordings_sheet.dart';
import 'tuner/tuner_settings_screen.dart';

class TunerCanvasColors {
  const TunerCanvasColors({
    required this.canvasBg,
    required this.loadedCanvasBg,
    required this.gridRoot,
    required this.gridInScale,
    required this.gridOther,
    required this.labelRoot,
    required this.labelInScale,
    required this.labelOther,
    required this.separator,
    required this.emptyText,
    required this.scaleLabel,
    required this.tickLabel,
    required this.majorTick,
    required this.minorTick,
    required this.recordingMarker,
    required this.dotUnclear,
    required this.dotInTune,
    required this.dotSlightlyOff,
    required this.dotOff,
    required this.dotVeryOff,
    required this.playbackCursor,
    required this.statusInTune,
    required this.statusSlightlyOff,
    required this.statusOff,
    required this.recordingIcon,
  });

  final Color canvasBg;
  final Color loadedCanvasBg;
  final Color gridRoot;
  final Color gridInScale;
  final Color gridOther;
  final Color labelRoot;
  final Color labelInScale;
  final Color labelOther;
  final Color separator;
  final Color emptyText;
  final Color scaleLabel;
  final Color tickLabel;
  final Color majorTick;
  final Color minorTick;
  final Color recordingMarker;
  final Color dotUnclear;
  final Color dotInTune;
  final Color dotSlightlyOff;
  final Color dotOff;
  final Color dotVeryOff;
  final Color playbackCursor;
  final Color statusInTune;
  final Color statusSlightlyOff;
  final Color statusOff;
  final Color recordingIcon;

  factory TunerCanvasColors.fromColorScheme(ColorScheme cs) {
    return TunerCanvasColors(
      canvasBg: cs.surface,
      loadedCanvasBg: cs.surfaceContainerLow,
      gridRoot: cs.outlineVariant,
      gridInScale: cs.outlineVariant.withValues(alpha: 0.7),
      gridOther: cs.outlineVariant.withValues(alpha: 0.4),
      labelRoot: cs.onSurfaceVariant,
      labelInScale: cs.onSurface,
      labelOther: cs.outlineVariant,
      separator: cs.outlineVariant.withValues(alpha: 0.5),
      emptyText: cs.outline,
      scaleLabel: cs.onSurface.withValues(alpha: 0.4),
      tickLabel: cs.outline,
      majorTick: cs.outlineVariant,
      minorTick: cs.outlineVariant.withValues(alpha: 0.5),
      recordingMarker: cs.error.withValues(alpha: 0.7),
      dotUnclear: cs.outlineVariant,
      dotInTune: cs.primary,
      dotSlightlyOff: Colors.amber,
      dotOff: Colors.orange,
      dotVeryOff: cs.error,
      playbackCursor: Colors.deepOrangeAccent,
      statusInTune: cs.primary,
      statusSlightlyOff: Colors.amber,
      statusOff: Colors.deepOrange,
      recordingIcon: cs.error.withValues(alpha: 0.7),
    );
  }
}

const _visibleDurationMs = 8000.0;
const _globalMinMidi = 36.0;
const _globalMaxMidi = 108.0;
const _noteMargin = 38.0;
const _minMidi = 60.0;
const _maxMidi = 84.0;

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
    final canvasColors = TunerCanvasColors.fromColorScheme(colorScheme);

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
                  color: colorScheme.surface,
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
                              painter: PitchCanvasPainter(
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
                                colors: canvasColors,
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
                            Center(
                              child: Text(
                                '该录音没有音高数据',
                                style: TextStyle(
                                  color: colorScheme.outline,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          if (controller.isPlaying &&
                              hasLoadedRecording &&
                              history.isNotEmpty)
                            IgnorePointer(
                              ignoring: controller.isPaused,
                              child: PlaybackPositionLine(
                                playbackPositionMs:
                                    controller.playbackPositionMs,
                                recordingFirstMs: history.first.timestampMillis,
                                cursorTimestamp: cursorTs!,
                                visibleDurationMs: _visibleDurationMs.toInt(),
                                colors: canvasColors,
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
          TimeAxis(
            cursorTimestamp: cursorTs,
            visibleDurationMs: _visibleDurationMs.toInt(),
            scrollOffsetMs: _scrollOffsetMs,
            autoFollow: _autoFollow,
            historyNotEmpty: history.isNotEmpty,
            recordingStartMs: recordingStartForAxis,
            colors: canvasColors,
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
      return RecordingPlaybackBar(
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
      return LatestRecordingChip(
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
      MaterialPageRoute(builder: (_) => const TunerSettingsScreen()),
    );
  }

  void _showRecordingsList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => const RecordingsListSheet(),
    );
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
          color: Theme.of(context).colorScheme.primary,
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
        ? colorScheme.primary
        : cents.abs() <= 15
        ? Colors.amber
        : Colors.deepOrange;

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
        color: isRunning
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
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
        color: isPaused ? Theme.of(context).colorScheme.primary : Colors.amber,
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
