import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/pitch_trace_controller.dart';
import '../models/pitch_reading.dart';
import '../models/pitch_trace_recording.dart';
import 'pitch_trace/pitch_canvas.dart';
import 'pitch_trace/recordings_sheet.dart';
import 'pitch_trace/pitch_trace_settings_screen.dart';

class PitchCanvasColors {
  const PitchCanvasColors({
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
    required this.pitchLine,
    required this.pitchLineSoft,
    required this.pitchPoint,
    required this.pitchLowClarity,
    required this.directionUp,
    required this.directionDown,
    required this.directionFlat,
    required this.highlightNoteBg,
    required this.highlightNoteLine,
    required this.timeGridMajor,
    required this.timeGridMinor,
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
  final Color pitchLine;
  final Color pitchLineSoft;
  final Color pitchPoint;
  final Color pitchLowClarity;
  final Color directionUp;
  final Color directionDown;
  final Color directionFlat;
  final Color highlightNoteBg;
  final Color highlightNoteLine;
  final Color timeGridMajor;
  final Color timeGridMinor;
  final Color statusInTune;
  final Color statusSlightlyOff;
  final Color statusOff;
  final Color recordingIcon;

  factory PitchCanvasColors.fromColorScheme(ColorScheme cs) {
    return PitchCanvasColors(
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
      pitchLine: cs.primary,
      pitchLineSoft: cs.primary.withValues(alpha: 0.62),
      pitchPoint: cs.primary,
      pitchLowClarity: cs.outline,
      directionUp: Colors.deepOrange,
      directionDown: Colors.blueAccent,
      directionFlat: cs.primary,
      highlightNoteBg: cs.primaryContainer.withValues(alpha: 0.55),
      highlightNoteLine: cs.primary.withValues(alpha: 0.45),
      timeGridMajor: cs.outlineVariant.withValues(alpha: 0.34),
      timeGridMinor: cs.outlineVariant.withValues(alpha: 0.16),
      statusInTune: cs.primary,
      statusSlightlyOff: Colors.amber,
      statusOff: Colors.deepOrange,
      recordingIcon: cs.error.withValues(alpha: 0.7),
    );
  }
}

const _globalMinMidi = 36.0;
const _globalMaxMidi = 108.0;
const _noteMargin = 48.0;

class PitchTraceScreen extends StatefulWidget {
  const PitchTraceScreen({super.key});
  @override
  State<PitchTraceScreen> createState() => _PitchTraceScreenState();
}

class _PitchTraceScreenState extends State<PitchTraceScreen> {
  double _scrollOffsetMs = 0;
  double _verticalOffsetSemitones = 0;
  bool _autoFollow = true;
  int? _recordingStartMs;
  bool _isPinching = false;
  double _pinchStartVisibleDurationMs =
      PitchTraceController.defaultVisibleDurationMs;
  double _pinchStartMidiSpan = PitchTraceController.defaultMidiSpan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PitchTraceController>().loadRecordings();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PitchTraceController>();
    final reading = controller.reading;
    final colorScheme = Theme.of(context).colorScheme;
    final canvasColors = PitchCanvasColors.fromColorScheme(colorScheme);

    final hasLoadedRecording = controller.loadedRecordingHistory.isNotEmpty;
    final displayHistory = hasLoadedRecording
        ? controller.loadedRecordingHistory
        : controller.history;
    final history = displayHistory;

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
    final topBarReading = _topBarReading(controller, history, cursorTs);
    final hasTopBarPitch = topBarReading?.hasPitch ?? false;

    int? recordingStartForAxis = _recordingStartMs;
    if (hasLoadedRecording && history.isNotEmpty) {
      recordingStartForAxis = history.first.timestampMillis;
    }
    final cursorElapsedText = _formatCursorElapsed(
      cursorTs,
      recordingStartForAxis,
    );
    final highlightedMidi = hasTopBarPitch
        ? topBarReading!.midiNumberFor(controller.referenceA4Hz)
        : null;

    final hasLatestRecording = controller.latestRecordingPath != null;
    final recordings = controller.recordings;
    final visibleDurationMs = controller.visibleDurationMs;
    final midiSpan = controller.midiSpan;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _TopBar(
            noteLabel: hasTopBarPitch
                ? topBarReading!.noteLabelFor(controller.referenceA4Hz)
                : '--',
            frequency: hasTopBarPitch ? topBarReading!.frequency : 0,
            hasPitch: hasTopBarPitch,
            cursorElapsedText: cursorElapsedText,
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
            visibleDurationMs: visibleDurationMs,
            midiSpan: midiSpan,
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
                      final effectiveCenterMidi = controller.centerMidi
                          .toDouble();
                      final effectiveMinMidi =
                          effectiveCenterMidi - midiSpan / 2;
                      final effectiveMaxMidi =
                          effectiveCenterMidi + midiSpan / 2;
                      final semitonesPerPixel = midiSpan / canvasH;
                      final historyNotEmpty = history.isNotEmpty;

                      return Stack(
                        children: [
                          GestureDetector(
                            onScaleStart: (details) {
                              if (details.pointerCount >= 2) {
                                _beginPinchZoom(controller);
                              } else {
                                _isPinching = false;
                              }
                            },
                            onScaleUpdate: (details) {
                              if (!historyNotEmpty ||
                                  (controller.isPlaying &&
                                      !controller.isPaused) ||
                                  (controller.isRunning &&
                                      !controller.isRecordingPaused)) {
                                return;
                              }
                              setState(() {
                                _autoFollow = false;
                                if (details.pointerCount >= 2) {
                                  if (!_isPinching) {
                                    _beginPinchZoom(controller);
                                  }
                                  final hScale = _dampedPinchScale(
                                    details.horizontalScale,
                                  );
                                  final vScale = _dampedPinchScale(
                                    details.verticalScale,
                                  );
                                  final newDuration =
                                      (_pinchStartVisibleDurationMs / hScale)
                                          .clamp(3000.0, 30000.0);
                                  controller.setVisibleDurationMs(newDuration);

                                  final newSpan = (_pinchStartMidiSpan / vScale)
                                      .clamp(12.0, 48.0);
                                  controller.setMidiSpan(newSpan);
                                } else {
                                  _isPinching = false;
                                  // Single finger pan
                                  final effectivePixelsPerMs =
                                      (canvasW - _noteMargin) /
                                      visibleDurationMs;
                                  _scrollOffsetMs -=
                                      details.focalPointDelta.dx /
                                      effectivePixelsPerMs;
                                  final isFrozen =
                                      controller.isPaused ||
                                      controller.isRecordingPaused;
                                  _scrollOffsetMs = _scrollOffsetMs.clamp(
                                    _minScrollMs(
                                      history,
                                      baseCursorMs,
                                      isFrozen,
                                    ),
                                    _maxScrollMs(
                                      history,
                                      baseCursorMs,
                                      isFrozen,
                                      visibleDurationMs,
                                    ),
                                  );
                                  _verticalOffsetSemitones +=
                                      details.focalPointDelta.dy *
                                      semitonesPerPixel;
                                  _verticalOffsetSemitones =
                                      _verticalOffsetSemitones.clamp(
                                        _globalMinMidi - effectiveMinMidi,
                                        _globalMaxMidi - effectiveMaxMidi,
                                      );
                                }
                              });
                            },
                            onScaleEnd: (details) {
                              _isPinching = false;
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
                                visibleDurationMs: visibleDurationMs.toInt(),
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
                                minMidi: effectiveMinMidi,
                                maxMidi: effectiveMaxMidi,
                                referenceA4Hz: controller.referenceA4Hz,
                                highlightedMidi: highlightedMidi,
                                overlayHistory: controller.overlayHistory,
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
                          if (controller.overlayHistory.isNotEmpty &&
                              !controller.isRunning)
                            Positioned(
                              left: 12,
                              top: 12,
                              child: _OverlayChip(
                                name: controller.overlayRecordingName ?? '录音',
                                onClear: () => controller.clearOverlay(),
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
                                visibleDurationMs: visibleDurationMs.toInt(),
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
            visibleDurationMs: visibleDurationMs.toInt(),
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
                      final ctrl = context.read<PitchTraceController>();
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
                  onTap: () => context.read<PitchTraceController>().toggle(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingArea(
    PitchTraceController controller,
    bool hasLatestRecording,
    bool hasLoadedRecording,
    List<PitchTraceRecording> recordings,
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
        name: controller.latestRecordingPath == null
            ? '录音'
            : controller.recordingDisplayName(controller.latestRecordingPath!),
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
    List<PitchReading> history,
    int? baseCursorMs,
    bool isPaused,
    double visibleDurationMs,
  ) {
    if (history.length < 2) return 0;
    if (isPaused && baseCursorMs != null) {
      return (baseCursorMs - history.first.timestampMillis).toDouble();
    }
    return (history.last.timestampMillis -
            history.first.timestampMillis -
            visibleDurationMs)
        .toDouble()
        .clamp(0, double.infinity);
  }

  double _minScrollMs(
    List<PitchReading> history,
    int? baseCursorMs,
    bool isPaused,
  ) {
    if (isPaused && baseCursorMs != null && history.isNotEmpty) {
      return (baseCursorMs - history.last.timestampMillis).toDouble();
    }
    return 0.0;
  }

  void _beginPinchZoom(PitchTraceController controller) {
    _isPinching = true;
    _pinchStartVisibleDurationMs = controller.visibleDurationMs;
    _pinchStartMidiSpan = controller.midiSpan;
  }

  double _dampedPinchScale(double rawScale) {
    if (rawScale <= 0) return 1;
    const damping = 0.55;
    return math.pow(rawScale, damping).toDouble();
  }

  PitchReading? _topBarReading(
    PitchTraceController controller,
    List<PitchReading> history,
    int? cursorTs,
  ) {
    final liveReading = controller.reading;
    if (controller.isRunning && !controller.isRecordingPaused) {
      return (liveReading?.hasPitch ?? false) ? liveReading : null;
    }

    if (history.isEmpty) return null;
    final targetTs = cursorTs ?? history.last.timestampMillis;
    for (final reading in history.reversed) {
      if (reading.timestampMillis <= targetTs) return reading;
    }
    return history.first;
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0) return '$mins 分 $secs 秒';
    return '$secs 秒';
  }

  String? _formatCursorElapsed(int? cursorTs, int? recordingStartMs) {
    if (cursorTs == null || recordingStartMs == null) return null;
    final elapsedMs = math.max(0, cursorTs - recordingStartMs);
    final minutes = elapsedMs ~/ 60000;
    final seconds = (elapsedMs % 60000) / 1000;
    if (minutes > 0) {
      return '$minutes:${seconds.toStringAsFixed(1).padLeft(4, '0')}';
    }
    return '${seconds.toStringAsFixed(1)}s';
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PitchTraceSettingsScreen()),
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
    required this.frequency,
    required this.hasPitch,
    required this.cursorElapsedText,
    required this.isRunning,
    required this.hasLoadedRecording,
    required this.recordingDuration,
    required this.visibleDurationMs,
    required this.midiSpan,
    required this.onSettingsTap,
  });
  final String noteLabel;
  final double frequency;
  final bool hasPitch;
  final String? cursorElapsedText;
  final bool isRunning;
  final bool hasLoadedRecording;
  final String? recordingDuration;
  final double visibleDurationMs;
  final double midiSpan;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final freqText = hasPitch ? '${frequency.toStringAsFixed(1)} Hz' : '--';
    final timeText = cursorElapsedText ?? '--';
    final windowText =
        '${(visibleDurationMs / 1000).round()}秒 · ${midiSpan.round()}半音';

    final statusColor = !isRunning && !hasLoadedRecording
        ? colorScheme.outline
        : !hasPitch
        ? Colors.grey
        : colorScheme.primary;

    final controller = context.watch<PitchTraceController>();
    String subtitle;
    if (isRunning && controller.isRecordingPaused) {
      subtitle = '录音已暂停';
    } else if (isRunning) {
      subtitle = hasPitch ? '$timeText · $freqText' : '等待声音输入...';
    } else if (hasLoadedRecording) {
      subtitle = hasPitch
          ? '$timeText · $freqText'
          : recordingDuration != null
          ? '录音时长: $recordingDuration'
          : '查看录音音高数据';
    } else {
      subtitle = '点击下方按钮开始记录';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 2),
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
                        freqText,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w500,
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
                const SizedBox(height: 2),
                Text(
                  '窗口 $windowText',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSettingsTap,
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: '音高轨迹设置',
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

class _MicButton extends StatefulWidget {
  const _MicButton({
    required this.isRunning,
    required this.isBusy,
    required this.onTap,
  });

  final bool isRunning;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRunning != widget.isRunning ||
        oldWidget.isBusy != widget.isBusy) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isRunning && !widget.isBusy) {
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final btnColor = widget.isRunning ? colorScheme.error : colorScheme.primary;
    final ringColor = widget.isRunning
        ? colorScheme.error
        : colorScheme.primary;

    return SizedBox(
      width: 60,
      height: 60,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          final scale = _pulseAnim.value;
          final ringOpacity = widget.isRunning
              ? 0.2 * (scale - 1.0) / 0.12
              : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Breathing ring
              if (widget.isRunning && !widget.isBusy)
                Transform.scale(
                  scale: scale * 1.15,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ringColor.withValues(alpha: ringOpacity),
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              // Main button
              Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Material(
                    color: btnColor,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      onTap: widget.isBusy ? null : widget.onTap,
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: widget.isBusy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                widget.isRunning ? Icons.stop : Icons.mic,
                                color: Colors.white,
                                size: 26,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({required this.name, required this.onClear});

  final String name;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.compare_arrows,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            '对比: $name',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onClear,
            child: Icon(
              Icons.close,
              size: 14,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
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
