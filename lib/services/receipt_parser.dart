class ReceiptParser {
  /// Главный метод: принимает все строки с чека, возвращает только названия товаров
  List<String> parseReceipt(List<String> allLines) {
    // Шаг 1: Склеиваем разорванные строки
    final List<String> merged = _mergeBrokenLines(allLines);

    // Шаг 2: Удаляем строки-разделители и заголовки
    final List<String> withoutHeaders = _removeHeaders(merged);

    // Шаг 3: Оставляем только товарные позиции
    final List<String> productLines = _extractProductLines(withoutHeaders);

    // Шаг 4: Очищаем названия от веса, цены, количества
    final List<String> cleaned = _cleanProductNames(productLines);

    // Шаг 5: Нормализуем OCR-шум
    final List<String> normalized = _normalizeOcrNoise(cleaned);

    // Шаг 6: Убираем дубликаты и пустые строки
    return _removeDuplicatesAndEmpty(normalized);
  }

  /// Склеивает строки, разорванные переносом
  List<String> _mergeBrokenLines(List<String> lines) {
    final List<String> result = [];

    for (int i = 0; i < lines.length; i++) {
      final String current = lines[i].trim();
      if (current.isEmpty) continue;

      // Если строка начинается со строчной буквы — продолжение предыдущей
      if (RegExp(r'^[а-яёa-z]').hasMatch(current) && result.isNotEmpty) {
        result[result.length - 1] = '${result.last} $current';
        continue;
      }

      // Вес/объём на отдельной строке
      if (_isWeightOrVolume(current) && result.isNotEmpty) {
        result[result.length - 1] = '${result.last} $current';
        continue;
      }

      result.add(current);
    }

    return result;
  }

  /// Проверяет, является ли строка весом/объёмом
  bool _isWeightOrVolume(String line) {
    return RegExp(
      r'^\d+[.,]?\d*\s*(г|мл|л|кг|шт|гр|мг)$',
      caseSensitive: false,
    ).hasMatch(line.trim());
  }

  /// Удаляет заголовки, разделители, служебные строки
  List<String> _removeHeaders(List<String> lines) {
    final List<String> result = [];
    bool foundProducts = false;

    for (final String line in lines) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Ищем начало товарного блока (обычно после "------" или похожих разделителей)
      if (_isSeparator(trimmed)) {
        foundProducts = true;
        continue;
      }

      // До разделителя — это шапка чека
      if (!foundProducts && _isHeaderLine(trimmed)) {
        continue;
      }

      result.add(trimmed);
    }

    return result;
  }

  /// Проверяет, является ли строка разделителем
  bool _isSeparator(String line) {
    return RegExp(r'^[-=_*]{3,}$').hasMatch(line.trim());
  }

  /// Проверяет, является ли строка частью шапки чека
  bool _isHeaderLine(String line) {
    final String lower = line.toLowerCase().trim();

    final List<String> headerPatterns = [
      'кассир', 'смена', 'чек', 'приход', 'продажа', 'инн',
      'магазин', 'адрес', 'телефон', 'сайт', 'ккт', 'фн',
      'фд', 'фп', 'дата', 'время', 'пятёрочка', 'пятерочка',
      'магнит', 'дикси', 'лента', 'ашан', 'перекрёсток',
      'спар', 'балтика', 'красное', 'налогообложения',
      'система', 'патент', 'ош', 'ооо', 'ао', 'зао', 'ип',
      'реквизиты', 'благодарим', 'спасибо',
    ];

    for (final String pattern in headerPatterns) {
      if (lower.contains(pattern)) return true;
    }

    return false;
  }

  /// Извлекает только строки с товарами
  List<String> _extractProductLines(List<String> lines) {
    final List<String> productLines = [];

    for (final String line in lines) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Строка должна содержать кириллицу
      if (!RegExp(r'[а-яА-ЯёЁ]').hasMatch(trimmed)) continue;

      // Не должна быть служебной
      if (_isServiceLine(trimmed)) continue;

      // Не должна быть итоговой строкой
      if (_isTotalLine(trimmed)) {
        break;
      }

      productLines.add(trimmed);
    }

    return productLines;
  }

  /// Проверяет, является ли строка служебной
  bool _isServiceLine(String line) {
    final String lower = line.toLowerCase().trim();

    final List<String> servicePatterns = [
      'акция', 'скидка', 'цена', 'к оплате', 'наличными',
      'безналичными', 'бонус', 'баллы', 'выручка', 'карта',
      'списание', 'начисление', 'баланс', 'дисконт',
      'промо', 'спецпредложение', 'социальная', 'пенсионер',
      'кол-во', 'количество', 'стоимость', 'ндс',
      'энергетическая', 'ценность', 'ккал', 'кдж',
      'белки', 'жиры', 'углеводы', 'пищевая',
      'производитель', 'изготовитель', 'состав',
      'срок годности', 'годен до', 'изготовлен',
      'страна', 'происхождение', 'сертификат',
      'гост', 'ту', 'декларация', 'фасовка',
      'visa', 'mastercard', 'мир', 'сбербанк',
      'эквайринг', 'терминал', 'оператор',
      'курьер', 'доставка', 'заказ', 'клиент',
    ];

    for (final String pattern in servicePatterns) {
      if (lower.contains(pattern)) return true;
    }

    // Номера телефонов
    if (RegExp(r'[\d]{3,4}[\s-]?[\d]{2,3}[\s-]?[\d]{2,3}').hasMatch(line)) return true;

    // Email и URL
    if (line.contains('@') || line.contains('www.') || line.contains('.ru')) return true;

    return false;
  }

  /// Проверяет, является ли строка итоговой
  bool _isTotalLine(String line) {
    final String lower = line.toLowerCase().trim();
    return RegExp(
      r'(итого?|всего|сумма|сдача|к оплате)\s*[=:]?\s*\d+[.,]\d{2}',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  /// Очищает название товара от веса, цены, количества
  String _cleanProductName(String line) {
    String cleaned = line;

    // Удаляем номер позиции в начале
    cleaned = cleaned.replaceFirst(RegExp(r'^\d{1,3}[.)]\s*'), '');

    // Удаляем цену в конце (число с двумя знаками после запятой)
    cleaned = cleaned.replaceFirst(RegExp(r'\s*\d+[.,]\d{2}\s*$'), '');

    // Удаляем количество x цена в конце
    cleaned = cleaned.replaceFirst(RegExp(r'\s*\d+\s*[xх]\s*\d+[.,]\d{2}\s*$'), '');

    // Удаляем вес/объём в конце
    cleaned = cleaned.replaceFirst(
      RegExp(r'\s+\d+[.,]?\d*\s*(г|мл|л|кг|шт|гр|мг)\s*$', caseSensitive: false),
      '',
    );

    // Удаляем проценты в конце
    cleaned = cleaned.replaceFirst(RegExp(r'\s+\d+[.,]?\d*\s*%\s*$'), '');

    // Удаляем количество штук в конце
    cleaned = cleaned.replaceFirst(
      RegExp(r'\s+\d+\s*(шт|штук)\s*$', caseSensitive: false),
      '',
    );

    // Удаляем оставшиеся числа в конце строки
    cleaned = cleaned.replaceFirst(RegExp(r'\s+\d+[.,]?\d*\s*$'), '');

    return cleaned.trim();
  }

  /// Применяет _cleanProductName ко всем строкам
  List<String> _cleanProductNames(List<String> lines) {
    return lines.map((line) => _cleanProductName(line)).toList();
  }

  /// Нормализует OCR-шум (замена похожих символов)
  List<String> _normalizeOcrNoise(List<String> lines) {
    return lines.map((line) {
      String normalized = line;

      // Заменяем латинские буквы на русские (частые ошибки OCR)
      const Map<String, String> replacements = {
        'a': 'а', 'A': 'А',
        'e': 'е', 'E': 'Е',
        'o': 'о', 'O': 'О',
        'p': 'р', 'P': 'Р',
        'c': 'с', 'C': 'С',
        'y': 'у', 'Y': 'У',
        'k': 'к', 'K': 'К',
        'x': 'х', 'X': 'Х',
        'b': 'в', 'B': 'В',
        'm': 'м', 'M': 'М',
        'n': 'н', 'N': 'Н',
        't': 'т', 'T': 'Т',
      };

      // Заменяем только в словах, где есть и другие русские буквы
      if (RegExp(r'[а-яё]').hasMatch(normalized.toLowerCase())) {
        for (final entry in replacements.entries) {
          normalized = normalized.replaceAll(entry.key, entry.value);
        }
      }

      // Удаляем множественные пробелы
      normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

      return normalized.trim();
    }).toList();
  }

  /// Убирает дубликаты и пустые строки
  List<String> _removeDuplicatesAndEmpty(List<String> lines) {
    final List<String> result = [];
    final Set<String> seen = {};

    for (final String line in lines) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.length < 3) continue;

      // Проверяем на дубликат (игнорируя регистр)
      final String lower = trimmed.toLowerCase();
      if (seen.contains(lower)) continue;

      seen.add(lower);
      result.add(trimmed);
    }

    return result;
  }
}