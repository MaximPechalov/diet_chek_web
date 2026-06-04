import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/usecases/scan_receipt.dart';
import '../../services/ocr_service.dart';
import '../../data/models/receipt.dart';
import 'controller/scanner_controller.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _showFirstScanHint = false;
  bool _showTutorial = false;
  final GlobalKey _scanButtonKey = GlobalKey();
  final GlobalKey _galleryButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkFirstScan();
  }

  Future<void> _checkFirstScan() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool hasScanned = prefs.getBool('has_scanned') ?? false;
      final bool tutorialShown = prefs.getBool('tutorial_shown') ?? false;
      if (mounted) {
        setState(() {
          _showFirstScanHint = !hasScanned;
          _showTutorial = !tutorialShown && !hasScanned;
        });
      }
    } catch (e) {}
  }

  Future<void> _markAsScanned() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_scanned', true);
      if (mounted) {
        setState(() => _showFirstScanHint = false);
      }
    } catch (e) {}
  }

  Future<void> _dismissTutorial() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tutorial_shown', true);
      setState(() => _showTutorial = false);
    } catch (e) {}
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
          final Widget mainContent = Scaffold(
            appBar: AppBar(
              title: const Text('Сканер чека'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showScanTips(context),
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  flex: 2,
                  child: _CameraPreview(
                    controller: controller,
                    showHint: _showFirstScanHint && !_showTutorial,
                    onDismissHint: _markAsScanned,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: _ScanInfoPanel(controller: controller),
                ),
              ],
            ),
            bottomNavigationBar: _BottomScanButton(
              controller: controller,
              onPickFromGallery: () => _pickFromGallery(context),
              onSaveToHistory: _saveToHistory,
              onFirstScan: _markAsScanned,
              scanButtonKey: _scanButtonKey,
              galleryButtonKey: _galleryButtonKey,
            ),
          );

          // Туториал-оверлей
          if (_showTutorial) {
            return Stack(
              children: [
                mainContent,
                _TutorialOverlay(
                  scanButtonKey: _scanButtonKey,
                  galleryButtonKey: _galleryButtonKey,
                  onDismiss: _dismissTutorial,
                ),
              ],
            );
          }

          return mainContent;
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

  Future<void> _pickFromGallery(BuildContext context) async {
    final ScannerController controller = context.read<ScannerController>();

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null) return;

      final bool? usePhoto = await _showPhotoPreview(context, image.path);
      if (usePhoto != true) return;

      await _processImage(context, controller, image.path);
    } catch (e) {
      if (mounted) {
        _showErrorDialog(context, 'Ошибка загрузки: $e', () => _pickFromGallery(context));
      }
    }
  }

  Future<bool?> _showPhotoPreview(BuildContext context, String imagePath) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Предпросмотр'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imagePath, height: 300, fit: BoxFit.contain),
              ),
              const SizedBox(height: 12),
              const Text('Использовать это фото для сканирования?'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Сканировать')),
          ],
        );
      },
    );
  }

  Future<void> _processImage(BuildContext context, ScannerController controller, String imagePath) async {
    final bool onlineSuccess = await controller.scanReceiptFromFile(imagePath);
    if (!mounted) return;

    if (onlineSuccess && controller.currentReceipt != null) {
      await _markAsScanned();
      await _saveToHistory(controller.currentReceipt!);
      _navigateToResult(context, controller);
    } else if (controller.errorMessage != null) {
      _showErrorDialog(context, controller.errorMessage!, () => _processImage(context, controller, imagePath));
    } else if (!onlineSuccess && controller.dataSource != null) {
      _showOfflineDialog(context, controller);
    }
  }

  void _showErrorDialog(BuildContext context, String message, VoidCallback onRetry) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
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
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
            child: child,
          );
        },
      ),
    );
  }

  void _showOfflineDialog(BuildContext context, ScannerController controller) {
    final String message = controller.dataSource == ScanDataSource.offlineTimeout
        ? 'Сервер не отвечает (превышено время ожидания).'
        : 'Нет подключения к интернету.';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Нет доступа к онлайн-базе'),
          content: Text('$message\n\nИспользовать офлайн-данные?'),
          actions: [
            TextButton(onPressed: () { Navigator.pop(dialogContext); controller.reset(); }, child: const Text('Нет')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                controller.useOfflineData();
                if (controller.currentReceipt != null && context.mounted) {
                  await _markAsScanned();
                  await _saveToHistory(controller.currentReceipt!);
                  _navigateToResult(context, controller);
                }
              },
              child: const Text('Да, использовать офлайн'),
            ),
          ],
        );
      },
    );
  }

  void _showScanTips(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Как сканировать'),
          content: const Text(
            '1. Положите чек на ровную поверхность\n2. Убедитесь, что текст хорошо освещен\n3. Держите камеру прямо над чеком\n4. Чек должен полностью помещаться в рамку\n5. Избегайте бликов и теней\n\nВы также можете загрузить фото чека из галереи.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Понятно'))],
        );
      },
    );
  }
}

