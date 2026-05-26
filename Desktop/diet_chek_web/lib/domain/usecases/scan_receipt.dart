import '../../data/datasources/local_database.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/models/receipt.dart';
import '../../data/models/scanned_item.dart';
import '../../data/models/product.dart';
import '../../data/models/diet_rule.dart';

class ScanReceiptUseCase {
  final ProductRepository _productRepository;

  ScanReceiptUseCase(this._productRepository);

  Receipt execute(List<String> rawLines, List<String> activeDiets) {
    final List<ScannedItem> items = [];

    for (final String line in rawLines) {
      final String normalized = _normalizeLine(line);

      Product? matchedProduct = _productRepository.findByKey(normalized);
      if (matchedProduct == null) {
        matchedProduct = _productRepository.findByNormalizedText(normalized);
      }

      Map<String, DietRule>? dietResults;
      if (matchedProduct != null) {
        print('Продукт: ${matchedProduct.key}');
        dietResults = {};
        for (final String dietKey in activeDiets) {
          final DietRule? rule = matchedProduct.getRule(dietKey);
          print('  $dietKey: ${rule?.verdict} | ${rule?.condition} | ${rule?.reason}');
          if (rule != null) {
            dietResults[dietKey] = rule;
          }
        }
      }

      items.add(ScannedItem(
        rawText: line,
        normalizedText: normalized,
        matchedProduct: matchedProduct,
        dietResults: dietResults,
      ));
    }

    return Receipt(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      scannedAt: DateTime.now(),
      items: items,
    );
  }

  String _normalizeLine(String rawLine) {
    String normalized = rawLine;

    normalized = normalized.replaceAll(RegExp(r'\b[A-ZА-Я]{2,}\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\d+\.?\d*\s*(г|мл|л|кг|шт)\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\b(ТМ|ТЗ|АО|ООО|ОАО|ЗАО|ИП)\b'), '');
    normalized = normalized.replaceAll(RegExp(r'["«»\*]'), '');
    normalized = normalized.toLowerCase();

    if (normalized.contains(',')) {
      normalized = normalized.split(',').first;
    }

    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    return normalized;
  }
}