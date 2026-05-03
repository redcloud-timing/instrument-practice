import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/theme_controller.dart';

const _presetColors = <_PresetColor>[
  _PresetColor('嫩绿', Color(0xFF99FF99)),
  _PresetColor('青绿', Color(0xFF2E7D6B)),
  _PresetColor('蓝色', Color(0xFF42A5F5)),
  _PresetColor('紫色', Color(0xFFAB47BC)),
  _PresetColor('橙色', Color(0xFFFF7043)),
  _PresetColor('红色', Color(0xFFEF5350)),
  _PresetColor('绿色', Color(0xFF66BB6A)),
  _PresetColor('琥珀', Color(0xFFFFCA28)),
];

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  final _hexController = TextEditingController();
  String? _hexError;

  @override
  void initState() {
    super.initState();
    final currentColor = context.read<ThemeController>().themeColor;
    _hexController.text = _colorToHex(currentColor);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '$r$g$b'.toUpperCase();
  }

  void _applyColor(Color color) {
    context.read<ThemeController>().setThemeColor(color);
    _hexController.text = _colorToHex(color);
    setState(() => _hexError = null);
  }

  void _applyHex() {
    final text = _hexController.text.trim();
    if (text.isEmpty) {
      setState(() => _hexError = '请输入颜色代码');
      return;
    }

    final color = _parseHex(text);
    if (color == null) {
      setState(() => _hexError = '无效颜色代码，例如：99FF99');
      return;
    }

    _applyColor(color);
  }

  Color? _parseHex(String hex) {
    try {
      final cleaned = hex.replaceFirst('#', '');
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      }
      if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<ThemeController>().themeColor;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('主题设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: themeColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前主题色',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '#${_colorToHex(themeColor)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (themeColor != ThemeController.defaultColor)
                    TextButton(
                      onPressed: () =>
                          _applyColor(ThemeController.defaultColor),
                      child: const Text('恢复默认'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('预设颜色', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final preset in _presetColors)
                _PresetChip(
                  color: preset.color,
                  label: preset.label,
                  selected: themeColor == preset.color,
                  onTap: () => _applyColor(preset.color),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('自定义颜色', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hexController,
                  maxLength: 8,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    prefixText: '#',
                    hintText: '99FF99',
                    errorText: _hexError,
                    border: const OutlineInputBorder(),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (_) {
                    if (_hexError != null) {
                      setState(() => _hexError = null);
                    }
                  },
                  onSubmitted: (_) => _applyHex(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _applyHex,
                style: FilledButton.styleFrom(minimumSize: const Size(60, 50)),
                child: const Text('应用'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetColor {
  const _PresetColor(this.label, this.color);
  final String label;
  final Color color;
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.25),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
