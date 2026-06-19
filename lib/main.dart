import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'controllers/theme_controller.dart';
import 'controllers/pitch_trace_controller.dart';
import 'controllers/metronome_controller.dart';
import 'controllers/practice_controller.dart';
import 'controllers/library_controller.dart';
import 'routes/app_router.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/metronome_screen.dart';
import 'screens/pitch_trace_screen.dart';
import 'screens/theme_settings_screen.dart';
import 'services/database_service.dart';
import 'services/document_library_service.dart';
import 'services/metronome_sound_service.dart';
import 'services/pitch_trace_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');

  final databaseService = DatabaseService();
  await databaseService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PracticeController(databaseService)..init(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              MetronomeController(databaseService, MetronomeSoundService())
                ..init()
                ..attachLifecycleObserver(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              LibraryController(databaseService, DocumentLibraryService())
                ..init(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              PitchTraceController(databaseService, PitchTraceService())
                ..init()
                ..attachLifecycleObserver(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeController(databaseService)..init(),
        ),
      ],
      child: const FlutePracticeApp(),
    ),
  );
}

class FlutePracticeApp extends StatelessWidget {
  const FlutePracticeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return MaterialApp(
      title: '练琴乐时',
      debugShowCheckedModeBanner: false,
      themeMode: themeController.themeMode,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _buildAppTheme(themeController, Brightness.light),
      darkTheme: _buildAppTheme(themeController, Brightness.dark),
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const MainShell(),
    );
  }
}

ThemeData _buildAppTheme(ThemeController controller, Brightness brightness) {
  final ambience = controller.ambience;
  final isDark = brightness == Brightness.dark;
  final seedColor = controller.themeColor;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  final background = isDark
      ? ambience.darkBackground
      : ambience.lightBackground;
  final surface = isDark ? ambience.darkSurface : ambience.lightSurface;
  final surfaceAlt = isDark
      ? ambience.darkSurfaceAlt
      : ambience.lightSurfaceAlt;
  final primary = seedColor;
  final scheme = baseScheme.copyWith(
    primary: primary,
    onPrimary: primary.computeLuminance() > 0.5 ? Colors.black : Colors.white,
    secondary: ambience.accentColor,
    tertiary: ambience.warmColor,
    surface: surface,
    surfaceContainer: _blend(surface, primary, isDark ? 0.08 : 0.035),
    surfaceContainerHigh: _blend(surface, primary, isDark ? 0.10 : 0.05),
    surfaceContainerHighest: surfaceAlt,
    outlineVariant: _blend(baseScheme.outlineVariant, primary, 0.10),
  );

  final baseTheme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
  );

  return baseTheme.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: scheme.onSurface,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: baseTheme.textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      color: surface,
      surfaceTintColor: primary.withValues(alpha: isDark ? 0.08 : 0.04),
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.primaryContainer,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return baseTheme.textTheme.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        );
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _blend(surface, primary, isDark ? 0.05 : 0.025),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? surfaceAlt : const Color(0xFF222826),
      contentTextStyle: TextStyle(
        color: isDark ? scheme.onSurface : Colors.white,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
  );
}

Color _blend(Color base, Color overlay, double alpha) {
  return Color.alphaBlend(overlay.withValues(alpha: alpha), base);
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _pages = const [
    HomeScreen(),
    MetronomeScreen(),
    LibraryScreen(),
    PitchTraceScreen(),
  ];

  Future<void> _pickHomePracticeImage() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final picked = await context
          .read<LibraryController>()
          .documentService
          .pickImage();
      if (!mounted || picked == null) return;

      await context.read<PracticeController>().saveHomePracticeImage(picked);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已更换首页练习图片')));
    } on DocumentLibraryException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomImage =
        context.watch<PracticeController>().homePracticeImage != null;

    return Scaffold(
      appBar: _index == 0
          ? AppBar(
              title: const Text('练琴乐时'),
              centerTitle: true,
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: '更多',
                  onSelected: (value) {
                    switch (value) {
                      case 'image':
                        _pickHomePracticeImage();
                        break;
                      case 'reset_image':
                        context
                            .read<PracticeController>()
                            .clearHomePracticeImage();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已恢复默认练习图片')),
                        );
                        break;
                      case 'theme':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ThemeSettingsScreen(),
                          ),
                        );
                        break;
                    }
                  },
                  itemBuilder: (context) {
                    return [
                      const PopupMenuItem(
                        value: 'image',
                        child: ListTile(
                          leading: Icon(Icons.image_outlined),
                          title: Text('更换练习图片'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (hasCustomImage)
                        const PopupMenuItem(
                          value: 'reset_image',
                          child: ListTile(
                            leading: Icon(Icons.restore_outlined),
                            title: Text('恢复默认图片'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'theme',
                        child: ListTile(
                          leading: Icon(Icons.palette_outlined),
                          title: Text('主题设置'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ];
                  },
                ),
              ],
            )
          : null,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.music_note_outlined),
            selectedIcon: Icon(Icons.music_note),
            label: '节拍器',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: '资料',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            selectedIcon: Icon(Icons.show_chart),
            label: '音高轨迹',
          ),
        ],
      ),
    );
  }
}
