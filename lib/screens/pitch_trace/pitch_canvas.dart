import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/musical_scale.dart';
import '../../models/pitch_reading.dart';
import '../pitch_trace_screen.dart';

const _noteMargin = 48.0;

class PlaybackPositionLine extends StatelessWidget {
  const PlaybackPositionLine({
    super.key,
    required this.playbackPositionMs,
    required this.recordingFirstMs,
    required this.cursorTimestamp,
    required this.visibleDurationMs,
    required this.colors,
  });

  final int playbackPositionMs;
  final int recordingFirstMs;
  final int cursorTimestamp;
  final int visibleDurationMs;
  final PitchCanvasColors colors;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PlaybackPositionPainter(
        playbackPositionMs: playbackPositionMs,
        recordingFirstMs: recordingFirstMs,
        colors: colors,
        cursorTimestamp: cursorTimestamp,
        visibleDurationMs: visibleDurationMs,
      ),
      size: Size.infinite,
    );
  }
}

class PlaybackPositionPainter extends CustomPainter {
  const PlaybackPositionPainter({
    required this.playbackPositionMs,
    required this.recordingFirstMs,
    required this.cursorTimestamp,
    required this.visibleDurationMs,
    required this.colors,
  });

  final int playbackPositionMs;
  final int recordingFirstMs;
  final int cursorTimestamp;
  final int visibleDurationMs;
  final PitchCanvasColors colors;

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
        ..color = colors.playbackCursor.withValues(alpha: 0.18)
        ..strokeWidth = 9.0,
    );
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = colors.playbackCursor
        ..strokeWidth = 3.0,
    );
  }

  @override
  bool shouldRepaint(covariant PlaybackPositionPainter oldDelegate) {
    return oldDelegate.playbackPositionMs != playbackPositionMs;
  }
}

class TimeAxis extends StatelessWidget {
  const TimeAxis({
    super.key,
    required this.cursorTimestamp,
    required this.visibleDurationMs,
    required this.scrollOffsetMs,
    required this.autoFollow,
    required this.historyNotEmpty,
    required this.recordingStartMs,
    required this.colors,
  });

