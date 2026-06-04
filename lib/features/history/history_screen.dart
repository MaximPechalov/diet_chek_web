import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
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
  List<Receipt> _filteredReceipts = [];
  bool _isLoading = true;
  bool _isFiltering = false;

  List<Receipt>? _clearedBackup;
  Timer? _restoreTimer;
  int _restoreSeconds = 10;
  bool _showRestoreUI = false;

  Receipt? _deletedReceipt;
  int? _deletedIndex;
  Timer? _deleteTimer;
  int _deleteSeconds = 5;
  bool _showDeleteUI = false;

  String? _selectedDietFilter;
  String? _selectedRatingFilter;
  bool _sortAscending = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  final Set<String> _pinnedReceipts = {};

  @override
  void dispose() {
    _restoreTimer?.cancel();
    _deleteTimer?.cancel();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadReceipts();
    _loadPinned();
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
      }
    } catch (e) {
      _receipts = [];
    }

    _applyFilters();
    setState(() => _isLoading = false);
  }

  Future<void> _loadPinned() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String>? pinned = prefs.getStringList('pinned_receipts');
      if (pinned != null) {
        _pinnedReceipts.addAll(pinned);
      }
    } catch (e) {}
  }

  Future<void> _savePinned() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinned_receipts', _pinnedReceipts.toList());
  }

  void _togglePin(Receipt receipt) {
    setState(() {
      if (_pinnedReceipts.contains(receipt.id)) {
        _pinnedReceipts.remove(receipt.id);
      } else {
        _pinnedReceipts.add(receipt.id);
      }
    });
    _savePinned();
    _applyFilters();
  }

  // debounce для поиска
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = value;
        _isFiltering = true;
      });
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredReceipts = List.from(_receipts);

    if (_searchQuery.isNotEmpty) {
      _filteredReceipts = _filteredReceipts.where((Receipt r) {
        return r.items.any((item) {
          return item.rawText.toLowerCase().contains(_searchQuery.toLowerCase());
        });
      }).toList();
    }

    if (_selectedDietFilter != null) {
      _filteredReceipts = _filteredReceipts.where((Receipt r) {
        return r.items.any((item) {
          return item.dietResults != null && item.dietResults!.containsKey(_selectedDietFilter);
        });
      }).toList();
    }

    if (_selectedRatingFilter != null && _selectedDietFilter != null) {
      _filteredReceipts = _filteredReceipts.where((Receipt r) {
        if (r.items.isEmpty) return false;
        return r.getDietScore(_selectedDietFilter!) >= _ratingFilterValue();
      }).toList();
    }

    _filteredReceipts.sort((a, b) {
      final bool aPinned = _pinnedReceipts.contains(a.id);
      final bool bPinned = _pinnedReceipts.contains(b.id);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      if (_sortAscending) {
        return a.scannedAt.compareTo(b.scannedAt);
      } else {
        return b.scannedAt.compareTo(a.scannedAt);
      }
    });

    // Сбрасываем индикатор фильтрации
    setState(() => _isFiltering = false);
  }

  double _ratingFilterValue() {
    switch (_selectedRatingFilter) {
      case 'high': return 0.8;
      case 'medium': return 0.5;
      case 'low': return 0.0;
      default: return 0.0;
    }
  }

  double? _getReceiptScore(Receipt receipt) {
    if (_selectedDietFilter == null) return null;
    if (receipt.items.isEmpty) return null;
    final bool hasDiet = receipt.items.any((item) {
      return item.dietResults != null && item.dietResults!.containsKey(_selectedDietFilter);
    });
    if (!hasDiet) return null;
    return receipt.getDietScore(_selectedDietFilter!);
  }

  Future<void> _deleteReceipt(int index) async {
    _deletedReceipt = _filteredReceipts[index];
    _deletedIndex = _receipts.indexOf(_deletedReceipt!);
    _deleteSeconds = 5;
    _showDeleteUI = true;

    setState(() {
      _receipts.removeAt(_deletedIndex!);
      _pinnedReceipts.remove(_deletedReceipt!.id);
      _applyFilters();
    });

    await _saveReceipts();
    await _savePinned();
    _startDeleteTimer();
  }

  void _startDeleteTimer() {
    _deleteTimer?.cancel();
    _deleteSeconds = 5;

    _deleteTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _deleteSeconds--);
      if (_deleteSeconds <= 0) {
        timer.cancel();
        setState(() {
          _showDeleteUI = false;
          _deletedReceipt = null;
          _deletedIndex = null;
        });
      }
    });
  }

  void _undoDelete() {
    _deleteTimer?.cancel();
    if (_deletedReceipt != null && _deletedIndex != null) {
      setState(() {
        _receipts.insert(_deletedIndex!, _deletedReceipt!);
        _applyFilters();
        _showDeleteUI = false;
      });
      _deletedReceipt = null;
      _deletedIndex = null;
      _saveReceipts();
    }
  }

  void _confirmDelete() {
    _deleteTimer?.cancel();
    setState(() {
      _showDeleteUI = false;
      _deletedReceipt = null;
      _deletedIndex = null;
    });
  }

  Future<void> _clearAll() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Очистить историю'),
          content: const Text('Удалить все незакреплённые чеки?\n\nЗакреплённые чеки останутся.\nУ вас будет 10 секунд, чтобы отменить это действие.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _clearedBackup = List.from(_receipts);
      _restoreSeconds = 10;
      _showRestoreUI = true;

      setState(() {
        _receipts.removeWhere((r) => !_pinnedReceipts.contains(r.id));
        _applyFilters();
      });

      await _saveReceipts();
      _startRestoreTimer();
    }
  }

  void _startRestoreTimer() {
    _restoreTimer?.cancel();
    _restoreSeconds = 10;

    _restoreTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _restoreSeconds--);
      if (_restoreSeconds <= 0) {
        timer.cancel();
        setState(() {
          _showRestoreUI = false;
          _clearedBackup = null;
        });
      }
    });
  }

  void _restoreHistory() {
    _restoreTimer?.cancel();
    if (_clearedBackup != null) {
      setState(() {
        _receipts = List.from(_clearedBackup!);
        _applyFilters();
        _showRestoreUI = false;
      });
      _clearedBackup = null;
      _saveReceipts();
    }
  }

  void _confirmClearAll() {
    _restoreTimer?.cancel();
    setState(() {
      _showRestoreUI = false;
      _clearedBackup = null;
    });
  }

  Future<void> _saveReceipts() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = _receipts.map((Receipt r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList('receipts', jsonList);
  }

  Color _receiptColor(Receipt receipt) {
    final double? score = _getReceiptScore(receipt);
    if (score == null) return Colors.grey;
    if (score >= 0.7) return Colors.green;
    if (score >= 0.4) return Colors.orange;
    return Colors.red;
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
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterBar(),
          // Индикатор фильтрации
          if (_isFiltering)
            const LinearProgressIndicator(minHeight: 2),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showRestoreUI || _showDeleteUI ? _buildRestoreBanner() : const SizedBox.shrink(),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Поиск по товарам...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _isFiltering = true;
                    });
                    _applyFilters();
                  },
                )
              : null,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedDietFilter,
                  decoration: const InputDecoration(
                    labelText: 'Диета',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Все')),
                    DropdownMenuItem(value: 'no_sugar', child: Text('Без сахара')),
                    DropdownMenuItem(value: 'keto', child: Text('Кето')),
                    DropdownMenuItem(value: 'low_fodmap', child: Text('Low-FODMAP')),
                    DropdownMenuItem(value: 'lactose_free', child: Text('Без лактозы')),
                  ],
                  onChanged: (String? value) {
                    setState(() {
                      _selectedDietFilter = value;
                      if (value == null) _selectedRatingFilter = null;
                      _isFiltering = true;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _selectedDietFilter != null ? 1.0 : 0.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _selectedDietFilter != null ? null : 0,
                    child: DropdownButtonFormField<String>(
                      value: _selectedRatingFilter,
                      decoration: const InputDecoration(
                        labelText: 'Рейтинг',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Все')),
                        DropdownMenuItem(value: 'high', child: Text('≥ 80%')),
                        DropdownMenuItem(value: 'medium', child: Text('≥ 50%')),
                        DropdownMenuItem(value: 'low', child: Text('Любой')),
                      ],
                      onChanged: (String? value) {
                        setState(() {
                          _selectedRatingFilter = value;
                          _isFiltering = true;
                        });
                        _applyFilters();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text('Сортировка:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Сначала новые'),
                selected: !_sortAscending,
                onSelected: (bool selected) {
                  if (selected) {
                    setState(() {
                      _sortAscending = false;
                      _isFiltering = true;
                    });
                    _applyFilters();
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Сначала старые'),
                selected: _sortAscending,
                onSelected: (bool selected) {
                  if (selected) {
                    setState(() {
                      _sortAscending = true;
                      _isFiltering = true;
                    });
                    _applyFilters();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreBanner() {
    final bool isClearAll = _showRestoreUI;
    final int seconds = isClearAll ? _restoreSeconds : _deleteSeconds;
    final String text = isClearAll
        ? 'История будет удалена через ${seconds}с'
        : 'Чек будет удалён через ${seconds}с';
    final VoidCallback onUndo = isClearAll ? _restoreHistory : _undoDelete;
    final VoidCallback onConfirm = isClearAll ? _confirmClearAll : _confirmDelete;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.orange[50],
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: Colors.orange[700], fontSize: 13))),
          TextButton(onPressed: onConfirm, child: const Text('ОК')),
          const SizedBox(width: 4),
          TextButton(onPressed: onUndo, child: const Text('Отменить')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredReceipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _receipts.isEmpty ? 'История пуста' : _searchQuery.isNotEmpty ? 'Ничего не найдено' : 'Нет чеков по фильтрам',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              _receipts.isEmpty ? 'Отсканируйте первый чек,\nи он появится здесь' : 'Измените параметры поиска или фильтра',
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
        itemCount: _filteredReceipts.length,
        itemBuilder: (BuildContext context, int index) {
          final Receipt receipt = _filteredReceipts[index];
          final double? score = _getReceiptScore(receipt);
          final Color scoreColor = _receiptColor(receipt);
          final bool isPinned = _pinnedReceipts.contains(receipt.id);

          return Card(
            elevation: 2,
            shadowColor: Colors.black26,
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
                        color: scoreColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.receipt_long, color: scoreColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isPinned) ...[
                                Icon(Icons.push_pin, size: 14, color: Colors.amber[700]),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  _formatDate(receipt.scannedAt),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Товаров: ${receipt.totalCount} | Распознано: ${receipt.matchedCount}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (score != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: scoreColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(score * 10).toStringAsFixed(0)}/10',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: scoreColor),
                        ),
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                      color: isPinned ? Colors.amber[700] : Colors.grey[400],
                      onPressed: () => _togglePin(receipt),
                      tooltip: isPinned ? 'Открепить' : 'Закрепить',
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
                                    if (selected) setSheetState(() => selectedDiet = diet);
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
                                iconColor = Colors.green; icon = Icons.check_circle; verdictText = 'Разрешено';
                              } else if (rule.isForbidden) {
                                iconColor = Colors.red; icon = Icons.cancel; verdictText = 'Запрещено';
                              } else if (rule.isWarning) {
                                iconColor = Colors.orange; icon = Icons.warning_amber; verdictText = 'С осторожностью';
                              }
                            } else if (item.isMatched) {
                              iconColor = Colors.green; icon = Icons.check_circle; verdictText = 'Распознано';
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
                                        style: TextStyle(fontSize: 12, color: iconColor, fontWeight: FontWeight.w500)),
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
      'no_sugar': 'Без сахара', 'keto': 'Кето', 'low_fodmap': 'Low-FODMAP', 'lactose_free': 'Без лактозы',
    };
    return names[key] ?? key;
  }

  Color _dietColor(String key) {
    const Map<String, Color> colors = {
      'no_sugar': Color(0xFF42A5F5), 'keto': Color(0xFFFF7043), 'low_fodmap': Color(0xFFAB47BC), 'lactose_free': Color(0xFF26A69A),
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