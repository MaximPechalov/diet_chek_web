import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/datasources/local_database.dart';
import 'data/repositories/product_repository.dart';
import 'domain/usecases/scan_receipt.dart';
import 'services/ocr_service.dart';
import 'services/ingredient_analyzer.dart';
import 'services/open_food_facts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  try {
    await LocalDatabase.initialize();
  } catch (e) {
    print('Ошибка загрузки базы продуктов: $e');
  }

  try {
    await IngredientAnalyzer.initialize();
  } catch (e) {
    print('Ошибка загрузки словаря ингредиентов: $e');
  }

  final ProductRepository productRepository = ProductRepository();
  final ScanReceiptUseCase scanReceiptUseCase = ScanReceiptUseCase(productRepository);
  final OcrService ocrService = OcrService();
  final OpenFoodFactsService openFoodFactsService = OpenFoodFactsService();

  runApp(
    MultiProvider(
      providers: [
        Provider<ProductRepository>.value(value: productRepository),
        Provider<ScanReceiptUseCase>.value(value: scanReceiptUseCase),
        Provider<OcrService>.value(value: ocrService),
        Provider<OpenFoodFactsService>.value(value: openFoodFactsService),
      ],
      child: DietChekApp(),
    ),
  );
}