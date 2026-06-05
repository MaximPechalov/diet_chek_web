import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../app.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _dietsKey = 'active_diets';
  static const String _themeKey = 'theme_mode';

  bool _noSugar = false;
  bool _keto = false;
  bool _lowFodmap = false;
  bool _lactoseFree = false;
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> activeDiets = prefs.getStringList(_dietsKey) ?? [];
      final String? themeStr = prefs.getString(_themeKey);

      setState(() {
        _noSugar = activeDiets.contains('no_sugar');
        _keto = activeDiets.contains('keto');
        _lowFodmap = activeDiets.contains('low_fodmap');
        _lactoseFree = activeDiets.contains('lactose_free');
        _themeMode = _parseThemeMode(themeStr);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDiets() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> activeDiets = [];
      if (_noSugar) activeDiets.add('no_sugar');
      if (_keto) activeDiets.add('keto');
      if (_lowFodmap) activeDiets.add('low_fodmap');
      if (_lactoseFree) activeDiets.add('lactose_free');
      await prefs.setStringList(_dietsKey, activeDiets);
    } catch (e) {}
  }

  Future<void> _saveTheme() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, _themeMode.name);
    } catch (e) {}
  }

  ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  void _toggleDiet(bool? value, String dietKey) {
    setState(() {
      switch (dietKey) {
        case 'no_sugar': _noSugar = value ?? false; break;
        case 'keto': _keto = value ?? false; break;
        case 'low_fodmap': _lowFodmap = value ?? false; break;
        case 'lactose_free': _lactoseFree = value ?? false; break;
      }
    });
    _saveDiets();
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _saveTheme();
    appKey.currentState?.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Настройки')),
        body: _buildSkeletonLoading(),
      );
    }

    final int activeCount = (_noSugar ? 1 : 0) + (_keto ? 1 : 0) + (_lowFodmap ? 1 : 0) + (_lactoseFree ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Кастомизация',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CustomizationScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Заголовок секции диет
          Row(
            children: [
              Icon(Icons.restaurant_menu, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Выберите диеты',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Анализ будет проводиться по выбранным диетам',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              // Бейдж с количеством активных диет
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: activeCount > 0
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$activeCount/4',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: activeCount > 0
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _AnimatedDietTile(
            title: 'Без добавленного сахара',
            subtitle: 'Исключает продукты с сахаром, сиропами, патокой, медом',
            value: _noSugar,
            onChanged: (v) => _toggleDiet(v, 'no_sugar'),
            color: AppColors.noSugarCard,
            icon: Icons.no_food,
            index: 0,
          ),
          _AnimatedDietTile(
            title: 'Кето / Низкоуглеводная',
            subtitle: 'Максимум жиров, минимум углеводов (< 25 г/день)',
            value: _keto,
            onChanged: (v) => _toggleDiet(v, 'keto'),
            color: AppColors.ketoCard,
            icon: Icons.egg,
            index: 1,
          ),
          _AnimatedDietTile(
            title: 'Low-FODMAP',
            subtitle: 'Для людей с СРК и вздутием',
            value: _lowFodmap,
            onChanged: (v) => _toggleDiet(v, 'low_fodmap'),
            color: AppColors.lowFodmapCard,
            icon: Icons.healing,
            index: 2,
          ),
          _AnimatedDietTile(
            title: 'Без лактозы',
            subtitle: 'Исключает молочный сахар',
            value: _lactoseFree,
            onChanged: (v) => _toggleDiet(v, 'lactose_free'),
            color: AppColors.lactoseFreeCard,
            icon: Icons.water_drop,
            index: 3,
          ),

          const SizedBox(height: 32),

          // Заголовок секции темы
          Row(
            children: [
              Icon(Icons.palette_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Оформление',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Выберите тему приложения',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          _ThemeOptionTile(
            title: 'Светлая',
            subtitle: 'Стандартная светлая тема',
            icon: Icons.light_mode,
            selected: _themeMode == ThemeMode.light,
            onTap: () => _setThemeMode(ThemeMode.light),
          ),
          _ThemeOptionTile(
            title: 'Тёмная',
            subtitle: 'Тёмная тема для экономии заряда',
            icon: Icons.dark_mode,
            selected: _themeMode == ThemeMode.dark,
            onTap: () => _setThemeMode(ThemeMode.dark),
          ),
          _ThemeOptionTile(
            title: 'Как в системе',
            subtitle: 'Автоматически подстраивается под систему',
            icon: Icons.settings_suggest,
            selected: _themeMode == ThemeMode.system,
            onTap: () => _setThemeMode(ThemeMode.system),
          ),

          const SizedBox(height: 32),

          // Информация
          Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'О приложении',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _InfoTile(
            icon: Icons.info_outline,
            title: 'О Dietio',
            subtitle: 'Версия 1.0.0',
            onTap: () => _showAboutDialog(context),
          ),
          _InfoTile(
            icon: Icons.storage,
            title: 'База продуктов',
            subtitle: 'Более 340 продуктов по 4 диетам',
            onTap: null,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ShimmerBox(height: 24, width: 180),
        const SizedBox(height: 16),
        ...List.generate(4, (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ShimmerBox(height: 80),
        )),
        const SizedBox(height: 20),
        _ShimmerBox(height: 24, width: 150),
        const SizedBox(height: 16),
        ...List.generate(3, (index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ShimmerBox(height: 65),
        )),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF2E7D32), const Color(0xFF4CAF50)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.receipt_long, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dietio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  Text('v1.0.0', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ],
          ),
          content: const Text(
            'Персональный диетический аудитор чеков.\n\n'
            'Сканируйте чеки и составы продуктов. Dietio анализирует каждый товар '
            'по выбранным диетам и показывает, что можно есть, а что нет.\n\n'
            '© 2026 Dietio',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }
}

// Анимированный тайл диеты
class _AnimatedDietTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool?> onChanged;
  final Color color;
  final IconData icon;
  final int index;

  const _AnimatedDietTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.color,
    required this.icon,
    required this.index,
  });

  @override
  State<_AnimatedDietTile> createState() => _AnimatedDietTileState();
}

class _AnimatedDietTileState extends State<_AnimatedDietTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 350 + (widget.index * 80)),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.value ? widget.color.withOpacity(0.4) : Colors.grey.withOpacity(0.15),
                width: widget.value ? 1.5 : 1,
              ),
              boxShadow: widget.value
                  ? [BoxShadow(color: widget.color.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: widget.value ? widget.color.withOpacity(0.04) : Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SwitchListTile(
                secondary: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.value ? widget.color.withOpacity(0.12) : Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.value ? widget.color : Colors.grey[400],
                    size: 22,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.value ? widget.color.withOpacity(0.12) : Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.value ? 'Активна' : 'Выкл',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.value ? widget.color : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    widget.subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.3),
                  ),
                ),
                value: widget.value,
                onChanged: widget.onChanged,
                activeColor: widget.color,
                inactiveThumbColor: Colors.grey[300],
                inactiveTrackColor: Colors.grey[200],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Тайл выбора темы
