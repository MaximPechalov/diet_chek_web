// lib/data/repositories/receipt_repository.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../models/receipt.dart';
import '../models/scanned_item.dart';
import '../models/product.dart';
import '../models/diet_rule.dart';

class ReceiptRepository {
  static const String _boxName = 'receipts';
  late Box _box;

  // Инициализация хранилища Hive
  Future<void> initialize() async {
    _box = await Hive.openBox(_boxName);
  }

  // Сохраняет чек в локальное хранилище
  Future<void> saveReceipt(Receipt receipt) async {
    // Превращаем чек в JSON-совместимый Map
    final Map<String, dynamic> json = _receiptToJson(receipt);
    await _box.put(receipt.id, json);
  }

  // Загружает чек по ID
  Future<Receipt?> getReceipt(String id) async {
    final Map<String, dynamic>? json = _box.get(id) as Map<String, dynamic>?;
    if (json == null) return null;
    return _receiptFromJson(json);
  }

  // Загружает все чеки, отсортированные по дате (сначала новые)
  Future<List<Receipt>> getAllReceipts() async {
    final List<Receipt> receipts = [];

    for (final dynamic key in _box.keys) {
      final Map<String, dynamic>? json = _box.get(key) as Map<String, dynamic>?;
      if (json != null) {
        receipts.add(_receiptFromJson(json));
      }
    }

    // Сортируем по дате: новые сверху
    receipts.sort((Receipt a, Receipt b) => b.scannedAt.compareTo(a.scannedAt));

    return receipts;
  }

  // Удаляет чек по ID
  Future<void> deleteReceipt(String id) async {
    await _box.delete(id);
  }

  // Очищает всю историю
  Future<void> clearAll() async {
    await _box.clear();
  }

  // Количество сохраненных чеков
  int get count => _box.length;

  // Преобразует Receipt в Map для сохранения в Hive
  Map<String, dynamic> _receiptToJson(Receipt receipt) {
    return {
      'id': receipt.id,
      'scannedAt': receipt.scannedAt.toIso8601String(),
      'storeName': receipt.storeName,
      'totalAmount': receipt.totalAmount,
      'items': receipt.items.map((ScannedItem item) => _scannedItemToJson(item)).toList(),
    };
  }

  // Преобразует ScannedItem в Map
  Map<String, dynamic> _scannedItemToJson(ScannedItem item) {
    return {
      'rawText': item.rawText,
      'normalizedText': item.normalizedText,
      'matchedProduct': item.matchedProduct != null ? _productToJson(item.matchedProduct!) : null,
      'dietResults': item.dietResults?.map((String key, DietRule rule) {
        return MapEntry(key, _dietRuleToJson(rule));
      }),
    };
  }

  // Преобразует Product в Map
  Map<String, dynamic> _productToJson(Product product) {
    return {
      'key': product.key,
      'category': product.category,
      'subcategory': product.subcategory,
      'baseTokens': product.baseTokens,
      'attributes': product.attributes,
      'dietRules': product.dietRules.map((String key, DietRule rule) {
        return MapEntry(key, _dietRuleToJson(rule));
      }),
    };
  }

  // Преобразует DietRule в Map
  Map<String, dynamic> _dietRuleToJson(DietRule rule) {
    return {
      'verdict': rule.verdict,
      'condition': rule.condition,
      'reason': rule.reason,
    };
  }

  // Восстанавливает Receipt из Map
  Receipt _receiptFromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] as String,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      storeName: json['storeName'] as String?,
      totalAmount: json['totalAmount'] as double?,
      items: (json['items'] as List<dynamic>).map((dynamic item) {
        return _scannedItemFromJson(item as Map<String, dynamic>);
      }).toList(),
    );
  }

  // Восстанавливает ScannedItem из Map
  ScannedItem _scannedItemFromJson(Map<String, dynamic> json) {
    return ScannedItem(
      rawText: json['rawText'] as String,
      normalizedText: json['normalizedText'] as String,
      matchedProduct: json['matchedProduct'] != null
          ? _productFromJson(json['matchedProduct'] as Map<String, dynamic>)
          : null,
      dietResults: json['dietResults'] != null
          ? (json['dietResults'] as Map<String, dynamic>).map((String key, dynamic value) {
              return MapEntry(key, _dietRuleFromJson(value as Map<String, dynamic>));
            })
          : null,
    );
  }

  // Восстанавливает Product из Map
  Product _productFromJson(Map<String, dynamic> json) {
    return Product(
      key: json['key'] as String,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String,
      baseTokens: List<String>.from(json['baseTokens'] as List),
      attributes: json['attributes'] as Map<String, dynamic>,
      dietRules: (json['dietRules'] as Map<String, dynamic>).map((String key, dynamic value) {
        return MapEntry(key, _dietRuleFromJson(value as Map<String, dynamic>));
      }),
    );
  }

  // Восстанавливает DietRule из Map
  DietRule _dietRuleFromJson(Map<String, dynamic> json) {
    return DietRule(
      verdict: json['verdict'] as String,
      condition: json['condition'] as String?,
      reason: json['reason'] as String?,
    );
  }
}