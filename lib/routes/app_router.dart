import 'package:flutter/material.dart';

import '../screens/calendar_screen.dart';
import '../screens/daily_read_edit_screen.dart';
import '../screens/day_detail_screen.dart';
import '../screens/document_viewer_screen.dart';
import '../screens/pitch_trace/pitch_trace_settings_screen.dart';
import '../screens/text_edit_screen.dart';
import '../screens/theme_settings_screen.dart';
import 'app_routes.dart';

/// 集中管理应用路由，避免 Navigator.push 硬编码
///
/// 使用方式：
/// ```dart
/// Navigator.pushNamed(context, AppRoutes.dayDetail, arguments: date);
/// ```
class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.calendar:
        return MaterialPageRoute(
          builder: (_) => const CalendarScreen(),
          settings: settings,
        );
      case AppRoutes.dayDetail:
        final date = settings.arguments;
        if (date is! DateTime) return _invalidArguments(settings);
        return MaterialPageRoute(
          builder: (_) => DayDetailScreen(date: date),
          settings: settings,
        );
      case AppRoutes.documentViewer:
        final itemUri = settings.arguments;
        if (itemUri is! String || itemUri.isEmpty) {
          return _invalidArguments(settings);
        }
        return MaterialPageRoute(
          builder: (_) => DocumentViewerScreen(itemUri: itemUri),
          settings: settings,
        );
      case AppRoutes.pitchTraceSettings:
        return MaterialPageRoute(
          builder: (_) => const PitchTraceSettingsScreen(),
          settings: settings,
        );
      case AppRoutes.themeSettings:
        return MaterialPageRoute(
          builder: (_) => const ThemeSettingsScreen(),
          settings: settings,
        );
      case AppRoutes.textEdit:
        final arguments = settings.arguments;
        if (arguments is! TextEditRouteArguments) {
          return _invalidArguments(settings);
        }
        return MaterialPageRoute(
          builder: (_) => TextEditScreen(
            title: arguments.title,
            initialText: arguments.initialText,
            hintText: arguments.hintText,
            saveLabel: arguments.saveLabel,
            selectAllOnOpen: arguments.selectAllOnOpen,
            minLines: arguments.singleLine ? 1 : 10,
            maxLines: arguments.singleLine ? 1 : null,
            textInputAction: arguments.singleLine
                ? TextInputAction.done
                : TextInputAction.newline,
          ),
          settings: settings,
        );
      case AppRoutes.dailyReadEdit:
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

  static Route<dynamic> _invalidArguments(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) =>
          const Scaffold(body: Center(child: Text('页面参数无效，请返回后重试。'))),
      settings: settings,
    );
  }
}
