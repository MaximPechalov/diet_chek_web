import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class LocalDatabase {
  LocalDatabase._();

  // Хранилище продуктов в оперативной памяти
  // Ключ — нормализованное название (например, "творог"),
  // Значение — Map с полями из JSON (category, attributes, diet_rules и т.д.)
  static final Map<String, Map<String, dynamic>> _products = {};

  // Правила диет, загруженные из секции "diets" JSON-файла
  static final Map<String, dynamic> _diets = {};

  // Мета-информация (версия, дата, правила OCR)
  static Map<String, dynamic> _meta = {};

  // Публичные геттеры — только для чтения
  static Map<String, Map<String, dynamic>> get products => _products;
  static Map<String, dynamic> get diets => _diets;
  static Map<String, dynamic> get meta => _meta;

  // Загрузка JSON из assets в память
  static Future<void> initialize() async {
    // Читаем файл как строку
    final String jsonString = await rootBundle.loadString(
      'assets/database/food_database.json',
    );

    // Декодируем JSON
    final Map<String, dynamic> data = json.decode(jsonString);

    // Сохраняем мета-информацию
    _meta = data['meta'] as Map<String, dynamic>;

    // Сохраняем диеты
    _diets.clear();
    _diets.addAll(data['diets'] as Map<String, dynamic>);

    // Сохраняем продукты из всех категорий в плоский Map
    _products.clear();
    final Map<String, dynamic> productsSection =
        data['products'] as Map<String, dynamic>;

    for (final String category in productsSection.keys) {
      final Map<String, dynamic> categoryProducts =
          productsSection[category] as Map<String, dynamic>;

      for (final String productKey in categoryProducts.keys) {
        _products[productKey] =
            categoryProducts[productKey] as Map<String, dynamic>;
      }
    }
  }

  // Поиск продукта по ключу
  static Map<String, dynamic>? findProduct(String normalizedKey) {
    return _products[normalizedKey];
  }

  // Проверка, загружена ли база
  static bool get isInitialized => _products.isNotEmpty;
}