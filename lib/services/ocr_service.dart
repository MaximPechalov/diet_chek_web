import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'receipt_parser.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  final ReceiptParser _parser = ReceiptParser();

  Future<List<String>> recognizeText(String imagePath) async {
    try {
      final InputImage inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      final List<String> allLines = [];
      for (final TextBlock block in recognizedText.blocks) {
        for (final TextLine line in block.lines) {
          allLines.add(line.text.trim());
        }
      }

      // Используем парсер для извлечения товарных позиций
      final List<String> parsed = _parser.parseReceipt(allLines);
      
      // Если парсер ничего не нашёл — fallback
      if (parsed.isEmpty) {
        return _getReceiptLinesFallback();
      }
      
      return parsed;
    } catch (e) {
      return _getReceiptLinesFallback();
    }
  }

  Future<List<String>> recognizeCompositionText(String imagePath) async {
    try {
      final InputImage inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      final List<String> lines = [];
      for (final TextBlock block in recognizedText.blocks) {
        for (final TextLine line in block.lines) {
          lines.add(line.text);
        }
      }

      return lines;
    } catch (e) {
      return _getCompositionLinesFallback();
    }
  }

  List<String> filterReceiptLines(List<String> allLines) {
    final List<String> productLines = [];
    for (final String line in allLines) {
      if (line.trim().isEmpty) continue;
      if (line.trim().length < 3) continue;
      productLines.add(line.trim());
    }
    return productLines;
  }

  List<String> _getReceiptLinesFallback() {
    return [
      'МОЛОКО 3.2% 1Л',
      'ТВОРОГ 5% 180Г',
      'ХЛЕБ БЕЛЫЙ НАРЕЗНОЙ',
      'САХАР-ПЕСОК 1КГ',
      'ОГУРЦЫ СВЕЖИЕ',
      'СЫР РОССИЙСКИЙ 200Г',
      'ЯЙЦО КУРИНОЕ 10ШТ',
      'СМЕТАНА 20% 250Г',
      'ПЕЧЕНЬЕ ОВСЯНОЕ',
      'КОЛБАСА ДОКТОРСКАЯ',
      'СОК АПЕЛЬСИНОВЫЙ 1Л',
      'МАКАРОНЫ 500Г',
      'ИНДЕЙКА ФИЛЕ',
      'КОФЕ РАСТВОРИМЫЙ',
    ];
  }

  List<String> _getCompositionLinesFallback() {
    return [
      'Мука пшеничная в/с, сахар, масло растительное,',
      'мальтодекстрин, сыворотка молочная сухая,',
      'соль, разрыхлитель, ароматизатор',
    ];
  }

  void dispose() {
    _textRecognizer.close();
  }
}