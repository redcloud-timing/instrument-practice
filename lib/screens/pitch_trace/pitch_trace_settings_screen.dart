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
      appBar: AppBar(title: const Text('听音设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 颜色阈值 ──
          const Text(
            '颜色阈值',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '调整轨迹颜色的灵敏度，绿色=音准，黄色=轻微偏差，红色=明显偏差',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          _buildColorThresholdSelector(controller),
          const SizedBox(height: 28),

          // ── 检测精度 ──
          const Text(
            '检测精度',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '调整音高检测的采样密度。小窗口+高重叠=更细腻的轨迹，但低音精度下降',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          _buildWindowSizeSelector(controller),
          const SizedBox(height: 28),

          // ── 识别音域 ──
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

          // ── 显示范围 ──
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

          // ── 参考音 ──
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

          // ── 音阶选择 ──
          const Text(
            '音阶选择',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '选择音阶后，属于该音阶的音名会高亮显示在左侧刻度上',
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

          // ── 居中音名 ──
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
          const SizedBox(height: 28),

          // ── 技术说明 ──
          const Divider(height: 1),
          const SizedBox(height: 20),
          const Text(
            '技术说明',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildTechnicalNote(context),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 构建方法
  // ──────────────────────────────────────────────

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
            runSpacing: 4,
            children: PitchTraceController.visibleDurationStepsMs.map((ms) {
              final label = '${(ms / 1000).round()}秒';
              final isSelected = controller.visibleDurationMs == ms;
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => controller.setVisibleDurationMs(ms),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            '半音跨度',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: PitchTraceController.midiSpanSteps.map((span) {
              final label = '${span.round()}半音';
              final isSelected = controller.midiSpan == span;
              return ChoiceChip(
                label: Text(label),
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
    final lowNote = _noteLabelForFrequency(
      controller.minFrequency,
      controller.referenceA4Hz,
    );
    final highNote = _noteLabelForFrequency(
      controller.maxFrequency,
      controller.referenceA4Hz,
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
                '$lowNote ${controller.minFrequency.round()} Hz  —  '
                '$highNote ${controller.maxFrequency.round()} Hz',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          RangeSlider(
            values: values,
            min: PitchTraceController.minAllowedFrequency,
            max: PitchTraceController.maxAllowedFrequency,
            divisions: 252,
            labels: RangeLabels(
              '${controller.minFrequency.round()} Hz',
              '${controller.maxFrequency.round()} Hz',
            ),
            onChanged: (v) => controller.setFrequencyRange(v.start, v.end),
          ),
          Text(
            '拖动两端调整识别范围，长笛常用范围约 250–2500 Hz',
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

  String _noteLabelForFrequency(double frequency, double referenceA4Hz) {
    return PitchReading(
      frequency: frequency,
      amplitude: 0,
      clarity: 1,
      timestampMillis: 0,
    ).noteLabelFor(referenceA4Hz);
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
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: allScales.length,
              itemBuilder: (context, index) {
                final scale = allScales[index];
                final isSelected = scale == controller.scale;
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(scale.label),
                  selected: isSelected,
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

  Widget _buildColorThresholdSelector(PitchTraceController controller) {
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
              const Icon(Icons.palette, size: 16),
              const SizedBox(width: 6),
              const Text('绿色阈值（音准范围）', style: TextStyle(fontSize: 14)),
              const Spacer(),
              Text(
                '±${controller.greenThresholdCents.toStringAsFixed(0)}¢',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: controller.greenThresholdCents,
            min: 1,
            max: 20,
            divisions: 19,
            onChanged: (v) => controller.setGreenThresholdCents(v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.palette, size: 16),
              const SizedBox(width: 6),
              const Text('黄色阈值（轻微偏差）', style: TextStyle(fontSize: 14)),
              const Spacer(),
              Text(
                '±${controller.yellowThresholdCents.toStringAsFixed(0)}¢',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: controller.yellowThresholdCents,
            min: 5,
            max: 40,
            divisions: 35,
            onChanged: (v) => controller.setYellowThresholdCents(v),
          ),
          const SizedBox(height: 4),
          Text(
            '超过黄色阈值的偏差显示为红色',
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

  Widget _buildWindowSizeSelector(PitchTraceController controller) {
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
              const Icon(Icons.tune, size: 16),
              const SizedBox(width: 6),
              const Text('窗口大小', style: TextStyle(fontSize: 14)),
              const Spacer(),
              Text(
                '${controller.windowSize}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _windowSizeDescription(controller.windowSize),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.56),
            ),
          ),
          Wrap(
            spacing: 8,
            children: PitchTraceController.windowSizeSteps.map((size) {
              final isSelected = size == controller.windowSize;
              return ChoiceChip(
                label: Text('$size'),
                selected: isSelected,
                onSelected: (_) => controller.setWindowSize(size),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.tune, size: 16),
              const SizedBox(width: 6),
              const Text('重叠比例', style: TextStyle(fontSize: 14)),
              const Spacer(),
              Text(
                '${(controller.overlapRatio * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _overlapRatioDescription(controller.overlapRatio),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.56),
            ),
          ),
          Wrap(
            spacing: 8,
            children: PitchTraceController.overlapRatioSteps.map((ratio) {
              final isSelected = ratio == controller.overlapRatio;
              return ChoiceChip(
                label: Text('${(ratio * 100).toInt()}%'),
                selected: isSelected,
                onSelected: (_) => controller.setOverlapRatio(ratio),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Text(
            '当前采样率: ~${_estimatedSampleRate(controller.windowSize, controller.overlapRatio).toStringAsFixed(0)} 次/秒',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  String _windowSizeDescription(int size) {
    switch (size) {
      case 1024:
        return '极高采样密度，适合高音乐器';
      case 2048:
        return '默认，平衡精度和密度';
      case 4096:
        return '原始精度，适合低音乐器';
      case 8192:
        return '最高精度，适合极低音';
      default:
        return '';
    }
  }

  String _overlapRatioDescription(double ratio) {
    switch (ratio) {
      case 0.0:
        return '无重叠，最低CPU负载';
      case 0.25:
        return '轻度重叠';
      case 0.5:
        return '默认，采样密度翻倍';
      case 0.75:
        return '高重叠，最高密度';
      default:
        return '';
    }
  }

  double _estimatedSampleRate(int windowSize, double overlapRatio) {
    const sampleRate = 44100.0;
    final hopSize = windowSize * (1.0 - overlapRatio);
    return sampleRate / hopSize;
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
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isSelected = entry.key == currentMidi;
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(entry.value),
                  selected: isSelected,
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

  // ──────────────────────────────────────────────
  // 技术说明
  // ──────────────────────────────────────────────

  Widget _buildTechnicalNote(BuildContext context) {
    final textColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.7);
    const sectionStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.6,
    );
    const bodyStyle = TextStyle(fontSize: 13, height: 1.6);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DefaultTextStyle(
        style: bodyStyle.copyWith(color: textColor),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 颜色阈值说明 ──
            Text('颜色阈值', style: sectionStyle),
            SizedBox(height: 8),
            Text(
              '轨迹颜色基于音分偏差（cent）着色。音分是衡量音高偏差的'
              '对数单位：1 个半音 = 100 音分。',
            ),
            SizedBox(height: 8),
            Text(
              '• 绿色（±N¢）：偏差在此范围内视为音准良好，轨迹显示绿色。\n'
              '• 黄色（±M¢）：偏差超过绿色阈值但未超过黄色阈值，显示黄色。\n'
              '• 红色：偏差超过黄色阈值，显示红色，提示需要调整。',
            ),
            SizedBox(height: 8),
            Text(
              '阈值含义举例：\n'
              '• ±5¢ ≈ 非常严格的音准，接近专业演奏水平\n'
              '• ±10¢ ≈ 良好的音准，适合日常练习\n'
              '• ±15¢ ≈ 宽松的音准，初学者适用\n'
              '• ±25¢ ≈ 半个四分之一音，非常宽松',
            ),
            SizedBox(height: 8),
            Text(
              '绿色阈值范围 1~20¢，黄色阈值范围 5~40¢。'
              '系统会自动保证黄色阈值大于绿色阈值。',
            ),

            SizedBox(height: 20),
            Divider(height: 1),
            SizedBox(height: 20),

            // ── 检测精度说明 ──
            Text('检测精度', style: sectionStyle),
            SizedBox(height: 8),
            Text(
              '音高检测使用 YIN 算法（一种自相关基频检测算法）。'
              '算法每次分析一段音频"窗口"，计算其中的基频。',
            ),
            SizedBox(height: 8),
            Text(
              '窗口大小（样本数）\n'
              '决定每次分析的音频时长。44100 Hz 采样率下：\n'
              '• 1024 ≈ 23ms → 约 43 次/秒，适合高音，低音精度下降\n'
              '• 2048 ≈ 46ms → 约 21 次/秒，默认推荐\n'
              '• 4096 ≈ 93ms → 约 11 次/秒，低音检测精度高\n'
              '• 8192 ≈ 186ms → 约 5 次/秒，最高精度但采样稀疏',
            ),
            SizedBox(height: 8),
            Text(
              '为什么窗口大小影响低音精度？\n'
              'YIN 算法需要至少 2 个完整周期的波形才能准确检测基频。'
              '低音频率低、周期长，需要更大的窗口才能容纳足够周期。\n'
              '例如：C4（262Hz）周期约 3.8ms，2048 窗口（46ms）可容纳 '
              '~12 个周期，精度充足。但 C2（65Hz）周期约 15ms，'
              '2048 窗口仅容纳 ~3 个周期，可能不够稳定。',
            ),
            SizedBox(height: 8),
            Text(
              '重叠比例\n'
              '分析窗口之间的重叠程度。50% 重叠意味着每次前进窗口一半的'
              '距离就开始下一次分析，采样密度翻倍但不改变单次分析精度。\n'
              '• 0%：无重叠，每次前进整个窗口\n'
              '• 50%：默认，每次前进半个窗口，采样密度 ×2\n'
              '• 75%：高重叠，每次前进 1/4 窗口，采样密度 ×4',
            ),
            SizedBox(height: 8),
            Text(
              'CPU 负载：YIN 算法复杂度 O(n²)，n 为窗口大小。'
              '1024 窗口的计算量约为 4096 的 1/16。'
              '重叠比例增加会线性增加计算频率，但对现代手机影响很小。\n\n'
              '建议：\n'
              '• 长笛、人声（C4 以上）：2048 + 50% 重叠（默认）\n'
              '• 大提琴、低音提琴：4096 + 0% 重叠\n'
              '• 追求极致细腻轨迹：1024 + 75% 重叠',
            ),
          ],
        ),
      ),
    );
  }
}
