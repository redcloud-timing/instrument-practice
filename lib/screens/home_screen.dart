import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/practice_controller.dart';
import '../utils/app_date_utils.dart';
import 'calendar_screen.dart';
import 'day_detail_screen.dart';
import 'text_edit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waterController;

  @override
  void initState() {
    super.initState();
    _waterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _waterController.dispose();
    super.dispose();
  }

  Future<void> _editDailyRead(BuildContext context, String currentText) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TextEditScreen(
          title: '编辑每日必读',
          initialText: currentText,
          hintText: '写下练习前提醒、长期注意事项或练习原则',
        ),
      ),
    );

    if (result != null && context.mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!context.mounted) return;
      await context.read<PracticeController>().saveDailyRead(result);
    }
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

  void _waterFlower() {
    _waterController.forward(from: 0);
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
            waterAnimation: _waterController,
            onTimerPressed: () => _toggleTimer(context),
            onWaterPressed: _waterFlower,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _DailyReadCard(
                    text: controller.dailyRead,
                    onEdit: () => _editDailyRead(context, controller.dailyRead),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 84,
                  child: Column(
                    children: [
                      Expanded(
                        child: _CalendarEntryCard(
                          onTap: () => _openCalendar(context),
                        ),
                      ),
                      const SizedBox(height: 8),
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
              ],
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
    required this.waterAnimation,
    required this.onTimerPressed,
    required this.onWaterPressed,
  });

  final int elapsedSeconds;
  final int todayPracticeSeconds;
  final bool isRunning;
  final Animation<double> waterAnimation;
  final VoidCallback onTimerPressed;
  final VoidCallback onWaterPressed;

  int get _growthStage {
    return (todayPracticeSeconds ~/ (30 * 60)).clamp(0, 4).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final growthProgress = (todayPracticeSeconds / (2 * 60 * 60)).clamp(
      0.0,
      1.0,
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
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
                  AppDateUtils.formatDuration(todayPracticeSeconds),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: waterAnimation,
              builder: (context, child) {
                return SizedBox(
                  height: 110,
                  child: CustomPaint(
                    painter: _PixelFlowerPainter(
                      stage: _growthStage,
                      waterProgress: waterAnimation.value,
                      colorScheme: colorScheme,
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: growthProgress,
                minHeight: 6,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppDateUtils.formatDuration(elapsedSeconds),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              isRunning ? '练习进行中' : '准备开始练习',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (isRunning && elapsedSeconds > 4 * 60 * 60) ...[
              const SizedBox(height: 4),
              const Text(
                '计时已超过 4 小时，请确认是否忘记结束。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onTimerPressed,
                    icon: Icon(
                      isRunning ? Icons.stop : Icons.play_arrow,
                      size: 18,
                    ),
                    label: Text(
                      isRunning ? '结束并记录' : '开始练习',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: '浇水',
                  child: IconButton.outlined(
                    onPressed: onWaterPressed,
                    icon: const Icon(Icons.water_drop_outlined, size: 20),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(40, 40),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyReadCard extends StatelessWidget {
  const _DailyReadCard({required this.text, required this.onEdit});

  final String text;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
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
                GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.edit_outlined, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  text.isEmpty ? '点击右上角编辑每日必读。' : text,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarEntryCard extends StatelessWidget {
  const _CalendarEntryCard({required this.onTap});

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 22,
                color: colorScheme.primary,
              ),
              Column(
                children: [
                  Text(
                    '${today.month}月${today.day}日',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _weekday(today.weekday),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              Text(
                '查看日历',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colorScheme.primary),
              ),
            ],
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(
                Icons.music_note_outlined,
                size: 22,
                color: colorScheme.primary,
              ),
              Column(
                children: [
                  Text('今日练习', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 1),
                  Text(
                    AppDateUtils.formatDuration(todaySeconds),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                '记录心得',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PixelFlowerPainter extends CustomPainter {
  const _PixelFlowerPainter({
    required this.stage,
    required this.waterProgress,
    required this.colorScheme,
  });

  final int stage;
  final double waterProgress;
  final ColorScheme colorScheme;

  static const int _grid = 19;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide.clamp(100.0, 110.0);
    final pixel = side / _grid;
    final left = (size.width - side) / 2;
    final top = (size.height - side) / 2;
    final sway = waterProgress > 0
        ? (0.5 - (waterProgress - 0.5).abs()) * pixel * 0.6
        : 0.0;

    final bgPaint = Paint()
      ..color = colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, side, side),
        const Radius.circular(8),
      ),
      bgPaint,
    );

    void px(int x, int y, Color color) {
      final rect = Rect.fromLTWH(
        left + x * pixel + sway,
        top + y * pixel,
        pixel,
        pixel,
      ).deflate(0.5);
      canvas.drawRect(rect, Paint()..color = color);
    }

    final outline = stage >= 4 ? const Color(0xFF1F3B2D) : Colors.black;
    final stemColor = stage >= 4 ? const Color(0xFF2F8C4C) : Colors.black;
    final leaf = stage >= 4 ? const Color(0xFF55B567) : Colors.black;
    final petal = stage >= 4 ? const Color(0xFFFF7AA8) : Colors.white;
    final petalShadow = stage >= 4 ? const Color(0xFFE64B7C) : Colors.black;
    final center = stage >= 4 ? const Color(0xFFFFD34D) : Colors.white;

    _drawPot(px, stage >= 4);
    _drawStemAndLeaves(px, stemColor, leaf);

    if (stage == 0) {
      px(8, 13, leaf);
      px(10, 13, leaf);
    } else if (stage == 1) {
      _drawBud(px, outline, petal, 9, 10);
    } else if (stage == 2) {
      _drawBud(px, outline, petal, 9, 8);
      px(7, 10, leaf);
      px(11, 10, leaf);
    } else {
      _drawBloom(px, outline, petal, petalShadow, center);
    }

    _drawWateringCan(canvas, left, top, pixel, waterProgress);
    if (waterProgress > 0) {
      _drawDrops(canvas, left, top, pixel, waterProgress);
    }
  }

  void _drawPot(void Function(int x, int y, Color color) px, bool colored) {
    final pot = colored ? const Color(0xFFB66A3C) : Colors.black;
    final potLight = colored ? const Color(0xFFD89362) : Colors.white;
    for (var x = 6; x <= 12; x++) {
      px(x, 16, pot);
    }
    for (var x = 7; x <= 11; x++) {
      px(x, 17, pot);
    }
    px(8, 15, potLight);
    px(9, 15, potLight);
    px(10, 15, potLight);
  }

  void _drawStemAndLeaves(
    void Function(int x, int y, Color color) px,
    Color stemColor,
    Color leafColor,
  ) {
    final top = switch (stage) {
      0 => 13,
      1 => 11,
      2 => 9,
      _ => 7,
    };
    for (var y = top; y <= 15; y++) {
      px(9, y, stemColor);
    }
    if (stage >= 1) {
      px(8, 12, leafColor);
      px(7, 12, leafColor);
      px(10, 13, leafColor);
      px(11, 13, leafColor);
    }
    if (stage >= 2) {
      px(8, 10, leafColor);
      px(7, 9, leafColor);
      px(10, 11, leafColor);
      px(11, 10, leafColor);
    }
  }

  void _drawBud(
    void Function(int x, int y, Color color) px,
    Color outline,
    Color fill,
    int x,
    int y,
  ) {
    px(x, y, fill);
    px(x - 1, y + 1, outline);
    px(x, y + 1, outline);
    px(x + 1, y + 1, outline);
  }

  void _drawBloom(
    void Function(int x, int y, Color color) px,
    Color outline,
    Color petalColor,
    Color shadow,
    Color centerColor,
  ) {
    final petals = <Offset>[
      const Offset(9, 5),
      const Offset(7, 7),
      const Offset(11, 7),
      const Offset(9, 9),
    ];
    for (final item in petals) {
      px(item.dx.toInt(), item.dy.toInt(), petalColor);
      px(item.dx.toInt(), item.dy.toInt() + 1, shadow);
    }
    px(8, 6, outline);
    px(10, 6, outline);
    px(8, 8, outline);
    px(10, 8, outline);
    px(9, 7, centerColor);
  }

  void _drawWateringCan(
    Canvas canvas,
    double left,
    double top,
    double pixel,
    double progress,
  ) {
    final paint = Paint()
      ..color = stage >= 4
          ? const Color(0xFF6AA6D8)
          : Colors.black.withValues(alpha: 0.9);
    final canLeft = left + 2 * pixel;
    final canTop = top + (5.5 + progress * 0.5) * pixel;
    canvas.drawRect(
      Rect.fromLTWH(canLeft, canTop + pixel, 3 * pixel, 2 * pixel),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(canLeft + 2.5 * pixel, canTop + 0.5 * pixel, pixel, pixel),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        canLeft + 4 * pixel,
        canTop + 0.7 * pixel,
        2 * pixel,
        pixel,
      ),
      paint,
    );
    canvas.drawCircle(
      Offset(canLeft - 0.2 * pixel, canTop + 2 * pixel),
      pixel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = pixel * 0.45
        ..color = paint.color,
    );
  }

  void _drawDrops(
    Canvas canvas,
    double left,
    double top,
    double pixel,
    double progress,
  ) {
    final dropPaint = Paint()
      ..color = (stage >= 4 ? const Color(0xFF399BE5) : Colors.black)
          .withValues(alpha: (1 - progress).clamp(0.0, 1.0));
    for (var i = 0; i < 4; i++) {
      final dx = left + (7 + i * 1.4) * pixel;
      final dy = top + (7 + progress * 6 + (i.isEven ? 0 : 1)) * pixel;
      canvas.drawRect(
        Rect.fromLTWH(dx, dy, pixel * 0.55, pixel * 0.55),
        dropPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PixelFlowerPainter oldDelegate) {
    return oldDelegate.stage != stage ||
        oldDelegate.waterProgress != waterProgress ||
        oldDelegate.colorScheme != colorScheme;
  }
}
