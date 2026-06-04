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

  // Показываем splash screen
  runApp(const SplashScreen());

  // Загружаем все данные в фоне
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

  // Заменяем splash на основное приложение
  runApp(
    MultiProvider(
      providers: [
        Provider<ProductRepository>.value(value: productRepository),
        Provider<ScanReceiptUseCase>.value(value: scanReceiptUseCase),
        Provider<OcrService>.value(value: ocrService),
      ],
      child: onboardingComplete
          ? DietioApp()
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
                      child: DietioApp(),
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

// Splash Screen
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Определяем тему системы
    final bool isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFF2E7D32),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  Icons.receipt_long,
                  size: 60,
                  color: isDark ? Colors.white : const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Dietio',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Персональный диетический аудитор',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: isDark ? Colors.white : Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}