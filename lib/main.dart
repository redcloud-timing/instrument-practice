import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'controllers/theme_controller.dart';
import 'controllers/tuner_controller.dart';
import 'controllers/metronome_controller.dart';
import 'controllers/practice_controller.dart';
import 'controllers/library_controller.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/metronome_screen.dart';
import 'screens/theme_settings_screen.dart';
import 'screens/tuner_screen.dart';
import 'services/database_service.dart';
import 'services/document_library_service.dart';
import 'services/metronome_sound_service.dart';
import 'services/tuner_service.dart';

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
                ..init(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              LibraryController(databaseService, DocumentLibraryService())
                ..init(),
        ),
        ChangeNotifierProvider(create: (_) => TunerController(TunerService())),
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
    final themeColor = context.watch<ThemeController>().themeColor;

    return MaterialApp(
      title: '长笛练习',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: themeColor).copyWith(
          primary: themeColor,
          onPrimary: themeColor.computeLuminance() > 0.5
              ? Colors.black
              : Colors.white,
        ),
        cardTheme: const CardThemeData(margin: EdgeInsets.zero),
      ),
      home: const MainShell(),
    );
  }
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
    TunerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _index == 0
          ? AppBar(
              title: const Text('长笛练习'),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: '主题设置',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ThemeSettingsScreen(),
                      ),
                    );
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
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: '调音器',
          ),
        ],
      ),
    );
  }
}
