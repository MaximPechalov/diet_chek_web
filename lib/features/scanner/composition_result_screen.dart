import 'package:flutter/material.dart';
import '../../services/ingredient_analyzer.dart';

class CompositionResultScreen extends StatelessWidget {
  final String compositionText;
  final Map<String, List<FoundIngredient>> results;

  const CompositionResultScreen({
    super.key,
    required this.compositionText,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Результат анализа состава'),
      ),
      body: Column(
        children: [
          // Распознанный текст
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Распознанный состав:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  compositionText,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Результаты
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 64, color: Colors.green[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Опасных ингредиентов не найдено!',
                          style: TextStyle(fontSize: 18, color: Colors.green[700]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Продукт подходит для выбранных диет',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: results.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String dietKey = results.keys.elementAt(index);
                      final List<FoundIngredient> ingredients = results[dietKey]!;
                      return _DietResultCard(
                        dietKey: dietKey,
                        ingredients: ingredients,
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Назад'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DietResultCard extends StatelessWidget {
  final String dietKey;
  final List<FoundIngredient> ingredients;

  const _DietResultCard({
    required this.dietKey,
    required this.ingredients,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: _dietColor(dietKey).withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _dietColor(dietKey).withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _dietColor(dietKey),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  IngredientAnalyzer.getDietName(dietKey),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _dietColor(dietKey),
                  ),
                ),
                const Spacer(),
                Text(
                  'Найдено: ${ingredients.length}',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: ingredients.map((FoundIngredient ingredient) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    ingredient.ingredient,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red[800],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '⚠ Эти ингредиенты запрещены для диеты «${IngredientAnalyzer.getDietName(dietKey)}»',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
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