import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/practice_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/library_item.dart';
import '../routes/app_routes.dart';
import '../services/document_library_service.dart';
import '../utils/app_date_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _editDailyRead(BuildContext context) async {
    await Navigator.pushNamed<void>(context, AppRoutes.dailyReadEdit);
  }

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

  void _openCalendar(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.calendar);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PracticeController>();
    final today = DateTime.now();
    final todayLog = controller.logForDate(today);
    final todaySavedSeconds = todayLog?.durationSeconds ?? 0;
    final activeStart = controller.activeTimerStart;
    final activeSecondsToday =
        activeStart != null &&
            AppDateUtils.dateKey(activeStart) == AppDateUtils.dateKey(today)
        ? controller.elapsedSeconds
        : 0;
    final todayPracticeSeconds = todaySavedSeconds + activeSecondsToday;

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          _PracticeTimerCard(
            elapsedSeconds: controller.elapsedSeconds,
            todayPracticeSeconds: todayPracticeSeconds,
            isRunning: controller.isTimerRunning,
            practiceImage: controller.homePracticeImage,
            onTimerPressed: () => _toggleTimer(context),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 112,
            child: Row(
              children: [
                Expanded(
                  child: _CalendarEntryCard(
                    streakDays: controller.streakDays,
                    pastDaysFlowers: controller.pastDaysFlowers,
                    onTap: () => _openCalendar(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TodaySummaryCard(
                    todaySeconds: todayPracticeSeconds,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.dayDetail,
                        arguments: AppDateUtils.dateOnly(today),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _DailyReadCard(
              text: controller.dailyRead,
              fontSize: controller.dailyReadFontSize,
              onEdit: () => _editDailyRead(context),
              onDecreaseFont: () => context
                  .read<PracticeController>()
                  .changeDailyReadFontSize(-1),
              onIncreaseFont: () =>
                  context.read<PracticeController>().changeDailyReadFontSize(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeTimerCard extends StatelessWidget {
  const _PracticeTimerCard({
    required this.elapsedSeconds,
    required this.todayPracticeSeconds,
    required this.isRunning,
    required this.practiceImage,
    required this.onTimerPressed,
  });

  final int elapsedSeconds;
  final int todayPracticeSeconds;
  final bool isRunning;
  final LibraryItem? practiceImage;
  final VoidCallback onTimerPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isRunning
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text('练习计时', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  '今日总计 ${AppDateUtils.formatDuration(todayPracticeSeconds)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 4, child: _buildTimerSection(context)),
                const SizedBox(width: 10),
                Expanded(flex: 6, child: _buildImageSection(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final over4h = isRunning && elapsedSeconds > 4 * 60 * 60;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppDateUtils.formatDuration(elapsedSeconds),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isRunning ? colorScheme.primary : null,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          isRunning ? '练习进行中' : '准备开始练习',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        if (over4h) ...[
          const SizedBox(height: 4),
          Text(
            '计时已超过 4 小时\n请确认是否忘记结束',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onTimerPressed,
            icon: Icon(isRunning ? Icons.stop : Icons.play_arrow, size: 17),
            label: Text(
              isRunning ? '结束记录' : '开始练习',
              style: const TextStyle(fontSize: 13),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(38),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: AspectRatio(
              aspectRatio: 32 / 30,
              child: _PracticeImageReveal(
                image: practiceImage,
                practiceSeconds: todayPracticeSeconds,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PracticeImageReveal extends StatefulWidget {
  const _PracticeImageReveal({
    required this.image,
    required this.practiceSeconds,
  });

  static const defaultAsset = 'assets/images/default_lotus_ink.png';

  final LibraryItem? image;
  final int practiceSeconds;

  @override
  State<_PracticeImageReveal> createState() => _PracticeImageRevealState();
}

class _PracticeImageRevealState extends State<_PracticeImageReveal> {
  final _documentService = DocumentLibraryService();
  Future<Uint8List>? _imageBytesFuture;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant _PracticeImageReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image?.uri != widget.image?.uri) {
      _loadImage();
    }
  }

  void _loadImage() {
    final image = widget.image;
    _imageBytesFuture = image == null
        ? null
        : _documentService.loadImageBytes(image);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (widget.practiceSeconds / (2 * 60 * 60))
        .clamp(0.0, 1.0)
        .toDouble();
    final eased = Curves.easeOutCubic.transform(progress);
    final revealProfile = context.watch<ThemeController>().imageRevealProfile;
    final imageOpacity =
        revealProfile.minOpacity + eased * (1.0 - revealProfile.minOpacity);
    final blurSigma = revealProfile.maxBlur * (1.0 - eased);
    final fogOpacity = revealProfile.maxFogOpacity * (1.0 - eased);
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(decoration: BoxDecoration(color: colorScheme.surface)),
          Opacity(
            opacity: imageOpacity,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: _buildImage(),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: fogOpacity),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final future = _imageBytesFuture;
    if (future == null) {
      return Image.asset(_PracticeImageReveal.defaultAsset, fit: BoxFit.cover);
    }

    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (snapshot.connectionState == ConnectionState.done &&
            bytes != null &&
            bytes.isNotEmpty) {
          return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
        }

        return Image.asset(
          _PracticeImageReveal.defaultAsset,
          fit: BoxFit.cover,
        );
      },
    );
  }
}

class _DailyReadCard extends StatelessWidget {
  const _DailyReadCard({
    required this.text,
    required this.fontSize,
    required this.onEdit,
    required this.onDecreaseFont,
    required this.onIncreaseFont,
  });

  final String text;
  final double fontSize;
  final VoidCallback onEdit;
  final VoidCallback onDecreaseFont;
  final VoidCallback onIncreaseFont;

  @override
  Widget build(BuildContext context) {
    final canDecrease = fontSize > PracticeController.dailyReadMinFontSize;
    final canIncrease = fontSize < PracticeController.dailyReadMaxFontSize;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_outlined, size: 16),
                const SizedBox(width: 4),
                Text('每日必读', style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                _DailyReadHeaderButton(
                  tooltip: '缩小字体',
                  icon: Icons.remove_circle_outline,
                  onPressed: canDecrease ? onDecreaseFont : null,
                ),
                SizedBox(
                  width: 24,
                  child: Text(
                    fontSize.round().toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                _DailyReadHeaderButton(
                  tooltip: '放大字体',
                  icon: Icons.add_circle_outline,
                  onPressed: canIncrease ? onIncreaseFont : null,
                ),
                _DailyReadHeaderButton(
                  tooltip: '编辑每日必读',
                  icon: Icons.edit_outlined,
                  onPressed: onEdit,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  text.isEmpty ? '点击右上角编辑每日必读。' : text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: fontSize,
                    height: 1.55,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyReadHeaderButton extends StatelessWidget {
  const _DailyReadHeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _CalendarEntryCard extends StatelessWidget {
  const _CalendarEntryCard({
    required this.streakDays,
    required this.pastDaysFlowers,
    required this.onTap,
  });

  final int streakDays;
  final List<int> pastDaysFlowers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text('练习日历', style: Theme.of(context).textTheme.labelLarge),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${today.month}.${today.day}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        _weekday(today.weekday),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      '连续 $streakDays 天',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    _FlowerTrail(stages: pastDaysFlowers),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _weekday(int wd) {
    const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return days[wd - 1];
  }
}

class _FlowerTrail extends StatelessWidget {
  const _FlowerTrail({required this.stages});

  final List<int> stages;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final stage in stages.take(5)) ...[
          Icon(
            stage >= 4
                ? Icons.local_florist
                : stage >= 0
                ? Icons.spa
                : Icons.circle_outlined,
            size: 13,
            color: stage >= 4
                ? colorScheme.primary
                : stage >= 0
                ? colorScheme.tertiary
                : colorScheme.outlineVariant,
          ),
          const SizedBox(width: 2),
        ],
      ],
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({required this.todaySeconds, required this.onTap});

  final int todaySeconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text('今日练习', style: Theme.of(context).textTheme.labelLarge),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  AppDateUtils.formatDuration(todaySeconds),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  todaySeconds > 0 ? '点击补充练习心得' : '今天还没有记录',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
