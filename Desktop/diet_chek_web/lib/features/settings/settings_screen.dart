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
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void _toggleDiet(bool? value, String dietKey) {
    setState(() {
      switch (dietKey) {
        case 'no_sugar':
          _noSugar = value ?? false;
          break;
        case 'keto':
          _keto = value ?? false;
          break;
        case 'low_fodmap':
          _lowFodmap = value ?? false;
          break;
        case 'lactose_free':
          _lactoseFree = value ?? false;
          break;
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Выберите диеты', 'Анализ будет проводиться по выбранным диетам'),
          const SizedBox(height: 8),

          _DietSwitchTile(
            title: 'Без добавленного сахара',
            subtitle: 'Исключает продукты с сахаром, сиропами, патокой, медом',
            value: _noSugar,
            onChanged: (bool? value) => _toggleDiet(value, 'no_sugar'),
            color: const Color(0xFF42A5F5),
            icon: Icons.no_food,
          ),
          _DietSwitchTile(
            title: 'Кето / Низкоуглеводная',
            subtitle: 'Максимум жиров, минимум углеводов (< 25 г/день)',
            value: _keto,
            onChanged: (bool? value) => _toggleDiet(value, 'keto'),
            color: const Color(0xFFFF7043),
            icon: Icons.egg,
          ),
          _DietSwitchTile(
            title: 'Low-FODMAP',
            subtitle: 'Для людей с СРК и вздутием',
            value: _lowFodmap,
            onChanged: (bool? value) => _toggleDiet(value, 'low_fodmap'),
            color: const Color(0xFFAB47BC),
            icon: Icons.healing,
          ),
          _DietSwitchTile(
            title: 'Без лактозы',
            subtitle: 'Исключает молочный сахар',
            value: _lactoseFree,
            onChanged: (bool? value) => _toggleDiet(value, 'lactose_free'),
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

          const SizedBox(height: 32),
          _buildSectionHeader('О приложении', null),
          const SizedBox(height: 8),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('О DietChek'),
            subtitle: const Text('Версия 1.0.0'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAboutDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('База продуктов'),
            subtitle: const Text('Версия 1.0 от 24.05.2026'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDatabaseInfo(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Связаться с нами'),
            subtitle: const Text('Предложения и пожелания'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email: support@dietchek.app')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.5,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('О приложении'),
          content: const Text(
            'DietChek — ваш персональный диетический аудитор.\n\n'
            'Сфотографируйте чек или состав продукта и получите мгновенный анализ '
            'по выбранным диетам.\n\n'
            'Приложение работает полностью офлайн.',
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

  void _showDatabaseInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('База продуктов'),
          content: Text(
            'Текущая версия: 1.0\nДата обновления: 24 мая 2026\n\n'
            'Содержит более 200 продуктов по 4 диетам:\n'
            '• Без сахара\n• Кето\n• Low-FODMAP\n• Без лактозы\n\n'
            'База регулярно пополняется.',
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

class _DietSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool?> onChanged;
  final Color color;
  final IconData icon;

  const _DietSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
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

  const _ThemeOptionTile({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: selected ? Theme.of(context).colorScheme.primary : null),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        trailing: selected
            ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}