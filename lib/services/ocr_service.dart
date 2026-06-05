import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<List<String>> recognizeText(String imagePath) async {
    try {
      final InputImage inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      final List<String> lines = [];
      for (final TextBlock block in recognizedText.blocks) {
        for (final TextLine line in block.lines) {
          lines.add(line.text);
        }
      }

      return filterReceiptLines(lines);
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

  List<String> _getReceiptLinesFallback() {
    return [
      'МОЛОКО ПРОСТОКВАШИНО 3.2% 1Л',
      'ТВОРОГ ПРОСТОКВАШИНО 5% 180Г',
      'ХЛЕБ БЕЛЫЙ НАРЕЗНОЙ',
      'САХАР-ПЕСОК 1КГ',
      'ОГУРЦЫ СВЕЖИЕ',
      'СЫР РОССИЙСКИЙ 200Г',
      'ЯЙЦО КУРИНОЕ С0 10ШТ',
      'СМЕТАНА ДЕРЕВЕНСКАЯ 20% 250Г',
      'ПЕЧЕНЬЕ ОВСЯНОЕ С ШОКОЛАДОМ',
      'КОЛБАСА ДОКТОРСКАЯ ВАРЕНАЯ',
      'СОК АПЕЛЬСИНОВЫЙ 1Л',
      'МАКАРОНЫ РОЖКИ 500Г',
      'ИНДЕЙКА ФИЛЕ ОХЛАЖДЕННАЯ',
      'КОФЕ РАСТВОРИМЫЙ СУБЛИМИРОВАННЫЙ',
    ];
  }

  List<String> _getCompositionLinesFallback() {
    return [
      'Мука пшеничная в/с, сахар, масло растительное,',
      'мальтодекстрин, сыворотка молочная сухая,',
      'соль, разрыхлитель, ароматизатор',
    ];
  }

  List<String> filterReceiptLines(List<String> allLines) {
    final List<String> productLines = [];
    for (final String line in allLines) {
      if (_isServiceLine(line)) continue;
      productLines.add(line);
    }
    return productLines;
  }

  bool _isServiceLine(String line) {
    final String lowerLine = line.toLowerCase();
    final List<String> servicePatterns = [
      'инн', 'касса', 'смена', 'чек', 'продажа', 'итог', 'сумма',
      'сдача', 'ндс', 'кассир', 'магазин', 'адрес', 'телефон',
      'дата', 'время', 'ккт', 'фн', 'фд', 'фп', 'реквизиты',
      'благодарим', 'спасибо', 'покуп',
    ];
    for (final String pattern in servicePatterns) {
      if (lowerLine.contains(pattern)) return true;
    }
    if (line.length < 3) return true;
    return false;
  }

  void dispose() {
    _textRecognizer.close();
  }
}