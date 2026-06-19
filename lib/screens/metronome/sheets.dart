import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/metronome_controller.dart';
import '../../models/metronome_preset.dart';

class BpmKeypadSheet extends StatefulWidget {
  const BpmKeypadSheet({super.key});

  @override
  State<BpmKeypadSheet> createState() => _BpmKeypadSheetState();
}

class _BpmKeypadSheetState extends State<BpmKeypadSheet> {
  late String _digits;

  @override
  void initState() {
    super.initState();
    _digits = '';
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
                _digits.isEmpty ? '--' : _digits,
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
                      child: KeypadButton(
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
                  child: KeypadButton(
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
                  child: KeypadButton(label: '0', onTap: () => _appendDigit(0)),
                ),
                Expanded(
                  child: KeypadButton(
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

class KeypadButton extends StatelessWidget {
  const KeypadButton({super.key, this.label, this.icon, required this.onTap});

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

class PresetSheet extends StatelessWidget {
  const PresetSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetronomeController>();

    return SheetScaffold(
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
              child: const Text('还没有保存的预设。先调好节拍，再点"保存当前节拍"。'),
            )
          else
            for (final preset in controller.savedPresets)
              PresetListTile(
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
      builder: (_) => const PresetNameSheet(),
    );

    if (name == null || !context.mounted) return;
    await context.read<MetronomeController>().saveCurrentPreset(name);
  }
}

class PresetListTile extends StatelessWidget {
  const PresetListTile({
    super.key,
    required this.preset,
    required this.selected,
  });

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

class PresetNameSheet extends StatefulWidget {
  const PresetNameSheet({super.key});

  @override
  State<PresetNameSheet> createState() => _PresetNameSheetState();
}

class _PresetNameSheetState extends State<PresetNameSheet> {
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

class PatternSheet extends StatefulWidget {
  const PatternSheet({super.key});

  @override
  State<PatternSheet> createState() => _PatternSheetState();
}

class _PatternSheetState extends State<PatternSheet> {
  late int _selectedCount;

  @override
  void initState() {
    super.initState();
    _selectedCount = context.read<MetronomeController>().beatsPerBar;
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
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

class SoundSheet extends StatelessWidget {
  const SoundSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MetronomeController>();

    return SheetScaffold(
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

class SheetScaffold extends StatelessWidget {
  const SheetScaffold({super.key, required this.title, required this.child});

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
