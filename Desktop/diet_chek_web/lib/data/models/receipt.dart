import 'scanned_item.dart';

class Receipt {
  final String id;
  final DateTime scannedAt;
  final List<ScannedItem> items;
  final String? storeName;
  final double? totalAmount;

  const Receipt({
    required this.id,
    required this.scannedAt,
    required this.items,
    this.storeName,
    this.totalAmount,
  });

  factory Receipt.fromRawLines(List<String> rawLines) {
    return Receipt(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      scannedAt: DateTime.now(),
      items: rawLines.map((line) => ScannedItem.fromRawText(line)).toList(),
      storeName: null,
      totalAmount: null,
    );
  }

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

  int get matchedCount => items.where((item) => item.isMatched).length;
  int get unknownCount => items.where((item) => item.isUnknown).length;
  int get totalCount => items.length;

  double get matchRate {
    if (items.isEmpty) return 0.0;
    return matchedCount / totalCount;
  }

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

  double getDietScore(String dietKey) {
    final Map<String, int> summary = getDietSummary(dietKey);
    final int total = matchedCount;
    if (total == 0) return 0.0;
    final double score = (summary['allowed']! * 1.0 + summary['warnings']! * 0.5) / total;
    return score.clamp(0.0, 1.0);
  }

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] as String,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      storeName: json['storeName'] as String?,
      totalAmount: json['totalAmount'] as double?,
      items: (json['items'] as List<dynamic>)
          .map((item) => ScannedItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scannedAt': scannedAt.toIso8601String(),
      'storeName': storeName,
      'totalAmount': totalAmount,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'Receipt($id, items: ${items.length}, matched: $matchedCount, unknown: $unknownCount)';
  }
}