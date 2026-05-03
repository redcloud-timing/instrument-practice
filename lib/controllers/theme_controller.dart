import 'package:flutter/material.dart';

import '../services/database_service.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._databaseService);

  final DatabaseService _databaseService;
  static const _themeColorKey = 'theme_color';
  static const Color defaultColor = Color(0xFF99FF99);

  Color _themeColor = defaultColor;
  Color get themeColor => _themeColor;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    final saved = await _databaseService.getSetting(_themeColorKey);
    if (saved != null && saved.isNotEmpty) {
      final color = _parseColor(saved);
      if (color != null) {
        _themeColor = color;
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setThemeColor(Color color) async {
    _themeColor = color;
    await _databaseService.setSetting(_themeColorKey, _colorToString(color));
    notifyListeners();
  }

  String _colorToString(Color color) {
    final a = (color.a * 255).round().toRadixString(16).padLeft(2, '0');
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$a$r$g$b'.toUpperCase();
  }

  Color? _parseColor(String hex) {
    try {
      final cleaned = hex.replaceFirst('#', '');
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      }
      if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      }
    } catch (_) {}
    return null;
  }
}
