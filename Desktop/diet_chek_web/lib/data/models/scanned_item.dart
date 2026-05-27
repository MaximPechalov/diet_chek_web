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

  Map<String, dynamic> toJson() {
    return {
      'rawText': rawText,
      'normalizedText': normalizedText,
      'matchedProductKey': matchedProduct?.key,
      'matchedProductCategory': matchedProduct?.category,
      'matchedProductSubcategory': matchedProduct?.subcategory,
      'dietResults': dietResults?.map((key, rule) => MapEntry(key, {
            'verdict': rule.verdict,
            'condition': rule.condition,
            'reason': rule.reason,
          })),
    };
  }

  factory ScannedItem.fromJson(Map<String, dynamic> json) {
    Map<String, DietRule>? dietResults;
    if (json['dietResults'] != null) {
      dietResults = (json['dietResults'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, DietRule(
          verdict: value['verdict'] as String,
          condition: value['condition'] as String?,
          reason: value['reason'] as String?,
        )),
      );
    }

    return ScannedItem(
      rawText: json['rawText'] as String,
      normalizedText: json['normalizedText'] as String,
      matchedProduct: json['matchedProductKey'] != null
          ? Product(
              key: json['matchedProductKey'] as String,
              category: json['matchedProductCategory'] as String? ?? '',
              subcategory: json['matchedProductSubcategory'] as String? ?? '',
              baseTokens: [],
              attributes: {},
              dietRules: {},
            )
          : null,
      dietResults: dietResults,
    );
  }

  @override
  String toString() {
    return 'ScannedItem($rawText -> ${matchedProduct?.key ?? "UNKNOWN"})';
  }
}