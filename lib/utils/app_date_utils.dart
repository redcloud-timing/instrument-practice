import 'package:intl/intl.dart';

class AppDateUtils {
  static String dateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String readableDate(DateTime date) {
    return DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(date);
  }

  static String formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0分钟';

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours小时$minutes分钟';
    }
    if (minutes > 0) {
      return '$minutes分钟$seconds秒';
    }
    return '$seconds秒';
  }

  static String compactDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '';
    final minutes = (totalSeconds + 59) ~/ 60;
    if (minutes < 60) return '$minutes分';
    return '${minutes ~/ 60}时${minutes % 60}分';
  }
}
