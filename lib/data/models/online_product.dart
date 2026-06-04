class OnlineProduct {
  final String id;
  final String name;
  final String? brand;
  final String? imageUrl;
  final String? ingredientsText;
  final Map<String, double> nutrients; // ккал, белки, жиры, углеводы на 100г
  final List<String> allergens;
  final List<String> labels; // экомаркировки, сертификаты
  final String? source; // откуда данные: 'open_food_facts', 'cache'

  const OnlineProduct({
    required this.id,
    required this.name,
    this.brand,
    this.imageUrl,
    this.ingredientsText,
    required this.nutrients,
    required this.allergens,
    required this.labels,
    this.source,
  });

  factory OnlineProduct.fromOpenFoodFacts(Map<String, dynamic> json) {
    final Map<String, dynamic> product = json['product'] as Map<String, dynamic>? ?? {};

    // Извлекаем нутриенты
    final Map<String, double> nutrients = {};
    final Map<String, dynamic>? nutriments = product['nutriments'] as Map<String, dynamic>?;

    if (nutriments != null) {
      if (nutriments['energy-kcal_100g'] != null) {
        nutrients['energy_kcal'] = _toDouble(nutriments['energy-kcal_100g']);
      }
      if (nutriments['proteins_100g'] != null) {
        nutrients['proteins'] = _toDouble(nutriments['proteins_100g']);
      }
      if (nutriments['fat_100g'] != null) {
        nutrients['fat'] = _toDouble(nutriments['fat_100g']);
      }
      if (nutriments['carbohydrates_100g'] != null) {
        nutrients['carbohydrates'] = _toDouble(nutriments['carbohydrates_100g']);
      }
      if (nutriments['sugars_100g'] != null) {
        nutrients['sugars'] = _toDouble(nutriments['sugars_100g']);
      }
      if (nutriments['fiber_100g'] != null) {
        nutrients['fiber'] = _toDouble(nutriments['fiber_100g']);
      }
    }

    // Извлекаем аллергены
    final List<String> allergens = [];
    final String? allergensStr = product['allergens'] as String?;
    if (allergensStr != null && allergensStr.isNotEmpty) {
      allergens.addAll(allergensStr.split(',').map((s) => s.trim()));
    }

    // Извлекаем метки
    final List<String> labels = [];
    final String? labelsStr = product['labels'] as String?;
    if (labelsStr != null && labelsStr.isNotEmpty) {
      labels.addAll(labelsStr.split(',').map((s) => s.trim()));
    }

    return OnlineProduct(
      id: product['_id'] as String? ?? '',
      name: product['product_name'] as String? ?? 'Неизвестный продукт',
      brand: product['brands'] as String?,
      imageUrl: product['image_url'] as String?,
      ingredientsText: product['ingredients_text'] as String?,
      nutrients: nutrients,
      allergens: allergens,
      labels: labels,
      source: 'open_food_facts',
    );
  }

  // Для создания из кеша
  factory OnlineProduct.fromCache(Map<String, dynamic> json) {
    return OnlineProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      imageUrl: json['image_url'] as String?,
      ingredientsText: json['ingredients_text'] as String?,
      nutrients: Map<String, double>.from(json['nutrients'] as Map),
      allergens: List<String>.from(json['allergens'] as List),
      labels: List<String>.from(json['labels'] as List),
      source: 'cache',
    );
  }

  Map<String, dynamic> toCache() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'image_url': imageUrl,
      'ingredients_text': ingredientsText,
      'nutrients': nutrients,
      'allergens': allergens,
      'labels': labels,
    };
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String get nutrientsSummary {
    final List<String> parts = [];
    if (nutrients.containsKey('energy_kcal')) {
      parts.add('${nutrients['energy_kcal']!.toStringAsFixed(0)} ккал');
    }
    if (nutrients.containsKey('proteins')) {
      parts.add('Б: ${nutrients['proteins']!.toStringAsFixed(1)}г');
    }
    if (nutrients.containsKey('fat')) {
      parts.add('Ж: ${nutrients['fat']!.toStringAsFixed(1)}г');
    }
    if (nutrients.containsKey('carbohydrates')) {
      parts.add('У: ${nutrients['carbohydrates']!.toStringAsFixed(1)}г');
    }
    return parts.join(' | ');
  }

  @override
  String toString() => 'OnlineProduct($name, $nutrientsSummary)';
}