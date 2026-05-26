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
}