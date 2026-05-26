// lib/data/models/receipt.dart
import 'scanned_item.dart';

class Receipt {
  // Уникальный идентификатор чека (генерируется при создании)
  final String id;

  // Дата и время сканирования
  final DateTime scannedAt;

  // Список всех распознанных товаров в чеке
  final List<ScannedItem> items;

  // Название магазина, если удалось распознать (опционально)
  final String? storeName;

  // Общая сумма чека, если удалось распознать (опционально)
  final double? totalAmount;

  const Receipt({
    required this.id,
    required this.scannedAt,
    required this.items,
    this.storeName,
    this.totalAmount,
  });

  // Создаёт новый чек из списка сырых строк (сразу после OCR)
  factory Receipt.fromRawLines(List<String> rawLines) {
    return Receipt(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      scannedAt: DateTime.now(),
      items: rawLines.map((line) => ScannedItem.fromRawText(line)).toList(),
      storeName: null,
      totalAmount: null,
    );
  }

  // Создаёт копию с возможностью заменить отдельные поля
  Receipt copyWith({
    String? id,
    DateTime? scannedAt,
    List<ScannedItem>? items,
    String? storeName,
    double? totalAmount,
  }) {
    return Receipt(
      id: id ?? this.id,
      scannedAt: scannedAt ?? this.scannedAt,
      items: items ?? this.items,
      storeName: storeName ?? this.storeName,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }

  // Количество опознанных продуктов
  int get matchedCount {
    return items.where((item) => item.isMatched).length;
  }

  // Количество неопознанных продуктов
  int get unknownCount {
    return items.where((item) => item.isUnknown).length;
  }

  // Общее количество товаров в чеке
  int get totalCount {
    return items.length;
  }

  // Процент опознанных товаров (для статистики)
  double get matchRate {
    if (items.isEmpty) return 0.0;
    return matchedCount / totalCount;
  }

  // Сводка по конкретной диете: сколько товаров разрешено/предупреждено/запрещено
  Map<String, int> getDietSummary(String dietKey) {
    int allowed = 0;
    int warnings = 0;
    int forbidden = 0;
    int unknown = 0;

    for (final ScannedItem item in items) {
      if (item.isUnknown || item.dietResults == null) {
        unknown++;
        continue;
      }

      final dynamic rule = item.dietResults![dietKey];
      if (rule == null) {
        unknown++;
      } else if (rule.isAllowed) {
        allowed++;
      } else if (rule.isWarning) {
        warnings++;
      } else if (rule.isForbidden) {
        forbidden++;
      }
    }

    return {
      'allowed': allowed,
      'warnings': warnings,
      'forbidden': forbidden,
      'unknown': unknown,
    };
  }

  // Оценка качества чека по конкретной диете (от 0.0 до 1.0)
  // 1.0 — все товары разрешены, 0.0 — все запрещены
  double getDietScore(String dietKey) {
    final Map<String, int> summary = getDietSummary(dietKey);
    final int total = matchedCount;

    if (total == 0) return 0.0;

    // Разрешённые дают полный балл, предупреждения — половину, запрещённые — ноль
    final double score = (summary['allowed']! * 1.0 + summary['warnings']! * 0.5) / total;

    return score.clamp(0.0, 1.0);
  }

  @override
  String toString() {
    return 'Receipt($id, items: ${items.length}, matched: $matchedCount, unknown: $unknownCount)';
  }
}