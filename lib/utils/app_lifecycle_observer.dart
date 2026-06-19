import 'package:flutter/widgets.dart';

/// 轻量级 App 生命周期监听器，仅关注前后台切换
class AppLifecycleObserver extends WidgetsBindingObserver {
  AppLifecycleObserver({this.onPaused, this.onResumed});

  final VoidCallback? onPaused;
  final VoidCallback? onResumed;
  bool _attached = false;

  /// 注册到 WidgetsBinding
  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// 从 WidgetsBinding 移除
  void dispose() {
    if (_attached) {
      _attached = false;
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        onPaused?.call();
      case AppLifecycleState.resumed:
        onResumed?.call();
      default:
        break;
    }
  }
}
