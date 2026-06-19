import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/metronome_controller.dart';
import 'metronome/beat_board.dart';
import 'metronome/control_panel.dart';
import 'metronome/sheets.dart';

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
            const Expanded(child: BeatBoardPanel()),
            ControlPanel(
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
      builder: (_) => const BpmKeypadSheet(),
    );
  }

  void _showPresetSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const PresetSheet(),
    );
  }

  void _showPatternSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const PatternSheet(),
    );
  }

  void _showSoundSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const SoundSheet(),
    );
  }
}
