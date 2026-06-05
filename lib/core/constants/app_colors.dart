import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Брендовые цвета
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color primaryDark = Color(0xFF1B5E20);

  // Фон и поверхности
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEEEEEE);

  // Статусы диет — светофор
  static const Color statusAllowed = Color(0xFF4CAF50);
  static const Color statusWarning = Color(0xFFFFC107);
  static const Color statusForbidden = Color(0xFFF44336);

  // Текст
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnStatus = Color(0xFFFFFFFF);

  // Карточки диет
  static const Color ketoCard = Color(0xFFFF7043);
  static const Color noSugarCard = Color(0xFF42A5F5);
  static const Color lowFodmapCard = Color(0xFFAB47BC);
  static const Color lactoseFreeCard = Color(0xFF26A69A);

  // Цвета для конфетти
  static const List<Color> confettiColors = [
    Color(0xFF4CAF50), // зеленый
    Color(0xFFFFC107), // желтый
    Color(0xFF2196F3), // синий
    Color(0xFFFF5722), // оранжевый
    Color(0xFF9C27B0), // фиолетовый
    Color(0xFF00BCD4), // голубой
    Color(0xFFFF4081), // розовый
    Color(0xFF8BC34A), // лайм
  ];

  // Цвета для скелетонов
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  // Тени
  static Color shadowLight = Colors.black.withOpacity(0.08);
  static Color shadowMedium = Colors.black.withOpacity(0.15);
  static Color shadowDark = Colors.black.withOpacity(0.25);

  // Получение цвета диеты
  static Color getDietColor(String dietKey) {
    switch (dietKey) {
      case 'no_sugar':
        return noSugarCard;
      case 'keto':
        return ketoCard;
      case 'low_fodmap':
        return lowFodmapCard;
      case 'lactose_free':
        return lactoseFreeCard;
      default:
        return Colors.grey;
    }
  }

  // Получение названия диеты
  static String getDietName(String dietKey) {
    switch (dietKey) {
      case 'no_sugar':
        return 'Без сахара';
      case 'keto':
        return 'Кето';
      case 'low_fodmap':
        return 'Low-FODMAP';
      case 'lactose_free':
        return 'Без лактозы';
      default:
        return dietKey;
    }
  }

  // Получение короткого названия диеты
  static String getDietShortName(String dietKey) {
    switch (dietKey) {
      case 'no_sugar':
        return 'Сахар';
      case 'keto':
        return 'Кето';
      case 'low_fodmap':
        return 'FODMAP';
      case 'lactose_free':
        return 'Лактоза';
      default:
        return dietKey;
    }
  }

  // Получение иконки диеты
  static IconData getDietIcon(String dietKey) {
    switch (dietKey) {
      case 'no_sugar':
        return Icons.no_food;
      case 'keto':
        return Icons.egg;
      case 'low_fodmap':
        return Icons.healing;
      case 'lactose_free':
        return Icons.water_drop;
      default:
        return Icons.help_outline;
    }
  }
}