import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
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
        title: const Text('Результат анализа'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Экспорт будет добавлен позже'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Распознанный текст
          _CompositionHeader(compositionText: compositionText),
          
          // Результаты
          Expanded(
            child: results.isEmpty
                ? _EmptyResult()
                : _ResultsList(results: results),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }
}

// Заголовок с распознанным составом
class _CompositionHeader extends StatelessWidget {
  final String compositionText;

  const _CompositionHeader({required this.compositionText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.menu_book,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Распознанный состав:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              compositionText,
              style: const TextStyle(fontSize: 14, height: 1.5),
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Пустой результат
class _EmptyResult extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, size: 55, color: Colors.green[400]),
            ),
            const SizedBox(height: 24),
            Text(
              'Опасных ингредиентов не найдено!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Продукт подходит для выбранных диет',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.green[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Список результатов
class _ResultsList extends StatelessWidget {
  final Map<String, List<FoundIngredient>> results;

  const _ResultsList({required this.results});

  @override
  Widget build(BuildContext context) {
    // Сортируем: сначала диеты с наибольшим количеством запрещённых ингредиентов
    final sortedEntries = results.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedEntries.length,
      itemBuilder: (BuildContext context, int index) {
        final String dietKey = sortedEntries[index].key;
        final List<FoundIngredient> ingredients = sortedEntries[index].value;
        return _AnimatedDietResultCard(
          dietKey: dietKey,
          ingredients: ingredients,
          index: index,
        );
      },
    );
  }
}

// Анимированная карточка результата диеты
class _AnimatedDietResultCard extends StatefulWidget {
  final String dietKey;
  final List<FoundIngredient> ingredients;
  final int index;

  const _AnimatedDietResultCard({
    required this.dietKey,
    required this.ingredients,
    required this.index,
  });

  @override
  State<_AnimatedDietResultCard> createState() => _AnimatedDietResultCardState();
}

class _AnimatedDietResultCardState extends State<_AnimatedDietResultCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 350 + (widget.index * 100)),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color dietColor = AppColors.getDietColor(widget.dietKey);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 2,
          shadowColor: dietColor.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: dietColor.withOpacity(0.3), width: 1),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  dietColor.withOpacity(0.06),
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок диеты
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: dietColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        AppColors.getDietIcon(widget.dietKey),
                        color: dietColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            IngredientAnalyzer.getDietName(widget.dietKey),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: dietColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Диета ${AppColors.getDietName(widget.dietKey)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    // Бейдж с количеством
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber, size: 16, color: Colors.red[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.ingredients.length}',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Список ингредиентов
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.ingredients.map((FoundIngredient ingredient) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close, size: 14, color: Colors.red[400]),
                          const SizedBox(width: 6),
                          Text(
                            ingredient.ingredient,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                // Предупреждение
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber, size: 18, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '⚠ Эти ингредиенты запрещены для диеты «${IngredientAnalyzer.getDietName(widget.dietKey)}»',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[800],
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}