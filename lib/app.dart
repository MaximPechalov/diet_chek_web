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

  void setThemeMode(ThemeMode mode) => setState(() => _themeMode = mode);
  void setAccentColorFromHue(double hue) => setState(() => _accentHue = hue);
  void setBackgroundColor(double hue, double saturation, double lightness) {
    setState(() {
      _backgroundHue = hue;
      _backgroundSaturation = saturation;
      _backgroundLightness = lightness;
    });
  }

  Color get _accentColor =>
      HSLColor.fromAHSL(1.0, _accentHue, 0.5, 0.5).toColor();

  Color get _backgroundColor {
    if (_themeMode == ThemeMode.dark) return const Color(0xFF121212);
    return HSLColor.fromAHSL(
      1.0,
      _backgroundHue,
      _backgroundSaturation,
      _backgroundLightness,
    ).toColor();
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
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        scaffoldBackgroundColor: _backgroundColor,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      home: const MainNavigationScreen(),
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
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final double tabWidth =
        MediaQuery.of(context).size.width / _screens.length;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        children: _screens,
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Анимированный индикатор
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              top: 8,
              left: _getIndicatorPosition(tabWidth),
              child: Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Табы
            Row(
              children: [
                _buildTab(
                  index: 0,
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'Чек',
                  primaryColor: primaryColor,
                ),
                _buildTab(
                  index: 1,
                  icon: Icons.menu_book_outlined,
                  activeIcon: Icons.menu_book,
                  label: 'Состав',
                  primaryColor: primaryColor,
                ),
                _buildTab(
                  index: 2,
                  icon: Icons.history_outlined,
                  activeIcon: Icons.history,
                  label: 'История',
                  primaryColor: primaryColor,
                ),
                _buildTab(
                  index: 3,
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart,
                  label: 'Статистика',
                  primaryColor: primaryColor,
                ),
                _buildTab(
                  index: 4,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Настройки',
                  primaryColor: primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _getIndicatorPosition(double tabWidth) {
    return _currentIndex * tabWidth + (tabWidth - 28) / 2;
  }

  Widget _buildTab({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required Color primaryColor,
  }) {
    final bool isActive = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index != _currentIndex) {
            setState(() => _currentIndex = index);
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
            );
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey('${index}_$isActive'),
                size: 24,
                color: isActive ? primaryColor : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? primaryColor : Colors.grey[400],
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}