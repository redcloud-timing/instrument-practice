import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/practice_controller.dart';
import '../utils/app_date_utils.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  Future<void> _toggleTimer(BuildContext context) async {
    final controller = context.read<PracticeController>();

    if (controller.isTimerRunning) {
      final savedSeconds = await controller.stopTimerAndSave();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已记录本次练习：${AppDateUtils.formatDuration(savedSeconds)}'),
        ),
      );
      return;
    }

    await controller.startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PracticeController>();
    final isRunning = controller.isTimerRunning;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: Column(
              children: [
                Icon(
                  isRunning
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  AppDateUtils.formatDuration(controller.elapsedSeconds),
                  style: Theme.of(context).textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isRunning ? '练习进行中' : '准备开始练习',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (isRunning && controller.elapsedSeconds > 4 * 60 * 60) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '计时已超过 4 小时，请确认是否忘记结束。',
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _toggleTimer(context),
                    icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
                    label: Text(isRunning ? '结束并记录' : '开始练习'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
