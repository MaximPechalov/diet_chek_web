import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class IngredientAnalyzer {
  static Map<String, dynamic>? _forbiddenData;
  static bool _isLoaded = false;

  // Загрузка словаря запрещённых ингредиентов
  static Future<void> initialize() async {
    if (_isLoaded) return;

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/database/forbidden_ingredients.json',
      );
      _forbiddenData = json.decode(jsonString) as Map<String, dynamic>;
      _isLoaded = true;
    } catch (e) {
      _isLoaded = false;
    }
  }

  // Главный метод: анализ текста состава
  // Возвращает Map: ключ — название диеты, значение — список найденных опасных ингредиентов
  static Map<String, List<FoundIngredient>> analyze(
    String compositionText, {
    List<String>? activeDiets,
  }) {
    final Map<String, List<FoundIngredient>> results = {};

    if (!_isLoaded || _forbiddenData == null) return results;

    // Нормализуем текст
    final String normalizedText = compositionText.toLowerCase().trim();

    // Список диет для проверки (все или только активные)
    final List<String> dietsToCheck = activeDiets ?? _forbiddenData!.keys.toList();

    for (final String dietKey in dietsToCheck) {
      if (!_forbiddenData!.containsKey(dietKey)) continue;

      final Map<String, dynamic> dietData = _forbiddenData![dietKey] as Map<String, dynamic>;
      final List<dynamic> ingredients = dietData['ingredients'] as List<dynamic>;

      final List<FoundIngredient> found = [];

      for (final dynamic ingredient in ingredients) {
        final String ingredientStr = ingredient.toString().toLowerCase();

        if (normalizedText.contains(ingredientStr)) {
          found.add(FoundIngredient(
            ingredient: ingredient.toString(),
            dietKey: dietKey,
          ));
        }
      }

      if (found.isNotEmpty) {
        results[dietKey] = found;
      }
    }

    return results;
  }

  // Получение названия диеты по ключу
  static String getDietName(String dietKey) {
    if (_forbiddenData == null) return dietKey;
    final Map<String, dynamic>? dietData = _forbiddenData![dietKey] as Map<String, dynamic>?;
    return dietData?['name'] as String? ?? dietKey;
  }

  // Проверка, загружен ли словарь
  static bool get isLoaded => _isLoaded;
}

// Модель найденного ингредиента
class FoundIngredient {
  final String ingredient;
  final String dietKey;

  const FoundIngredient({
    required this.ingredient,
    required this.dietKey,
  });

  String get dietName => IngredientAnalyzer.getDietName(dietKey);

  @override
  String toString() => '$ingredient ($dietKey)';
}