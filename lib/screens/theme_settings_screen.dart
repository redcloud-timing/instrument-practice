import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/theme_controller.dart';

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
    _hexController.text = ThemeController.colorToRgbString(
      context.read<ThemeController>().themeColor,
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Future<void> _applyAmbience(ThemeAmbience ambience) async {
    await context.read<ThemeController>().applyAmbience(ambience.id);
    if (!mounted) return;
    _hexController.text = ThemeController.colorToRgbString(ambience.seedColor);
    setState(() => _hexError = null);
  }

  Future<void> _applyHex() async {
    final text = _hexController.text.trim();
    if (text.isEmpty) {
      setState(() => _hexError = '请输入颜色代码');
      return;
    }

    final color = ThemeController.parseHex(text);
    if (color == null) {
      setState(() => _hexError = '无效颜色代码，例如：99FF99');
      return;
    }

    await context.read<ThemeController>().setThemeColor(color);
    if (!mounted) return;
    _hexController.text = ThemeController.colorToRgbString(color);
    setState(() => _hexError = null);
  }

  Future<void> _resetTheme() async {
    await context.read<ThemeController>().resetThemeDesign();
    if (!mounted) return;
    _hexController.text = ThemeController.colorToRgbString(
      context.read<ThemeController>().themeColor,
    );
    setState(() => _hexError = null);
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('主题设置'),
        actions: [
          IconButton(
            tooltip: '恢复默认',
            onPressed: _resetTheme,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            _ThemePreviewCard(controller: themeController),
            const SizedBox(height: 22),
            const _SectionHeader(
              icon: Icons.brightness_6_outlined,
              title: '显示模式',
            ),
            const SizedBox(height: 10),
            _ThemeModeSelector(controller: themeController),
            const SizedBox(height: 24),
            const _SectionHeader(icon: Icons.palette_outlined, title: '氛围预设'),
            const SizedBox(height: 10),
            _AmbienceGrid(
              selectedId: themeController.ambienceId,
              onSelected: _applyAmbience,
            ),
            const SizedBox(height: 24),
            const _SectionHeader(
              icon: Icons.filter_drama_outlined,
              title: '图片显现',
            ),
            const SizedBox(height: 10),
            _RevealStyleSelector(controller: themeController),
            const SizedBox(height: 24),
            const _SectionHeader(icon: Icons.tune_outlined, title: '自定义主色'),
            const SizedBox(height: 10),
            _CustomColorPanel(
              controller: _hexController,
              errorText: _hexError,
              onChanged: () {
                if (_hexError != null) {
                  setState(() => _hexError = null);
                }
              },
              onApply: _applyHex,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ambience = controller.ambience;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(ambience.icon, color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ambience.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ambience.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '#${ThemeController.colorToRgbString(controller.themeColor)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SwatchStrip(colors: ambience.swatches),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.56,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.72),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '练习计时',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: 0.62,
                            minHeight: 7,
                            backgroundColor: colorScheme.surface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(onPressed: () {}, child: const Text('开始')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      selected: {controller.themeMode},
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto_outlined),
          label: Text('系统'),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_outlined),
          label: Text('浅色'),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_outlined),
          label: Text('深色'),
        ),
      ],
      onSelectionChanged: (values) {
        controller.setThemeMode(values.first);
      },
    );
  }
}

class _AmbienceGrid extends StatelessWidget {
  const _AmbienceGrid({required this.selectedId, required this.onSelected});

  final String selectedId;
  final ValueChanged<ThemeAmbience> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ThemeAmbience.all.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: columns == 2 ? 1.08 : 1.18,
          ),
          itemBuilder: (context, index) {
            final ambience = ThemeAmbience.all[index];
            return _AmbienceCard(
              ambience: ambience,
              selected: selectedId == ambience.id,
              onTap: () => onSelected(ambience),
            );
          },
        );
      },
    );
  }
}

class _AmbienceCard extends StatelessWidget {
  const _AmbienceCard({
    required this.ambience,
    required this.selected,
    required this.onTap,
  });

  final ThemeAmbience ambience;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.52)
          : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          width: selected ? 1.8 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(ambience.icon, size: 20, color: ambience.seedColor),
                  const Spacer(),
                  if (selected)
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ambience.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                ambience.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              _SwatchDots(colors: ambience.swatches),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevealStyleSelector extends StatelessWidget {
  const _RevealStyleSelector({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.imageRevealProfile;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<PracticeImageRevealStyle>(
          showSelectedIcon: false,
          selected: {controller.imageRevealStyle},
          segments: [
            for (final style in PracticeImageRevealStyle.values)
              ButtonSegment(
                value: style,
                icon: const Icon(Icons.blur_on_outlined),
                label: Text(style.profile.label),
              ),
          ],
          onSelectionChanged: (values) {
            controller.setImageRevealStyle(values.first);
          },
        ),
        const SizedBox(height: 8),
        Text(
          profile.description,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _CustomColorPanel extends StatelessWidget {
  const _CustomColorPanel({
    required this.controller,
    required this.errorText,
    required this.onChanged,
    required this.onApply,
  });

  final TextEditingController controller;
  final String? errorText;
  final VoidCallback onChanged;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                maxLength: 8,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 18),
                decoration: InputDecoration(
                  prefixText: '#',
                  hintText: '99FF99',
                  errorText: errorText,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                onChanged: (_) => onChanged(),
                onSubmitted: (_) => onApply(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('应用'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(76, 50),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 7),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _SwatchStrip extends StatelessWidget {
  const _SwatchStrip({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Row(
          children: [
            for (final color in colors)
              Expanded(child: ColoredBox(color: color)),
          ],
        ),
      ),
    );
  }
}

class _SwatchDots extends StatelessWidget {
  const _SwatchDots({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final color in colors) ...[
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(width: 5),
        ],
      ],
    );
  }
}
