import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/usecases/scan_receipt.dart';
import '../../../data/models/receipt.dart';
import '../../../services/ocr_service.dart';
import '../../../services/open_food_facts_service.dart';
import '../../../data/models/online_product.dart';

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