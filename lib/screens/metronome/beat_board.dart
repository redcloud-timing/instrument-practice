import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/metronome_controller.dart';
import '../../models/metronome_preset.dart';
import 'painters.dart';

class BeatBoardPanel extends StatelessWidget {
  const BeatBoardPanel({super.key});

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
                child: BeatBoard(
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
                  child: CometAnimationArea(
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

class CometAnimationArea extends StatefulWidget {
  const CometAnimationArea({
    super.key,
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
  State<CometAnimationArea> createState() => _CometAnimationAreaState();
}

class _CometAnimationAreaState extends State<CometAnimationArea>
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
  void didUpdateWidget(covariant CometAnimationArea oldWidget) {
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
          painter: CometPainter(
            beatCount: widget.beatCount,
            progress: _animCtrl!.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class BeatBoard extends StatelessWidget {
  const BeatBoard({
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
                    child: BeatColumn(
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

class BeatColumn extends StatelessWidget {
  const BeatColumn({
    super.key,
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
                    child: MiniCircleButton(
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
          EditableDot(
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
                        EditableDot(
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
              child: MiniCircleButton(
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

class EditableDot extends StatelessWidget {
  const EditableDot({
    super.key,
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
              painter: ThreeQuarterArcPainter(
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

class MiniCircleButton extends StatelessWidget {
  const MiniCircleButton({
    super.key,
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
