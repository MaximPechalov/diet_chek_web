import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/usecases/scan_receipt.dart';
import '../../../data/models/receipt.dart';
import '../../../services/ocr_service.dart';
import '../../../services/open_food_facts_service.dart';
import '../../../data/models/online_product.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/models/diet_rule.dart';
import '../../../data/models/product.dart';
import '../../../data/models/scanned_item.dart';

enum ScanDataSource {
  online,
  local,
  offlineTimeout,
  offlineError,
}

class ScannerController extends ChangeNotifier {
  final ScanReceiptUseCase _scanReceiptUseCase;
  final OcrService _ocrService;
  final OpenFoodFactsService _openFoodFactsService;

  bool _isProcessing = false;
  String? _errorMessage;
  Receipt? _currentReceipt;
  List<String> _activeDiets = [];
  OnlineProduct? _onlineResult;
  ScanDataSource? _dataSource;
  List<String>? _pendingProductLines;
  List<String>? _pendingDiets;

  ScannerController({
    required ScanReceiptUseCase scanReceiptUseCase,
    required OcrService ocrService,
    required dynamic receiptRepository,
    required OpenFoodFactsService openFoodFactsService,
  })  : _scanReceiptUseCase = scanReceiptUseCase,
        _ocrService = ocrService,
        _openFoodFactsService = openFoodFactsService {
    _loadActiveDiets();
  }

  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  Receipt? get currentReceipt => _currentReceipt;
  List<String> get activeDiets => _activeDiets;
  OnlineProduct? get onlineResult => _onlineResult;
  ScanDataSource? get dataSource => _dataSource;

  Future<void> _loadActiveDiets() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _activeDiets = prefs.getStringList('active_diets') ?? [];
    } catch (e) {
      _activeDiets = [];
    }
    notifyListeners();
  }

  void setActiveDiets(List<String> diets) {
    _activeDiets = diets;
    notifyListeners();
  }

  Future<bool> scanReceiptFromFile(String imagePath) async {
    _isProcessing = true;
    _errorMessage = null;
    _onlineResult = null;
    _dataSource = null;
    notifyListeners();

    try {
      final List<String> allLines = await _ocrService.recognizeText(imagePath);
      final List<String> productLines = _ocrService.filterReceiptLines(allLines);

      if (productLines.isEmpty) {
        _errorMessage = 'Не найдено товарных позиций';
        _isProcessing = false;
        notifyListeners();
        return false;
      }

      List<String> diets = [];
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        diets = prefs.getStringList('active_diets') ?? [];
      } catch (e) {
        diets = [];
      }

      _pendingProductLines = productLines;
      _pendingDiets = diets;

      _currentReceipt = _scanReceiptUseCase.execute(productLines, diets);
      _dataSource = ScanDataSource.local;
      _isProcessing = false;
      notifyListeners();
      return true;

    } catch (e) {
      _errorMessage = e.toString();
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  void updateItem(ScannedItem oldItem, String productKey) {
    if (_currentReceipt == null) return;

    final ProductRepository productRepository = ProductRepository();
    final Product? product = productRepository.findByKey(productKey);

    if (product == null) return;

    Map<String, DietRule>? dietResults;
    dietResults = {};
    for (final String dietKey in _activeDiets) {
      final DietRule? rule = product.getRule(dietKey);
      if (rule != null) {
        dietResults[dietKey] = rule;
      }
    }

    final List<ScannedItem> updatedItems = _currentReceipt!.items.map((item) {
      if (item == oldItem) {
        return item.copyWith(
          matchedProduct: product,
          dietResults: dietResults,
        );
      }
      return item;
    }).toList();

    _currentReceipt = _currentReceipt!.copyWith(items: updatedItems);
    _saveUpdatedReceiptToHistory();
    notifyListeners();
  }

  Future<void> _saveUpdatedReceiptToHistory() async {
    if (_currentReceipt == null) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> savedReceipts = prefs.getStringList('receipts') ?? [];

      final String updatedJson = jsonEncode(_currentReceipt!.toJson());
      final int existingIndex = savedReceipts.indexWhere(
        (String json) => json.contains('"id":"${_currentReceipt!.id}"'),
      );

      if (existingIndex >= 0) {
        savedReceipts[existingIndex] = updatedJson;
      } else {
        savedReceipts.insert(0, updatedJson);
      }

      await prefs.setStringList('receipts', savedReceipts);
    } catch (e) {}
  }

  void useOfflineData() {
    if (_pendingProductLines == null || _pendingDiets == null) return;
    _currentReceipt = _scanReceiptUseCase.execute(_pendingProductLines!, _pendingDiets!);
    _dataSource = ScanDataSource.local;
    notifyListeners();
  }

  void reset() {
    _currentReceipt = null;
    _errorMessage = null;
    _isProcessing = false;
    _onlineResult = null;
    _dataSource = null;
    _pendingProductLines = null;
    _pendingDiets = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}