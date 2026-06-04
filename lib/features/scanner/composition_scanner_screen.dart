import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ocr_service.dart';
import '../../services/ingredient_analyzer.dart';
import 'composition_result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompositionScannerScreen extends StatefulWidget {
  const CompositionScannerScreen({super.key});

  @override
  State<CompositionScannerScreen> createState() => _CompositionScannerScreenState();
}

class _CompositionScannerScreenState extends State<CompositionScannerScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканер состава'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showTips(context),
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
            child: _InfoPanel(errorMessage: _errorMessage),
          ),
        ],
      ),
      bottomNavigationBar: _BottomButtons(
        isProcessing: _isProcessing,
        onPickFromGallery: _pickFromGallery,
        onTestData: _useTestData,
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
      final List<String> lines = await ocrService.recognizeCompositionText('');
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
      final List<String> lines = await ocrService.recognizeCompositionText(imagePath);

      if (lines.isEmpty) {
        setState(() {
          _errorMessage = 'Не удалось распознать текст';
          _isProcessing = false;
        });
        return;
      }

      final String compositionText = lines.join(', ');
      await _analyzeText(compositionText);
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка распознавания: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _analyzeText(String compositionText) async {
    List<String> activeDiets = [];
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      activeDiets = prefs.getStringList('active_diets') ?? [];
    } catch (e) {
      activeDiets = [];
    }

    final Map<String, List<FoundIngredient>> results = IngredientAnalyzer.analyze(
      compositionText,
      activeDiets: activeDiets.isEmpty ? null : activeDiets,
    );

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
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              )),
              child: child,
            );
          },
        ),
      );
    }
  }

  void _showTips(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Как сканировать состав'),
          content: const Text(
            '1. Наведите камеру на состав продукта\n'
            '2. Текст должен быть хорошо освещен\n'
            '3. Держите камеру прямо над упаковкой\n'
            '4. Избегайте бликов и теней\n\n'
            'Приложение проанализирует каждый ингредиент\n'
            'и покажет, какие из них запрещены\n'
            'для выбранных вами диет.',
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
  final bool isProcessing;

  const _CameraPreview({required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              size: 80,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Сфотографируйте состав на упаковке\nили выберите фото из галереи',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            if (isProcessing)
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

class _InfoPanel extends StatelessWidget {
  final String? errorMessage;

  const _InfoPanel({this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Анализ состава',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Приложение найдёт в составе ингредиенты,\n'
            'запрещённые для выбранных вами диет.\n\n'
            'Работает полностью офлайн.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const Spacer(),
          if (errorMessage != null)
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
                      errorMessage!,
                      style: TextStyle(color: Colors.red[700], fontSize: 13),
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
  final VoidCallback onTestData;

  const _BottomButtons({
    required this.isProcessing,
    required this.onPickFromGallery,
    required this.onTestData,
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
                icon: const Icon(Icons.photo_library),
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
                onPressed: isProcessing ? null : onTestData,
                icon: const Icon(Icons.document_scanner),
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
}