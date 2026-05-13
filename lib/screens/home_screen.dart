import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/practice_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/library_item.dart';
import '../services/document_library_service.dart';
import '../utils/app_date_utils.dart';
import 'calendar_screen.dart';
import 'daily_read_edit_screen.dart';
import 'day_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _editDailyRead(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const DailyReadEditScreen()),
    );
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CalendarScreen()),
    );
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DayDetailScreen(
                            date: AppDateUtils.dateOnly(today),
                          ),
                        ),
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

// ignore: unused_element
class _PracticeFlowerPainter extends CustomPainter {
  const _PracticeFlowerPainter({
    required this.growthStage,
    required this.colorFillProgress,
    required this.musicProgress,
    required this.waterProgress,
    required this.sunProgress,
    required this.themeColor,
  });

  final int growthStage;
  final double colorFillProgress;
  final double musicProgress;
  final double waterProgress;
  final double sunProgress;
  final Color themeColor;

  static const int _gridW = 32;
  static const int _gridH = 30;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final scene = _sceneRect(size);
    _drawVectorBackground(canvas, scene);
    _drawVectorScene(canvas, scene, _VectorFlowerPalette.gray());

    final fill = colorFillProgress.clamp(0.0, 1.0).toDouble();
    if (fill > 0) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(
          scene.left,
          scene.bottom - scene.height * fill,
          scene.right,
          scene.bottom,
        ),
      );
      _drawVectorScene(
        canvas,
        scene,
        _VectorFlowerPalette.fromTheme(themeColor),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  Rect _sceneRect(Size size) {
    const aspect = 100 / 94;
    final available = Offset.zero & size;
    if (available.width / available.height > aspect) {
      final width = available.height * aspect;
      final left = (available.width - width) / 2;
      return Rect.fromLTWH(left, 0, width, available.height);
    }
    final height = available.width / aspect;
    final top = (available.height - height) / 2;
    return Rect.fromLTWH(0, top, available.width, height);
  }

  void _drawVectorBackground(Canvas canvas, Rect scene) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(scene, Radius.circular(scene.width * 0.035)),
      Paint()..color = const Color(0xFFF7F7F7),
    );
  }

  void _drawVectorScene(
    Canvas canvas,
    Rect scene,
    _VectorFlowerPalette palette,
  ) {
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(scene, Radius.circular(scene.width * 0.035)),
    );
    _drawVectorFlower(canvas, scene, palette);
    _drawVectorMusicNotes(canvas, scene, palette);
    _drawVectorWater(canvas, scene, palette);
    _drawVectorSun(canvas, scene, palette);
    canvas.restore();
  }

  Offset _pt(Rect scene, double x, double y) {
    return Offset(
      scene.left + scene.width * x / 100,
      scene.top + scene.height * y / 94,
    );
  }

  double _u(Rect scene) => min(scene.width / 100, scene.height / 94);

  void _drawVectorFlower(
    Canvas canvas,
    Rect scene,
    _VectorFlowerPalette palette,
  ) {
    final unit = _u(scene);
    final stage = growthStage.clamp(0, 5).toInt();
    final waterY = 78.0;

    canvas.drawOval(
      Rect.fromCenter(
        center: _pt(scene, 50, 84),
        width: unit * 54,
        height: unit * 8,
      ),
      Paint()..color = palette.shadow,
    );

    _drawLotusWater(canvas, scene, palette, waterY);

    if (stage == 0) {
      final head = _pt(scene, 50, 61);
      _drawLotusCurvedStem(
        canvas,
        scene,
        palette,
        _pt(scene, 50, waterY + 1),
        head.translate(0, unit * 8),
        2.2,
      );
      _drawLotusBud(canvas, scene, palette, head, 0);
      return;
    }

    if (stage == 1) {
      _drawRaisedLotusLeaf(
        canvas,
        scene,
        palette,
        stemBase: _pt(scene, 50, waterY + 1),
        center: _pt(scene, 49, 49),
        width: 43,
        height: 20,
        rotation: -0.04,
        stemWidth: 2.9,
      );
      _drawRaisedLotusLeaf(
        canvas,
        scene,
        palette,
        stemBase: _pt(scene, 56, waterY + 1),
        center: _pt(scene, 65, 68),
        width: 20,
        height: 9,
        rotation: 0.22,
        stemWidth: 2.0,
      );
      return;
    }

    if (stage == 2) {
      _drawRaisedLotusLeaf(
        canvas,
        scene,
        palette,
        stemBase: _pt(scene, 49, waterY + 1),
        center: _pt(scene, 39, 48),
        width: 54,
        height: 24,
        rotation: -0.2,
        stemWidth: 3.0,
      );
      _drawRaisedLotusLeaf(
        canvas,
        scene,
        palette,
        stemBase: _pt(scene, 65, waterY + 1),
        center: _pt(scene, 70, 65),
        width: 28,
        height: 13,
        rotation: 0.1,
        stemWidth: 2.2,
      );
      return;
    }

    _drawRaisedLotusLeaf(
      canvas,
      scene,
      palette,
      stemBase: _pt(scene, 31, waterY + 2),
      center: _pt(scene, 27, stage >= 5 ? 61 : 64),
      width: stage >= 5 ? 40 : 36,
      height: stage >= 5 ? 17 : 16,
      rotation: -0.34,
      stemWidth: 2.2,
    );
    _drawRaisedLotusLeaf(
      canvas,
      scene,
      palette,
      stemBase: _pt(scene, 73, waterY + 2),
      center: _pt(scene, 74, stage >= 5 ? 64 : 70),
      width: stage >= 5 ? 34 : 26,
      height: stage >= 5 ? 15 : 12,
      rotation: 0.28,
      stemWidth: 2.0,
    );
    if (stage >= 4) {
      _drawLotusPad(
        canvas,
        scene,
        palette,
        _pt(scene, 50, 82),
        stage >= 5 ? 25 : 21,
        stage >= 5 ? 10 : 8,
        0.04,
      );
    }

    final head = _pt(scene, 50, switch (stage) {
      3 => 31.0,
      4 => 25.0,
      _ => 22.0,
    });
    _drawLotusCurvedStem(
      canvas,
      scene,
      palette,
      _pt(scene, 50, waterY + 1),
      head.translate(0, unit * (stage >= 5 ? 17 : 15)),
      stage >= 5 ? 2.9 : 2.6,
    );

    if (stage == 3) {
      _drawLotusBud(canvas, scene, palette, head, 1);
    } else if (stage == 4) {
      _drawLotusBud(canvas, scene, palette, head, 2);
    } else {
      _drawLotusBloom(canvas, scene, palette, head, 5);
    }
  }

  void _drawLotusCurvedStem(
    Canvas canvas,
    Rect scene,
    _VectorFlowerPalette palette,
    Offset start,
    Offset end,
    double width,
  ) {
    final unit = _u(scene);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx - unit * 5,
        start.dy - unit * 15,
        end.dx + unit * 5,
        end.dy + unit * 16,
        end.dx,
        end.dy,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.stem
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = unit * width,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.stemLight.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = unit * width * 0.32,
    );
  }

  void _drawLotusWater(
    Canvas canvas,
    Rect scene,
    _VectorFlowerPalette palette,
    double waterY,
  ) {
    final unit = _u(scene);
    for (final y in [waterY, waterY + 4.2, waterY + 8.0]) {
      final left = _pt(scene, 14, y);
      final right = _pt(scene, 86, y);
      final path = Path()
        ..moveTo(left.dx, left.dy)
        ..cubicTo(
          _pt(scene, 32, y - 3).dx,
          _pt(scene, 32, y - 3).dy,
          _pt(scene, 48, y + 3).dx,
          _pt(scene, 48, y + 3).dy,
          _pt(scene, 63, y).dx,
          _pt(scene, 63, y).dy,
        )
        ..cubicTo(
          _pt(scene, 72, y - 2).dx,
          _pt(scene, 72, y - 2).dy,
          _pt(scene, 80, y - 1).dx,
          _pt(scene, 80, y - 1).dy,
          right.dx,
          right.dy,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = palette.waterLight.withValues(alpha: 0.42)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = unit * 1.2,
      );
    }
  }

  void _drawLotusPad(
    Canvas canvas,
    Rect scene,
    _VectorFlowerPalette palette,
    Offset center,
    double width,
    double height,
    double rotation,
  ) {
    final unit = _u(scene);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: unit * width,
      height: unit * height,
    );
    canvas.drawOval(rect, Paint()..color = palette.leaf.withValues(alpha: 0.9));
    final notch = Path()
      ..moveTo(0, 0)
      ..lineTo(unit * width * 0.43, -unit * height * 0.18)
      ..quadraticBezierTo(
        unit * width * 0.25,
        0,
        unit * width * 0.43,
        unit * height * 0.18,
      )
      ..close();
    canvas.drawPath(
      notch,
      Paint()..color = const Color(0xFFF7F7F7).withValues(alpha: 0.55),
    );
    for (var i = -2; i <= 2; i++) {
      canvas.drawLine(
        Offset.zero,
        Offset(unit * width * 0.38, unit * height * i * 0.09),
        Paint()
          ..color = palette.leafLight.withValues(alpha: 0.55)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = unit * 0.8,
      );
    }
    canvas.restore();
  }

  void _drawRaisedLotusLeaf(
    Canvas canvas,
    Rect scene,
    _VectorFlowerPalette palette, {
    required Offset stemBase,
    required Offset center,
    required double width,
    required double height,
    required double rotation,
    required double stemWidth,
  }) {
    _drawLotusCurvedStem(
      canvas,
      scene,
      palette,
      stemBase,
      center.translate(0, _u(scene) * height * 0.25),
      stemWidth,
    );
    _drawLotusPad(canvas, scene, palette, center, width, height, rotation);
  }

  // ignore: unused_element
  void _drawLotusHead(
    Canvas canvas,
    Rect scene,
    _VectorFlowerPalette palette,
    Offset center,
    int stage,
  ) {
    if (stage <= 1) {
      _drawLotusBud(canvas, scene, palette, center, stage);
      return;
    }
    _drawLotusBloom(canvas, scene, palette, center, stage);
  }

  void _drawLotusBud(
    Canvas canvas,
    Rect scene,
    _VectorFlowerPalette palette,
    Offset center,
    int stage,
  ) {
    final unit = _u(scene);
    final scale = switch (stage) {
      0 => 0.66,
      1 => 0.92,
      _ => 1.22,
    };
    final height = unit * (24 * scale);
    final width = unit * (13 * scale);
    final baseY = center.dy + height * 0.45;
    final tip = Offset(center.dx, center.dy - height * 0.58);

    final outer = Path()
      ..moveTo(center.dx, baseY)
      ..cubicTo(
        center.dx - width,
        center.dy + height * 0.1,
        center.dx - width * 0.55,
        center.dy - height * 0.35,
        tip.dx,
        tip.dy,
      )
      ..cubicTo(
        center.dx + width * 0.55,
        center.dy - height * 0.35,
        center.dx + width,
        center.dy + height * 0.1,
        center.dx,
        baseY,
      )
      ..close();
    canvas.drawPath(outer, Paint()..color = palette.petalShadow);

    final left = Path()
      ..moveTo(center.dx - unit * 0.4, baseY - unit)
      ..cubicTo(
        center.dx - width * 0.82,
        center.dy + height * 0.05,
        center.dx - width * 0.38,
        center.dy - height * 0.36,
        tip.dx,
        tip.dy,
      )
      ..cubicTo(
        center.dx - width * 0.16,
        center.dy - height * 0.1,
        center.dx - width * 0.14,
        center.dy + height * 0.18,
        center.dx - unit * 0.4,
        baseY - unit,
      )
      ..close();
    canvas.drawPath(left, Paint()..color = palette.petal);

    final right = Path()
      ..moveTo(center.dx + unit * 0.4, baseY - unit)
      ..cubicTo(
        center.dx + width * 0.82,
        center.dy + height * 0.05,
        center.dx + width * 0.38,
        center.dy - height * 0.36,
        tip.dx,
        tip.dy,
      )
      ..cubicTo(
        center.dx + width * 0.16,
        center.dy - height * 0.1,
        center.dx + width * 0.14,
        center.dy + height * 0.18,
        center.dx + unit * 0.4,
        baseY - unit,
      )
      ..close();
    canvas.drawPath(
      right,
      Paint()..color = palette.petalLight.withValues(alpha: 0.88),
    );

    canvas.drawCircle(
      Offset(center.dx, baseY),
      unit * (stage == 0 ? 3.0 : 3.7),
      Paint()..color = palette.leaf,
    );
  }

  void _drawLotusBloom(
    Canvas canvas,
    Rect scene,
    _VectorFlowerPalette palette,
    Offset center,
    int stage,
  ) {
    final unit = _u(scene);
    final openness = switch (stage) {
      2 => 0.55,
      3 => 0.78,
      _ => 1.0,
    };
    final base = center.translate(0, unit * (14 - stage * 1.4));
    final layers = <_LotusPetalSpec>[
      _LotusPetalSpec(-58, 13, 19, 10, 0, palette.petalShadow),
      _LotusPetalSpec(58, 13, 19, 10, 0, palette.petalShadow),
      _LotusPetalSpec(-34, 8, 24, 11, -0.28, palette.petal),
      _LotusPetalSpec(34, 8, 24, 11, 0.28, palette.petal),
      _LotusPetalSpec(0, 3, 27, 12, 0, palette.petalLight),
      _LotusPetalSpec(-72, 20, 17, 8.5, -0.38, palette.petalShadow),
      _LotusPetalSpec(72, 20, 17, 8.5, 0.38, palette.petalShadow),
    ];

    for (final spec in layers) {
      if (stage == 2 && spec.angle.abs() > 60) continue;
      final angle = spec.angle * openness;
      final length = unit * spec.length * openness;
      final width = unit * spec.width * (0.72 + openness * 0.28);
      final tip = base.translate(
        sin(angle * pi / 180) * unit * (15 + spec.lift) * openness,
        -cos(angle * pi / 180) * length,
      );
      _drawLotusPetal(
        canvas,
        base.translate(0, unit * spec.lift),
        tip,
        width,
        spec.color,
        spec.tilt,
      );
    }

    if (stage >= 3) {
      for (final spec in [
        _LotusPetalSpec(-24, -2, 20, 8, -0.18, palette.petalLight),
        _LotusPetalSpec(24, -2, 20, 8, 0.18, palette.petal),
        _LotusPetalSpec(0, -5, 22, 8.5, 0, palette.petalLight),
      ]) {
        final angle = spec.angle * openness;
        final tip = base.translate(
          sin(angle * pi / 180) * unit * 9 * openness,
          -cos(angle * pi / 180) * unit * spec.length * openness,
        );
        _drawLotusPetal(
          canvas,
          base.translate(0, unit * spec.lift),
          tip,
          unit * spec.width,
          spec.color,
          spec.tilt,
        );
      }
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(0, -unit * (stage >= 4 ? 3.4 : 1.8)),
        width: unit * (stage >= 4 ? 12 : 8),
        height: unit * (stage >= 4 ? 7 : 5),
      ),
      Paint()..color = palette.center,
    );
    if (stage >= 4) {
      for (var i = 0; i < 9; i++) {
        final angle = i * 2 * pi / 9;
        canvas.drawCircle(
          base.translate(
            cos(angle) * unit * 4.2,
            -unit * 3.4 + sin(angle) * unit * 2.0,
          ),
          unit * 0.65,
          Paint()..color = palette.centerDot,
        );
      }
    }
  }

  void _drawLotusPetal(
    Canvas canvas,
    Offset base,
    Offset tip,
    double width,
    Color color,
    double tilt,
  ) {
    final dx = tip.dx - base.dx;
    final dy = tip.dy - base.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final nx = -dy / len;
    final ny = dx / len;
    final leftControl = Offset(
      base.dx + dx * 0.34 + nx * width * (0.92 + tilt),
      base.dy + dy * 0.48 + ny * width * (0.92 + tilt),
    );
    final rightControl = Offset(
      base.dx + dx * 0.34 - nx * width * (0.92 - tilt),
      base.dy + dy * 0.48 - ny * width * (0.92 - tilt),
    );
    final path = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(leftControl.dx, leftControl.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(rightControl.dx, rightControl.dy, base.dx, base.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(
          base.dx + dx * 0.42,
          base.dy + dy * 0.48,
          tip.dx,
          tip.dy,
        ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width * 0.08,
    );
  }

  void _drawVectorMusicNotes(
    Canvas canvas,
    Rect scene,
    _VectorFlowerPalette palette,
  ) {
    if (musicProgress <= 0) return;
    final unit = _u(scene);
    final fade = (1.0 - musicProgress).clamp(0.0, 1.0);
    final notes = <_VectorNoteSpec>[
      _VectorNoteSpec(15, 28, 0.00, 1.00, 1, 0),
      _VectorNoteSpec(26, 17, 0.10, 0.82, 0, 1),
      _VectorNoteSpec(70, 19, 0.04, 0.86, 2, 2),
      _VectorNoteSpec(82, 31, 0.14, 0.78, 1, 3),
      _VectorNoteSpec(30, 39, 0.20, 0.72, 3, 4),
      _VectorNoteSpec(76, 45, 0.28, 0.66, 0, 5),
    ];

    for (final note in notes) {
      final local = (musicProgress - note.delay).clamp(0.0, 1.0);
      final alpha = (fade * (0.55 + local * 0.45)).clamp(0.0, 1.0);
      if (alpha <= 0) continue;
      final sway = sin((musicProgress + note.delay) * pi * 2) * unit * 2.2;
      final center = _pt(scene, note.x, note.y - local * 13).translate(sway, 0);
      final color = palette
          .noteColors[note.colorIndex % palette.noteColors.length]
          .withValues(alpha: alpha);
      _drawVectorNote(canvas, center, unit * note.scale, color, note.kind);
    }
  }

  void _drawVectorNote(
    Canvas canvas,
    Offset center,
    double unit,
    Color color,
    int kind,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = unit * 0.55
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (kind == 2) {
      final left = center.translate(-unit * 2.0, unit * 2.2);
      final right = center.translate(unit * 2.0, unit * 1.6);
      canvas.drawOval(
        Rect.fromCenter(center: left, width: unit * 3.0, height: unit * 2.0),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: right, width: unit * 3.0, height: unit * 2.0),
        paint,
      );
      canvas.drawLine(
        left.translate(unit * 1.0, 0),
        left.translate(unit * 1.0, -unit * 7.0),
        stroke,
      );
      canvas.drawLine(
        right.translate(unit * 1.0, 0),
        right.translate(unit * 1.0, -unit * 7.0),
        stroke,
      );
      canvas.drawLine(
        left.translate(unit * 1.0, -unit * 7.0),
        right.translate(unit * 1.0, -unit * 7.0),
        stroke..strokeWidth = unit * 0.9,
      );
      return;
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, unit * 2.2),
        width: unit * 3.1,
        height: unit * 2.0,
      ),
      paint,
    );
    canvas.drawLine(
      center.translate(unit * 1.1, unit * 2.0),
      center.translate(unit * 1.1, -unit * 5.5),
      stroke,
    );

    if (kind == 0) return;
    if (kind == 3) {
      canvas.drawArc(
        Rect.fromCenter(
          center: center.translate(unit * 2.1, -unit * 2.3),
          width: unit * 4.2,
          height: unit * 3.4,
        ),
        -pi * 0.78,
        pi * 1.08,
        false,
        stroke,
      );
      return;
    }

    final flag = Path()
      ..moveTo(center.dx + unit * 1.1, center.dy - unit * 5.5)
      ..quadraticBezierTo(
        center.dx + unit * 4.3,
        center.dy - unit * 3.8,
        center.dx + unit * 2.6,
        center.dy - unit * 1.2,
      )
      ..quadraticBezierTo(
        center.dx + unit * 2.1,
        center.dy - unit * 2.7,
        center.dx + unit * 1.1,
        center.dy - unit * 2.6,
      )
      ..close();
    canvas.drawPath(flag, paint);
  }

  void _drawVectorWater(
    Canvas canvas,
    Rect scene,
    _VectorFlowerPalette palette,
  ) {
    if (waterProgress <= 0) return;
    final unit = _u(scene);
    final alpha = (sin(waterProgress * pi) * 1.15).clamp(0.0, 1.0);
    final pivot = _pt(scene, 20, 18);

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(-0.22 + sin(waterProgress * pi) * 0.14);
    canvas.translate(-pivot.dx, -pivot.dy);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: _pt(scene, 20, 20),
        width: unit * 12,
        height: unit * 8,
      ),
      Radius.circular(unit * 2),
    );
    final paint = Paint()..color = palette.can.withValues(alpha: alpha);
    canvas.drawRRect(body, paint);
    canvas.drawRect(
      Rect.fromLTWH(
        _pt(scene, 25, 17.6).dx,
        _pt(scene, 25, 17.6).dy,
        unit * 10,
        unit * 2.4,
      ),
      paint,
    );
    canvas.drawCircle(
      _pt(scene, 16, 20),
      unit * 3.0,
      Paint()
        ..color = palette.can.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 1.2,
    );
    canvas.restore();

    final streamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = unit * 1.2;
    for (var i = 0; i < 3; i++) {
      final phase = i * 0.14;
      final travel = (waterProgress + phase).clamp(0.0, 1.0);
      final offset = (i - 1) * 1.2;
      final path = Path()
        ..moveTo(_pt(scene, 34, 20 + offset).dx, _pt(scene, 34, 20 + offset).dy)
        ..cubicTo(
          _pt(scene, 41, 24 + offset).dx,
          _pt(scene, 41, 24 + offset).dy,
          _pt(scene, 47, 32 + offset).dx,
          _pt(scene, 47, 32 + offset).dy,
          _pt(scene, 49, 43 + offset).dx,
          _pt(scene, 49, 43 + offset).dy,
        );
      final metric = path.computeMetrics().first;
      final end = metric.length * travel;
      final start = max(0.0, end - metric.length * 0.48);
      if (end <= 0) continue;
      canvas.drawPath(
        metric.extractPath(start, end),
        streamPaint
          ..color = (i.isEven ? palette.waterLight : palette.water).withValues(
            alpha: alpha,
          ),
      );
    }
  }

  void _drawVectorSun(Canvas canvas, Rect scene, _VectorFlowerPalette palette) {
    if (sunProgress <= 0) return;
    final unit = _u(scene);
    final alpha = (1.0 - sunProgress).clamp(0.0, 1.0);
    final center = _pt(scene, 78, 18 + (1 - sunProgress) * 6);
    final radius = unit * 5.5;
    final paint = Paint()..color = palette.sun.withValues(alpha: alpha);
    final rayPaint = Paint()
      ..color = palette.sun.withValues(alpha: alpha * 0.75)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = unit * 1.2;
    for (var i = 0; i < 12; i++) {
      final angle = i * 2 * pi / 12;
      canvas.drawLine(
        center.translate(
          cos(angle) * radius * 1.35,
          sin(angle) * radius * 1.35,
        ),
        center.translate(
          cos(angle) * (radius * 1.35 + unit * 5 * sunProgress),
          sin(angle) * (radius * 1.35 + unit * 5 * sunProgress),
        ),
        rayPaint,
      );
    }
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(
      center.translate(-unit * 1.5, -unit * 1.5),
      radius * 0.45,
      Paint()..color = palette.sunLight.withValues(alpha: alpha),
    );
  }

  // ignore: unused_element
  void _drawBackground(
    Canvas canvas,
    double ox,
    double oy,
    double ps,
    Size size,
  ) {
    final bgRect = Rect.fromLTWH(ox, oy, _gridW * ps, _gridH * ps);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, Radius.circular(ps * 0.8)),
      Paint()..color = const Color(0xFFF5F5F5),
    );
  }

  // ignore: unused_element
  _BwColors _bwColors() {
    return const _BwColors(
      black: Color(0xFF1A1A1A),
      dark: Color(0xFF555555),
      mid: Color(0xFF999999),
      light: Color(0xFFCCCCCC),
      white: Color(0xFFF0F0F0),
    );
  }

  // ignore: unused_element
  _ColorPalette _colorPalette() {
    final hsl = HSLColor.fromColor(themeColor);
    final h = hsl.hue;
    return _ColorPalette(
      stem: HSLColor.fromAHSL(1, (h + 80) % 360, 0.55, 0.38).toColor(),
      leaf: HSLColor.fromAHSL(1, (h + 70) % 360, 0.60, 0.48).toColor(),
      leafLight: HSLColor.fromAHSL(1, (h + 65) % 360, 0.55, 0.62).toColor(),
      petal: HSLColor.fromAHSL(1, h, 0.65, 0.70).toColor(),
      petalShadow: HSLColor.fromAHSL(1, h, 0.55, 0.55).toColor(),
      petalDark: HSLColor.fromAHSL(1, (h + 10) % 360, 0.50, 0.42).toColor(),
      center: HSLColor.fromAHSL(1, (h + 35) % 360, 0.80, 0.62).toColor(),
      canBody: HSLColor.fromAHSL(1, (h + 160) % 360, 0.40, 0.55).toColor(),
      water: const Color(0xFF42A5F5),
      waterLight: const Color(0xFF81D4FA),
      sunBody: const Color(0xFFFFC928),
      sunLight: const Color(0xFFFFF176),
    );
  }

  // ignore: unused_element
  void _drawFlower(
    void Function(int gx, int gy, Color bw, Color cl) px,
    _BwColors bw,
    _ColorPalette cl,
  ) {
    final stage = growthStage.clamp(0, 4).toInt();
    final headY = switch (stage) {
      0 => 15,
      1 => 13,
      2 => 11,
      3 => 9,
      _ => 8,
    };

    _drawSingleStem(px, bw, cl, headY);
    _drawSingleLeaves(px, bw, cl, stage);
    _drawFlowerHead(px, bw, cl, stage, 16, headY);
    _drawFlowerStemBase(px, bw, cl);
  }

  void _drawSingleStem(
    void Function(int gx, int gy, Color bw, Color cl) px,
    _BwColors bw,
    _ColorPalette cl,
    int headY,
  ) {
    for (var y = headY + 3; y <= 25; y++) {
      px(15, y, bw.dark, cl.stem);
      px(16, y, bw.light, cl.stem);
    }
  }

  void _drawSingleLeaves(
    void Function(int gx, int gy, Color bw, Color cl) px,
    _BwColors bw,
    _ColorPalette cl,
    int stage,
  ) {
    final lowLeafY = stage >= 2 ? 19 : 21;
    _drawLeaf(px, bw, cl, left: true, stemX: 15, stemY: lowLeafY, length: 5);
    _drawLeaf(
      px,
      bw,
      cl,
      left: false,
      stemX: 16,
      stemY: lowLeafY - 2,
      length: 5,
    );

    if (stage >= 2) {
      _drawLeaf(px, bw, cl, left: true, stemX: 15, stemY: 16, length: 4);
    }
    if (stage >= 3) {
      _drawLeaf(px, bw, cl, left: false, stemX: 16, stemY: 14, length: 4);
    }
  }

  void _drawLeaf(
    void Function(int gx, int gy, Color bw, Color cl) px,
    _BwColors bw,
    _ColorPalette cl, {
    required bool left,
    required int stemX,
    required int stemY,
    required int length,
  }) {
    final dir = left ? -1 : 1;
    for (var i = 1; i <= length; i++) {
      final x = stemX + dir * i;
      final y = stemY - i ~/ 2;
      px(
        x,
        y,
        i == length ? bw.dark : bw.light,
        i == 1 ? cl.leafLight : cl.leaf,
      );
      if (i > 1 && i < length) {
        px(x, y + 1, bw.dark, cl.leaf);
      }
    }
    px(stemX + dir, stemY, bw.light, cl.leafLight);
  }

  void _drawFlowerStemBase(
    void Function(int gx, int gy, Color bw, Color cl) px,
    _BwColors bw,
    _ColorPalette cl,
  ) {
    for (var x = 13; x <= 18; x++) {
      px(x, 26, bw.mid, cl.leaf);
    }
    for (var x = 14; x <= 17; x++) {
      px(x, 27, bw.dark, cl.stem);
    }
  }

  void _drawFlowerHead(
    void Function(int gx, int gy, Color bw, Color cl) px,
    _BwColors bw,
    _ColorPalette cl,
    int stage,
    int cx,
    int cy,
  ) {
    final petal = cl.petal;
    final shadow = cl.petalShadow;
    final dark = cl.petalDark;
    final center = cl.center;
    final petalLight = cl.petalLight();

    void block(int x1, int y1, int x2, int y2, Color gray, Color color) {
      for (var x = x1; x <= x2; x++) {
        for (var y = y1; y <= y2; y++) {
          px(x, y, gray, color);
        }
      }
    }

    if (stage == 0) {
      block(cx - 1, cy - 2, cx + 1, cy - 1, bw.white, petalLight);
      block(cx - 2, cy, cx - 1, cy + 1, bw.light, petal);
      block(cx + 1, cy, cx + 2, cy + 1, bw.light, petal);
      block(cx - 1, cy + 1, cx + 1, cy + 2, bw.mid, shadow);
      px(cx, cy, bw.white, center);
      return;
    }

    if (stage == 1) {
      block(cx - 1, cy - 4, cx + 1, cy - 2, bw.white, petalLight);
      block(cx - 4, cy - 1, cx - 2, cy + 1, bw.light, petal);
      block(cx + 2, cy - 1, cx + 4, cy + 1, bw.light, petal);
      block(cx - 1, cy + 2, cx + 1, cy + 4, bw.mid, shadow);
      block(cx - 1, cy - 1, cx + 1, cy + 1, bw.white, center);
      px(cx, cy, bw.light, center);
      return;
    }

    final radius = stage == 2
        ? 5
        : stage == 3
        ? 6
        : 7;
    block(cx - 2, cy - radius, cx + 2, cy - radius + 2, bw.white, petalLight);
    block(cx - radius, cy - 2, cx - radius + 2, cy + 2, bw.light, petal);
    block(cx + radius - 2, cy - 2, cx + radius, cy + 2, bw.light, petal);
    block(cx - 2, cy + radius - 2, cx + 2, cy + radius, bw.dark, shadow);

    block(cx - radius + 1, cy - radius + 1, cx - 3, cy - 3, bw.white, petal);
    block(cx + 3, cy - radius + 1, cx + radius - 1, cy - 3, bw.white, petal);
    block(cx - radius + 1, cy + 3, cx - 3, cy + radius - 1, bw.dark, shadow);
    block(cx + 3, cy + 3, cx + radius - 1, cy + radius - 1, bw.dark, shadow);

    if (stage >= 3) {
      block(
        cx - 1,
        cy - radius - 1,
        cx + 1,
        cy - radius - 1,
        bw.white,
        petalLight,
      );
      block(cx - radius - 1, cy - 1, cx - radius - 1, cy + 1, bw.mid, dark);
      block(cx + radius + 1, cy - 1, cx + radius + 1, cy + 1, bw.mid, dark);
      block(cx - 1, cy + radius + 1, cx + 1, cy + radius + 1, bw.black, dark);
    }

    if (stage >= 4) {
      block(
        cx - 3,
        cy - radius + 1,
        cx + 3,
        cy - radius + 1,
        bw.white,
        petalLight,
      );
      block(cx - radius + 1, cy - 3, cx - radius + 1, cy + 3, bw.light, petal);
      block(cx + radius - 1, cy - 3, cx + radius - 1, cy + 3, bw.light, petal);
      block(cx - 4, cy + 4, cx - 2, cy + 5, bw.black, dark);
      block(cx + 2, cy + 4, cx + 4, cy + 5, bw.black, dark);
    }

    block(cx - 2, cy - 2, cx + 2, cy + 2, bw.white, center);
    block(cx - 1, cy - 1, cx + 1, cy + 1, bw.light, center);
    px(cx, cy, bw.white, cl.centerHighlight());
  }

  // ignore: unused_element
  void _drawMusicNotes(
    Canvas canvas,
    double ox,
    double oy,
    double ps,
    double progress,
  ) {
    if (progress <= 0) return;
    final fade = (1.0 - progress).clamp(0.0, 1.0);
    final notes =
        <
          ({
            double x,
            double y,
            double delay,
            double scale,
            int kind,
            Color color,
          })
        >[
          (
            x: 5.0,
            y: 9.0,
            delay: 0.00,
            scale: 1.00,
            kind: 1,
            color: const Color(0xFFE91E63),
          ),
          (
            x: 9.0,
            y: 5.5,
            delay: 0.10,
            scale: 0.82,
            kind: 0,
            color: const Color(0xFF42A5F5),
          ),
          (
            x: 21.5,
            y: 6.4,
            delay: 0.04,
            scale: 0.84,
            kind: 2,
            color: const Color(0xFFFFB300),
          ),
          (
            x: 26.0,
            y: 10.0,
            delay: 0.14,
            scale: 0.78,
            kind: 1,
            color: const Color(0xFF7E57C2),
          ),
          (
            x: 12.5,
            y: 12.0,
            delay: 0.20,
            scale: 0.70,
            kind: 3,
            color: const Color(0xFF26A69A),
          ),
          (
            x: 24.0,
            y: 14.5,
            delay: 0.28,
            scale: 0.65,
            kind: 0,
            color: const Color(0xFFFF7043),
          ),
        ];

    for (final note in notes) {
      final local = (progress - note.delay).clamp(0.0, 1.0);
      final alpha = (fade * (0.55 + local * 0.45)).clamp(0.0, 1.0);
      if (alpha <= 0) continue;
      final sway = sin((progress + note.delay) * pi * 2) * ps * 0.8;
      final center = Offset(
        ox + note.x * ps + sway,
        oy + (note.y - local * 5.0) * ps,
      );
      _drawNote(
        canvas,
        center,
        ps * note.scale,
        note.color.withValues(alpha: alpha),
        note.kind,
      );
    }
  }

  void _drawNote(
    Canvas canvas,
    Offset center,
    double ps,
    Color color,
    int kind,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stemPaint = Paint()
      ..color = color
      ..strokeWidth = ps * 0.32
      ..strokeCap = StrokeCap.round;

    if (kind == 2) {
      final left = center.translate(-ps * 0.8, 0);
      final right = center.translate(ps * 0.9, -ps * 0.15);
      canvas.drawOval(
        Rect.fromCenter(
          center: left.translate(0, ps * 1.2),
          width: ps * 1.15,
          height: ps * 0.82,
        ),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: right.translate(0, ps * 1.2),
          width: ps * 1.15,
          height: ps * 0.82,
        ),
        paint,
      );
      canvas.drawLine(
        left.translate(ps * 0.45, ps * 1.05),
        left.translate(ps * 0.45, -ps * 1.25),
        stemPaint,
      );
      canvas.drawLine(
        right.translate(ps * 0.45, ps * 1.05),
        right.translate(ps * 0.45, -ps * 1.25),
        stemPaint,
      );
      canvas.drawLine(
        left.translate(ps * 0.45, -ps * 1.25),
        right.translate(ps * 0.45, -ps * 1.25),
        stemPaint..strokeWidth = ps * 0.48,
      );
      return;
    }

    if (kind == 3) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(-ps * 0.25, ps * 1.12),
          width: ps * 1.18,
          height: ps * 0.84,
        ),
        paint,
      );
      canvas.drawLine(
        center.translate(ps * 0.35, ps * 1.0),
        center.translate(ps * 0.35, -ps * 1.35),
        stemPaint,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: center.translate(ps * 0.95, -ps * 0.52),
          width: ps * 1.55,
          height: ps * 1.3,
        ),
        -pi * 0.78,
        pi * 1.08,
        false,
        stemPaint,
      );
      return;
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, ps * 1.15),
        width: ps * 1.35,
        height: ps * 0.92,
      ),
      paint,
    );
    canvas.drawLine(
      center.translate(ps * 0.55, ps * 1.05),
      center.translate(ps * 0.55, -ps * 1.35),
      stemPaint,
    );
    if (kind == 0) return;

    final flag = Path()
      ..moveTo(center.dx + ps * 0.55, center.dy - ps * 1.35)
      ..quadraticBezierTo(
        center.dx + ps * 1.7,
        center.dy - ps * 0.95,
        center.dx + ps * 1.15,
        center.dy - ps * 0.25,
      )
      ..quadraticBezierTo(
        center.dx + ps * 0.95,
        center.dy - ps * 0.65,
        center.dx + ps * 0.55,
        center.dy - ps * 0.65,
      )
      ..close();
    canvas.drawPath(flag, paint);
  }

  // ignore: unused_element
  void _drawWateringCan(
    Canvas canvas,
    double ox,
    double oy,
    double ps,
    double progress,
    _BwColors bw,
    _ColorPalette cl,
  ) {
    if (progress <= 0) return;
    final alpha = (sin(progress * pi) * 1.2).clamp(0.0, 1.0);
    final canColor = colorFillProgress > 0.35 ? cl.canBody : bw.dark;
    final paint = Paint()..color = canColor.withValues(alpha: alpha);

    final tilt = -0.24 + sin(progress * pi) * 0.18;
    final cx = ox + 5.8 * ps;
    final cy = oy + 4.0 * ps;

    canvas.save();
    canvas.translate(cx + 2.4 * ps, cy + 1.6 * ps);
    canvas.rotate(tilt);
    canvas.translate(-cx - 2.4 * ps, -cy - 1.6 * ps);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx, cy, 4.8 * ps, 3.4 * ps),
        Radius.circular(ps * 0.45),
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx + 4.2 * ps, cy + 0.8 * ps, 3.0 * ps, ps),
      paint,
    );
    canvas.drawCircle(
      Offset(cx + 1.0 * ps, cy + 1.4 * ps),
      ps * 1.0,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ps * 0.45
        ..color = paint.color,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx + 1.6 * ps, cy - 0.8 * ps, 1.8 * ps, ps * 0.7),
      paint,
    );
    canvas.restore();
  }

  // ignore: unused_element
  void _drawWaterStream(
    Canvas canvas,
    double ox,
    double oy,
    double ps,
    double progress,
    _ColorPalette cl,
  ) {
    final alpha = (sin(progress * pi) * 1.15).clamp(0.0, 1.0);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = ps * 0.46
      ..color = cl.water.withValues(alpha: alpha);

    final streams = <({double offset, double phase, Color color})>[
      (offset: -0.32, phase: 0.00, color: cl.waterLight),
      (offset: 0.00, phase: 0.14, color: cl.water),
      (offset: 0.34, phase: 0.26, color: cl.waterLight),
    ];

    for (final stream in streams) {
      final path = Path()
        ..moveTo(ox + 13.1 * ps, oy + (6.0 + stream.offset) * ps)
        ..cubicTo(
          ox + 15.0 * ps,
          oy + (7.3 + stream.offset) * ps,
          ox + 16.5 * ps,
          oy + (10.2 + stream.offset) * ps,
          ox + 16.2 * ps,
          oy + (13.5 + stream.offset) * ps,
        );
      final metric = path.computeMetrics().first;
      final travel = (progress + stream.phase).clamp(0.0, 1.0);
      final end = metric.length * travel;
      final start = max(0.0, end - metric.length * 0.45);
      if (end <= 0) continue;
      canvas.drawPath(
        metric.extractPath(start, end),
        basePaint..color = stream.color.withValues(alpha: alpha),
      );
    }
  }

  // ignore: unused_element
  void _drawSun(
    Canvas canvas,
    double ox,
    double oy,
    double ps,
    double progress,
    _ColorPalette cl,
  ) {
    if (progress <= 0) return;
    final alpha = (1.0 - progress).clamp(0.0, 1.0);
    final sunColor = cl.sunBody;
    final paint = Paint()..color = sunColor.withValues(alpha: alpha);
    final lightPaint = Paint()..color = cl.sunLight.withValues(alpha: alpha);

    final sx = ox + 24 * ps;
    final sy = oy + 1.5 * ps + (1 - progress) * ps * 3;
    final r = ps * 2;

    // Sun body
    canvas.drawCircle(Offset(sx, sy), r, paint);
    // Inner highlight
    canvas.drawCircle(Offset(sx, sy), r * 0.6, lightPaint);

    // Rays (8 directions)
    final rayCount = 8;
    for (var i = 0; i < rayCount; i++) {
      final angle = (i / rayCount) * 3.14159 * 2;
      final rayLen = r * 0.8 * progress;
      final rx = sx + (r + ps * 0.3) * cos(angle);
      final ry = sy + (r + ps * 0.3) * sin(angle);
      final ex = sx + (r + ps * 0.3 + rayLen) * cos(angle);
      final ey = sy + (r + ps * 0.3 + rayLen) * sin(angle);
      canvas.drawLine(
        Offset(rx, ry),
        Offset(ex, ey),
        Paint()
          ..color = sunColor.withValues(alpha: alpha * 0.7)
          ..strokeWidth = ps * 0.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PracticeFlowerPainter oldDelegate) {
    return oldDelegate.growthStage != growthStage ||
        oldDelegate.colorFillProgress != colorFillProgress ||
        oldDelegate.musicProgress != musicProgress ||
        oldDelegate.waterProgress != waterProgress ||
        oldDelegate.sunProgress != sunProgress ||
        oldDelegate.themeColor != themeColor;
  }
}

class _VectorNoteSpec {
  const _VectorNoteSpec(
    this.x,
    this.y,
    this.delay,
    this.scale,
    this.kind,
    this.colorIndex,
  );

  final double x;
  final double y;
  final double delay;
  final double scale;
  final int kind;
  final int colorIndex;
}

class _LotusPetalSpec {
  const _LotusPetalSpec(
    this.angle,
    this.lift,
    this.length,
    this.width,
    this.tilt,
    this.color,
  );

  final double angle;
  final double lift;
  final double length;
  final double width;
  final double tilt;
  final Color color;
}

class _VectorFlowerPalette {
  const _VectorFlowerPalette({
    required this.shadow,
    required this.stem,
    required this.stemLight,
    required this.leaf,
    required this.leafLight,
    required this.petal,
    required this.petalLight,
    required this.petalShadow,
    required this.center,
    required this.centerLight,
    required this.centerDot,
    required this.can,
    required this.water,
    required this.waterLight,
    required this.sun,
    required this.sunLight,
    required this.noteColors,
  });

  factory _VectorFlowerPalette.gray() {
    return const _VectorFlowerPalette(
      shadow: Color(0x33000000),
      stem: Color(0xFF505050),
      stemLight: Color(0xFF9A9A9A),
      leaf: Color(0xFF6B6B6B),
      leafLight: Color(0xFFB7B7B7),
      petal: Color(0xFFD4D4D4),
      petalLight: Color(0xFFF4F4F4),
      petalShadow: Color(0xFF8A8A8A),
      center: Color(0xFFBEBEBE),
      centerLight: Color(0xFFF6F6F6),
      centerDot: Color(0xFF777777),
      can: Color(0xFF686868),
      water: Color(0xFF777777),
      waterLight: Color(0xFFB6B6B6),
      sun: Color(0xFF737373),
      sunLight: Color(0xFFE0E0E0),
      noteColors: [
        Color(0xFF4F4F4F),
        Color(0xFF6A6A6A),
        Color(0xFF808080),
        Color(0xFF5B5B5B),
        Color(0xFF909090),
        Color(0xFF707070),
      ],
    );
  }

  factory _VectorFlowerPalette.fromTheme(Color themeColor) {
    final hsl = HSLColor.fromColor(themeColor);
    final h = hsl.hue;
    return _VectorFlowerPalette(
      shadow: HSLColor.fromAHSL(0.18, (h + 85) % 360, 0.45, 0.28).toColor(),
      stem: HSLColor.fromAHSL(1, (h + 86) % 360, 0.58, 0.36).toColor(),
      stemLight: HSLColor.fromAHSL(1, (h + 82) % 360, 0.55, 0.56).toColor(),
      leaf: HSLColor.fromAHSL(1, (h + 72) % 360, 0.62, 0.43).toColor(),
      leafLight: HSLColor.fromAHSL(1, (h + 68) % 360, 0.58, 0.62).toColor(),
      petal: HSLColor.fromAHSL(1, h, 0.66, 0.68).toColor(),
      petalLight: HSLColor.fromAHSL(1, h, 0.70, 0.82).toColor(),
      petalShadow: HSLColor.fromAHSL(1, h, 0.52, 0.48).toColor(),
      center: HSLColor.fromAHSL(1, (h + 36) % 360, 0.84, 0.58).toColor(),
      centerLight: HSLColor.fromAHSL(1, (h + 42) % 360, 0.90, 0.76).toColor(),
      centerDot: HSLColor.fromAHSL(1, (h + 25) % 360, 0.78, 0.34).toColor(),
      can: HSLColor.fromAHSL(1, (h + 160) % 360, 0.42, 0.54).toColor(),
      water: const Color(0xFF42A5F5),
      waterLight: const Color(0xFF81D4FA),
      sun: const Color(0xFFFFC928),
      sunLight: const Color(0xFFFFF176),
      noteColors: const [
        Color(0xFFE91E63),
        Color(0xFF42A5F5),
        Color(0xFFFFB300),
        Color(0xFF7E57C2),
        Color(0xFF26A69A),
        Color(0xFFFF7043),
      ],
    );
  }

  final Color shadow;
  final Color stem;
  final Color stemLight;
  final Color leaf;
  final Color leafLight;
  final Color petal;
  final Color petalLight;
  final Color petalShadow;
  final Color center;
  final Color centerLight;
  final Color centerDot;
  final Color can;
  final Color water;
  final Color waterLight;
  final Color sun;
  final Color sunLight;
  final List<Color> noteColors;
}

class _BwColors {
  const _BwColors({
    required this.black,
    required this.dark,
    required this.mid,
    required this.light,
    required this.white,
  });

  final Color black;
  final Color dark;
  final Color mid;
  final Color light;
  final Color white;
}

class _ColorPalette {
  const _ColorPalette({
    required this.stem,
    required this.leaf,
    required this.leafLight,
    required this.petal,
    required this.petalShadow,
    required this.petalDark,
    required this.center,
    required this.canBody,
    required this.water,
    required this.waterLight,
    required this.sunBody,
    required this.sunLight,
  });

  final Color stem;
  final Color leaf;
  final Color leafLight;
  final Color petal;
  final Color petalShadow;
  final Color petalDark;
  final Color center;
  final Color canBody;
  final Color water;
  final Color waterLight;
  final Color sunBody;
  final Color sunLight;

  Color petalLight() {
    final hsl = HSLColor.fromColor(petal);
    return hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor();
  }

  Color centerHighlight() {
    final hsl = HSLColor.fromColor(center);
    return hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0)).toColor();
  }
}
