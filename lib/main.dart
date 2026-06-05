import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

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

  // Запрашиваем разрешение камеры
  await _requestCameraPermission();

  // Загрузка данных
  final List<Future<void>> initTasks = [
    LocalDatabase.initialize(),
    IngredientAnalyzer.initialize(),
    ScanReceiptUseCase.loadBrands(),
  ];

  // Показываем splash пока загружаются данные
  runApp(const _SplashApp());

  // Загружаем данные в фоне
  for (final task in initTasks) {
    try {
      await task;
    } catch (e) {
      // продолжаем при ошибке
    }
  }

  // Запускаем основное приложение
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

Future<void> _requestCameraPermission() async {
  final PermissionStatus status = await Permission.camera.request();
  if (status.isDenied || status.isPermanentlyDenied) {
    // Можно показать диалог с объяснением, но пока просто логируем
    print('Разрешение камеры не получено: $status');
  }
}

Future<bool> _isOnboardingComplete() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_complete') ?? false;
  } catch (e) {
    return false;
  }
}

class _SplashApp extends StatefulWidget {
  const _SplashApp();

  @override
  State<_SplashApp> createState() => _SplashAppState();
}

class _SplashAppState extends State<_SplashApp> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1a1a1a), const Color(0xFF0d2d0d), const Color(0xFF1a1a1a)]
                  : [const Color(0xFF2E7D32), const Color(0xFF388E3C), const Color(0xFF4CAF50)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(scale: _pulseAnimation.value, child: child);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 25,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.receipt_long, size: 70, color: Color(0xFF2E7D32)),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'Dietio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Персональный диетический аудитор',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 15,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 60),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}