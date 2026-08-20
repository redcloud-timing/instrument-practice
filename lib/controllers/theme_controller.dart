import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../utils/app_constants.dart';

enum PracticeImageRevealStyle { gentle, balanced, vivid }

class PracticeImageRevealProfile {
  const PracticeImageRevealProfile({
    required this.label,
    required this.description,
    required this.minOpacity,
    required this.maxBlur,
    required this.maxFogOpacity,
  });

  final String label;
  final String description;
  final double minOpacity;
  final double maxBlur;
  final double maxFogOpacity;
}

extension PracticeImageRevealStyleInfo on PracticeImageRevealStyle {
  PracticeImageRevealProfile get profile {
    return switch (this) {
      PracticeImageRevealStyle.gentle => const PracticeImageRevealProfile(
        label: '淡雅',
        description: '雾气更重，变化最柔和',
        minOpacity: 0.14,
        maxBlur: 12,
        maxFogOpacity: 0.68,
      ),
      PracticeImageRevealStyle.balanced => const PracticeImageRevealProfile(
        label: '标准',
        description: '清晰度和显现速度均衡',
        minOpacity: 0.22,
        maxBlur: 8,
        maxFogOpacity: 0.56,
      ),
      PracticeImageRevealStyle.vivid => const PracticeImageRevealProfile(
        label: '鲜明',
        description: '图片更早显色，练习反馈更直接',
        minOpacity: 0.30,
        maxBlur: 5,
        maxFogOpacity: 0.42,
      ),
    };
  }
}

class ThemeAmbience {
  const ThemeAmbience({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.seedColor,
    required this.accentColor,
    required this.warmColor,
    required this.lightBackground,
    required this.lightSurface,
    required this.lightSurfaceAlt,
    required this.darkBackground,
    required this.darkSurface,
    required this.darkSurfaceAlt,
  });

  static const customId = 'custom';

  static const all = <ThemeAmbience>[
    ThemeAmbience(
      id: 'lotus_morning',
      name: '清晨荷风',
      description: '浅绿、淡粉、明亮练习感',
      icon: Icons.local_florist_outlined,
      seedColor: Color(0xFF99FF99),
      accentColor: Color(0xFFF08FB1),
      warmColor: Color(0xFFE9B949),
      lightBackground: Color(0xFFF5FBF3),
      lightSurface: Color(0xFFFFFFFF),
      lightSurfaceAlt: Color(0xFFE8F6E8),
      darkBackground: Color(0xFF101A13),
      darkSurface: Color(0xFF17231B),
      darkSurfaceAlt: Color(0xFF213528),
    ),
    ThemeAmbience(
      id: 'ink_celadon',
      name: '水墨青瓷',
      description: '青绿、瓷白、安静东方感',
      icon: Icons.water_drop_outlined,
      seedColor: Color(0xFF2E7D6B),
      accentColor: Color(0xFF5B8EA7),
      warmColor: Color(0xFFC8A34A),
      lightBackground: Color(0xFFF4F8F6),
      lightSurface: Color(0xFFFFFEFA),
      lightSurfaceAlt: Color(0xFFDFECE8),
      darkBackground: Color(0xFF0D1716),
      darkSurface: Color(0xFF142321),
      darkSurfaceAlt: Color(0xFF203633),
    ),
    ThemeAmbience(
      id: 'moon_lotus',
      name: '月下蓝莲',
      description: '蓝紫、银白、夜间专注',
      icon: Icons.nights_stay_outlined,
      seedColor: Color(0xFF6FA8FF),
      accentColor: Color(0xFFB497FF),
      warmColor: Color(0xFFECC56F),
      lightBackground: Color(0xFFF4F7FD),
      lightSurface: Color(0xFFFFFFFF),
      lightSurfaceAlt: Color(0xFFE4EBFA),
      darkBackground: Color(0xFF0D1220),
      darkSurface: Color(0xFF151C2E),
      darkSurfaceAlt: Color(0xFF222C45),
    ),
    ThemeAmbience(
      id: 'amber_stage',
      name: '暮色琥珀',
      description: '琥珀、松绿、温暖舞台光',
      icon: Icons.wb_sunny_outlined,
      seedColor: Color(0xFFC97924),
      accentColor: Color(0xFF44735E),
      warmColor: Color(0xFFE5B64C),
      lightBackground: Color(0xFFFFF8EE),
      lightSurface: Color(0xFFFFFDF8),
      lightSurfaceAlt: Color(0xFFF7E7CF),
      darkBackground: Color(0xFF1D140B),
      darkSurface: Color(0xFF2A1D11),
      darkSurfaceAlt: Color(0xFF3B2A18),
    ),
    ThemeAmbience(
      id: 'rose_room',
      name: '玫瑰练习室',
      description: '玫瑰、紫调、柔和明快',
      icon: Icons.favorite_border,
      seedColor: Color(0xFFD35D83),
      accentColor: Color(0xFF8E79D8),
      warmColor: Color(0xFFE7B05E),
      lightBackground: Color(0xFFFFF5F7),
      lightSurface: Color(0xFFFFFFFF),
      lightSurfaceAlt: Color(0xFFF6DEE6),
      darkBackground: Color(0xFF1D1018),
      darkSurface: Color(0xFF2B1823),
      darkSurfaceAlt: Color(0xFF3E2332),
    ),
    ThemeAmbience(
      id: 'turquoise_lake',
      name: '松石湖面',
      description: '松石、湖蓝、清爽通透',
      icon: Icons.waves_outlined,
      seedColor: Color(0xFF00A6A6),
      accentColor: Color(0xFF3D8BFD),
      warmColor: Color(0xFFECC96D),
      lightBackground: Color(0xFFF0FBFA),
      lightSurface: Color(0xFFFFFFFF),
      lightSurfaceAlt: Color(0xFFD9F0EF),
      darkBackground: Color(0xFF071A1C),
      darkSurface: Color(0xFF0F2729),
      darkSurfaceAlt: Color(0xFF183B3E),
    ),
    ThemeAmbience(
      id: 'wisteria_night',
      name: '紫藤夜练',
      description: '紫藤、洋红、沉静但有张力',
      icon: Icons.auto_awesome_outlined,
      seedColor: Color(0xFF7D67D8),
      accentColor: Color(0xFFE07AA4),
      warmColor: Color(0xFFECC06A),
      lightBackground: Color(0xFFF8F5FF),
      lightSurface: Color(0xFFFFFFFF),
      lightSurfaceAlt: Color(0xFFE9E2FA),
      darkBackground: Color(0xFF120F1F),
      darkSurface: Color(0xFF1E1831),
      darkSurfaceAlt: Color(0xFF2D2448),
    ),
    ThemeAmbience(
      id: 'ink_gray',
      name: '极简墨灰',
      description: '墨灰、鼠尾草、克制耐看',
      icon: Icons.contrast_outlined,
      seedColor: Color(0xFF4D6470),
      accentColor: Color(0xFF8BA494),
      warmColor: Color(0xFFC6A15D),
      lightBackground: Color(0xFFF7F7F4),
      lightSurface: Color(0xFFFFFFFF),
      lightSurfaceAlt: Color(0xFFE7E9E4),
      darkBackground: Color(0xFF101315),
      darkSurface: Color(0xFF1A1E20),
      darkSurfaceAlt: Color(0xFF292F31),
    ),
  ];

