import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/pitch_trace_controller.dart';
import '../../models/pitch_trace_recording.dart';
import '../text_edit_screen.dart';

enum _RecordingAction { rename, note, delete }

class RecordingsListSheet extends StatefulWidget {
  const RecordingsListSheet({super.key});
  @override
  State<RecordingsListSheet> createState() => _RecordingsListSheetState();
}

class _RecordingsListSheetState extends State<RecordingsListSheet> {
  @override
  void initState() {
    super.initState();
    context.read<PitchTraceController>().loadRecordings();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PitchTraceController>();
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
            final title = rec.title.trim().isEmpty ? dateStr : rec.title.trim();
            final baseSubtitle = rec.title.trim().isEmpty
                ? durStr
                : '$dateStr · $durStr';
            final note = rec.note.trim();

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
                title,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                note.isEmpty ? baseSubtitle : '$baseSubtitle\n$note',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                  PopupMenuButton<_RecordingAction>(
                    tooltip: '更多操作',
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (action) {
                      switch (action) {
                        case _RecordingAction.rename:
                          _renameRecording(context, rec);
                          break;
                        case _RecordingAction.note:
                          _editRecordingNote(context, rec);
                          break;
                        case _RecordingAction.delete:
                          controller.deleteRecording(rec.path);
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _RecordingAction.rename,
                        child: ListTile(
                          leading: Icon(Icons.drive_file_rename_outline),
                          title: Text('重命名'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _RecordingAction.note,
                        child: ListTile(
                          leading: Icon(Icons.sticky_note_2_outlined),
                          title: Text('备注'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _RecordingAction.delete,
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('删除'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _renameRecording(
    BuildContext context,
    PitchTraceRecording recording,
  ) async {
    final controller = context.read<PitchTraceController>();
    final initialTitle = recording.title.trim().isEmpty
        ? recording.name.replaceAll('.wav', '')
        : recording.title;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TextEditScreen(
          title: '重命名录音',
          initialText: initialTitle,
          hintText: '输入录音名称',
          minLines: 1,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          selectAllOnOpen: true,
        ),
      ),
    );

    if (result == null || !mounted || !context.mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted || !context.mounted) return;

    if (result.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('录音名称不能为空。')));
      return;
    }

    await controller.renameRecording(recording.path, result);
  }

  Future<void> _editRecordingNote(
    BuildContext context,
    PitchTraceRecording recording,
  ) async {
    final controller = context.read<PitchTraceController>();
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TextEditScreen(
          title: '录音备注',
          initialText: recording.note,
          hintText: '写下音高变化、气息、尾音或老师提醒',
        ),
      ),
    );

    if (result == null || !mounted || !context.mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted || !context.mounted) return;
    await controller.saveRecordingNote(recording.path, result);
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