class _ThemeOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
                    : Colors.grey.withOpacity(0.15),
                width: selected ? 1.5 : 1,
              ),
              color: selected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.04)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? Theme.of(context).colorScheme.primary : Colors.grey[500],
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 15,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[200],
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Информационный тайл
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Шиммер для скелетона
class _ShimmerBox extends StatefulWidget {
  final double height;
  final double? width;

  const _ShimmerBox({required this.height, this.width});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.grey[200]!,
                Colors.grey[100]!,
                Colors.grey[200]!,
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value.clamp(0.0, 1.0),
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Экран кастомизации (без изменений, оставляю существующий)
class CustomizationScreen extends StatefulWidget {
  const CustomizationScreen({super.key});

  @override
  State<CustomizationScreen> createState() => _CustomizationScreenState();
}

class _CustomizationScreenState extends State<CustomizationScreen> {
  static const String _accentHueKey = 'accent_hue';
  static const String _backgroundHueKey = 'background_hue';
  static const String _backgroundSaturationKey = 'background_saturation';
  double _accentHue = 120;
  double _backgroundHue = 210;
  double _backgroundSaturation = 0.05;
  double _backgroundLightness = 0.95;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _accentHue = prefs.getDouble(_accentHueKey) ?? 120;
      _backgroundHue = prefs.getDouble(_backgroundHueKey) ?? 210;
      _backgroundSaturation = prefs.getDouble(_backgroundSaturationKey) ?? 0.05;
      _backgroundLightness = prefs.getDouble('background_lightness') ?? 0.95;
    });
  }

  Future<void> _saveHue() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_accentHueKey, _accentHue);
  }

  Future<void> _saveBackground() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_backgroundHueKey, _backgroundHue);
    await prefs.setDouble(_backgroundSaturationKey, _backgroundSaturation);
    await prefs.setDouble('background_lightness', _backgroundLightness);
  }

  void _setHue(double hue) {
    setState(() => _accentHue = hue);
    _saveHue();
    appKey.currentState?.setAccentColorFromHue(_accentHue);
  }

  void _setBackground(double hue, double saturation, double lightness) {
    setState(() {
      _backgroundHue = hue;
      _backgroundSaturation = saturation;
      _backgroundLightness = lightness;
    });
    _saveBackground();
    appKey.currentState?.setBackgroundColor(_backgroundHue, _backgroundSaturation, _backgroundLightness);
  }

  Color _currentColor() => HSLColor.fromAHSL(1.0, _accentHue, 0.5, 0.5).toColor();

  Color _previewBackgroundColor() {
    return HSLColor.fromAHSL(1.0, _backgroundHue, _backgroundSaturation, _backgroundLightness).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Кастомизация')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Заголовок секции
          Row(
            children: [
              Icon(Icons.color_lens, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Цветовая схема',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Выберите основной цвет приложения',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Превью цвета
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: _currentColor(),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _currentColor().withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // HSL слайдер
          _HueSlider(value: _accentHue, onChanged: _setHue),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Оттенок: ${_accentHue.toInt()}°',
              style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),

          const SizedBox(height: 36),

          // Заголовок секции фона
          Row(
            children: [
              Icon(Icons.wallpaper, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Фон',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Выберите цвет и насыщенность фона',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),

          // Превью фона
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: _previewBackgroundColor(),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Text(
                'Превью фона',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Слайдеры фона
          _buildSliderLabel('Цвет фона'),
          _HueSlider(value: _backgroundHue, onChanged: (v) => _setBackground(v, _backgroundSaturation, _backgroundLightness)),
          Center(
            child: Text(
              'Оттенок: ${_backgroundHue.toInt()}°',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),

          const SizedBox(height: 20),
          _buildSliderLabel('Насыщенность'),
          _buildSlider(
            value: _backgroundSaturation,
            min: 0,
            max: 0.6,
            leftIcon: Icons.blur_off,
            rightIcon: Icons.blur_on,
            onChanged: (v) => setState(() => _backgroundSaturation = v),
            onChangeEnd: (v) {
              _saveBackground();
              appKey.currentState?.setBackgroundColor(_backgroundHue, _backgroundSaturation, _backgroundLightness);
            },
            formatValue: (v) => '${(v * 100).toInt()}%',
          ),

          const SizedBox(height: 20),
          _buildSliderLabel('Яркость фона'),
          _buildSlider(
            value: _backgroundLightness,
            min: 0.80,
            max: 1.00,
            leftIcon: Icons.brightness_low,
            rightIcon: Icons.brightness_high,
            onChanged: (v) => setState(() => _backgroundLightness = v),
            onChangeEnd: (v) {
              _saveBackground();
              appKey.currentState?.setBackgroundColor(_backgroundHue, _backgroundSaturation, _backgroundLightness);
            },
            formatValue: (v) => '${(v * 100).toInt()}%',
          ),

          const SizedBox(height: 40),

          // Кнопки сброса
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _setHue(120);
                    _setBackground(210, 0.05, 0.95);
                  },
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Сбросить'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.setDouble(_accentHueKey, 120);
                    await prefs.setDouble(_backgroundHueKey, 210);
                    await prefs.setDouble(_backgroundSaturationKey, 0.05);
                    await prefs.setDouble('background_lightness', 0.95);
                    setState(() {
                      _accentHue = 120;
                      _backgroundHue = 210;
                      _backgroundSaturation = 0.05;
                      _backgroundLightness = 0.95;
                    });
                    appKey.currentState?.setAccentColorFromHue(120);
                    appKey.currentState?.setBackgroundColor(210, 0.05, 0.95);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Настройки сброшены'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('Сбросить всё'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSliderLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]),
      ),
    );
  }

  Widget _buildSlider({
    required double value,
    required double min,
    required double max,
    required IconData leftIcon,
    required IconData rightIcon,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
    required String Function(double) formatValue,
  }) {
    return Row(
      children: [
        Icon(leftIcon, size: 18, color: Colors.grey[500]),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            activeColor: _currentColor(),
          ),
        ),
        Icon(rightIcon, size: 18, color: Colors.grey[500]),
      ],
    );
  }
}

// HSL слайдер
class _HueSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _HueSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: GestureDetector(
        onPanDown: (d) => _update(d.localPosition.dx, context),
        onPanUpdate: (d) => _update(d.localPosition.dx, context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
                Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000),
              ],
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
            ],
          ),
          child: Align(
            alignment: Alignment(value / 360 * 2 - 1, 0),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!, width: 3),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _update(double dx, BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final double clamped = (dx / box.size.width * 360).clamp(0, 360);
    onChanged(clamped);
  }
}