  static ThemeAmbience? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final ambience in all) {
      if (ambience.id == id) return ambience;
    }
    return null;
  }

  static ThemeAmbience? matchingColor(Color color) {
    for (final ambience in all) {
      if (_sameColor(ambience.seedColor, color)) return ambience;
    }
    return null;
  }

  static ThemeAmbience custom(Color seedColor) {
    final hsl = HSLColor.fromColor(seedColor);
    final lightSurfaceAlt = hsl
        .withSaturation((hsl.saturation * 0.42).clamp(0.08, 0.48))
        .withLightness(0.90)
        .toColor();
    final darkSurfaceAlt = hsl
        .withSaturation((hsl.saturation * 0.35).clamp(0.10, 0.46))
        .withLightness(0.20)
        .toColor();

    return ThemeAmbience(
      id: customId,
      name: '自定义颜色',
      description: '跟随你输入的主色自动生成',
      icon: Icons.palette_outlined,
      seedColor: seedColor,
      accentColor: HSLColor.fromAHSL(
        1,
        (hsl.hue + 42) % 360,
        (hsl.saturation * 0.72).clamp(0.20, 0.70),
        0.56,
      ).toColor(),
      warmColor: HSLColor.fromAHSL(
        1,
        (hsl.hue + 105) % 360,
        0.54,
        0.62,
      ).toColor(),
      lightBackground: hsl
          .withSaturation((hsl.saturation * 0.24).clamp(0.04, 0.30))
          .withLightness(0.97)
          .toColor(),
      lightSurface: const Color(0xFFFFFFFF),
      lightSurfaceAlt: lightSurfaceAlt,
      darkBackground: hsl
          .withSaturation((hsl.saturation * 0.22).clamp(0.08, 0.28))
          .withLightness(0.08)
          .toColor(),
      darkSurface: hsl
          .withSaturation((hsl.saturation * 0.20).clamp(0.08, 0.30))
          .withLightness(0.12)
          .toColor(),
      darkSurfaceAlt: darkSurfaceAlt,
    );
  }

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color seedColor;
  final Color accentColor;
  final Color warmColor;
  final Color lightBackground;
  final Color lightSurface;
  final Color lightSurfaceAlt;
  final Color darkBackground;
  final Color darkSurface;
  final Color darkSurfaceAlt;

  List<Color> get swatches => [
    seedColor,
    accentColor,
    warmColor,
    lightSurfaceAlt,
  ];
}

class ThemeController extends ChangeNotifier {
  ThemeController(this._databaseService);

  final DatabaseService _databaseService;
  static const Color defaultColor = Color(0xFF99FF99);

  Color _themeColor = defaultColor;
  Color get themeColor => _themeColor;

