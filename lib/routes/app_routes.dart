/// 应用内页面名称与路由参数。
///
/// 主导航的四个页面由 [IndexedStack] 常驻，不在这里重复注册。
class AppRoutes {
  AppRoutes._();

  static const calendar = '/calendar';
  static const dayDetail = '/calendar/day';
  static const documentViewer = '/library/viewer';
  static const pitchTraceSettings = '/pitch-trace/settings';
  static const themeSettings = '/settings/theme';
  static const textEdit = '/edit/text';
  static const dailyReadEdit = '/daily-read/edit';
}

class TextEditRouteArguments {
  const TextEditRouteArguments({
    required this.title,
    required this.initialText,
    required this.hintText,
    this.saveLabel = '保存',
    this.selectAllOnOpen = false,
    this.singleLine = false,
  });

  final String title;
  final String initialText;
  final String hintText;
  final String saveLabel;
  final bool selectAllOnOpen;
  final bool singleLine;
}
