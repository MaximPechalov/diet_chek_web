import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../data/models/receipt.dart';
import '../../data/models/scanned_item.dart';
import '../../data/models/diet_rule.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Receipt> _receipts = [];
  bool _isLoading = true;

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

      if (savedReceipts != null) {
        _receipts = savedReceipts
            .map((String json) => Receipt.fromJson(jsonDecode(json)))
            .toList();
        _receipts.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
      }
    } catch (e) {
      _receipts = [];
    }

    setState(() => _isLoading = false);
  }

  Future<void> _deleteReceipt(int index) async {
    _receipts.removeAt(index);
    await _saveReceipts();
    setState(() {});
  }

  Future<void> _clearAll() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Очистить историю'),
          content: const Text('Удалить все сохраненные чеки?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Удалить все'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _receipts.clear();
      await _saveReceipts();
      setState(() {});
    }
  }

  Future<void> _saveReceipts() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = _receipts
        .map((Receipt r) => jsonEncode(r.toJson()))
        .toList();
    await prefs.setStringList('receipts', jsonList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История'),
        actions: [
          if (_receipts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAll,
              tooltip: 'Очистить историю',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_receipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('История пуста', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(
              'Отсканируйте первый чек,\nи он появится здесь',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReceipts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _receipts.length,
        itemBuilder: (BuildContext context, int index) {
          final Receipt receipt = _receipts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _showDetail(context, receipt),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(receipt.scannedAt),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Товаров: ${receipt.totalCount} | Распознано: ${receipt.matchedCount}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.grey[400],
                      onPressed: () => _deleteReceipt(index),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, Receipt receipt) {
    final Set<String> allDiets = {};
    for (final ScannedItem item in receipt.items) {
      if (item.dietResults != null) {
        allDiets.addAll(item.dietResults!.keys);
      }
    }
    final List<String> dietList = allDiets.toList();

    String? selectedDiet;
    if (dietList.isNotEmpty) {
      selectedDiet = dietList.first;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.3,
              expand: false,
              builder: (BuildContext context, ScrollController scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Чек от ${_formatDate(receipt.scannedAt)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),

                      if (dietList.length > 1) ...[
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: dietList.map((String diet) {
                              final bool isSelected = diet == selectedDiet;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(_dietDisplayName(diet)),
                                  selected: isSelected,
                                  onSelected: (bool selected) {
                                    if (selected) {
                                      setSheetState(() {
                                        selectedDiet = diet;
                                      });
                                    }
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
                      ],

                      const SizedBox(height: 12),
                      Text('Всего: ${receipt.totalCount} | Распознано: ${receipt.matchedCount}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600])),

                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: receipt.items.map((ScannedItem item) {
                            DietRule? rule;
                            if (selectedDiet != null && item.dietResults != null) {
                              rule = item.dietResults![selectedDiet];
                            }

                            Color iconColor = Colors.grey;
                            IconData icon = Icons.help_outline;
                            String verdictText = 'Не распознано';
                            String? reason;

                            if (rule != null) {
                              reason = rule.fullDescription;
                              if (rule.isAllowed) {
                                iconColor = Colors.green;
                                icon = Icons.check_circle;
                                verdictText = 'Разрешено';
                              } else if (rule.isForbidden) {
                                iconColor = Colors.red;
                                icon = Icons.cancel;
                                verdictText = 'Запрещено';
                              } else if (rule.isWarning) {
                                iconColor = Colors.orange;
                                icon = Icons.warning_amber;
                                verdictText = 'С осторожностью';
                              }
                            } else if (item.isMatched) {
                              iconColor = Colors.green;
                              icon = Icons.check_circle;
                              verdictText = 'Распознано';
                            }

                            return Tooltip(
                              message: reason ?? verdictText,
                              child: ListTile(
                                dense: true,
                                title: Text(item.rawText, style: const TextStyle(fontSize: 14)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.matchedProduct != null)
                                      Text('${item.matchedProduct!.category} → ${item.matchedProduct!.key}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                    Text(verdictText,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: iconColor,
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                leading: Icon(icon, color: iconColor, size: 22),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
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

  String _formatDate(DateTime date) {
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин. назад';
    if (diff.inDays < 1) return '${diff.inHours} ч. назад';
    if (diff.inDays == 1) return 'Вчера';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    return '${date.day}.${date.month}.${date.year}';
  }
}