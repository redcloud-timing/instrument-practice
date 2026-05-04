import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/tuner_controller.dart';

class RecordingsListSheet extends StatefulWidget {
  const RecordingsListSheet({super.key});
  @override
  State<RecordingsListSheet> createState() => _RecordingsListSheetState();
}

class _RecordingsListSheetState extends State<RecordingsListSheet> {
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
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  Icons.mic_off,
                  size: 40,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  '暂无录音',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
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
                    : Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.7),
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

class RecordingPlaybackBar extends StatelessWidget {
  const RecordingPlaybackBar({
    super.key,
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
                    color: Theme.of(context).colorScheme.primary,
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
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                IconButton(
                  onPressed: onStop,
                  icon: Icon(
                    Icons.stop,
                    size: 20,
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.7),
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Theme.of(context).colorScheme.primary,
                inactiveTrackColor: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                thumbColor: Theme.of(context).colorScheme.primary,
                overlayColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.2),
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

class LatestRecordingChip extends StatelessWidget {
  const LatestRecordingChip({
    super.key,
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
            Icon(
              Icons.mic,
              size: 18,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
            ),
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
