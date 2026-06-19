import 'package:flutter/material.dart';

import '../screens/calendar_screen.dart';
import '../screens/daily_read_edit_screen.dart';
import '../screens/day_detail_screen.dart';
import '../screens/library_screen.dart';
import '../screens/metronome_screen.dart';
import '../screens/pitch_trace_screen.dart';
import '../screens/theme_settings_screen.dart';

/// 集中管理应用路由，避免 Navigator.push 硬编码
///
/// 使用方式：
/// ```dart
/// Navigator.pushNamed(context, AppRouter.dayDetail, arguments: date);
/// ```
class AppRouter {
  AppRouter._();

  static const calendar = '/calendar';
  static const dayDetail = '/calendar/day';
  static const library = '/library';
  static const documentViewer = '/library/viewer';
  static const metronome = '/metronome';
  static const pitchTrace = '/pitch-trace';
  static const themeSettings = '/settings/theme';
  static const textEdit = '/edit/text';
  static const dailyReadEdit = '/daily-read/edit';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case calendar:
        return MaterialPageRoute(
          builder: (_) => const CalendarScreen(),
          settings: settings,
        );
      case dayDetail:
        final date = settings.arguments as DateTime;
        return MaterialPageRoute(
          builder: (_) => DayDetailScreen(date: date),
          settings: settings,
        );
      case library:
        return MaterialPageRoute(
          builder: (_) => const LibraryScreen(),
          settings: settings,
        );
      case metronome:
        return MaterialPageRoute(
          builder: (_) => const MetronomeScreen(),
          settings: settings,
        );
      case pitchTrace:
        return MaterialPageRoute(
          builder: (_) => const PitchTraceScreen(),
          settings: settings,
        );
      case themeSettings:
        return MaterialPageRoute(
          builder: (_) => const ThemeSettingsScreen(),
          settings: settings,
        );
      case dailyReadEdit:
        return MaterialPageRoute(
          builder: (_) => const DailyReadEditScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) =>
              Scaffold(body: Center(child: Text('页面不存在: ${settings.name}'))),
          settings: settings,
        );
    }
  }
}
