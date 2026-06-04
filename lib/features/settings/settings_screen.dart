import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
          _buildSectionHeader('Выберите диеты', 'Анализ будет проводиться по выбранным диетам'),
          const SizedBox(height: 8),

          _DietSwitchTile(
            title: 'Без добавленного сахара',
            subtitle: 'Исключает продукты с сахаром, сиропами, патокой, медом',
            value: _noSugar,
            onChanged: (v) => _toggleDiet(v, 'no_sugar'),
            color: const Color(0xFF42A5F5),
            icon: Icons.no_food,
          ),
          _DietSwitchTile(
            title: 'Кето / Низкоуглеводная',
            subtitle: 'Максимум жиров, минимум углеводов (< 25 г/день)',
            value: _keto,
            onChanged: (v) => _toggleDiet(v, 'keto'),
            color: const Color(0xFFFF7043),
            icon: Icons.egg,
          ),
          _DietSwitchTile(
            title: 'Low-FODMAP',
            subtitle: 'Для людей с СРК и вздутием',
            value: _lowFodmap,
            onChanged: (v) => _toggleDiet(v, 'low_fodmap'),
            color: const Color(0xFFAB47BC),
            icon: Icons.healing,
          ),
          _DietSwitchTile(
            title: 'Без лактозы',
            subtitle: 'Исключает молочный сахар',
            value: _lactoseFree,
            onChanged: (v) => _toggleDiet(v, 'lactose_free'),
            color: const Color(0xFF26A69A),
            icon: Icons.water_drop,
          ),

          const SizedBox(height: 32),
          _buildSectionHeader('Оформление', 'Выберите тему приложения'),
          const SizedBox(height: 8),

          _ThemeOptionTile(
            title: 'Светлая',
            icon: Icons.light_mode,
            selected: _themeMode == ThemeMode.light,
            onTap: () => _setThemeMode(ThemeMode.light),
          ),
          _ThemeOptionTile(
            title: 'Тёмная',
            icon: Icons.dark_mode,
            selected: _themeMode == ThemeMode.dark,
            onTap: () => _setThemeMode(ThemeMode.dark),
          ),
          _ThemeOptionTile(
            title: 'Как в системе',
            icon: Icons.settings_suggest,
            selected: _themeMode == ThemeMode.system,
            onTap: () => _setThemeMode(ThemeMode.system),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.5)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ],
    );
  }
}

// ============ ЭКРАН КАСТОМИЗАЦИИ ============

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
  }

  void _setHue(double hue) {
    setState(() => _accentHue = hue);
    _saveHue();
    appKey.currentState?.setAccentColorFromHue(_accentHue);
  }

  void _setBackground(double hue, double saturation) {
    setState(() {
      _backgroundHue = hue;
      _backgroundSaturation = saturation;
    });
    _saveBackground();
    appKey.currentState?.setBackgroundColor(_backgroundHue, _backgroundSaturation);
  }

  Color _currentColor() => HSLColor.fromAHSL(1.0, _accentHue, 0.5, 0.5).toColor();

  Color _previewBackgroundColor() {
    return HSLColor.fromAHSL(1.0, _backgroundHue, _backgroundSaturation, 0.95).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Кастомизация')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Цветовая схема', 'Выберите основной цвет приложения'),
          const SizedBox(height: 20),

          Center(
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _currentColor(),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _currentColor().withOpacity(0.5), blurRadius: 16, spreadRadius: 2)],
              ),
            ),
          ),
          const SizedBox(height: 24),

          _HueSlider(value: _accentHue, onChanged: _setHue),

          const SizedBox(height: 8),
          Center(child: Text('Оттенок: ${_accentHue.toInt()}°', style: TextStyle(fontSize: 12, color: Colors.grey[600]))),

          const SizedBox(height: 32),
          _buildSectionHeader('Фон', 'Выберите цвет и насыщенность фона'),
          const SizedBox(height: 16),

          Center(
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: _previewBackgroundColor(),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Center(
                child: Text('Превью фона', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text('Цвет фона', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          _HueSlider(value: _backgroundHue, onChanged: (v) => _setBackground(v, _backgroundSaturation)),
          const SizedBox(height: 4),
          Center(child: Text('Оттенок: ${_backgroundHue.toInt()}°', style: TextStyle(fontSize: 11, color: Colors.grey[500]))),

          const SizedBox(height: 16),
          Text('Насыщенность', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.blur_off, size: 16, color: Colors.grey),
              Expanded(
                child: Slider(
                  value: _backgroundSaturation,
                  min: 0,
                  max: 0.8,
                  onChanged: (v) => setState(() => _backgroundSaturation = v),
                  onChangeEnd: (v) {
                    _saveBackground();
                    appKey.currentState?.setBackgroundColor(_backgroundHue, _backgroundSaturation);
                  },
                  activeColor: _currentColor(),
                ),
              ),
              const Icon(Icons.blur_on, size: 16, color: Colors.grey),
            ],
          ),
          Center(child: Text('${(_backgroundSaturation * 100).toInt()}%', style: TextStyle(fontSize: 11, color: Colors.grey[500]))),

          const SizedBox(height: 40),
          _buildSectionHeader('Сброс', null),
          const SizedBox(height: 8),

          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Сбросить цвет'),
            subtitle: const Text('Вернуть зелёный цвет по умолчанию'),
            onTap: () {
              _setHue(120);
              _setBackground(210, 0.05);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('Сбросить всё'),
            subtitle: const Text('Вернуть настройки по умолчанию'),
            onTap: () async {
              final SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setDouble(_accentHueKey, 120);
              await prefs.setDouble(_backgroundHueKey, 210);
              await prefs.setDouble(_backgroundSaturationKey, 0.05);
              setState(() {
                _accentHue = 120;
                _backgroundHue = 210;
                _backgroundSaturation = 0.05;
              });
              appKey.currentState?.setAccentColorFromHue(120);
              appKey.currentState?.setBackgroundColor(210, 0.05);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Настройки сброшены.')),
                );
              }
            },
          ),

          const SizedBox(height: 40),
          _buildSectionHeader('О приложении', null),
          const SizedBox(height: 8),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('DietChek'),
            subtitle: const Text('Версия 1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('База продуктов'),
            subtitle: const Text('Версия 1.0 от 24.05.2026'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.5)),
        if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600]))],
      ],
    );
  }
}

// ============ ВИДЖЕТЫ ============

class _DietSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool?> onChanged;
  final Color color;
  final IconData icon;

  const _DietSwitchTile({required this.title, required this.subtitle, required this.value, required this.onChanged, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        secondary: Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        value: value,
        onChanged: onChanged,
        activeColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionTile({required this.title, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: selected ? Theme.of(context).colorScheme.primary : null),
        title: Text(title, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? Theme.of(context).colorScheme.primary : null)),
        trailing: selected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _HueSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _HueSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: GestureDetector(
        onPanDown: (d) => _update(d.localPosition.dx, context),
        onPanUpdate: (d) => _update(d.localPosition.dx, context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(colors: [
              Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
              Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000),
            ]),
          ),
          child: Align(
            alignment: Alignment(value / 360 * 2 - 1, 0),
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: Colors.white, shape: BoxShape.circle,
                border: Border.all(color: Colors.black26, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
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