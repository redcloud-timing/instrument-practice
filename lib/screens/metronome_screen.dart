import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/metronome_controller.dart';
import '../models/metronome_preset.dart';

class MetronomeScreen extends StatelessWidget {
  const MetronomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetronomeController>();

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Column(
          children: [
            const Expanded(child: _BeatBoardPanel()),
            _ControlPanel(
              onPreset: () => _showPresetSheet(context),
              onPattern: () => _showPatternSheet(context),
              onSound: () => _showSoundSheet(context),
              onBpmTap: () => _showBpmKeypad(context),
            ),
          ],
        ),
        if (controller.flashEnabled && controller.flashPulse > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(controller.flashPulse),
                tween: Tween(begin: 0.22, end: 0),
                duration: const Duration(milliseconds: 180),
                builder: (context, opacity, child) {
                  return ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: opacity),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  void _showBpmKeypad(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          _BpmKeypadSheet(initialBpm: context.read<MetronomeController>().bpm),
    );
  }

  void _showPresetSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _PresetSheet(),
    );
  }

  void _showPatternSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _PatternSheet(),
    );
  }

  void _showSoundSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _SoundSheet(),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.onPreset,
    required this.onPattern,
    required this.onSound,
    required this.onBpmTap,
  });

  final VoidCallback onPreset;
  final VoidCallback onPattern;
  final VoidCallback onSound;
  final VoidCallback onBpmTap;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetronomeController>();
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ToolButton(
                      tooltip: '预设节拍',
                      icon: Icons.queue_music_outlined,
                      onPressed: onPreset,
                    ),
                    _ToolButton(
                      tooltip: '节拍设置',
                      icon: Icons.grid_view_outlined,
                      onPressed: onPattern,
                    ),
                    _ToolButton(
                      tooltip: '音色与反馈',
                      icon: Icons.graphic_eq,
                      onPressed: onSound,
                    ),
                    IconButton(
                      tooltip: controller.showCometAnimation
                          ? '关闭动画'
                          : '${controller.beatsPerBar} 拍图形',
                      onPressed: () => context
                          .read<MetronomeController>()
                          .toggleCometAnimation(),
                      icon: SizedBox(
                        width: 22,
                        height: 22,
                        child: CustomPaint(
                          painter: _BeatShapePainter(
                            beatCount: controller.beatsPerBar,
                            color: controller.showCometAnimation
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    const Spacer(),
                    _RepeatIconButton(
                      tooltip: '减慢',
                      icon: Icons.remove,
                      onStep: () =>
                          context.read<MetronomeController>().changeBpm(-1),
                    ),
                    const SizedBox(width: 60),
                    GestureDetector(
                      onTap: onBpmTap,
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(
                          '${controller.bpm}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 60),
                    _RepeatIconButton(
                      tooltip: '加快',
                      icon: Icons.add,
                      onStep: () =>
                          context.read<MetronomeController>().changeBpm(1),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: IconButton(
                          onPressed: () =>
                              context.read<MetronomeController>().toggle(),
                          icon: Icon(
                            controller.isRunning
                                ? Icons.stop
                                : Icons.play_arrow,
                            size: 28,
                          ),
                          style: IconButton.styleFrom(
                            minimumSize: Size.fromHeight(52),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BeatBoardPanel extends StatelessWidget {
  const _BeatBoardPanel();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetronomeController>();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        const Spacer(flex: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                controller.selectedPresetName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.96,
                        end: 1.0,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _BeatBoard(
                  key: ValueKey(controller.beatsPerBar),
                  beats: controller.beatPattern,
                  subdivisionPatterns: controller.subdivisionPatterns,
                  currentBeat: controller.currentBeat,
                  currentSubdivision: controller.currentSubdivision,
                  isRunning: controller.isRunning,
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 1),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedOpacity(
              opacity: controller.showCometAnimation ? 1.0 : 0.0,
              duration: controller.showCometAnimation
                  ? const Duration(milliseconds: 300)
                  : const Duration(milliseconds: 400),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _CometAnimationArea(
                    beatCount: controller.beatsPerBar,
                    isRunning: controller.isRunning,
                    barDuration: controller.barDuration,
                    active: controller.showCometAnimation,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
        const Spacer(flex: 1),
      ],
    );
  }
}

class _CometPainter extends CustomPainter {
  const _CometPainter({
    required this.beatCount,
    required this.progress,
    required this.color,
  });

  final int beatCount;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    // Background path
    final pathPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, pathPaint);

    // Use Flutter's PathMetric for reliable position along the path
    final metric = path.computeMetrics(forceClosed: beatCount >= 3).first;
    final totalLen = metric.length;
    if (totalLen <= 0) return;

    // Comet head
    final headDist = totalLen * progress;
    final headTangent = metric.getTangentForOffset(headDist);
    if (headTangent == null) return;
    canvas.drawCircle(headTangent.position, 5, Paint()..color = color);

    // Comet tail
    const tailPoints = 10;
    const tailLength = 0.12;
    for (var i = tailPoints; i > 0; i--) {
      var raw = progress - tailLength * i / tailPoints;
      if (raw < 0) raw += 1.0;
      final dist = (raw * totalLen).clamp(0.0, totalLen);
      final t = metric.getTangentForOffset(dist);
      if (t == null) continue;
      final fraction = i / tailPoints;
      final nearness = 1.0 - fraction;
      final dotRadius = 1.0 + 4.0 * nearness;
      canvas.drawCircle(
        t.position,
        dotRadius,
        Paint()..color = color.withValues(alpha: 0.08 + 0.55 * nearness),
      );
    }
  }

  Path _buildPath(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 6;
    final path = Path();

    if (beatCount == 1) {
      path.moveTo(center.dx, center.dy - radius);
      path.lineTo(center.dx, center.dy + radius);
    } else if (beatCount == 2) {
      final m = 6.0;
      path.moveTo(m, m);
      path.lineTo(m, size.height - m);
      path.lineTo(size.width - m, size.height - m);
    } else {
      for (var i = 0; i < beatCount; i++) {
        final angle = -math.pi / 2 - (2 * math.pi * i / beatCount);
        final x = center.dx + radius * math.cos(angle);
        final y = center.dy + radius * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _CometPainter oldDelegate) {
    return beatCount != oldDelegate.beatCount ||
        progress != oldDelegate.progress ||
        color != oldDelegate.color;
  }
}

class _CometAnimationArea extends StatefulWidget {
  const _CometAnimationArea({
    required this.beatCount,
    required this.isRunning,
    required this.barDuration,
    required this.active,
    required this.color,
  });

  final int beatCount;
  final bool isRunning;
  final Duration barDuration;
  final bool active;
  final Color color;

  @override
  State<_CometAnimationArea> createState() => _CometAnimationAreaState();
}

class _CometAnimationAreaState extends State<_CometAnimationArea>
    with SingleTickerProviderStateMixin {
  AnimationController? _animCtrl;
  Duration _lastBarDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: widget.barDuration);
    _lastBarDuration = widget.barDuration;
    if (widget.active && widget.isRunning) {
      _animCtrl!.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _CometAnimationArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dur = widget.barDuration;
    if (dur != _lastBarDuration && dur > Duration.zero) {
      _lastBarDuration = dur;
      _animCtrl!.duration = dur;
    }

    final shouldRun = widget.active && widget.isRunning;
    final wasRunning = oldWidget.active && oldWidget.isRunning;
    if (shouldRun && !wasRunning) {
      _animCtrl!
        ..value = 0
        ..repeat();
    } else if (!shouldRun && wasRunning) {
      _animCtrl!.stop();
    }
  }

  @override
  void dispose() {
    _animCtrl!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animCtrl!,
      builder: (context, child) {
        return CustomPaint(
          painter: _CometPainter(
            beatCount: widget.beatCount,
            progress: _animCtrl!.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _BeatBoard extends StatelessWidget {
  const _BeatBoard({
    super.key,
    required this.beats,
    required this.subdivisionPatterns,
    required this.currentBeat,
    required this.currentSubdivision,
    required this.isRunning,
  });

  final List<BeatType> beats;
  final List<List<BeatType>> subdivisionPatterns;
  final int currentBeat;
  final int currentSubdivision;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < beats.length; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _BeatColumn(
                      index: index,
                      type: beats[index],
                      subdivisionDots: index < subdivisionPatterns.length
                          ? subdivisionPatterns[index]
                          : const [],
                      activeBeat: isRunning && currentBeat == index + 1,
                      currentSubdivision: currentBeat == index + 1
                          ? currentSubdivision
                          : 0,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BeatColumn extends StatelessWidget {
  const _BeatColumn({
    required this.index,
    required this.type,
    required this.subdivisionDots,
    required this.activeBeat,
    required this.currentSubdivision,
  });

  final int index;
  final BeatType type;
  final List<BeatType> subdivisionDots;
  final bool activeBeat;
  final int currentSubdivision;

  @override
  Widget build(BuildContext context) {
    final subBeatCount = subdivisionDots.length;
    final hasSubBeats = subBeatCount > 0;
    const buttonAreaHeight = 36.0;
    const mainBeatSize = 28.0;
    const fixedGapHeight = 240.0;
    const minusGapHeight = 4.0;
    const totalHeight =
        buttonAreaHeight +
        minusGapHeight +
        mainBeatSize +
        fixedGapHeight +
        buttonAreaHeight;

    return SizedBox(
      width: 62,
      height: totalHeight,
      child: Column(
        children: [
          SizedBox(
            height: buttonAreaHeight,
            child: hasSubBeats
                ? Align(
                    alignment: Alignment.bottomCenter,
                    child: _MiniCircleButton(
                      tooltip: '减少细分',
                      icon: Icons.remove,
                      onTap: () => context
                          .read<MetronomeController>()
                          .removeSubdivisionDotAt(index),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: minusGapHeight),
          _EditableDot(
            size: mainBeatSize,
            type: type,
            active: activeBeat && currentSubdivision == 0,
            label: '${index + 1}',
            onTap: () => context.read<MetronomeController>().cycleBeatAt(index),
          ),
          SizedBox(
            height: fixedGapHeight,
            child: hasSubBeats
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (
                        var dotIndex = 0;
                        dotIndex < subBeatCount;
                        dotIndex++
                      )
                        _EditableDot(
                          size: 22,
                          type: subdivisionDots[dotIndex],
                          active:
                              activeBeat && currentSubdivision == dotIndex + 1,
                          onTap: () => context
                              .read<MetronomeController>()
                              .cycleSubdivisionDotAt(index, dotIndex),
                        ),
                    ],
                  )
                : null,
          ),
          SizedBox(
            height: buttonAreaHeight,
            child: Align(
              alignment: Alignment.topCenter,
              child: _MiniCircleButton(
                tooltip: '增加细分',
                icon: Icons.add,
                enabled:
                    subBeatCount <
                    MetronomeController.maxSubdivisionDotsPerBeat,
                onTap: () => context
                    .read<MetronomeController>()
                    .addSubdivisionDotAt(index),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableDot extends StatelessWidget {
  const _EditableDot({
    required this.size,
    required this.type,
    required this.active,
    required this.onTap,
    this.label,
  });

  final double size;
  final BeatType type;
  final bool active;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fillColor = active ? colorScheme.primary : _fillColor(colorScheme);
    final isAccent = type == BeatType.accent || type == BeatType.subaccent;
    final borderColor = isAccent
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    final borderWidth = type == BeatType.accent
        ? 2.0
        : type == BeatType.subaccent
        ? 1.5
        : 1.0;

    Widget dot;
    if (type == BeatType.subaccent) {
      dot = SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fillColor,
              ),
            ),
            CustomPaint(
              size: Size(size, size),
              painter: _ThreeQuarterArcPainter(
                color: borderColor,
                strokeWidth: borderWidth,
              ),
            ),
            if (label != null)
              Text(
                label!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: active ? colorScheme.onPrimary : colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      );
    } else {
      dot = AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fillColor,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: label == null
            ? null
            : Center(
                child: Text(
                  label!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: active
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      );
    }

    return GestureDetector(onTap: onTap, child: dot);
  }

  Color _fillColor(ColorScheme colorScheme) {
    switch (type) {
      case BeatType.accent:
        return colorScheme.primaryContainer;
      case BeatType.subaccent:
        return colorScheme.secondaryContainer;
      case BeatType.normal:
        return colorScheme.surfaceContainerHighest;
      case BeatType.rest:
        return colorScheme.surface;
    }
  }
}

class _ThreeQuarterArcPainter extends CustomPainter {
  const _ThreeQuarterArcPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final offset = strokeWidth / 2;
    final rect =
        Offset(offset, offset) &
        Size(size.width - strokeWidth, size.height - strokeWidth);

    canvas.drawArc(rect, math.pi / 4, 3 * math.pi / 2, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ThreeQuarterArcPainter oldDelegate) {
    return color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
  }
}

class _MiniCircleButton extends StatelessWidget {
  const _MiniCircleButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? colorScheme.onSurface
                : colorScheme.onSurface.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class _BpmKeypadSheet extends StatefulWidget {
  const _BpmKeypadSheet({required this.initialBpm});

  final int initialBpm;

  @override
  State<_BpmKeypadSheet> createState() => _BpmKeypadSheetState();
}

class _BpmKeypadSheetState extends State<_BpmKeypadSheet> {
  late String _digits;

  @override
  void initState() {
    super.initState();
    _digits = '${widget.initialBpm}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('BPM', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Text(
                _digits.isEmpty ? '0' : _digits,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 12),
            for (final row in const [
              [1, 2, 3],
              [4, 5, 6],
              [7, 8, 9],
            ]) ...[
              Row(
                children: [
                  for (final number in row)
                    Expanded(
                      child: _KeypadButton(
                        label: '$number',
                        onTap: () => _appendDigit(number),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: _KeypadButton(
                    label: 'TAP',
                    onTap: () {
                      context.read<MetronomeController>().recordTapTempo();
                      setState(() {
                        _digits = '${context.read<MetronomeController>().bpm}';
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _KeypadButton(
                    label: '0',
                    onTap: () => _appendDigit(0),
                  ),
                ),
                Expanded(
                  child: _KeypadButton(
                    icon: Icons.backspace_outlined,
                    onTap: _deleteDigit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _submit, child: const Text('确定')),
            ),
          ],
        ),
      ),
    );
  }

  void _appendDigit(int digit) {
    setState(() {
      final next = '${_digits == '0' ? '' : _digits}$digit';
      _digits = next.length > 3 ? next.substring(0, 3) : next;
    });
  }

  void _deleteDigit() {
    setState(() {
      if (_digits.isEmpty) return;
      _digits = _digits.substring(0, _digits.length - 1);
    });
  }

  void _submit() {
    final value = int.tryParse(_digits);
    if (value != null) {
      context.read<MetronomeController>().setBpm(value);
    }
    Navigator.pop(context);
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: icon == null
            ? Text(label!, style: Theme.of(context).textTheme.titleLarge)
            : Icon(icon),
      ),
    );
  }
}

class _PresetSheet extends StatelessWidget {
  const _PresetSheet();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetronomeController>();

    return _SheetScaffold(
      title: '预设节拍',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _saveCurrentPreset(context),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('保存当前节拍'),
            ),
          ),
          const SizedBox(height: 12),
          if (controller.savedPresets.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: const Text('还没有保存的预设。先调好节拍，再点“保存当前节拍”。'),
            )
          else
            for (final preset in controller.savedPresets)
              _PresetListTile(
                preset: preset,
                selected: controller.selectedPresetName == preset.name,
              ),
        ],
      ),
    );
  }

  Future<void> _saveCurrentPreset(BuildContext context) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _PresetNameSheet(),
    );

    if (name == null || !context.mounted) return;
    await context.read<MetronomeController>().saveCurrentPreset(name);
  }
}

class _PresetListTile extends StatelessWidget {
  const _PresetListTile({required this.preset, required this.selected});

  final MetronomePreset preset;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          leading: Icon(
            selected ? Icons.check_circle : Icons.queue_music_outlined,
            color: selected ? colorScheme.primary : null,
          ),
          title: Text(
            preset.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${preset.bpm} BPM · ${preset.beats.length} 拍 · ${preset.subdivisionBeats.map((dots) => dots.length).join('-')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () =>
                context.read<MetronomeController>().deletePreset(preset.name),
          ),
          onTap: () {
            context.read<MetronomeController>().applyPreset(preset);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

class _PresetNameSheet extends StatefulWidget {
  const _PresetNameSheet();

  @override
  State<_PresetNameSheet> createState() => _PresetNameSheetState();
}

class _PresetNameSheetState extends State<_PresetNameSheet> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('命名预设', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 20,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '预设名称',
                hintText: '例如：慢练三连音',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }
}

class _PatternSheet extends StatefulWidget {
  const _PatternSheet();

  @override
  State<_PatternSheet> createState() => _PatternSheetState();
}

class _PatternSheetState extends State<_PatternSheet> {
  late int _selectedCount;

  @override
  void initState() {
    super.initState();
    _selectedCount = context.read<MetronomeController>().beatsPerBar;
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: '节拍设置',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('拍数', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (
                var count = MetronomeController.minBeatsPerBar;
                count <= MetronomeController.maxBeatsPerBar;
                count++
              )
                ChoiceChip(
                  label: Text('$count'),
                  selected: _selectedCount == count,
                  onSelected: (_) {
                    setState(() => _selectedCount = count);
                    final ctrl = context.read<MetronomeController>();
                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (!mounted) return;
                      ctrl.setBeatCount(count);
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SoundSheet extends StatelessWidget {
  const _SoundSheet();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetronomeController>();

    return _SheetScaffold(
      title: '音色与反馈',
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final style in MetronomeSoundStyle.values)
                  ChoiceChip(
                    label: Text(style.label),
                    selected: controller.soundStyle == style,
                    onSelected: (_) => context
                        .read<MetronomeController>()
                        .setSoundStyle(style),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('强拍闪屏'),
            value: controller.flashEnabled,
            onChanged: (value) =>
                context.read<MetronomeController>().setFlashEnabled(value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('震动反馈'),
            value: controller.vibrationEnabled,
            onChanged: (value) =>
                context.read<MetronomeController>().setVibrationEnabled(value),
          ),
        ],
      ),
    );
  }
}

class _BeatShapePainter extends CustomPainter {
  const _BeatShapePainter({required this.beatCount, required this.color});

  final int beatCount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 3;

    if (beatCount == 1) {
      canvas.drawLine(
        Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius),
        paint,
      );
    } else if (beatCount == 2) {
      final margin = 3.0;
      canvas.drawLine(
        Offset(margin, size.height - margin),
        Offset(margin, margin),
        paint,
      );
      canvas.drawLine(
        Offset(margin, size.height - margin),
        Offset(size.width - margin, size.height - margin),
        paint,
      );
    } else {
      final path = Path();
      for (var i = 0; i < beatCount; i++) {
        final angle = -math.pi / 2 - (2 * math.pi * i / beatCount);
        final x = center.dx + radius * math.cos(angle);
        final y = center.dy + radius * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BeatShapePainter oldDelegate) {
    return beatCount != oldDelegate.beatCount || color != oldDelegate.color;
  }
}

class _RepeatIconButton extends StatefulWidget {
  const _RepeatIconButton({
    required this.tooltip,
    required this.icon,
    required this.onStep,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onStep;

  @override
  State<_RepeatIconButton> createState() => _RepeatIconButtonState();
}

class _RepeatIconButtonState extends State<_RepeatIconButton> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRepeat() {
    widget.onStep();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      widget.onStep();
    });
  }

  void _stopRepeat() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onStep,
      onLongPressStart: (_) => _startRepeat(),
      onLongPressEnd: (_) => _stopRepeat(),
      onLongPressCancel: _stopRepeat,
      child: Tooltip(
        message: widget.tooltip,
        child: SizedBox(width: 28, height: 40, child: Icon(widget.icon)),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
