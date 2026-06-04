// lib/data/repositories/product_repository.dart
import '../datasources/local_database.dart';
import '../models/product.dart';

class ProductRepository {
  // Кеш уже созданных объектов Product, чтобы не парсить JSON каждый раз
  final Map<String, Product> _cache = {};

  // Поиск продукта по нормализованному ключу из чека
  // Возвращает Product, если нашли, иначе null
  Product? findByKey(String normalizedKey) {
    // Сначала проверяем кеш
    if (_cache.containsKey(normalizedKey)) {
      return _cache[normalizedKey];
    }

    // Ищем в сырых данных LocalDatabase
    final Map<String, dynamic>? jsonData = LocalDatabase.findProduct(normalizedKey);

    if (jsonData == null) {
      return null;
    }

    // Создаём типизированный объект и кладём в кеш
    final Product product = Product.fromJson(normalizedKey, jsonData);
    _cache[normalizedKey] = product;
    return product;
  }

  // Поиск продукта по строке из чека (перебором токенов)
  // Принимает уже нормализованную строку (например, "творог простоквашино 9")
  // Возвращает Product и ключ, по которому нашли совпадение
  Product? findByNormalizedText(String normalizedText) {
    // Проходим по всем продуктам в базе
    for (final String key in LocalDatabase.products.keys) {
      final Map<String, dynamic> jsonData = LocalDatabase.products[key]!;
      final List<dynamic> tokens = jsonData['base_tokens'] as List<dynamic>;

      // Проверяем, содержит ли нормализованная строка хотя бы один токен продукта
      for (final dynamic token in tokens) {
        if (normalizedText.contains(token.toString().toLowerCase())) {
          return findByKey(key);
        }
      }
    }

    return null;
  }

  // Поиск продуктов по категории
  List<Product> findByCategory(String category) {
    final List<Product> result = [];

    for (final String key in LocalDatabase.products.keys) {
      final Product? product = findByKey(key);
      if (product != null && product.category == category) {
        result.add(product);
      }
    }

    return result;
  }

  // Получение всех продуктов (для отладки или админки)
  List<Product> getAllProducts() {
    final List<Product> result = [];

    for (final String key in LocalDatabase.products.keys) {
      final Product? product = findByKey(key);
      if (product != null) {
        result.add(product);
      }
    }

    return result;
  }

  // Проверка, загружена ли база
  bool get isDatabaseReady {
    return LocalDatabase.isInitialized;
  }

  // Количество продуктов в базе
  int get productCount {
    return LocalDatabase.products.length;
  }

  // Очистка кеша (если база обновилась)
  void clearCache() {
    _cache.clear();
  }
}