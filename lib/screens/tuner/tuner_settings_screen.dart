import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/tuner_controller.dart';
import '../../models/musical_scale.dart';
import '../../models/tuner_reading.dart';

class TunerSettingsScreen extends StatefulWidget {
  const TunerSettingsScreen({super.key});
  @override
  State<TunerSettingsScreen> createState() => _TunerSettingsScreenState();
}

class _TunerSettingsScreenState extends State<TunerSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TunerController>();
    final allScales = MusicalScale.allScales();

    final centerNoteOptions = <int, String>{};
    for (var midi = 60; midi <= 84; midi += 1) {
      final noteName = noteNames[midi % 12];
      final octave = midi ~/ 12 - 1;
      centerNoteOptions[midi] = '$noteName$octave';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('调音器设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '音阶选择',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '选择调音时左侧音高显示的基准音阶',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          _buildScaleSelector(controller, allScales),
          const SizedBox(height: 28),
          const Text(
            '居中音名',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '选择音高显示区域中心位置的音名',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          _buildCenterSelector(controller, centerNoteOptions),
        ],
      ),
    );
  }

  Widget _buildScaleSelector(
    TunerController controller,
    List<MusicalScale> allScales,
  ) {
    final currentLabel = controller.scale.label;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Icon(
                  Icons.music_note,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '当前: $currentLabel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 200,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: allScales.length,
              itemBuilder: (context, index) {
                final scale = allScales[index];
                final isSelected = scale.label == controller.scale.label;
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    scale.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => controller.setScale(scale),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterSelector(
    TunerController controller,
    Map<int, String> options,
  ) {
    final currentMidi = controller.centerMidi;
    final entries = options.entries.toList();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Icon(
                  Icons.center_focus_strong,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '当前: ${options[currentMidi] ?? 'C5'}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 200,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isSelected = entry.key == controller.centerMidi;
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => controller.setCenterMidi(entry.key),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
