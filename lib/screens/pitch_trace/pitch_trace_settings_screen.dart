import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/pitch_trace_controller.dart';
import '../../models/musical_scale.dart';
import '../../models/pitch_reading.dart';

class PitchTraceSettingsScreen extends StatefulWidget {
  const PitchTraceSettingsScreen({super.key});
  @override
  State<PitchTraceSettingsScreen> createState() =>
      _PitchTraceSettingsScreenState();
}

class _PitchTraceSettingsScreenState extends State<PitchTraceSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PitchTraceController>();
    final allScales = MusicalScale.allScales();

    final centerNoteOptions = <int, String>{};
    for (var midi = 60; midi <= 84; midi += 1) {
      final noteName = noteNames[midi % 12];
      final octave = midi ~/ 12 - 1;
      centerNoteOptions[midi] = '$noteName$octave';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('音高轨迹设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '参考音 A4',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '默认 440 Hz，可按乐团或老师要求调整音名参考',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          _buildReferenceSelector(controller),
          const SizedBox(height: 28),
          const Text(
            '识别音域',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '缩小范围可以减少环境噪声和倍频误判',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          _buildFrequencyRangeSelector(controller),
          const SizedBox(height: 28),
          const Text(
            '显示范围',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '调整主界面一次显示多长时间、上下覆盖多少半音；双指缩放也会贴近这些档位。',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          _buildTraceWindowSelector(controller),
          const SizedBox(height: 28),
          const Text(
            '音阶选择',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '选择左侧音高坐标中更醒目的基准音阶',
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

  Widget _buildTraceWindowSelector(PitchTraceController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.zoom_out_map,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '当前: ${(controller.visibleDurationMs / 1000).round()}秒 · '
                '${controller.midiSpan.round()}半音',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '时间窗口',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PitchTraceController.visibleDurationStepsMs.map((
              duration,
            ) {
              final isSelected = controller.visibleDurationMs == duration;
              return ChoiceChip(
                label: Text('${(duration / 1000).round()}秒'),
                selected: isSelected,
                onSelected: (_) => controller.setVisibleDurationMs(duration),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            '纵向范围',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PitchTraceController.midiSpanSteps.map((span) {
              final isSelected = controller.midiSpan == span;
              return ChoiceChip(
                label: Text('${span.round()}半音'),
                selected: isSelected,
                onSelected: (_) => controller.setMidiSpan(span),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceSelector(PitchTraceController controller) {
    final selected = controller.referenceA4Hz.round();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [438, 439, 440, 441, 442].map((hz) {
        final isSelected = selected == hz;
        return ChoiceChip(
          label: Text('$hz Hz'),
          selected: isSelected,
          onSelected: (_) => controller.setReferenceA4Hz(hz.toDouble()),
        );
      }).toList(),
    );
  }

  Widget _buildFrequencyRangeSelector(PitchTraceController controller) {
    final values = RangeValues(
      controller.minFrequency,
      controller.maxFrequency,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.graphic_eq,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '${controller.minFrequency.round()} Hz - '
                '${controller.maxFrequency.round()} Hz',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: controller.resetFrequencyRange,
                child: const Text('恢复默认'),
              ),
            ],
          ),
          RangeSlider(
            values: values,
            min: PitchTraceController.minAllowedFrequency,
            max: PitchTraceController.maxAllowedFrequency,
            divisions:
                ((PitchTraceController.maxAllowedFrequency -
                            PitchTraceController.minAllowedFrequency) /
                        10)
                    .round(),
            labels: RangeLabels(
              '${values.start.round()} Hz',
              '${values.end.round()} Hz',
            ),
            onChanged: (newValues) {
              controller.setFrequencyRange(newValues.start, newValues.end);
            },
          ),
          Text(
            '默认范围覆盖低音人声测试和常用长笛音域；如果环境很吵，可以适当收窄。',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.56),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaleSelector(
    PitchTraceController controller,
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
    PitchTraceController controller,
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
