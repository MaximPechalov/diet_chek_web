import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/usecases/scan_receipt.dart';
import '../../services/ocr_service.dart';
import 'controller/scanner_controller.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ScannerController>(
      create: (BuildContext context) => ScannerController(
        scanReceiptUseCase: context.read<ScanReceiptUseCase>(),
        ocrService: context.read<OcrService>(),
        receiptRepository: null,
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
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  flex: 2,
                  child: _CameraPreview(controller: controller),
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
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    final ScannerController controller = context.read<ScannerController>();

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null) return; // Пользователь отменил выбор

      await controller.scanReceiptFromFile(image.path);

      if (controller.currentReceipt != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChangeNotifierProvider<ScannerController>.value(
              value: controller,
              child: const ResultScreen(),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  void _showScanTips(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Как сканировать'),
          content: const Text(
            '1. Положите чек на ровную поверхность\n'
            '2. Убедитесь, что текст хорошо освещен\n'
            '3. Держите камеру прямо над чеком\n'
            '4. Чек должен полностью помещаться в рамку\n'
            '5. Избегайте бликов и теней\n\n'
            'Вы также можете загрузить фото чека из галереи.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        );
      },
    );
  }
}

class _CameraPreview extends StatelessWidget {
  final ScannerController controller;

  const _CameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.document_scanner,
              size: 80,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Наведите камеру на чек\nили выберите фото из галереи',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            if (controller.isProcessing)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
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
          Text(
            'Активные диеты:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (controller.activeDiets.isEmpty)
            Text(
              'Диеты не выбраны. Перейдите в настройки.',
              style: TextStyle(color: Colors.grey[600]),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: controller.activeDiets.map((String diet) {
                return Chip(
                  label: Text(_dietDisplayName(diet)),
                  backgroundColor: _dietColor(diet),
                  labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList(),
            ),
          const Spacer(),
          if (controller.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.errorMessage!,
                      style: TextStyle(color: Colors.red[700], fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => controller.clearError(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _dietDisplayName(String dietKey) {
    const Map<String, String> names = {
      'no_sugar': 'Без сахара',
      'keto': 'Кето',
      'low_fodmap': 'Low-FODMAP',
      'lactose_free': 'Без лактозы',
    };
    return names[dietKey] ?? dietKey;
  }

  Color _dietColor(String dietKey) {
    const Map<String, Color> colors = {
      'no_sugar': Color(0xFF42A5F5),
      'keto': Color(0xFFFF7043),
      'low_fodmap': Color(0xFFAB47BC),
      'lactose_free': Color(0xFF26A69A),
    };
    return colors[dietKey] ?? Colors.grey;
  }
}

class _BottomScanButton extends StatelessWidget {
  final ScannerController controller;
  final VoidCallback onPickFromGallery;

  const _BottomScanButton({
    required this.controller,
    required this.onPickFromGallery,
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
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.photo_library),
                label: Text(
                  controller.isProcessing ? 'Обработка...' : 'Галерея',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: controller.isProcessing
                    ? null
                    : () => _onScanPressed(context),
                icon: controller.isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(
                  controller.isProcessing ? 'Обработка...' : 'Сканировать',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
    await controller.scanReceiptFromFile('');

    if (controller.currentReceipt != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider<ScannerController>.value(
            value: controller,
            child: const ResultScreen(),
          ),
        ),
      );
    }
  }
}