// Виджет туториала
class _TutorialOverlay extends StatelessWidget {
  final GlobalKey scanButtonKey;
  final GlobalKey galleryButtonKey;
  final VoidCallback onDismiss;

  const _TutorialOverlay({
    required this.scanButtonKey,
    required this.galleryButtonKey,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black54,
        child: Stack(
          children: [
            // Подсветка кнопки Галерея
            _buildHighlight(
              context: context,
              targetKey: galleryButtonKey,
              text: 'Загрузите фото чека\nиз галереи',
              alignment: Alignment.bottomCenter,
              offset: const Offset(0, -80),
            ),
            // Подсветка кнопки Сканировать
            _buildHighlight(
              context: context,
              targetKey: scanButtonKey,
              text: 'Или используйте\nтестовый скан',
              alignment: Alignment.bottomCenter,
              offset: const Offset(0, -80),
            ),
            // Кнопка закрыть
            Positioned(
              top: 60,
              right: 20,
              child: ElevatedButton(
                onPressed: onDismiss,
                child: const Text('Понятно'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlight({
    required BuildContext context,
    required GlobalKey targetKey,
    required String text,
    required Alignment alignment,
    required Offset offset,
  }) {
    final RenderBox? renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();

    final Offset position = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    return Stack(
      children: [
        // Подсвеченная область
        Positioned(
          left: position.dx - 4,
          top: position.dy - 4,
          width: size.width + 8,
          height: size.height + 8,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.8), blurRadius: 12, spreadRadius: 2)],
            ),
          ),
        ),
        // Текст подсказки
        Positioned(
          left: position.dx + size.width / 2 + offset.dx - 100,
          top: position.dy + offset.dy,
          child: Container(
            width: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: Column(
              children: [
                Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 4),
                Icon(Icons.arrow_downward, size: 20, color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CameraPreview extends StatelessWidget {
  final ScannerController controller;
  final bool showHint;
  final VoidCallback? onDismissHint;

  const _CameraPreview({required this.controller, this.showHint = false, this.onDismissHint});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.black,
          child: Center(
            child: controller.isProcessing
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      Text('Анализируем чек...', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.document_scanner, size: 80, color: Colors.white.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('Наведите камеру на чек\nили выберите фото из галереи',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                    ],
                  ),
          ),
        ),
        if (showHint && !controller.isProcessing)
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(children: [
                    Text('💡', style: TextStyle(fontSize: 20)), SizedBox(width: 8),
                    Expanded(child: Text('Нажмите «Сканировать» или «Галерея» чтобы начать анализ продуктов',
                        style: TextStyle(fontSize: 13, color: Colors.black87))),
                  ]),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight,
                    child: TextButton(onPressed: onDismissHint, child: const Text('Больше не показывать', style: TextStyle(fontSize: 12)))),
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
  const _ScanInfoPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Активные диеты:', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (controller.activeDiets.isEmpty)
            Text('Диеты не выбраны. Перейдите в настройки.', style: TextStyle(color: Colors.grey[600]))
          else
            Wrap(spacing: 8, runSpacing: 4,
              children: controller.activeDiets.map((String diet) {
                return Chip(label: Text(_dietDisplayName(diet)), backgroundColor: _dietColor(diet),
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12));
              }).toList()),
          const Spacer(),
          if (controller.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red[200]!)),
              child: Row(children: [
                Icon(Icons.error_outline, color: Colors.red[700]), const SizedBox(width: 8),
                Expanded(child: Text(controller.errorMessage!, style: TextStyle(color: Colors.red[700], fontSize: 13))),
              ]),
            ),
        ],
      ),
    );
  }

  String _dietDisplayName(String dietKey) {
    const Map<String, String> names = {'no_sugar': 'Без сахара', 'keto': 'Кето', 'low_fodmap': 'Low-FODMAP', 'lactose_free': 'Без лактозы'};
    return names[dietKey] ?? dietKey;
  }

  Color _dietColor(String dietKey) {
    const Map<String, Color> colors = {'no_sugar': Color(0xFF42A5F5), 'keto': Color(0xFFFF7043), 'low_fodmap': Color(0xFFAB47BC), 'lactose_free': Color(0xFF26A69A)};
    return colors[dietKey] ?? Colors.grey;
  }
}

class _BottomScanButton extends StatelessWidget {
  final ScannerController controller;
  final VoidCallback onPickFromGallery;
  final Future<void> Function(Receipt) onSaveToHistory;
  final VoidCallback onFirstScan;
  final GlobalKey scanButtonKey;
  final GlobalKey galleryButtonKey;