  String _ambienceId = ThemeAmbience.all.first.id;
  String get ambienceId => _ambienceId;
  ThemeAmbience get ambience {
    return ThemeAmbience.byId(_ambienceId) ?? ThemeAmbience.custom(_themeColor);
  }

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  PracticeImageRevealStyle _imageRevealStyle =
      PracticeImageRevealStyle.balanced;
  PracticeImageRevealStyle get imageRevealStyle => _imageRevealStyle;
  PracticeImageRevealProfile get imageRevealProfile =>
      _imageRevealStyle.profile;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    final savedAmbienceId = await _databaseService.getSetting(
      AppConstants.themeAmbienceKey,
    );
    final savedColor = await _databaseService.getSetting(
      AppConstants.themeColorKey,
    );
    final savedThemeMode = await _databaseService.getSetting(
      AppConstants.themeModeKey,
    );
    final savedRevealStyle = await _databaseService.getSetting(
      AppConstants.imageRevealStyleKey,
    );

    final savedAmbience = ThemeAmbience.byId(savedAmbienceId);
    if (savedAmbience != null) {
      _ambienceId = savedAmbience.id;
      _themeColor = savedAmbience.seedColor;
    } else if (savedColor != null && savedColor.isNotEmpty) {
      final color = parseHex(savedColor);
      if (color != null) {
        final matchingAmbience = ThemeAmbience.matchingColor(color);
        _themeColor = color;
        _ambienceId = matchingAmbience?.id ?? ThemeAmbience.customId;
      }
    }

    final mode = _themeModeFromName(savedThemeMode);
    if (mode != null) _themeMode = mode;

    final revealStyle = _revealStyleFromName(savedRevealStyle);
    if (revealStyle != null) _imageRevealStyle = revealStyle;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> applyAmbience(String ambienceId) async {
    final selected = ThemeAmbience.byId(ambienceId);
    if (selected == null) return;

    _ambienceId = selected.id;
    _themeColor = selected.seedColor;
    await _databaseService.setSetting(
      AppConstants.themeAmbienceKey,
      _ambienceId,
    );
    await _databaseService.setSetting(
      AppConstants.themeColorKey,
      colorToString(_themeColor),
    );
    notifyListeners();
  }

  Future<void> setThemeColor(Color color) async {
    final matchingAmbience = ThemeAmbience.matchingColor(color);
    _themeColor = color;
    _ambienceId = matchingAmbience?.id ?? ThemeAmbience.customId;
    await _databaseService.setSetting(
      AppConstants.themeAmbienceKey,
      _ambienceId,
    );
    await _databaseService.setSetting(
      AppConstants.themeColorKey,
      colorToString(color),
    );
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _databaseService.setSetting(AppConstants.themeModeKey, mode.name);
    notifyListeners();
  }

  Future<void> setImageRevealStyle(PracticeImageRevealStyle style) async {
    _imageRevealStyle = style;
    await _databaseService.setSetting(
      AppConstants.imageRevealStyleKey,
      style.name,
    );
    notifyListeners();
  }

  Future<void> resetThemeDesign() async {
    final defaultAmbience = ThemeAmbience.all.first;
    _themeColor = defaultAmbience.seedColor;
    _ambienceId = defaultAmbience.id;
    _themeMode = ThemeMode.system;
    _imageRevealStyle = PracticeImageRevealStyle.balanced;

    await _databaseService.setSetting(
      AppConstants.themeAmbienceKey,
      _ambienceId,
    );
    await _databaseService.setSetting(
      AppConstants.themeColorKey,
      colorToString(_themeColor),
    );
    await _databaseService.setSetting(
      AppConstants.themeModeKey,
      _themeMode.name,
    );
    await _databaseService.setSetting(
      AppConstants.imageRevealStyleKey,
      _imageRevealStyle.name,
    );
    notifyListeners();
  }

  static String colorToString(Color color) {
    final a = (color.a * 255).round().toRadixString(16).padLeft(2, '0');
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$a$r$g$b'.toUpperCase();
  }

  static String colorToRgbString(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '$r$g$b'.toUpperCase();
  }

  static Color? parseHex(String hex) {
    try {
      final cleaned = hex.trim().replaceFirst('#', '');
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      }
      if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      }
    } catch (e) {
      debugPrint('ThemeController.parseHex error: $e');
    }
    return null;
  }
}

ThemeMode? _themeModeFromName(String? name) {
  if (name == null) return null;
  for (final mode in ThemeMode.values) {
    if (mode.name == name) return mode;
  }
  return null;
}

PracticeImageRevealStyle? _revealStyleFromName(String? name) {
  if (name == null) return null;
  for (final style in PracticeImageRevealStyle.values) {
    if (style.name == name) return style;
  }
  return null;
}

bool _sameColor(Color a, Color b) {
  return (a.a - b.a).abs() < 0.001 &&
      (a.r - b.r).abs() < 0.001 &&
      (a.g - b.g).abs() < 0.001 &&
      (a.b - b.b).abs() < 0.001;
}
