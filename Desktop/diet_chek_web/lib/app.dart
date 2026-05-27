import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/scanner/scanner_screen.dart';
import 'features/scanner/composition_scanner_screen.dart';
import 'features/history/history_screen.dart';
import 'features/settings/settings_screen.dart';
import 'core/constants/app_colors.dart';

final GlobalKey<DietChekAppState> appKey = GlobalKey<DietChekAppState>();

class DietChekApp extends StatefulWidget {
  DietChekApp() : super(key: appKey);

  @override
  State<DietChekApp> createState() => DietChekAppState();
}

class DietChekAppState extends State<DietChekApp> {
  ThemeMode _themeMode = ThemeMode.system;
  double _accentHue = 120;
  double _backgroundWarmth = 0;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? themeStr = prefs.getString('theme_mode');
      _accentHue = prefs.getDouble('accent_hue') ?? 120;
      _backgroundWarmth = prefs.getDouble('background_warmth') ?? 0;
      setState(() {
        switch (themeStr) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          default:
            _themeMode = ThemeMode.system;
        }
      });
    } catch (e) {}
  }

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  void setAccentColorFromHue(double hue) {
    setState(() => _accentHue = hue);
  }

  void setBackgroundWarmth(double warmth) {
    setState(() => _backgroundWarmth = warmth);
  }

  Color get _accentColor => HSLColor.fromAHSL(1.0, _accentHue, 0.5, 0.5).toColor();

  Color get _backgroundColor {
    if (_themeMode == ThemeMode.dark) {
      return const Color(0xFF121212);
    }
    return Color.lerp(
      const Color(0xFFF5F5F5),
      const Color(0xFFF5F0E8),
      _backgroundWarmth,
    )!;
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _accentColor;

    return MaterialApp(
      title: 'DietChek',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        scaffoldBackgroundColor: _backgroundColor,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      home: const MainNavigationScreen(),
      routes: {
        '/home': (context) => const MainNavigationScreen(),
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ScannerScreen(),
    CompositionScannerScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Чек',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Состав',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'История',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}