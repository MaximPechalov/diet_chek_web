import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../services/ocr_service.dart';
import '../../services/ingredient_analyzer.dart';
import '../../data/models/receipt.dart';
import '../../data/models/scanned_item.dart';
import 'composition_result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompositionScannerScreen extends StatefulWidget {
  const CompositionScannerScreen({super.key});

  @override
  State<CompositionScannerScreen> createState() =>
      _CompositionScannerScreenState();
}

class _CompositionScannerScreenState extends State<CompositionScannerScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isProcessing = false;
  String? _errorMessage;
  List<String> _activeDiets = [];

  @override
  void initState() {
    super.initState();
    _loadActiveDiets();
  }

  Future<void> _loadActiveDiets() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> diets = prefs.getStringList('active_diets') ?? [];
      if (mounted) {
        setState(() => _activeDiets = diets);
      }
    } catch (e) {
      _activeDiets = [];
    }
  }

  Future<void> _saveToHistory(Receipt receipt) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> savedReceipts =
          prefs.getStringList('receipts') ?? [];
      savedReceipts.insert(0, jsonEncode(receipt.toJson()));
      await prefs.setStringList('receipts', savedReceipts);
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканер состава'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showTips(context),
            tooltip: 'Как сканировать',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: _CameraPreview(isProcessing: _isProcessing),
          ),
          Expanded(
            flex: 1,
            child: _InfoPanel(
              errorMessage: _errorMessage,
              activeDiets: _activeDiets,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomButtons(
        isProcessing: _isProcessing,
        onPickFromGallery: _pickFromGallery,
        onTestScan: _useTestData,
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null) {
        setState(() => _isProcessing = false);
        return;
      }

      await _analyzeImage(image.path);
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _useTestData() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final OcrService ocrService = context.read<OcrService>();
      final List<String> lines =
          await ocrService.recognizeCompositionText('');
      final String compositionText = lines.join(', ');

      await _analyzeText(compositionText);
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _analyzeImage(String imagePath) async {
    try {
      final OcrService ocrService = context.read<OcrService>();
      final List<String> lines =
          await ocrService.recognizeCompositionText(imagePath);

      if (lines.isEmpty) {
        setState(() {
          _errorMessage = 'Не удалось распознать текст';
          _isProcessing = false;
        });
        return;
      }

      await _analyzeText(lines.join(', '));
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка распознавания: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _analyzeText(String compositionText) async {
    if (compositionText.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Не удалось получить текст состава';
        _isProcessing = false;
      });
      return;
    }

    List<String> activeDiets = [];
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      activeDiets = prefs.getStringList('active_diets') ?? [];
    } catch (e) {
      activeDiets = [];
    }

    final Map<String, List<FoundIngredient>> results =
        IngredientAnalyzer.analyze(
      compositionText,
      activeDiets: activeDiets.isEmpty ? null : activeDiets,
    );

    final List<ScannedItem> items = compositionText
        .split(',')
        .map((s) => ScannedItem(
              rawText: s.trim(),
              normalizedText: s.trim().toLowerCase(),
            ))
        .toList();

    final Receipt receipt = Receipt(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      scannedAt: DateTime.now(),
      items: items,
      storeName: 'composition',
    );

    await _saveToHistory(receipt);

    setState(() => _isProcessing = false);

    if (mounted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              CompositionResultScreen(
            compositionText: compositionText,
            results: results,
          ),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubic,
                ),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  void _showTips(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Как сканировать состав',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildTipRow(
                  Icons.camera_alt, 'Наведите камеру на состав продукта'),
              const SizedBox(height: 12),
              _buildTipRow(
                  Icons.wb_sunny, 'Текст должен быть хорошо освещен'),
              const SizedBox(height: 12),
              _buildTipRow(Icons.center_focus_strong,
                  'Держите камеру прямо над упаковкой'),
              const SizedBox(height: 12),
              _buildTipRow(Icons.highlight_off, 'Избегайте бликов и теней'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Понятно'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTipRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

class _CameraPreview extends StatelessWidget {
  final bool isProcessing;

  const _CameraPreview({required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[900]!, Colors.grey[800]!],
        ),
      ),
      child: Center(
        child: isProcessing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Анализируем состав...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.menu_book,
                      size: 50,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Нажмите «Сканировать» для теста\nили «Галерея» для загрузки фото',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                      height: 1.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String? errorMessage;
  final List<String> activeDiets;

  const _InfoPanel({
    this.errorMessage,
    required this.activeDiets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Заголовок
          Row(
            children: [
              Icon(
                Icons.checklist,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Активные диеты:',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Центрированный контент — ИДЕНТИЧНО сканеру чека
          Expanded(
            child: Center(
              child: activeDiets.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Диеты не выбраны. Перейдите в настройки.',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: activeDiets.map((String diet) {
                        final Color c = AppColors.getDietColor(diet);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: c.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                AppColors.getDietIcon(diet),
                                size: 16,
                                color: c,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppColors.getDietName(diet),
                                style: TextStyle(
                                  color: c,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),

          // Ошибка внизу
          if (errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomButtons extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onPickFromGallery;
  final VoidCallback onTestScan;

  const _BottomButtons({
    required this.isProcessing,
    required this.onPickFromGallery,
    required this.onTestScan,
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
                onPressed: isProcessing ? null : onPickFromGallery,
                icon: const Icon(Icons.photo_library, size: 20),
                label: const Text(
                  'Галерея',
                  style: TextStyle(fontSize: 13, letterSpacing: 0.3),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.secondary,
                  foregroundColor:
                      Theme.of(context).colorScheme.onSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isProcessing ? null : onTestScan,
                icon: const Icon(Icons.document_scanner, size: 20),
                label: const Text(
                  'Сканировать',
                  style: TextStyle(fontSize: 13, letterSpacing: 0.3),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.primary,
                  foregroundColor:
                      Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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