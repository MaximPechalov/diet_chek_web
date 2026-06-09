import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import '../../domain/usecases/scan_receipt.dart';
import '../../services/ocr_service.dart';
import '../../data/models/receipt.dart';
import '../../core/constants/app_colors.dart';
import 'controller/scanner_controller.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  final ImagePicker _imagePicker = ImagePicker();
  bool _showFirstScanHint = false;
  List<String> _activeDiets = [];
  
  // Камера
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkFirstScan();
    _loadActiveDiets();
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
      _isCameraReady = false;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras!.first,
          ),
          ResolutionPreset.medium,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() => _isCameraReady = true);
        }
      }
    } catch (e) {
      // Камера недоступна — показываем заглушку
    }
  }

  Future<void> _checkFirstScan() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool hasScanned = prefs.getBool('has_scanned') ?? false;
      if (mounted) setState(() => _showFirstScanHint = !hasScanned);
    } catch (e) {}
  }

  Future<void> _markAsScanned() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_scanned', true);
      if (mounted) setState(() => _showFirstScanHint = false);
    } catch (e) {}
  }

  Future<void> _loadActiveDiets() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> diets = prefs.getStringList('active_diets') ?? [];
      if (mounted) setState(() => _activeDiets = diets);
    } catch (e) {
      _activeDiets = [];
    }
  }

  Future<void> _toggleDiet(String dietKey) async {
    setState(() {
      if (_activeDiets.contains(dietKey)) {
        _activeDiets.remove(dietKey);
      } else {
        _activeDiets.add(dietKey);
      }
    });
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('active_diets', _activeDiets);
    } catch (e) {}
    if (mounted) {
      final controller = context.read<ScannerController>();
      controller.setActiveDiets(_activeDiets);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ScannerController>(
      create: (BuildContext context) => ScannerController(
        scanReceiptUseCase: context.read<ScanReceiptUseCase>(),
        ocrService: context.read<OcrService>(),
      ),
      child: Consumer<ScannerController>(
        builder: (BuildContext context, ScannerController controller, Widget? child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Сканер чека'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showScanTips(context),
                  tooltip: 'Как сканировать',
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  flex: 2,
                  child: _CameraPreview(
                    controller: controller,
                    cameraController: _cameraController,
                    isCameraReady: _isCameraReady,
                    showHint: _showFirstScanHint,
                    onDismissHint: _markAsScanned,
                    onTap: () => _takePhoto(context),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: _ScanInfoPanel(
                    controller: controller,
                    activeDiets: _activeDiets,
                    onToggleDiet: _toggleDiet,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _BottomScanButtons(
              controller: controller,
              onTakePhoto: () => _takePhoto(context),
              onPickFromGallery: () => _pickFromGallery(context),
              onSaveToHistory: _saveToHistory,
              onFirstScan: _markAsScanned,
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveToHistory(Receipt receipt) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> savedReceipts = prefs.getStringList('receipts') ?? [];
      savedReceipts.insert(0, jsonEncode(receipt.toJson()));
      await prefs.setStringList('receipts', savedReceipts);
    } catch (e) {}
  }

  Future<void> _takePhoto(BuildContext context) async {
    final PermissionStatus status = await Permission.camera.request();

    if (status.isGranted) {
      try {
        final XFile? photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
        );
        if (photo == null) return;
        final ScannerController controller = context.read<ScannerController>();
        await _processImage(context, controller, photo.path);
      } catch (e) {
        if (mounted) _showErrorDialog(context, 'Ошибка камеры: $e', () => _takePhoto(context));
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) _showPermissionDialog(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Разрешение камеры необходимо для сканирования'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    final ScannerController controller = context.read<ScannerController>();
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (image == null) return;
      final bool? usePhoto = await _showPhotoPreview(context, image.path);
      if (usePhoto != true) return;
      await _processImage(context, controller, image.path);
    } catch (e) {
      if (mounted) _showErrorDialog(context, 'Ошибка загрузки: $e', () => _pickFromGallery(context));
    }
  }

  Future<bool?> _showPhotoPreview(BuildContext context, String imagePath) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Предпросмотр'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(imagePath), height: 300, fit: BoxFit.contain)),
              const SizedBox(height: 16),
              const Text('Использовать это фото для сканирования?'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.document_scanner, size: 18),
              label: const Text('Сканировать'),
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processImage(BuildContext context, ScannerController controller, String imagePath) async {
    final bool success = await controller.scanReceiptFromFile(imagePath);
    if (!mounted) return;
    if (success && controller.currentReceipt != null) {
      await _markAsScanned();
      await _saveToHistory(controller.currentReceipt!);
      _navigateToResult(context, controller);
    } else if (controller.errorMessage != null) {
      _showErrorDialog(context, controller.errorMessage!, () => _processImage(context, controller, imagePath));
    }
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Доступ к камере'),
          content: const Text('Для сканирования чеков необходим доступ к камере. Пожалуйста, разрешите доступ в настройках приложения.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
            ElevatedButton(onPressed: () { Navigator.pop(dialogContext); openAppSettings(); }, child: const Text('Открыть настройки')),
          ],
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message, VoidCallback onRetry) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ошибка сканирования'),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
            ElevatedButton.icon(
              onPressed: () { Navigator.pop(dialogContext); onRetry(); },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Повторить'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToResult(BuildContext context, ScannerController controller) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ChangeNotifierProvider<ScannerController>.value(value: controller, child: const ResultScreen()),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _showScanTips(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text('Как сканировать чек', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _buildTipRow(Icons.crop_free, 'Положите чек на ровную поверхность'),
                  const SizedBox(height: 12),
                  _buildTipRow(Icons.wb_sunny, 'Убедитесь, что текст хорошо освещен'),
                  const SizedBox(height: 12),
                  _buildTipRow(Icons.center_focus_strong, 'Держите камеру прямо над чеком'),
                  const SizedBox(height: 12),
                  _buildTipRow(Icons.fit_screen, 'Чек должен полностью помещаться в рамку'),
                  const SizedBox(height: 12),
                  _buildTipRow(Icons.highlight_off, 'Избегайте бликов и теней'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Понятно'),
                      style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTipRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    );
  }
}

class _CameraPreview extends StatelessWidget {
  final ScannerController controller;
  final CameraController? cameraController;
  final bool isCameraReady;
  final bool showHint;
  final VoidCallback? onDismissHint;
  final VoidCallback onTap;

  const _CameraPreview({
    required this.controller,
    required this.cameraController,
    required this.isCameraReady,
    this.showHint = false,
    this.onDismissHint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Фон: камера или градиент
        if (isCameraReady && cameraController != null && !controller.isProcessing)
          CameraPreview(cameraController!)
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.grey[900]!, Colors.grey[800]!]),
            ),
          ),

        // Затемнение поверх камеры для лучшей читаемости иконки
        if (isCameraReady && !controller.isProcessing)
          Container(color: Colors.black.withOpacity(0.3)),

        // Контент по центру
        Center(
          child: controller.isProcessing
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
                    const SizedBox(height: 20),
                    Text('Анализируем чек...',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
                  ],
                )
              : GestureDetector(
                  onTap: onTap,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                        ),
                        child: Icon(Icons.receipt_long, size: 50, color: Colors.white.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        isCameraReady ? 'Нажмите для сканирования\nили выберите фото из галереи' : 'Сфотографируйте чек\nили выберите фото из галереи',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16, height: 1.5, letterSpacing: 0.2),
                      ),
                    ],
                  ),
                ),
        ),

        // Подсказка
        if (showHint && !controller.isProcessing)
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12)]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    const Text('💡', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Нажмите «Сканировать» или «Галерея» чтобы начать анализ', style: TextStyle(fontSize: 13, color: Colors.grey[800]))),
                  ]),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: TextButton(onPressed: onDismissHint, child: const Text('Больше не показывать', style: TextStyle(fontSize: 12)))),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ScanInfoPanel extends StatelessWidget {
  final ScannerController controller;
  final List<String> activeDiets;
  final Function(String) onToggleDiet;

  const _ScanInfoPanel({
    required this.controller,
    required this.activeDiets,
    required this.onToggleDiet,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> allDiets = [
      {'key': 'no_sugar', 'name': 'Без сахара', 'color': AppColors.noSugarCard, 'icon': Icons.no_food},
      {'key': 'keto', 'name': 'Кето', 'color': AppColors.ketoCard, 'icon': Icons.egg},
      {'key': 'low_fodmap', 'name': 'Low-FODMAP', 'color': AppColors.lowFodmapCard, 'icon': Icons.healing},
      {'key': 'lactose_free', 'name': 'Без лактозы', 'color': AppColors.lactoseFreeCard, 'icon': Icons.water_drop},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(children: [
            Icon(Icons.checklist, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text('Активные диеты:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: activeDiets.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Text('Нажмите на диету чтобы активировать', style: TextStyle(color: Colors.orange[700], fontSize: 13)),
                        ],
                      ),
                    )
                  : Wrap(
                      spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
                      children: allDiets.map((diet) {
                        final String key = diet['key'] as String;
                        final String name = diet['name'] as String;
                        final Color color = diet['color'] as Color;
                        final IconData icon = diet['icon'] as IconData;
                        final bool isActive = activeDiets.contains(key);
                        return GestureDetector(
                          onTap: () => onToggleDiet(key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isActive ? color.withOpacity(0.15) : Colors.grey[200],
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: isActive ? color.withOpacity(0.5) : Colors.grey[300]!, width: isActive ? 1.5 : 1),
                              boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))] : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 18, color: isActive ? color : Colors.grey[500]),
                                const SizedBox(width: 6),
                                Text(name, style: TextStyle(color: isActive ? color : Colors.grey[600], fontSize: 13, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
                                if (isActive) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.check_circle, size: 16, color: color),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),
          if (controller.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red[200]!)),
              child: Row(children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(controller.errorMessage!, style: TextStyle(color: Colors.red[700], fontSize: 13))),
              ]),
            ),
        ],
      ),
    );
  }
}

class _BottomScanButtons extends StatelessWidget {
  final ScannerController controller;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickFromGallery;
  final Future<void> Function(Receipt) onSaveToHistory;
  final VoidCallback onFirstScan;

  const _BottomScanButtons({
    required this.controller,
    required this.onTakePhoto,
    required this.onPickFromGallery,
    required this.onSaveToHistory,
    required this.onFirstScan,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: controller.isProcessing ? null : onPickFromGallery,
                icon: controller.isProcessing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.photo_library),
                label: const Text('Галерея', style: TextStyle(fontSize: 14, letterSpacing: 0.3)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: controller.isProcessing ? null : onTakePhoto,
                icon: controller.isProcessing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.camera_alt),
                label: const Text('Сканировать', style: TextStyle(fontSize: 14, letterSpacing: 0.3)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}