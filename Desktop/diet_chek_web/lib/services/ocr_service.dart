class OcrService {
  Future<List<String>> recognizeText(String imagePath) async {
    return _getReceiptLines();
  }

  Future<List<String>> recognizeCompositionText(String imagePath) async {
    return _getCompositionLines();
  }

  Future<List<String>> recognizeFromCameraImage(dynamic cameraImage) async {
    return _getReceiptLines();
  }

  List<String> _getReceiptLines() {
    return [
      'МОЛОКО ПРОСТОКВАШИНО 3.2% 1Л',
      'ТВОРОГ 5% 180Г',
      'ХЛЕБ БЕЛЫЙ НАРЕЗНОЙ',
      'САХАР-ПЕСОК 1КГ',
      'ОГУРЦЫ СВЕЖИЕ',
      'СЫР РОССИЙСКИЙ 200Г',
      'ЯЙЦО КУРИНОЕ С0 10ШТ',
    ];
  }

  List<String> _getCompositionLines() {
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
}