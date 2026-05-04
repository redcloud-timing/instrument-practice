import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/metronome_controller.dart';
import 'painters.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    super.key,
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
                    ToolButton(
                      tooltip: '预设节拍',
                      icon: Icons.queue_music_outlined,
                      onPressed: onPreset,
                    ),
                    ToolButton(
                      tooltip: '节拍设置',
                      icon: Icons.grid_view_outlined,
                      onPressed: onPattern,
                    ),
                    ToolButton(
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
                          painter: BeatShapePainter(
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
                    RepeatIconButton(
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
                    RepeatIconButton(
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

class RepeatIconButton extends StatefulWidget {
  const RepeatIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onStep,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onStep;

  @override
  State<RepeatIconButton> createState() => _RepeatIconButtonState();
}

class _RepeatIconButtonState extends State<RepeatIconButton> {
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

class ToolButton extends StatelessWidget {
  const ToolButton({
    super.key,
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
