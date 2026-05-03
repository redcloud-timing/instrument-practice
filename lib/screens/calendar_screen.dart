import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../controllers/practice_controller.dart';
import '../utils/app_date_utils.dart';
import 'day_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DayDetailScreen(date: AppDateUtils.dateOnly(_selectedDay)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PracticeController>();
    final selectedLog = controller.logForDate(_selectedDay);
    final selectedSeconds = selectedLog?.durationSeconds ?? 0;
    final hasNote = (selectedLog?.note ?? '').isNotEmpty;
    final note = selectedLog?.note ?? '';

    final isToday =
        _selectedDay.year == DateTime.now().year &&
        _selectedDay.month == DateTime.now().month &&
        _selectedDay.day == DateTime.now().day;

    final hasPractice = selectedSeconds > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('练习日历'), centerTitle: true),
      body: Column(
        children: [
          _DateHeader(
            selectedDay: _selectedDay,
            isToday: isToday,
            hasPractice: hasPractice,
            practiceSeconds: selectedSeconds,
            weekdayLabel: _weekdayLabel(_selectedDay.weekday),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _CalendarCard(
                  focusedDay: _focusedDay,
                  selectedDay: _selectedDay,
                  calendarFormat: _calendarFormat,
                  controller: controller,
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() => _focusedDay = focusedDay);
                  },
                  onFormatChanged: (format) {
                    setState(() => _calendarFormat = format);
                  },
                ),
                const SizedBox(height: 14),
                _NoteCard(
                  note: note,
                  hasNote: hasNote,
                  onTap: () => _openDetail(context),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayLabel(int wd) {
    const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return days[wd - 1];
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.selectedDay,
    required this.isToday,
    required this.hasPractice,
    required this.practiceSeconds,
    required this.weekdayLabel,
  });

  final DateTime selectedDay;
  final bool isToday;
  final bool hasPractice;
  final int practiceSeconds;
  final String weekdayLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${selectedDay.year}年${selectedDay.month}月',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '今天',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isToday
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '${selectedDay.day}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: isToday
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weekdayLabel,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasPractice
                        ? '已练习 ${AppDateUtils.compactDuration(practiceSeconds)}'
                        : '暂无练习记录',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.focusedDay,
    required this.selectedDay,
    required this.calendarFormat,
    required this.controller,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.onFormatChanged,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarFormat calendarFormat;
  final PracticeController controller;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onPageChanged;
  final void Function(CalendarFormat) onFormatChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: TableCalendar(
        locale: 'zh_CN',
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) =>
            day.year == selectedDay.year &&
            day.month == selectedDay.month &&
            day.day == selectedDay.day,
        calendarFormat: calendarFormat,
        availableCalendarFormats: const {
          CalendarFormat.month: '月',
          CalendarFormat.twoWeeks: '双周',
          CalendarFormat.week: '周',
        },
        onDaySelected: onDaySelected,
        onPageChanged: onPageChanged,
        onFormatChanged: onFormatChanged,
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.55),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          weekendStyle: TextStyle(
            color: colorScheme.error.withValues(alpha: 0.55),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: true,
          formatButtonShowsNext: false,
          formatButtonTextStyle: TextStyle(
            color: colorScheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          formatButtonDecoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          titleTextStyle: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: colorScheme.primary,
            size: 22,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: colorScheme.primary,
            size: 22,
          ),
          headerMargin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: true,
          todayDecoration: BoxDecoration(
            border: Border.all(color: colorScheme.primary, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          selectedDecoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          todayTextStyle: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
          selectedTextStyle: TextStyle(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
          weekendTextStyle: TextStyle(
            color: colorScheme.error.withValues(alpha: 0.7),
          ),
          outsideTextStyle: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.25),
          ),
          defaultTextStyle: TextStyle(color: colorScheme.onSurface),
          cellMargin: const EdgeInsets.all(5),
          tablePadding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) =>
              _DayCell(controller: controller, day: day),
          todayBuilder: (context, day, focusedDay) =>
              _DayCell(controller: controller, day: day, today: true),
          selectedBuilder: (context, day, focusedDay) =>
              _DayCell(controller: controller, day: day, selected: true),
          outsideBuilder: (context, day, focusedDay) =>
              _DayCell(controller: controller, day: day, outside: true),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.hasNote,
    required this.onTap,
  });

  final String note;
  final bool hasNote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '练习笔记',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.25),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: hasNote
                    ? SingleChildScrollView(
                        child: Text(
                          note,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.8),
                            height: 1.6,
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 80,
                        child: Center(
                          child: Text(
                            '点击此处添加练习笔记',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.controller,
    required this.day,
    this.selected = false,
    this.today = false,
    this.outside = false,
  });

  final PracticeController controller;
  final DateTime day;
  final bool selected;
  final bool today;
  final bool outside;

  @override
  Widget build(BuildContext context) {
    final log = controller.logForDate(day);
    final practiceSeconds = log?.durationSeconds ?? 0;
    final hasPractice = practiceSeconds > 0;
    final colorScheme = Theme.of(context).colorScheme;

    Color bgColor = Colors.transparent;
    Color textColor = outside
        ? colorScheme.onSurface.withValues(alpha: 0.25)
        : colorScheme.onSurface;

    if (selected) {
      bgColor = colorScheme.primary;
      textColor = colorScheme.onPrimary;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: today && !selected
            ? Border.all(color: colorScheme.primary, width: 2)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          if (hasPractice)
            _PracticeSquares(seconds: practiceSeconds, selected: selected)
          else
            const SizedBox(height: 7),
        ],
      ),
    );
  }
}

class _PracticeSquares extends StatelessWidget {
  const _PracticeSquares({required this.seconds, required this.selected});

  final int seconds;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final stage = (seconds / (30 * 60)).clamp(0, 4).toInt();
    if (stage == 0) return const SizedBox(height: 7);

    return SizedBox(
      width: 7,
      height: 7,
      child: CustomPaint(
        painter: _SquaresPainter(stage: stage, selected: selected),
      ),
    );
  }
}

class _SquaresPainter extends CustomPainter {
  _SquaresPainter({required this.stage, required this.selected});

  final int stage;
  final bool selected;

  static const _sq = 3.0;
  static const _gap = 1.0;
  static const _step = _sq + _gap;

  @override
  void paint(Canvas canvas, Size size) {
    final black = selected ? Colors.white : const Color(0xFF333333);
    final green = selected ? const Color(0xFFA5D6A7) : const Color(0xFF4CAF50);
    final blue = selected ? const Color(0xFF90CAF9) : const Color(0xFF2196F3);
    final red = selected ? const Color(0xFFEF9A9A) : const Color(0xFFF44336);

    void drawSquare(double col, double row, Color color) {
      canvas.drawRect(
        Rect.fromLTWH(col * _step, row * _step, _sq, _sq),
        Paint()..color = color,
      );
    }

    // 2x2 grid: top-left=black, top-right=green, bottom-left=blue, bottom-right=red
    // Stage 1 (30min): black
    if (stage >= 1) {
      drawSquare(0, 0, black);
    }
    // Stage 2 (60min): green (symmetric with black about center)
    if (stage >= 2) {
      drawSquare(1, 0, green);
    }
    // Stage 3 (90min): blue
    if (stage >= 3) {
      drawSquare(0, 1, blue);
    }
    // Stage 4 (120min): red
    if (stage >= 4) {
      drawSquare(1, 1, red);
    }
  }

  @override
  bool shouldRepaint(covariant _SquaresPainter oldDelegate) {
    return oldDelegate.stage != stage || oldDelegate.selected != selected;
  }
}
