import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/receipt.dart';
import '../../data/models/scanned_item.dart';
import '../../data/models/diet_rule.dart';
import '../../data/datasources/local_database.dart';
import '../../data/repositories/product_repository.dart';
import 'controller/scanner_controller.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ScannerController controller = context.watch<ScannerController>();
    final Receipt? receipt = controller.currentReceipt;

    if (receipt == null) {
      return const Scaffold(
        body: Center(child: Text('Нет данных для отображения')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Результаты анализа'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareResults(context, receipt),
          ),
        ],
      ),
      body: Column(
        children: [
          _ReceiptSummary(receipt: receipt, dataSource: controller.dataSource?.name),
          _DietSummaryCards(receipt: receipt),
          Expanded(
            child: _ProductList(receipt: receipt),
          ),
        ],
      ),
      bottomNavigationBar: _BottomActions(controller: controller),
    );
  }

  void _shareResults(BuildContext context, Receipt receipt) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Функция экспорта будет добавлена позже')),
    );
  }
}

class _ReceiptSummary extends StatelessWidget {
  final Receipt receipt;
  final String? dataSource;

  const _ReceiptSummary({required this.receipt, this.dataSource});

  @override
  Widget build(BuildContext context) {
    final double rate = receipt.matchRate;
    final Color barColor = rate >= 0.8 ? Colors.green : rate >= 0.5 ? Colors.orange : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                icon: Icons.receipt_long,
                label: 'Всего',
                value: receipt.totalCount.toString(),
              ),
              _StatItem(
                icon: Icons.check_circle_outline,
                label: 'Распознано',
                value: receipt.matchedCount.toString(),
                color: Colors.green,
              ),
              _StatItem(
                icon: Icons.help_outline,
                label: 'Неизвестно',
                value: receipt.unknownCount.toString(),
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Покрытие базы: ${(rate * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (dataSource != null && dataSource != 'online' && dataSource != 'local') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: dataSource == 'offline_timeout'
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: dataSource == 'offline_timeout'
                      ? Colors.orange.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    dataSource == 'offline_timeout' ? Icons.wifi_off : Icons.cloud_off,
                    size: 18,
                    color: dataSource == 'offline_timeout' ? Colors.orange[700] : Colors.red[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dataSource == 'offline_timeout'
                          ? 'Сервер не отвечает. Показаны данные из офлайн-базы.'
                          : 'Нет подключения к интернету.',
                      style: TextStyle(
                        fontSize: 12,
                        color: dataSource == 'offline_timeout' ? Colors.orange[700] : Colors.red[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color ?? Theme.of(context).colorScheme.primary, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _DietSummaryCards extends StatelessWidget {
  final Receipt receipt;

  const _DietSummaryCards({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final ScannedItem? firstAnalyzed = receipt.items.firstWhere(
      (ScannedItem item) => item.dietResults != null,
      orElse: () => receipt.items.first,
    );

    if (firstAnalyzed!.dietResults == null) {
      return const SizedBox.shrink();
    }

    final List<String> diets = firstAnalyzed!.dietResults!.keys.toList();

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        itemCount: diets.length,
        itemBuilder: (BuildContext context, int index) {
          final String dietKey = diets[index];
          final Map<String, int> summary = receipt.getDietSummary(dietKey);
          final double score = receipt.getDietScore(dietKey);

          return _DietCard(
            dietKey: dietKey,
            summary: summary,
            score: score,
          );
        },
      ),
    );
  }
}

class _DietCard extends StatelessWidget {
  final String dietKey;
  final Map<String, int> summary;
  final double score;

  const _DietCard({
    required this.dietKey,
    required this.summary,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _dietColor(dietKey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _dietColor(dietKey).withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dietDisplayName(dietKey),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _dietColor(dietKey),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _MiniDot(color: Colors.green, count: summary['allowed'] ?? 0),
              const SizedBox(width: 4),
              _MiniDot(color: Colors.orange, count: summary['warnings'] ?? 0),
              const SizedBox(width: 4),
              _MiniDot(color: Colors.red, count: summary['forbidden'] ?? 0),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Рейтинг: ${(score * 10).toStringAsFixed(0)}/10',
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  String _dietDisplayName(String key) {
    const Map<String, String> names = {
      'no_sugar': 'Без сахара',
      'keto': 'Кето',
      'low_fodmap': 'Low-FODMAP',
      'lactose_free': 'Без лактозы',
    };
    return names[key] ?? key;
  }

  Color _dietColor(String key) {
    const Map<String, Color> colors = {
      'no_sugar': Color(0xFF42A5F5),
      'keto': Color(0xFFFF7043),
      'low_fodmap': Color(0xFFAB47BC),
      'lactose_free': Color(0xFF26A69A),
    };
    return colors[key] ?? Colors.grey;
  }
}

class _MiniDot extends StatelessWidget {
  final Color color;
  final int count;

  const _MiniDot({required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 2),
        Text('$count', style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _ProductList extends StatelessWidget {
  final Receipt receipt;

  const _ProductList({required this.receipt});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: receipt.items.length,
      itemBuilder: (BuildContext context, int index) {
        final ScannedItem item = receipt.items[index];
        return _AnimatedProductTile(
          item: item,
          index: index,
        );
      },
    );
  }
}

class _AnimatedProductTile extends StatefulWidget {
  final ScannedItem item;
  final int index;

  const _AnimatedProductTile({required this.item, required this.index});

  @override
  State<_AnimatedProductTile> createState() => _AnimatedProductTileState();
}

class _AnimatedProductTileState extends State<_AnimatedProductTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _ProductTile(item: widget.item),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ScannedItem item;

  const _ProductTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.rawText,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.isUnknown)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Неизвестно',
                      style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                    ),
                  ),
              ],
            ),
            if (item.matchedProduct != null) ...[
              const SizedBox(height: 4),
              Text(
                '→ ${item.matchedProduct!.category} / ${item.matchedProduct!.subcategory}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
            if (item.dietResults != null && item.dietResults!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: item.dietResults!.entries.map((MapEntry<String, DietRule> entry) {
                  return _DietBadge(dietKey: entry.key, rule: entry.value);
                }).toList(),
              ),
            ],
            if (item.isUnknown)
              TextButton.icon(
                onPressed: () => _onUnknownTap(context, item),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Помочь распознать', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  void _onUnknownTap(BuildContext context, ScannedItem item) {
    final ScannerController controller = context.read<ScannerController>();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext ctx) {
        return _ProductSuggestionSheet(
          rawText: item.rawText,
          onSuggestionSelected: (String suggestion) {
            controller.updateItem(item, suggestion);
          },
        );
      },
    );
  }
}

class _ProductSuggestionSheet extends StatelessWidget {
  final String rawText;
  final ValueChanged<String> onSuggestionSelected;

  const _ProductSuggestionSheet({
    required this.rawText,
    required this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> keywords = _extractKeywords(rawText);
    final List<String> suggestions = _findSuggestions(keywords);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Что это за продукт?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(rawText, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 12),

          if (keywords.isNotEmpty) ...[
            Text('Ключевые слова: ${keywords.join(", ")}',
                style: TextStyle(fontSize: 12, color: Colors.blue[700])),
            const SizedBox(height: 12),
          ],

          if (suggestions.isNotEmpty) ...[
            Text('Возможные варианты:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...suggestions.take(8).map((suggestion) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.lightbulb_outline, size: 20, color: Colors.amber),
                  title: Text(suggestion, style: const TextStyle(fontSize: 14)),
                  onTap: () {
                    Navigator.pop(context);
                    onSuggestionSelected(suggestion);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Обновлено: $suggestion')),
                    );
                  },
                )),
          ] else ...[
            Text('Ничего не найдено в базе', style: TextStyle(color: Colors.grey[500])),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _extractKeywords(String text) {
    final List<String> allKeywords = [
      'молоко', 'творог', 'сыр', 'кефир', 'сметана', 'сливки', 'масло', 'йогурт',
      'хлеб', 'батон', 'булка', 'лаваш', 'багет',
      'говядина', 'свинина', 'курица', 'индейка', 'фарш', 'колбаса', 'сосиски',
      'лосось', 'треска', 'сельдь', 'скумбрия', 'тунец', 'креветки',
      'огурец', 'помидор', 'перец', 'капуста', 'морковь', 'картофель', 'лук', 'чеснок',
      'яблоко', 'банан', 'апельсин', 'виноград', 'груша', 'киви',
      'рис', 'гречка', 'макароны', 'мука', 'сахар', 'соль',
      'яйцо', 'шоколад', 'печенье', 'чипсы', 'орехи',
    ];

    final String lowerText = text.toLowerCase();
    return allKeywords.where((kw) => lowerText.contains(kw)).toList();
  }

  List<String> _findSuggestions(List<String> keywords) {
    final List<String> suggestions = [];

    for (final String kw in keywords) {
      for (final String productKey in LocalDatabase.products.keys) {
        final Map<String, dynamic> productData = LocalDatabase.products[productKey]!;
        final List<dynamic> tokens = productData['base_tokens'] as List<dynamic>;

        bool matches = productKey.toLowerCase().contains(kw.toLowerCase());
        if (!matches) {
          for (final dynamic token in tokens) {
            if (token.toString().toLowerCase().contains(kw.toLowerCase())) {
              matches = true;
              break;
            }
          }
        }

        if (matches && !suggestions.contains(productKey)) {
          suggestions.add(productKey);
        }
      }
    }

    return suggestions;
  }
}

class _DietBadge extends StatelessWidget {
  final String dietKey;
  final DietRule rule;

  const _DietBadge({required this.dietKey, required this.rule});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: rule.fullDescription,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _badgeColor(rule).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _badgeColor(rule).withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: _badgeColor(rule),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _badgeText,
              style: TextStyle(fontSize: 11, color: _badgeColor(rule), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Color _badgeColor(DietRule rule) {
    if (rule.isAllowed) return Colors.green;
    if (rule.isWarning) return Colors.orange;
    if (rule.isForbidden) return Colors.red;
    return Colors.grey;
  }

  String get _badgeText {
    final String shortName = _dietShortName(dietKey);
    if (rule.isAllowed) return '$shortName ✓';
    if (rule.isWarning) return '$shortName ⚠';
    if (rule.isForbidden) return '$shortName ✗';
    return shortName;
  }

  String _dietShortName(String key) {
    const Map<String, String> names = {
      'no_sugar': 'Сахар',
      'keto': 'Кето',
      'low_fodmap': 'FODMAP',
      'lactose_free': 'Лактоза',
    };
    return names[key] ?? key;
  }
}

class _BottomActions extends StatelessWidget {
  final ScannerController controller;

  const _BottomActions({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  controller.reset();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Новое сканирование'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check),
                label: const Text('Готово'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}