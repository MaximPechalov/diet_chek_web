import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'data/datasources/local_database.dart';
import 'data/repositories/product_repository.dart';
import 'domain/usecases/scan_receipt.dart';
import 'services/ocr_service.dart';
import 'services/ingredient_analyzer.dart';

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

  await ScanReceiptUseCase.loadBrands();

  final ProductRepository productRepository = ProductRepository();
  final ScanReceiptUseCase scanReceiptUseCase = ScanReceiptUseCase(productRepository);
  final OcrService ocrService = OcrService();

  final bool onboardingComplete = await _isOnboardingComplete();

  runApp(
    MultiProvider(
      providers: [
        Provider<ProductRepository>.value(value: productRepository),
        Provider<ScanReceiptUseCase>.value(value: scanReceiptUseCase),
        Provider<OcrService>.value(value: ocrService),
      ],
      child: onboardingComplete
          ? DietChekApp()
          : MaterialApp(
              debugShowCheckedModeBanner: false,
              home: OnboardingScreen(
                onComplete: () {
                  runApp(
                    MultiProvider(
                      providers: [
                        Provider<ProductRepository>.value(value: productRepository),
                        Provider<ScanReceiptUseCase>.value(value: scanReceiptUseCase),
                        Provider<OcrService>.value(value: ocrService),
                      ],
                      child: DietChekApp(),
                    ),
                  );
                },
              ),
            ),
    ),
  );
}

Future<bool> _isOnboardingComplete() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_complete') ?? false;
  } catch (e) {
    return false;
  }
}