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
          ? _PermissionGate(child: DietioApp())
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
                      child: _PermissionGate(child: DietioApp()),
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

/// Запрашивает разрешение камеры при первом запуске
class _PermissionGate extends StatefulWidget {
  final Widget child;
  _PermissionGate({required this.child});

  @override
  State<_PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<_PermissionGate> {
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Проверяем, не запрашивали ли уже разрешение
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool permissionAsked = prefs.getBool('camera_permission_asked') ?? false;

    if (!permissionAsked) {
      // Ждём кадр, чтобы диалог показался поверх интерфейса
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        final bool? granted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Доступ к камере', style: TextStyle(fontSize: 18, letterSpacing: 0.3))),
              ],
            ),
            content: const Text(
              'Для сканирования чеков и составов продуктов приложению нужен доступ к камере.\n\n'
              'Вы сможете изменить это в любое время в настройках телефона.',
              style: TextStyle(fontSize: 14, letterSpacing: 0.2),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Не сейчас', style: TextStyle(letterSpacing: 0.3)),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Разрешить', style: TextStyle(letterSpacing: 0.3)),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );

        if (granted == true) {
          final PermissionStatus status = await Permission.camera.request();
          if (status.isDenied || status.isPermanentlyDenied) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Разрешение камеры отклонено'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  action: SnackBarAction(
                    label: 'Настройки',
                    onPressed: () => openAppSettings(),
                  ),
                ),
              );
            }
          }
        }

        // Запоминаем, что спрашивали
        await prefs.setBool('camera_permission_asked', true);
      }
    }

    setState(() => _permissionChecked = true);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
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
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 25, offset: const Offset(0, 12))],
                      ),
                      child: const Icon(Icons.receipt_long, size: 70, color: Color(0xFF2E7D32)),
                    ),
                    const SizedBox(height: 36),
                    Text('Dietio', style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: 4, shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))])),
                    const SizedBox(height: 10),
                    Text('Персональный диетический аудитор', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15, letterSpacing: 1.2, fontWeight: FontWeight.w300)),
                    const SizedBox(height: 60),
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
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