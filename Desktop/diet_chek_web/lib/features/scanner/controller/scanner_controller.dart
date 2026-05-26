import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/usecases/scan_receipt.dart';
import '../../../data/models/receipt.dart';
import '../../../services/ocr_service.dart';
import 'dart:io';

class ScannerController extends ChangeNotifier {
  final ScanReceiptUseCase _scanReceiptUseCase;
  final OcrService _ocrService;

  bool _isProcessing = false;
  String? _errorMessage;
  Receipt? _currentReceipt;
  List<String> _activeDiets = [];

  ScannerController({
    required ScanReceiptUseCase scanReceiptUseCase,
    required OcrService ocrService,
    required dynamic receiptRepository,
  })  : _scanReceiptUseCase = scanReceiptUseCase,
        _ocrService = ocrService {
    _loadActiveDiets();
  }

  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  Receipt? get currentReceipt => _currentReceipt;
  List<String> get activeDiets => _activeDiets;

  Future<void> _loadActiveDiets() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _activeDiets = prefs.getStringList('active_diets') ?? [];
    notifyListeners();
  }

  void setActiveDiets(List<String> diets) {
    _activeDiets = diets;
    notifyListeners();
  }

  Future<void> scanReceiptFromFile(String imagePath) async {
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('ШАГ 1: Начинаем сканирование');
      
      final List<String> allLines = await _ocrService.recognizeText(imagePath);
      print('ШАГ 2: Получено ${allLines.length} строк');

      if (allLines.isEmpty) {
        throw Exception('Не удалось распознать текст');
      }

      final List<String> productLines = _ocrService.filterReceiptLines(allLines);
      print('ШАГ 3: После фильтрации ${productLines.length} строк');

      if (productLines.isEmpty) {
        throw Exception('Не найдено товарных позиций');
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> diets = prefs.getStringList('active_diets') ?? [];
      print('ШАГ 4: Активные диеты: $diets');

      _currentReceipt = _scanReceiptUseCase.execute(productLines, diets);
      print('ШАГ 5: Чек создан успешно');

    } catch (e) {
      print('ОШИБКА: $e');
      _errorMessage = e.toString();
      _currentReceipt = null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void reset() {
    _currentReceipt = null;
    _errorMessage = null;
    _isProcessing = false;
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