  const _BottomScanButton({
    required this.controller, required this.onPickFromGallery, required this.onSaveToHistory,
    required this.onFirstScan, required this.scanButtonKey, required this.galleryButtonKey,
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
                key: galleryButtonKey,
                onPressed: controller.isProcessing ? null : onPickFromGallery,
                icon: controller.isProcessing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.photo_library),
                label: const Text('Галерея', style: TextStyle(fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                key: scanButtonKey,
                onPressed: controller.isProcessing ? null : () => _onScanPressed(context),
                icon: controller.isProcessing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.camera_alt),
                label: const Text('Сканировать', style: TextStyle(fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onScanPressed(BuildContext context) async {
    final ScannerController controller = context.read<ScannerController>();
    final bool onlineSuccess = await controller.scanReceiptFromFile('');
    if (!context.mounted) return;

    if (onlineSuccess && controller.currentReceipt != null) {
      onFirstScan();
      await onSaveToHistory(controller.currentReceipt!);
      Navigator.push(context, PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ChangeNotifierProvider<ScannerController>.value(value: controller, child: const ResultScreen()),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
            child: child,
          );
        },
      ));
    } else if (controller.errorMessage != null) {
      _showErrorDialog(context, controller.errorMessage!, () => _onScanPressed(context));
    } else if (!onlineSuccess && controller.dataSource != null) {
      final String message = controller.dataSource == ScanDataSource.offlineTimeout
          ? 'Сервер не отвечает (превышено время ожидания).' : 'Нет подключения к интернету.';
      showDialog(context: context, builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Нет доступа к онлайн-базе'),
          content: Text('$message\n\nИспользовать офлайн-данные?'),
          actions: [
            TextButton(onPressed: () { Navigator.pop(dialogContext); controller.reset(); }, child: const Text('Нет')),
            ElevatedButton(onPressed: () async {
              Navigator.pop(dialogContext);
              controller.useOfflineData();
              if (controller.currentReceipt != null && context.mounted) {
                await onSaveToHistory(controller.currentReceipt!);
                Navigator.push(context, PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      ChangeNotifierProvider<ScannerController>.value(value: controller, child: const ResultScreen()),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                          .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
                      child: child,
                    );
                  },
                ));
              }
            }, child: const Text('Да, использовать офлайн')),
          ],
        );
      });
    }
  }

  void _showErrorDialog(BuildContext context, String message, VoidCallback onRetry) {
    showDialog(context: context, builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Ошибка сканирования'), content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
          ElevatedButton.icon(
            onPressed: () { Navigator.pop(dialogContext); onRetry(); },
            icon: const Icon(Icons.refresh, size: 18), label: const Text('Повторить')),
        ],
      );
    });
  }
}