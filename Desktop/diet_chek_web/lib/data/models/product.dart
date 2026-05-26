import 'diet_rule.dart';

class Product {
  final String key;
  final String category;
  final String subcategory;
  final List<String> baseTokens;
  final Map<String, dynamic> attributes;
  final Map<String, DietRule> dietRules;

  const Product({
    required this.key,
    required this.category,
    required this.subcategory,
    required this.baseTokens,
    required this.attributes,
    required this.dietRules,
  });

  factory Product.fromJson(String key, Map<String, dynamic> json) {
    // Парсим diet_rules в типизированный Map
    final Map<String, DietRule> parsedRules = {};
    final Map<String, dynamic> rulesJson = json['diet_rules'] as Map<String, dynamic>;

    for (final String dietKey in rulesJson.keys) {
      final dynamic ruleValue = rulesJson[dietKey];

      if (ruleValue is String) {
        // Простой случай: "allowed" или "forbidden"
        parsedRules[dietKey] = DietRule(
          verdict: ruleValue,
          condition: null,
          reason: null,
        );
      } else if (ruleValue is Map<String, dynamic>) {
        // Сложный случай: объект с condition и reason
        parsedRules[dietKey] = DietRule.fromJson(ruleValue);
      }
    }

    return Product(
      key: key,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String,
      baseTokens: List<String>.from(json['base_tokens'] as List),
      attributes: json['attributes'] as Map<String, dynamic>,
      dietRules: parsedRules,
    );
  }

  // Быстрый метод для получения вердикта по конкретной диете
  DietRule? getRule(String dietKey) {
    return dietRules[dietKey];
  }

  // Проверка, содержит ли продукт скрытый сахар
  bool get hasHiddenSugar {
    return attributes['hidden_sugar'] == true;
  }

  // Проверка, содержит ли продукт лактозу
  bool get containsLactose {
    return attributes['contains_lactose'] == true;
  }

  // Проверка, содержит ли продукт глютен
  bool get containsGluten {
    return attributes['contains_gluten'] == true;
  }

  @override
  String toString() {
    return 'Product($key, category: $category)';
  }
}