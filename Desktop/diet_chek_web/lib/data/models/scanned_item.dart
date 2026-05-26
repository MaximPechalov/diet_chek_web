import 'product.dart';
import 'diet_rule.dart';

class ScannedItem {
  final String rawText;
  final String normalizedText;
  final Product? matchedProduct;
  final Map<String, DietRule>? dietResults;

  const ScannedItem({
    required this.rawText,
    required this.normalizedText,
    this.matchedProduct,
    this.dietResults,
  });

  factory ScannedItem.fromRawText(String rawText) {
    return ScannedItem(
      rawText: rawText,
      normalizedText: rawText,
      matchedProduct: null,
      dietResults: null,
    );
  }

  ScannedItem copyWith({
    String? rawText,
    String? normalizedText,
    Product? matchedProduct,
    Map<String, DietRule>? dietResults,
  }) {
    return ScannedItem(
      rawText: rawText ?? this.rawText,
      normalizedText: normalizedText ?? this.normalizedText,
      matchedProduct: matchedProduct ?? this.matchedProduct,
      dietResults: dietResults ?? this.dietResults,
    );
  }

  bool get isMatched => matchedProduct != null;
  bool get isUnknown => matchedProduct == null;

  @override
  String toString() {
    return 'ScannedItem($rawText -> ${matchedProduct?.key ?? "UNKNOWN"})';
  }
}