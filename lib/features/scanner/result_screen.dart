import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
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
      return Scaffold(
        appBar: AppBar(title: const Text('Результаты анализа')),
        body: const Center(child: Text('Нет данных для отображения')),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _ReceiptSummary(
            receipt: receipt,
            dataSource: controller.dataSource?.name,
          ),
          const SizedBox(height: 8),
          _DietSummaryCards(receipt: receipt),
          const SizedBox(height: 8),
          Expanded(
            child: _ProductList(receipt: receipt),
          ),
        ],
      ),
      bottomNavigationBar: _BottomActions(controller: controller),
    );
  }
}

class _ReceiptSummary extends StatelessWidget {
  final Receipt receipt;
  final String? dataSource;

  const _ReceiptSummary({
    required this.receipt,
    this.dataSource,
  });

  @override
  Widget build(BuildContext context) {
    final double rate = receipt.matchRate;
    final Color barColor = rate >= 0.8
        ? Colors.green
        : rate >= 0.5
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
          const SizedBox(height: 20),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: rate),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: value,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Покрытие базы: ${(value * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              );
            },
          ),
          if (dataSource != null &&
              dataSource != 'online' &&
              dataSource != 'local') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dataSource == 'offline_timeout'
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: dataSource == 'offline_timeout'
                      ? Colors.orange.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    dataSource == 'offline_timeout'
                        ? Icons.wifi_off
                        : Icons.cloud_off,
                    size: 18,
                    color: dataSource == 'offline_timeout'
                        ? Colors.orange[700]
                        : Colors.red[700],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dataSource == 'offline_timeout'
                          ? 'Сервер не отвечает. Показаны данные из офлайн-базы.'
                          : 'Нет подключения к интернету.',
                      style: TextStyle(
                        fontSize: 12,
                        color: dataSource == 'offline_timeout'
                            ? Colors.orange[700]
                            : Colors.red[700],
                        letterSpacing: 0.2,
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
    final Color itemColor = color ?? Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: itemColor.withOpacity(0.1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: itemColor.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: itemColor,
            size: 28,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: itemColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            letterSpacing: 0.3,
          ),
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
      (item) => item.dietResults != null,
      orElse: () => receipt.items.first,
    );

    if (firstAnalyzed?.dietResults == null) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'Диеты не выбраны',
            style: TextStyle(
              color: Colors.grey,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
    }

    final List<String> diets = firstAnalyzed!.dietResults!.keys.toList();

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: diets.length,
        itemBuilder: (context, index) {
          final String dietKey = diets[index];
          final Map<String, int> summary = receipt.getDietSummary(dietKey);
          final double score = receipt.getDietScore(dietKey);
          final Color dietColor = AppColors.getDietColor(dietKey);

          return Container(
            constraints:
                const BoxConstraints(minWidth: 160, maxWidth: 210),
            margin: const EdgeInsets.only(right: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: dietColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: dietColor.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(
                  color: dietColor.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: dietColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        AppColors.getDietIcon(dietKey),
                        color: dietColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        AppColors.getDietShortName(dietKey),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: dietColor,
                          fontSize: 13,
                          letterSpacing: 0.4,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _MiniDot(
                      color: Colors.green,
                      count: summary['allowed'] ?? 0,
                    ),
                    const SizedBox(width: 8),
                    _MiniDot(
                      color: Colors.orange,
                      count: summary['warnings'] ?? 0,
                    ),
                    const SizedBox(width: 8),
                    _MiniDot(
                      color: Colors.red,
                      count: summary['forbidden'] ?? 0,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(dietColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(score * 10).toStringAsFixed(0)}/10',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: receipt.items.length,
      itemBuilder: (context, index) {
        final item = receipt.items[index];
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

  const _AnimatedProductTile({
    required this.item,
    required this.index,
  });

  @override
  State<_AnimatedProductTile> createState() => _AnimatedProductTileState();
}

class _AnimatedProductTileState extends State<_AnimatedProductTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300 + (widget.index * 60)),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
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
    // Определяем цвет тени по вердикту
    final bool isForbidden =
        item.dietResults?.values.any((r) => r.isForbidden) == true;
    final bool isWarning =
        item.dietResults?.values.any((r) => r.isWarning) == true;
    final bool isAllowed =
        item.dietResults?.values.any((r) => r.isAllowed) == true;

    Color shadowColor = Colors.grey.withOpacity(0.1);
    Color borderColor = Colors.grey.withOpacity(0.2);

    if (isForbidden) {
      shadowColor = Colors.red.withOpacity(0.15);
      borderColor = Colors.red.withOpacity(0.3);
    } else if (isWarning) {
      shadowColor = Colors.orange.withOpacity(0.15);
      borderColor = Colors.orange.withOpacity(0.3);
    } else if (isAllowed || item.isMatched) {
      shadowColor = Colors.green.withOpacity(0.15);
      borderColor = Colors.green.withOpacity(0.3);
    } else if (item.isUnknown) {
      shadowColor = Colors.orange.withOpacity(0.1);
      borderColor = Colors.orange.withOpacity(0.3);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.rawText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.isUnknown)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Неизвестно',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[800],
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
              ],
            ),
            if (item.matchedProduct != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.matchedProduct!.category} → ${item.matchedProduct!.subcategory}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
            if (item.dietResults != null &&
                item.dietResults!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: item.dietResults!.entries
                    .map(
                      (entry) => _DietBadge(
                        dietKey: entry.key,
                        rule: entry.value,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DietBadge extends StatelessWidget {
  final String dietKey;
  final DietRule rule;

  const _DietBadge({
    required this.dietKey,
    required this.rule,
  });

  Color get badgeColor {
    if (rule.isAllowed) return Colors.green;
    if (rule.isWarning) return Colors.orange;
    if (rule.isForbidden) return Colors.red;
    return Colors.grey;
  }

  String get badgeText {
    final String shortName = AppColors.getDietShortName(dietKey);
    if (rule.isAllowed) return '$shortName ✓';
    if (rule.isWarning) return '$shortName ⚠';
    if (rule.isForbidden) return '$shortName ✗';
    return shortName;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withOpacity(0.4),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            badgeText,
            style: TextStyle(
              fontSize: 12,
              color: badgeColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
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
                label: const Text(
                  'Новое сканирование',
                  style: TextStyle(letterSpacing: 0.4),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: const Text(
                  'Готово',
                  style: TextStyle(letterSpacing: 0.4),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}