  final int? cursorTimestamp;
  final int visibleDurationMs;
  final double scrollOffsetMs;
  final bool autoFollow;
  final bool historyNotEmpty;
  final int? recordingStartMs;
  final PitchCanvasColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CustomPaint(
          painter: TimeAxisPainter(
            cursorTimestamp: cursorTimestamp,
            visibleDurationMs: visibleDurationMs,
            scrollOffsetMs: scrollOffsetMs,
            recordingStartMs: recordingStartMs,
            colors: colors,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class TimeAxisPainter extends CustomPainter {
  const TimeAxisPainter({
    required this.cursorTimestamp,
    required this.visibleDurationMs,
    required this.scrollOffsetMs,
    required this.recordingStartMs,
    required this.colors,
  });

  final int? cursorTimestamp;
  final int visibleDurationMs;
  final double scrollOffsetMs;
  final int? recordingStartMs;
  final PitchCanvasColors colors;

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
        ..color = colors.separator
        ..strokeWidth = 0.5,
    );

    const majorIntervalMs = 1000;
    final minorStepMs = visibleDurationMs <= 8000 ? 250 : 500;
    final firstMinorTickMs = (leftEdge / minorStepMs).ceil() * minorStepMs;

    var t = firstMinorTickMs;
    while (t <= cursor) {
      final age = (cursor - t) / visibleDurationMs;
      final x = noteMargin + plotWidth * (1 - age);
      final isMajor = t % majorIntervalMs == 0;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, isMajor ? 9 : 4),
        Paint()
          ..color = isMajor ? colors.majorTick : colors.minorTick
          ..strokeWidth = isMajor ? 1.1 : 0.6,
      );

      if (recStart != null && isMajor) {
        final elapsedSec = (t - recStart) ~/ 1000;
        if (elapsedSec >= 0) {
          final tp = TextPainter(
            text: TextSpan(
              text: '${elapsedSec}s',
              style: TextStyle(color: colors.tickLabel, fontSize: 10),
            ),
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          tp.paint(canvas, Offset(x - tp.width / 2, h - tp.height - 2));
        }
      }

      t += minorStepMs;
    }

    if (recStart != null && recStart >= leftEdge && recStart <= cursor) {
      final zeroAge = (cursor - recStart) / visibleDurationMs;
      final zeroX = noteMargin + plotWidth * (1 - zeroAge);
      canvas.drawLine(
        Offset(zeroX, 0),
        Offset(zeroX, h),
        Paint()
          ..color = colors.recordingMarker
          ..strokeWidth = 1.5,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '0s',
          style: TextStyle(
            color: colors.recordingMarker,
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
  bool shouldRepaint(covariant TimeAxisPainter oldDelegate) {
    return oldDelegate.cursorTimestamp != cursorTimestamp ||
        oldDelegate.visibleDurationMs != visibleDurationMs ||
        oldDelegate.scrollOffsetMs != scrollOffsetMs ||
        oldDelegate.recordingStartMs != recordingStartMs;
  }
}

class _PitchPoint {
  const _PitchPoint(this.x, this.y, this.reading, this.midi);
  final double x;
  final double y;
  final PitchReading reading;
  final double midi;
}

class PitchCanvasPainter extends CustomPainter {
  PitchCanvasPainter({
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
    required this.colors,
    required this.minMidi,
    required this.maxMidi,
    required this.referenceA4Hz,
    required this.highlightedMidi,
    this.overlayHistory = const [],
    this.overlayColor,
  });

  final List<PitchReading> history;
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
  final PitchCanvasColors colors;
  final double minMidi;
  final double maxMidi;
  final double referenceA4Hz;
  final int? highlightedMidi;
  final List<PitchReading> overlayHistory;
  final Color? overlayColor;

  double get _effMinMidi => minMidi + verticalOffsetSemitones;
  double get _effMaxMidi => maxMidi + verticalOffsetSemitones;
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

    _drawTimeGrid(canvas, w, h, cursor);
    _drawGrid(canvas, w, h);
    if (overlayHistory.isNotEmpty && !isRunning) {
      _drawOverlayDots(canvas, w, h, cursor);
    }
    _drawPitchTrace(canvas, w, h, cursor);
    _drawScaleLabel(canvas, w);
  }

  void _drawBackground(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = hasLoadedRecording ? colors.loadedCanvasBg : colors.canvasBg,
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
            : '点击下方按钮开始记录',
        style: TextStyle(color: colors.emptyText, fontSize: 15),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(w / 2 - tp.width / 2, h / 2 - tp.height / 2));
  }

  void _drawTimeGrid(Canvas canvas, double w, double h, int cursor) {
    final noteMargin = _noteMargin;
    final plotWidth = w - noteMargin;
    final leftEdge = cursor - visibleDurationMs;
    final minorStepMs = visibleDurationMs <= 8000 ? 250 : 500;
    const majorStepMs = 1000;
    final firstMinor = (leftEdge / minorStepMs).ceil() * minorStepMs;

    for (var t = firstMinor; t <= cursor; t += minorStepMs) {
      final age = (cursor - t) / visibleDurationMs;
      final x = noteMargin + plotWidth * (1 - age);
      final isMajor = t % majorStepMs == 0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, h),
        Paint()
          ..color = isMajor ? colors.timeGridMajor : colors.timeGridMinor
          ..strokeWidth = isMajor ? 0.8 : 0.45,
      );
    }
  }

