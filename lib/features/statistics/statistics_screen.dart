import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../data/models/receipt.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<Receipt> _receipts = [];
  bool _isLoading = true;
  String? _selectedDiet;
  bool _showWeekly = true;

  final Map<String, String> _dietNames = {
    'no_sugar': 'Без сахара',
    'keto': 'Кето',
    'low_fodmap': 'Low-FODMAP',
    'lactose_free': 'Без лактозы',
  };

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() => _isLoading = true);

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String>? savedReceipts = prefs.getStringList('receipts');

      if (savedReceipts != null && savedReceipts.isNotEmpty) {
        _receipts = savedReceipts
            .map((String json) => Receipt.fromJson(jsonDecode(json)))
            .toList();

        final Set<String> diets = {};
        for (final Receipt receipt in _receipts) {
          for (final item in receipt.items) {
            if (item.dietResults != null) {
              diets.addAll(item.dietResults!.keys);
            }
          }
        }

        if (diets.isNotEmpty && _selectedDiet == null) {
          _selectedDiet = diets.first;
        }
      }
    } catch (e) {
      _receipts = [];
    }

    setState(() => _isLoading = false);
  }

  // Генерирует список дат за последние N дней
  List<String> _generateDateRange(int days) {
    final List<String> result = [];
    final DateTime now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final DateTime date = now.subtract(Duration(days: i));
      result.add('${date.day}.${date.month}');
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _receipts.isEmpty
              ? _buildEmptyState()
              : _buildStats(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Недостаточно данных', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Отсканируйте несколько чеков,\nчтобы увидеть статистику',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildStats() {
    int totalProducts = 0;
    int totalMatched = 0;
    double totalDietScore = 0;
    int dietReceiptCount = 0;

    final int daysToShow = _showWeekly ? 7 : 30;
    final List<String> allDays = _generateDateRange(daysToShow);
    final Map<String, List<double>> byDayScores = {};
    for (final String day in allDays) {
      byDayScores[day] = [];
    }

    for (final Receipt receipt in _receipts) {
      totalProducts += receipt.totalCount;
      totalMatched += receipt.matchedCount;

      if (_selectedDiet != null) {
        final bool hasDiet = receipt.items.any((item) {
          return item.dietResults != null && item.dietResults!.containsKey(_selectedDiet);
        });

        if (hasDiet) {
          final double score = receipt.getDietScore(_selectedDiet!);
          totalDietScore += score;
          dietReceiptCount++;

          final String dayKey = '${receipt.scannedAt.day}.${receipt.scannedAt.month}';
          if (byDayScores.containsKey(dayKey)) {
            byDayScores[dayKey]!.add(score);
          }
        }
      }
    }

    final double matchRate = totalProducts > 0 ? totalMatched / totalProducts * 100 : 0;
    final double avgDietScore = dietReceiptCount > 0 ? totalDietScore / dietReceiptCount * 10 : 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Выбор диеты
        if (_dietNames.keys.any((d) => _receipts.any((r) => r.items.any((i) => i.dietResults?.containsKey(d) ?? false)))) ...[
          _buildSectionHeader('Диета для статистики'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _dietNames.keys.where((d) {
                return _receipts.any((r) => r.items.any((i) => i.dietResults?.containsKey(d) ?? false));
              }).map((String diet) {
                final bool isSelected = diet == _selectedDiet;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_dietNames[diet] ?? diet),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      if (selected) setState(() => _selectedDiet = diet);
                    },
                    selectedColor: _dietColor(diet).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? _dietColor(diet) : Colors.grey[600],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Переключатель Неделя / Месяц
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Неделя'),
                selected: _showWeekly,
                onSelected: (bool selected) {
                  if (selected) setState(() => _showWeekly = true);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('Месяц'),
                selected: !_showWeekly,
                onSelected: (bool selected) {
                  if (selected) setState(() => _showWeekly = false);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Общая статистика
        _buildSectionHeader('Общая статистика'),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _StatCard(icon: Icons.receipt_long, label: 'Всего чеков', value: '${_receipts.length}', color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(icon: Icons.shopping_cart, label: 'Товаров', value: '$totalProducts', color: Colors.blue),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(icon: Icons.check_circle, label: 'Распознано', value: '${matchRate.toStringAsFixed(0)}%', color: Colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.star,
                label: _selectedDiet != null ? 'Рейтинг ${_dietNames[_selectedDiet] ?? ''}' : 'Рейтинг',
                value: _selectedDiet != null ? '${avgDietScore.toStringAsFixed(1)}/10' : '—',
                color: Colors.orange,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // По дням
        _buildSectionHeader('По дням (${_showWeekly ? "последние 7" : "последние 30"})'),
        const SizedBox(height: 12),

        if (_selectedDiet == null)
          Text('Выберите диету для графика', style: TextStyle(color: Colors.grey[500]))
        else
          ...allDays.map((String day) {
            final List<double> scores = byDayScores[day] ?? [];
            final double avgScore = scores.isEmpty ? 0 : scores.reduce((a, b) => a + b) / scores.length;
            final double dayRate = avgScore * 10;
            final bool hasData = scores.isNotEmpty;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(day, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: avgScore,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          hasData
                              ? (avgScore >= 0.8 ? Colors.green : avgScore >= 0.5 ? Colors.orange : Colors.red)
                              : Colors.grey[300]!,
                        ),
                        minHeight: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 45,
                    child: Text(
                      hasData ? '${dayRate.toStringAsFixed(0)}%' : '—',
                      style: TextStyle(
                        fontSize: 13,
                        color: hasData ? Colors.grey[700] : Colors.grey[400],
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 24),

        _buildSectionHeader('Советы'),
        const SizedBox(height: 12),
        _buildTip(
          icon: Icons.lightbulb,
          text: matchRate < 50
              ? 'Менее 50% товаров распознаются. Попробуйте использовать «Помочь распознать».'
              : 'Отличное покрытие базы! Продолжайте сканировать чеки.',
        ),
        if (_receipts.length < 3)
          _buildTip(icon: Icons.info_outline, text: 'Накопите больше чеков, чтобы увидеть детальную статистику.'),
        if (_selectedDiet != null && dietReceiptCount < _receipts.length)
          _buildTip(
            icon: Icons.info_outline,
            text: 'Статистика по «${_dietNames[_selectedDiet]}» учитывает $dietReceiptCount из ${_receipts.length} чеков.',
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _buildTip({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.amber[700]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[700]))),
        ],
      ),
    );
  }

  Color _dietColor(String key) {
    const Map<String, Color> colors = {
      'no_sugar': Color(0xFF42A5F5), 'keto': Color(0xFFFF7043),
      'low_fodmap': Color(0xFFAB47BC), 'lactose_free': Color(0xFF26A69A),
    };
    return colors[key] ?? Colors.grey;
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}