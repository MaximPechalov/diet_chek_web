// lib/features/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Ключи для хранения настроек
  static const String _dietsKey = 'active_diets';

  // Состояние переключателей диет
  bool _noSugar = false;
  bool _keto = false;
  bool _lowFodmap = false;
  bool _lactoseFree = false;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Загружаем настройки из SharedPreferences
  Future<void> _loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> activeDiets = prefs.getStringList(_dietsKey) ?? [];

    setState(() {
      _noSugar = activeDiets.contains('no_sugar');
      _keto = activeDiets.contains('keto');
      _lowFodmap = activeDiets.contains('low_fodmap');
      _lactoseFree = activeDiets.contains('lactose_free');
      _isLoading = false;
    });
  }

  // Сохраняем выбранные диеты
  Future<void> _saveSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> activeDiets = [];

    if (_noSugar) activeDiets.add('no_sugar');
    if (_keto) activeDiets.add('keto');
    if (_lowFodmap) activeDiets.add('low_fodmap');
    if (_lactoseFree) activeDiets.add('lactose_free');

    await prefs.setStringList(_dietsKey, activeDiets);
  }

  // Переключение диеты с сохранением
  Future<void> _toggleDiet(bool? value, String dietKey) async {
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

    await _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Секция выбора диет
          _buildSectionHeader('Выберите диеты', 'Анализ чека будет проводиться по выбранным диетам'),

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
            subtitle: 'Для людей с СРК и вздутием. Исключает ферментируемые углеводы',
            value: _lowFodmap,
            onChanged: (bool? value) => _toggleDiet(value, 'low_fodmap'),
            color: const Color(0xFFAB47BC),
            icon: Icons.healing,
          ),

          _DietSwitchTile(
            title: 'Без лактозы',
            subtitle: 'Исключает молочный сахар. Для людей с лактазной недостаточностью',
            value: _lactoseFree,
            onChanged: (bool? value) => _toggleDiet(value, 'lactose_free'),
            color: const Color(0xFF26A69A),
            icon: Icons.water_drop,
          ),

          const SizedBox(height: 24),

          // Секция информации
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
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
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
            'Сфотографируйте чек из магазина и получите мгновенный анализ продуктов '
            'по выбранным диетам.\n\n'
            'Приложение работает полностью офлайн. Ваши чеки хранятся только на устройстве.',
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
            'Текущая версия: 1.0\n'
            'Дата обновления: 24 мая 2026\n\n'
            'Содержит более 200 продуктов по 4 диетам:\n'
            '• Без сахара\n'
            '• Кето\n'
            '• Low-FODMAP\n'
            '• Без лактозы\n\n'
            'База регулярно пополняется. Обновления загружаются автоматически.',
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

// Виджет одного переключателя диеты
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