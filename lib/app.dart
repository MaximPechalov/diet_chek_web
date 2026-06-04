import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/scanner/scanner_screen.dart';
import 'features/scanner/composition_scanner_screen.dart';
import 'features/history/history_screen.dart';
import 'features/statistics/statistics_screen.dart';
import 'features/settings/settings_screen.dart';
import 'core/constants/app_colors.dart';

final GlobalKey<DietioAppState> appKey = GlobalKey<DietioAppState>();

class DietioApp extends StatefulWidget {
  DietioApp() : super(key: appKey);

  @override
  State<DietioApp> createState() => DietioAppState();
}

class DietioAppState extends State<DietioApp> {
  ThemeMode _themeMode = ThemeMode.system;
  double _accentHue = 120;
  double _backgroundHue = 210;
  double _backgroundSaturation = 0.05;
  double _backgroundLightness = 0.95;

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
      _backgroundHue = prefs.getDouble('background_hue') ?? 210;
      _backgroundSaturation = prefs.getDouble('background_saturation') ?? 0.05;
      _backgroundLightness = prefs.getDouble('background_lightness') ?? 0.95;
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

  void setBackgroundColor(double hue, double saturation, double lightness) {
    setState(() {
      _backgroundHue = hue;
      _backgroundSaturation = saturation;
      _backgroundLightness = lightness;
    });
  }

  Color get _accentColor => HSLColor.fromAHSL(1.0, _accentHue, 0.5, 0.5).toColor();

  Color get _backgroundColor {
    if (_themeMode == ThemeMode.dark) {
      return const Color(0xFF121212);
    }
    return HSLColor.fromAHSL(1.0, _backgroundHue, _backgroundSaturation, _backgroundLightness).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _accentColor;

    return MaterialApp(
      title: 'Dietio',
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
  final PageController _pageController = PageController();

  final List<Widget> _screens = const [
    ScannerScreen(),
    CompositionScannerScreen(),
    HistoryScreen(),
    StatisticsScreen(),
    SettingsScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _screens,
        onPageChanged: (int index) {
          setState(() => _currentIndex = index);
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        animationDuration: const Duration(milliseconds: 400),
        onDestinationSelected: (int index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
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
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Статистика',
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