import '../datasources/local_database.dart';
import '../models/product.dart';

class ProductRepository {
  final Map<String, Product> _cache = {};

  Product? findByKey(String normalizedKey) {
    if (_cache.containsKey(normalizedKey)) {
      return _cache[normalizedKey];
    }

    final Map<String, dynamic>? jsonData = LocalDatabase.findProduct(normalizedKey);

    if (jsonData == null) {
      return null;
    }

    final Product product = Product.fromJson(normalizedKey, jsonData);
    _cache[normalizedKey] = product;
    return product;
  }

  Product? findByNormalizedText(String normalizedText) {
    Product? bestMatch;
    int bestScore = 0;
    int bestTokenLength = 0;
    int bestTokenCount = 0;

    final List<String> numbersInText = _extractNumbers(normalizedText);

    for (final String key in LocalDatabase.products.keys) {
      final Map<String, dynamic> jsonData = LocalDatabase.products[key]!;
      final List<dynamic> tokens = jsonData['base_tokens'] as List<dynamic>;

      int totalTokenLength = 0;
      int matchedTokens = 0;
      int longestMatch = 0;
      bool numberMatched = false;

      for (final dynamic token in tokens) {
        final String tokenStr = token.toString().toLowerCase();
        if (normalizedText.contains(tokenStr)) {
          matchedTokens++;
          totalTokenLength += tokenStr.length;
          if (tokenStr.length > longestMatch) {
            longestMatch = tokenStr.length;
          }

          for (final String num in numbersInText) {
            if (tokenStr.contains(num)) {
              numberMatched = true;
              break;
            }
          }
        }
      }

      if (matchedTokens > 0) {
        int score = matchedTokens * 1 + longestMatch;

        if (numberMatched && numbersInText.isNotEmpty) {
          score += 100;
        }

        if (!numberMatched && numbersInText.isNotEmpty) {
          bool tokenHasAnyNumber = false;
          for (final dynamic token in tokens) {
            if (RegExp(r'\d').hasMatch(token.toString())) {
              tokenHasAnyNumber = true;
              break;
            }
          }
          if (tokenHasAnyNumber) {
            score -= 50;
          }
        }

        if (score > bestScore ||
            (score == bestScore && longestMatch > bestTokenLength) ||
            (score == bestScore && longestMatch == bestTokenLength && matchedTokens > bestTokenCount)) {
          bestMatch = findByKey(key);
          bestScore = score;
          bestTokenLength = longestMatch;
          bestTokenCount = matchedTokens;
        }
      }
    }

    return bestMatch;
  }

  List<String> _extractNumbers(String text) {
    final List<String> numbers = [];
    final RegExp regex = RegExp(r'(\d+[.,]?\d*)');
    for (final match in regex.allMatches(text)) {
      String num = match.group(1)!.replaceAll(',', '.');
      numbers.add(num);
    }
    return numbers;
  }

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

  bool get isDatabaseReady {
    return LocalDatabase.isInitialized;
  }

  int get productCount {
    return LocalDatabase.products.length;
  }

  void clearCache() {
    _cache.clear();
  }
}