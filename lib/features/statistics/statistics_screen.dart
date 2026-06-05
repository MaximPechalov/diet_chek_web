import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/constants/app_colors.dart';
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
            .map((String json) {
              try { return Receipt.fromJson(jsonDecode(json)); }
              catch (e) { return null; }
            })
            .whereType<Receipt>()
            .toList();

        final Set<String> diets = {};
        for (final receipt in _receipts) {
          for (final item in receipt.items) {
            if (item.dietResults != null) diets.addAll(item.dietResults!.keys);
          }
        }
        if (diets.isNotEmpty && _selectedDiet == null) _selectedDiet = diets.first;
      }
    } catch (e) {
      _receipts = [];
    }
    setState(() => _isLoading = false);
  }

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
      appBar: AppBar(title: const Text('Статистика')),
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
          Text('Недостаточно данных', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Отсканируйте несколько чеков,\nчтобы увидеть статистику', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
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

    // Сбор статистики по диетам
    final Map<String, Map<String, int>> dietStats = {};
    for (final receipt in _receipts) {
      totalProducts += receipt.totalCount;
      totalMatched += receipt.matchedCount;

      for (final item in receipt.items) {
        if (item.dietResults != null) {
          for (final entry in item.dietResults!.entries) {
            dietStats.putIfAbsent(entry.key, () => {'allowed': 0, 'warnings': 0, 'forbidden': 0});
            if (entry.value.isAllowed) dietStats[entry.key]!['allowed'] = (dietStats[entry.key]!['allowed'] ?? 0) + 1;
            else if (entry.value.isWarning) dietStats[entry.key]!['warnings'] = (dietStats[entry.key]!['warnings'] ?? 0) + 1;
            else if (entry.value.isForbidden) dietStats[entry.key]!['forbidden'] = (dietStats[entry.key]!['forbidden'] ?? 0) + 1;
          }
        }
      }

      if (_selectedDiet != null) {
        final bool hasDiet = receipt.items.any((item) => item.dietResults != null && item.dietResults!.containsKey(_selectedDiet));
        if (hasDiet) {
          final double score = receipt.getDietScore(_selectedDiet!);
          totalDietScore += score;
          dietReceiptCount++;
          final String dayKey = '${receipt.scannedAt.day}.${receipt.scannedAt.month}';
          if (byDayScores.containsKey(dayKey)) byDayScores[dayKey]!.add(score);
        }
      }
    }

    final double matchRate = totalProducts > 0 ? totalMatched / totalProducts * 100 : 0;
    final double avgDietScore = dietReceiptCount > 0 ? totalDietScore / dietReceiptCount * 10 : 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Выбор диеты
        if (dietStats.isNotEmpty) ...[
          _sectionTitle('Диета для статистики'),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: dietStats.keys.map((diet) {
                final bool isSelected = diet == _selectedDiet;
                final Color c = AppColors.getDietColor(diet);
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDiet = diet),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? c.withOpacity(0.12) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isSelected ? c.withOpacity(0.5) : Colors.transparent, width: 1.5),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(AppColors.getDietName(diet), style: TextStyle(color: isSelected ? c : Colors.grey[600], fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontSize: 13)),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Общая статистика
        _sectionTitle('Общая статистика'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard(icon: Icons.receipt_long, label: 'Всего чеков', value: '${_receipts.length}', color: Theme.of(context).colorScheme.primary)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(icon: Icons.shopping_cart, label: 'Товаров', value: '$totalProducts', color: Colors.blue)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard(icon: Icons.check_circle, label: 'Распознано', value: '${matchRate.toStringAsFixed(0)}%', color: Colors.green)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(icon: Icons.star, label: _selectedDiet != null ? 'Рейтинг ${AppColors.getDietShortName(_selectedDiet!)}' : 'Рейтинг', value: _selectedDiet != null ? '${avgDietScore.toStringAsFixed(1)}/10' : '—', color: Colors.orange)),
        ]),

        // Распределение по диете
        if (_selectedDiet != null && dietStats.containsKey(_selectedDiet)) ...[
          const SizedBox(height: 24),
          _sectionTitle('Распределение: ${AppColors.getDietName(_selectedDiet!)}'),
          const SizedBox(height: 12),
          _DietDistributionBar(stats: dietStats[_selectedDiet!]!),
        ],

        const SizedBox(height: 24),

        // График по дням
        _sectionTitle('По дням (${_showWeekly ? "последние 7" : "последние 30"})'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showWeekly = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _showWeekly ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _showWeekly ? Theme.of(context).colorScheme.primary.withOpacity(0.3) : Colors.transparent),
                ),
                child: Center(child: Text('Неделя', style: TextStyle(fontWeight: _showWeekly ? FontWeight.w600 : FontWeight.normal, color: _showWeekly ? Theme.of(context).colorScheme.primary : Colors.grey[600]))),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showWeekly = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_showWeekly ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: !_showWeekly ? Theme.of(context).colorScheme.primary.withOpacity(0.3) : Colors.transparent),
                ),
                child: Center(child: Text('Месяц', style: TextStyle(fontWeight: !_showWeekly ? FontWeight.w600 : FontWeight.normal, color: !_showWeekly ? Theme.of(context).colorScheme.primary : Colors.grey[600]))),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        if (_selectedDiet == null)
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(Icons.info_outline, color: Colors.grey[500]), const SizedBox(width: 10), Text('Выберите диету для отображения графика', style: TextStyle(color: Colors.grey[600]))]))
        else
          ...allDays.map((day) {
            final List<double> scores = byDayScores[day] ?? [];
            final double avg = scores.isEmpty ? 0 : scores.reduce((a, b) => a + b) / scores.length;
            final bool hasData = scores.isNotEmpty;
            final Color barColor = hasData ? (avg >= 0.8 ? Colors.green : avg >= 0.5 ? Colors.orange : Colors.red) : Colors.grey[300]!;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 45, child: Text(day, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: hasData ? Colors.grey[700] : Colors.grey[400]))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: avg,
                        backgroundColor: Colors.grey[100],
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        minHeight: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 45,
                    child: Text(hasData ? '${(avg * 100).toStringAsFixed(0)}%' : '—', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: hasData ? barColor : Colors.grey[400]), textAlign: TextAlign.right),
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 24),
        _sectionTitle('Советы'),
        const SizedBox(height: 10),
        _buildTip(Icons.lightbulb, matchRate < 50 ? 'Менее 50% товаров распознаются. Попробуйте использовать ручной ввод.' : 'Отличное покрытие базы! Продолжайте сканировать чеки.'),
        if (_receipts.length < 3) _buildTip(Icons.info_outline, 'Накопите больше чеков, чтобы увидеть детальную статистику.'),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold));
  }

  Widget _buildTip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.2))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 20, color: Colors.amber[700])),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4))),
          ],
        ),
      ),
    );
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
      elevation: 2,
      shadowColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 26)),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// Простая полоса распределения вместо круговой диаграммы
class _DietDistributionBar extends StatelessWidget {
  final Map<String, int> stats;
  const _DietDistributionBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    final int allowed = stats['allowed'] ?? 0;
    final int warnings = stats['warnings'] ?? 0;
    final int forbidden = stats['forbidden'] ?? 0;
    final int total = allowed + warnings + forbidden;

    if (total == 0) return const Text('Нет данных');

    return Column(
      children: [
        // Полоса
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 32,
            child: Row(
              children: [
                if (allowed > 0) Expanded(flex: allowed, child: Container(color: Colors.green)),
                if (warnings > 0) Expanded(flex: warnings, child: Container(color: Colors.orange)),
                if (forbidden > 0) Expanded(flex: forbidden, child: Container(color: Colors.red)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Легенда
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Legend(color: Colors.green, label: 'Разрешено', count: allowed),
            _Legend(color: Colors.orange, label: 'Осторожно', count: warnings),
            _Legend(color: Colors.red, label: 'Запрещено', count: forbidden),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _Legend({required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            Text('$count', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}