import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../../core/constants/app_colors.dart';
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
  String? _selectedTypeFilter;
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

  String _getScanType(Receipt receipt) {
    return receipt.storeName == 'composition' ? 'composition' : 'receipt';
  }

  IconData _getScanIcon(Receipt receipt) {
    return receipt.storeName == 'composition'
        ? Icons.menu_book
        : Icons.receipt_long;
  }

  String _getScanTypeLabel(Receipt receipt) {
    return receipt.storeName == 'composition' ? 'Состав' : 'Чек';
  }

  Future<void> _loadReceipts() async {
    setState(() => _isLoading = true);

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String>? savedReceipts = prefs.getStringList('receipts');

      if (savedReceipts != null && savedReceipts.isNotEmpty) {
        _receipts = savedReceipts
            .map((String json) {
              try {
                return Receipt.fromJson(jsonDecode(json));
              } catch (e) {
                return null;
              }
            })
            .whereType<Receipt>()
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

  Future<void> _saveReceipts() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> jsonList =
        _receipts.map((Receipt r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList('receipts', jsonList);
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

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = value);
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredReceipts = List.from(_receipts);

    if (_selectedTypeFilter != null) {
      _filteredReceipts = _filteredReceipts
          .where((r) => _getScanType(r) == _selectedTypeFilter)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      _filteredReceipts = _filteredReceipts
          .where((r) => r.items.any((item) =>
              item.rawText.toLowerCase().contains(_searchQuery.toLowerCase())))
          .toList();
    }

    if (_selectedDietFilter != null) {
      _filteredReceipts = _filteredReceipts
          .where((r) => r.items.any((item) =>
              item.dietResults != null &&
              item.dietResults!.containsKey(_selectedDietFilter)))
          .toList();
    }

    if (_selectedRatingFilter != null && _selectedDietFilter != null) {
      final double minScore = _selectedRatingFilter == 'high'
          ? 0.8
          : _selectedRatingFilter == 'medium'
              ? 0.5
              : 0.0;
      _filteredReceipts = _filteredReceipts.where((r) {
        if (r.items.isEmpty) return false;
        return r.getDietScore(_selectedDietFilter!) >= minScore;
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

    setState(() {});
  }

  Future<void> _deleteReceipt(int index) async {
    _deleteTimer?.cancel();
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

  void _confirmDeleteNow() {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Очистить историю',
            style: TextStyle(letterSpacing: 0.4),
          ),
          content: const Text(
            'Удалить все незакреплённые чеки?\n\nЗакреплённые чеки останутся.\nУ вас будет 10 секунд, чтобы отменить.',
            style: TextStyle(letterSpacing: 0.2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Отмена',
                style: TextStyle(letterSpacing: 0.3),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Удалить',
                style: TextStyle(letterSpacing: 0.3),
              ),
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

  void _confirmClearNow() {
    _restoreTimer?.cancel();
    setState(() {
      _showRestoreUI = false;
      _clearedBackup = null;
    });
  }

  double? _getReceiptScore(Receipt receipt) {
    if (_selectedDietFilter == null) return null;
    if (receipt.items.isEmpty) return null;
    return receipt.getDietScore(_selectedDietFilter!);
  }

  Color _receiptColor(Receipt receipt) {
    final double? score = _getReceiptScore(receipt);
    if (score == null) return Colors.grey;
    if (score >= 0.7) return Colors.green;
    if (score >= 0.4) return Colors.orange;
    return Colors.red;
  }

  void _showDetail(BuildContext context, Receipt receipt) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _ReceiptDetailScreen(receipt: receipt);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity:
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int receiptCount =
        _receipts.where((r) => _getScanType(r) == 'receipt').length;
    final int compositionCount =
        _receipts.where((r) => _getScanType(r) == 'composition').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'История',
          style: TextStyle(letterSpacing: 0.5),
        ),
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
          _buildFilterBar(receiptCount, compositionCount),
          if (_showRestoreUI || _showDeleteUI) _buildRestoreBanner(),
          Expanded(child: _buildBody()),
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
    final VoidCallback onConfirm =
        isClearAll ? _confirmClearNow : _confirmDeleteNow;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.orange[50],
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.orange[700],
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ),
          TextButton(
            onPressed: onConfirm,
            child: const Text(
              'ОК',
              style: TextStyle(letterSpacing: 0.3),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onUndo,
            child: const Text(
              'Отменить',
              style: TextStyle(letterSpacing: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Поиск по товарам...',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            letterSpacing: 0.2,
          ),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _applyFilters();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          filled: true,
          fillColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(0.5),
        ),
        style: const TextStyle(letterSpacing: 0.2),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildFilterBar(int receiptCount, int compositionCount) {
    final Color primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          if (receiptCount > 0 || compositionCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Все (${_receipts.length})',
                    isSelected: _selectedTypeFilter == null,
                    color: primary,
                    onTap: () {
                      setState(() => _selectedTypeFilter = null);
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 10),
                  if (receiptCount > 0)
                    _FilterChip(
                      label: 'Чеки ($receiptCount)',
                      isSelected: _selectedTypeFilter == 'receipt',
                      color: primary,
                      icon: Icons.receipt_long,
                      onTap: () {
                        setState(() => _selectedTypeFilter = 'receipt');
                        _applyFilters();
                      },
                    ),
                  const SizedBox(width: 10),
                  if (compositionCount > 0)
                    _FilterChip(
                      label: 'Составы ($compositionCount)',
                      isSelected: _selectedTypeFilter == 'composition',
                      color: const Color(0xFFFF7043),
                      icon: Icons.menu_book,
                      onTap: () {
                        setState(
                            () => _selectedTypeFilter = 'composition');
                        _applyFilters();
                      },
                    ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedDietFilter,
                  decoration: InputDecoration(
                    hintText: 'Диета',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      letterSpacing: 0.2,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.5),
                    isDense: true,
                  ),
                  style: const TextStyle(letterSpacing: 0.2),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Все диеты')),
                    DropdownMenuItem(
                        value: 'no_sugar', child: Text('Без сахара')),
                    DropdownMenuItem(value: 'keto', child: Text('Кето')),
                    DropdownMenuItem(
                        value: 'low_fodmap', child: Text('Low-FODMAP')),
                    DropdownMenuItem(
                        value: 'lactose_free', child: Text('Без лактозы')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedDietFilter = value;
                      if (value == null) _selectedRatingFilter = null;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: Alignment.centerLeft,
                child: _selectedDietFilter != null
                    ? SizedBox(
                        width: MediaQuery.of(context).size.width * 0.38,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: 1.0,
                          child: DropdownButtonFormField<String>(
                            value: _selectedRatingFilter,
                            decoration: InputDecoration(
                              hintText: 'Рейтинг',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                letterSpacing: 0.2,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withOpacity(0.5),
                              isDense: true,
                            ),
                            style: const TextStyle(letterSpacing: 0.2),
                            items: const [
                              DropdownMenuItem(
                                  value: null, child: Text('Любой')),
                              DropdownMenuItem(
                                  value: 'high', child: Text('≥ 80%')),
                              DropdownMenuItem(
                                  value: 'medium', child: Text('≥ 50%')),
                            ],
                            onChanged: (value) {
                              setState(
                                  () => _selectedRatingFilter = value);
                              _applyFilters();
                            },
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.sort, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                'Сортировка:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  setState(() => _sortAscending = false);
                  _applyFilters();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: !_sortAscending
                        ? primary.withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Сначала новые',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: !_sortAscending
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color:
                          !_sortAscending ? primary : Colors.grey[600],
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() => _sortAscending = true);
                  _applyFilters();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _sortAscending
                        ? primary.withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Сначала старые',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _sortAscending
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color:
                          _sortAscending ? primary : Colors.grey[600],
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long,
                size: 40,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _receipts.isEmpty ? 'История пуста' : 'Ничего не найдено',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _receipts.isEmpty
                  ? 'Отсканируйте первый чек,\nи он появится здесь'
                  : 'Измените параметры поиска или фильтра',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                letterSpacing: 0.2,
              ),
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
        itemBuilder: (context, index) {
          final Receipt receipt = _filteredReceipts[index];
          final double? score = _getReceiptScore(receipt);
          final Color scoreColor = _receiptColor(receipt);
          final bool isPinned = _pinnedReceipts.contains(receipt.id);
          final IconData scanIcon = _getScanIcon(receipt);
          final String scanTypeLabel = _getScanTypeLabel(receipt);

          return Hero(
            tag: 'receipt_${receipt.id}',
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isPinned
                      ? Colors.amber.withOpacity(0.4)
                      : Colors.grey.withOpacity(0.15),
                  width: isPinned ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isPinned
                        ? Colors.amber.withOpacity(0.15)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () => _showDetail(context, receipt),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: receipt.storeName == 'composition'
                                  ? const Color(0xFFFF7043)
                                      .withOpacity(0.1)
                                  : scoreColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: receipt.storeName == 'composition'
                                      ? const Color(0xFFFF7043)
                                          .withOpacity(0.15)
                                      : scoreColor.withOpacity(0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              scanIcon,
                              color: receipt.storeName == 'composition'
                                  ? const Color(0xFFFF7043)
                                  : scoreColor,
                              size: 24,
                            ),
                          ),
                          if (isPinned)
                            Positioned(
                              top: -3,
                              right: -3,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.amber[600],
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.3),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.push_pin,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _formatDate(receipt.scannedAt),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: receipt.storeName ==
                                            'composition'
                                        ? const Color(0xFFFF7043)
                                            .withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    scanTypeLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: receipt.storeName ==
                                              'composition'
                                          ? const Color(0xFFFF7043)
                                          : Colors.grey[600],
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              receipt.storeName == 'composition'
                                  ? 'Найдено ингредиентов: ${receipt.totalCount}'
                                  : 'Товаров: ${receipt.totalCount} | Распознано: ${receipt.matchedCount}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (score != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: scoreColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: scoreColor.withOpacity(0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: scoreColor.withOpacity(0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            '${(score * 10).toStringAsFixed(0)}/10',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: scoreColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: Icon(
                          isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          size: 20,
                        ),
                        color: isPinned
                            ? Colors.amber[700]
                            : Colors.grey[400],
                        onPressed: () => _togglePin(receipt),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                        ),
                        color: Colors.grey[400],
                        onPressed: () => _deleteReceipt(index),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color:
                isSelected ? color.withOpacity(0.3) : Colors.transparent,
          ),
        ),
        child: icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected ? color : Colors.grey[500],
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? color : Colors.grey[600],
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? color : Colors.grey[600],
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}

class _ReceiptDetailScreen extends StatefulWidget {
  final Receipt receipt;

  const _ReceiptDetailScreen({required this.receipt});

  @override
  State<_ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<_ReceiptDetailScreen> {
  String? _selectedDiet;
  final ScrollController _scrollController = ScrollController();
  double _headerScale = 1.0;

  @override
  void initState() {
    super.initState();

    final Set<String> allDiets = {};
    for (final item in widget.receipt.items) {
      if (item.dietResults != null) {
        allDiets.addAll(item.dietResults!.keys);
      }
    }
    if (allDiets.isNotEmpty) _selectedDiet = allDiets.first;

    _scrollController.addListener(() {
      final double offset = _scrollController.offset;
      final double newScale = (1.0 - (offset / 200)).clamp(0.85, 1.0);
      if ((newScale - _headerScale).abs() > 0.001) {
        setState(() => _headerScale = newScale);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final Set<String> allDiets = {};
    for (final item in widget.receipt.items) {
      if (item.dietResults != null) {
        allDiets.addAll(item.dietResults!.keys);
      }
    }
    final List<String> dietList = allDiets.toList();
    final bool isComposition = widget.receipt.storeName == 'composition';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          isComposition ? 'Состав' : 'Чек',
          style: const TextStyle(fontSize: 16, letterSpacing: 0.4),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'receipt_${widget.receipt.id}',
            child: Material(
              color: Colors.transparent,
              child: Transform.scale(
                scale: _headerScale,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 60,
                    bottom: 20,
                    left: 20,
                    right: 20,
                  ),
                  decoration: BoxDecoration(
                    color: isComposition
                        ? const Color(0xFFFF7043).withOpacity(0.1)
                        : Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.2),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isComposition
                              ? const Color(0xFFFF7043).withOpacity(0.2)
                              : Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isComposition
                              ? Icons.menu_book
                              : Icons.receipt_long,
                          color: isComposition
                              ? const Color(0xFFFF7043)
                              : Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isComposition
                                ? 'Анализ состава'
                                : 'Всего: ${widget.receipt.totalCount}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isComposition
                                ? 'Ингредиентов: ${widget.receipt.totalCount}'
                                : 'Распознано: ${widget.receipt.matchedCount}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (dietList.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: dietList.map((diet) {
                    final bool isSelected = diet == _selectedDiet;
                    final Color dietColor = AppColors.getDietColor(diet);
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(
                          AppColors.getDietName(diet),
                          style: const TextStyle(letterSpacing: 0.2),
                        ),
                        selected: isSelected,
                        onSelected: (v) {
                          if (v) setState(() => _selectedDiet = diet);
                        },
                        selectedColor: dietColor.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color:
                              isSelected ? dietColor : Colors.grey[600],
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: widget.receipt.items.map((item) {
                DietRule? rule;
                if (_selectedDiet != null && item.dietResults != null) {
                  rule = item.dietResults![_selectedDiet];
                }

                Color iconColor = Colors.grey;
                IconData icon = Icons.help_outline;
                String verdictText =
                    isComposition ? 'Ингредиент' : 'Не распознано';

                if (rule != null) {
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

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    title: Text(
                      item.rawText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.matchedProduct != null)
                          Text(
                            '${item.matchedProduct!.category} → ${item.matchedProduct!.key}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              letterSpacing: 0.2,
                            ),
                          ),
                        Text(
                          verdictText,
                          style: TextStyle(
                            fontSize: 12,
                            color: iconColor,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: iconColor.withOpacity(0.15),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}