  void _drawGrid(Canvas canvas, double w, double h) {
    final noteMargin = _noteMargin;
    final noteHeight = h / _effSemitones;
    final firstVisibleMidi = _effMinMidi.ceil();
    final lastVisibleMidi = _effMaxMidi.floor();
    final scaleNotes = scale.noteIndices();
    final rootIdx = noteNames.indexOf(scale.root);

    for (var midi = firstVisibleMidi; midi <= lastVisibleMidi; midi++) {
      final y = h - (midi - _effMinMidi + 0.5) * noteHeight;
      if (y < -20 || y > h + 20) continue;
      final isRoot = midi % 12 == rootIdx;
      final inScale = scaleNotes.contains(midi % 12);
      final isHighlighted = highlightedMidi == midi;

      Color lineColor;
      double strokeWidth;
      if (isHighlighted) {
        lineColor = colors.highlightNoteLine;
        strokeWidth = 1.6;
      } else if (isRoot) {
        lineColor = colors.gridRoot;
        strokeWidth = 1.0;
      } else if (inScale) {
        lineColor = colors.gridInScale;
        strokeWidth = 0.5;
      } else {
        lineColor = colors.gridOther;
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
      final name = '${noteNames[midi % 12]}${midi ~/ 12 - 1}';
      final isRoot = midi % 12 == rootIdx;
      final inScale = scaleNotes.contains(midi % 12);
      final isHighlighted = highlightedMidi == midi;

      final tp = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            color: isHighlighted
                ? colors.pitchLine
                : isRoot
                ? colors.labelRoot
                : inScale
                ? colors.labelInScale
                : colors.labelOther,
            fontSize: isHighlighted ? 13 : (isRoot ? 12 : (inScale ? 11 : 10)),
            fontWeight: isHighlighted
                ? FontWeight.w800
                : isRoot
                ? FontWeight.w700
                : inScale
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: noteMargin - 4);
      if (isHighlighted) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            1,
            y - tp.height / 2 - 2,
            noteMargin - 5,
            tp.height + 4,
          ),
          const Radius.circular(4),
        );
        canvas.drawRRect(rect, Paint()..color = colors.highlightNoteBg);
      }
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }

    canvas.drawLine(
      Offset(noteMargin, 0),
      Offset(noteMargin, h),
      Paint()
        ..color = colors.separator
        ..strokeWidth = 0.5,
    );
  }

  void _drawScaleLabel(Canvas canvas, double w) {
    final tp = TextPainter(
      text: TextSpan(
        text: scale.label,
        style: TextStyle(
          color: colors.scaleLabel,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(w - tp.width - 6, 4));
  }

  void _drawPitchTrace(Canvas canvas, double w, double h, int cursor) {
    final points = _visiblePitchPoints(w, h, cursor, history);

    if (points.isEmpty) return;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];

      if ((prev.midi - curr.midi).abs() > 4.0) continue;

      final clarity = math.min(prev.reading.clarity, curr.reading.clarity);
      linePaint.color = _segmentColor(clarity);
      canvas.drawLine(
        Offset(prev.x, prev.y),
        Offset(curr.x, curr.y),
        linePaint,
      );
    }

    final dotStep = math.max(1, points.length ~/ 80);
    for (var i = 0; i < points.length; i += dotStep) {
      final p = points[i];
      final clarity = p.reading.clarity.clamp(0.0, 1.0);
      final baseColor = clarity < 0.28
          ? colors.pitchLowClarity
          : colors.pitchPoint;
      final radius = 0.9 + clarity * 0.8;
      canvas.drawCircle(
        Offset(p.x, p.y),
        radius,
        Paint()..color = baseColor.withValues(alpha: 0.52),
      );
    }
  }

  List<_PitchPoint> _visiblePitchPoints(
    double w,
    double h,
    int cursor,
    List<PitchReading> source,
  ) {
    final noteMargin = _noteMargin;
    final plotWidth = w - noteMargin;
    final leftEdge = cursor - visibleDurationMs;
    final points = <_PitchPoint>[];

    for (final reading in source) {
      if (!reading.hasPitch) continue;
      if (reading.timestampMillis < leftEdge) continue;
      if (reading.timestampMillis > cursor) continue;

      final age = (cursor - reading.timestampMillis) / visibleDurationMs;
      final x = noteMargin + plotWidth * (1 - age);
      final midi = _midiValue(reading.frequency);
      final y = _yForMidi(midi, h);
      points.add(_PitchPoint(x, y, reading, midi));
    }

    return points;
  }

  Color _segmentColor(double clarity) {
    if (clarity < 0.28) {
      return colors.pitchLowClarity.withValues(alpha: 0.34);
    }
    return colors.pitchLine.withValues(alpha: 0.86);
  }

  double _midiValue(double frequency) {
    return 69 + 12 * math.log(frequency / referenceA4Hz) / math.ln2;
  }

  double _yForMidi(double midi, double h) {
    final normalized =
        (midi - _effMinMidi + 0.5).clamp(0.0, _effSemitones) / _effSemitones;
    return h - normalized * h;
  }

  void _drawOverlayDots(Canvas canvas, double w, double h, int cursor) {
    final noteMargin = _noteMargin;
    final plotWidth = w - noteMargin;
    final leftEdge = cursor - visibleDurationMs;
    final dotColor = (overlayColor ?? colors.dotInTune).withValues(alpha: 0.25);

    for (final reading in overlayHistory) {
      if (!reading.hasPitch) continue;
      if (reading.timestampMillis < leftEdge) continue;
      if (reading.timestampMillis > cursor) continue;

      final age = (cursor - reading.timestampMillis) / visibleDurationMs;
      final x = noteMargin + plotWidth * (1 - age);
      final midi = _midiValue(reading.frequency);
      final y = _yForMidi(midi, h);
      canvas.drawCircle(Offset(x, y), 1.3, Paint()..color = dotColor);
    }
  }

  @override
  bool shouldRepaint(covariant PitchCanvasPainter oldDelegate) {
    return oldDelegate.history != history ||
        oldDelegate.cursorTimestamp != cursorTimestamp ||
        oldDelegate.isRunning != isRunning ||
        oldDelegate.visibleDurationMs != visibleDurationMs ||
        oldDelegate.verticalOffsetSemitones != verticalOffsetSemitones ||
        oldDelegate.scale != scale ||
        oldDelegate.centerMidi != centerMidi ||
        oldDelegate.hasLoadedRecording != hasLoadedRecording ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.playbackPositionMs != playbackPositionMs ||
        oldDelegate.overlayHistory != overlayHistory ||
        oldDelegate.minMidi != minMidi ||
        oldDelegate.maxMidi != maxMidi ||
        oldDelegate.referenceA4Hz != referenceA4Hz ||
        oldDelegate.highlightedMidi != highlightedMidi;
  }
}
