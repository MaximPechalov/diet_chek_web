import '../../data/datasources/local_database.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/models/receipt.dart';
import '../../data/models/scanned_item.dart';
import '../../data/models/product.dart';
import '../../data/models/diet_rule.dart';

class ScanReceiptUseCase {
  final ProductRepository _productRepository;

  ScanReceiptUseCase(this._productRepository);

  Receipt execute(List<String> rawLines, List<String> activeDiets) {
    final List<String> mergedLines = _mergeBrokenLines(rawLines);
    final List<ScannedItem> items = [];

    for (final String line in mergedLines) {
      if (_isNotProductLine(line)) {
        continue;
      }

      final String normalized = _normalizeLine(line);

      Product? matchedProduct = _productRepository.findByKey(normalized);
      if (matchedProduct == null) {
        matchedProduct = _productRepository.findByNormalizedText(normalized);
      }
      if (matchedProduct == null) {
        matchedProduct = _fuzzyFindProduct(normalized);
      }

      print('Итог: $normalized → ${matchedProduct?.key ?? "НЕ НАЙДЕНО"}');

      Map<String, DietRule>? dietResults;
      if (matchedProduct != null) {
        dietResults = {};
        for (final String dietKey in activeDiets) {
          final DietRule? rule = matchedProduct.getRule(dietKey);
          if (rule != null) {
            dietResults[dietKey] = rule;
          }
        }
      }

      items.add(ScannedItem(
        rawText: line,
        normalizedText: normalized,
        matchedProduct: matchedProduct,
        dietResults: dietResults,
      ));
    }

    return Receipt(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      scannedAt: DateTime.now(),
      items: items,
    );
  }

  List<String> _mergeBrokenLines(List<String> lines) {
    final List<String> result = [];
    String? previousLine;

    for (final String line in lines) {
      final String trimmed = line.trim();

      if (_isQuantityLine(trimmed) && previousLine != null) {
        result.removeLast();
        result.add('$previousLine $trimmed');
        previousLine = null;
      } else {
        result.add(trimmed);
        previousLine = trimmed;
      }
    }

    return result;
  }

  bool _isQuantityLine(String line) {
    return RegExp(r'^\d+[,.]?\d*\s*%?\s*(г|мл|л|кг|шт)?$').hasMatch(line.trim());
  }

  bool _isNotProductLine(String line) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty) return true;
    if (RegExp(r'^\d+[,.]?\d*$').hasMatch(trimmed)) return true;
    if (RegExp(r'^\d{12,13}$').hasMatch(trimmed)) return true;
    if (RegExp(r'^(ВЕС|ИТОГО?|СУММА|СДАЧА|КАССА|СМЕНА|ЧЕК|НДС|ВСЕГО)', caseSensitive: false).hasMatch(trimmed)) return true;
    if (RegExp(r'\d{3,}[,.]\d{2}').hasMatch(trimmed)) return true;
    return false;
  }

  String _normalizeLine(String rawLine) {
    String normalized = rawLine;

    // 0. Удаляем известные бренды
    const List<String> knownBrands = [
      'ПРОСТОКВАШИНО', 'ДОМИК В ДЕРЕВНЕ', 'ВКУСНОТЕЕВО', 'МИРАТОРГ',
      'ЧЕРКИЗОВО', 'САВУШКИН', 'ДОБРЫЙ', 'J7', 'РИОБА', 'ЧУДО',
      'АКТИВИА', 'DANONE', 'ЭРМИГУРТ', 'ФРУТОНЯНЯ', 'АГУША',
      'ПЕТМОЛ', 'ВАЛИО', 'VALIO', 'PRESIDENT', 'БРЕСТ-ЛИТОВСК',
      'СЛОБОДА', 'ОЛЕЙНА', 'МАКФА', 'ЩЕБЕКИНСКИЕ', 'BONDUELLE',
      'БОНДЮЭЛЬ', 'GLOBAL VILLAGE', 'ЯСНО СОЛНЫШКО', 'КУРИНОЕ ЦАРСТВО',
      'ПЕТЕЛИНКА', 'ИНДИЛАЙТ', 'РУБЛЕВСКИЙ', 'ОСТАНКИНО',
    ];
    for (final String brand in knownBrands) {
      normalized = normalized.replaceAll(brand, '');
    }

    // 1. Удаляем оставшиеся слова заглавными буквами
    normalized = normalized.replaceAll(RegExp(r'\b[А-ЯЁ]{2,}\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\b[A-Z]{2,}\b'), '');

    // 2. Удаляем коды яиц
    normalized = normalized.replaceAll('С0', '');
    normalized = normalized.replaceAll('С1', '');
    normalized = normalized.replaceAll('С2', '');
    normalized = normalized.replaceAll('C0', '');
    normalized = normalized.replaceAll('C1', '');
    normalized = normalized.replaceAll('C2', '');

    // 3. ТМ, ТЗ, АО и т.д.
    normalized = normalized.replaceAll(RegExp(r'\b(ТМ|ТЗ|АО|ООО|ОАО|ЗАО|ИП)\b'), '');

    // 4. Кавычки, звездочки, решетки
    normalized = normalized.replaceAll(RegExp(r'["«»\*#]'), '');

    // 5. Расшифровка сокращений
    normalized = _expandAbbreviations(normalized);

    // 6. Исправление опечаток
    normalized = _fixTypos(normalized);

    // 7. Тип упаковки
    normalized = normalized.replaceAll(
      RegExp(r'\b(П/ПАК|П/П|ПЭТ|СТЕКЛО|ТЕТРАПАК|Ф/П|ПЮРПАК|ПЛАСТ|СТ/Б|Ж/Б)\b', caseSensitive: false), '');

    // 8. Весовые пометки
    normalized = normalized.replaceAll(
      RegExp(r'\b(ВЕС|ВЕСОВОЙ|РАЗВЕС|ФАС|ФАСОВАННЫЙ)\b', caseSensitive: false), '');

    // 9. Извлекаем числа из процентов ДО удаления единиц измерения
    normalized = normalized.replaceAllMapped(RegExp(r'(\d+[,.]?\d*)\s*%'), (match) {
      String num = match.group(1)!.replaceAll(',', '.');
      return num;
    });

    // 10. Удаляем числа с единицами измерения (10ШТ, 180Г, 1Л, 200МЛ, 1КГ)
    normalized = normalized.replaceAll(RegExp(r'\d+\.?\d*\s*[а-яА-Яa-zA-Z]+'), '');

    // 11. Замена запятой на точку
    normalized = normalized.replaceAll(RegExp(r'(\d+),(\d+)'), r'$1.$2');

    // 12. Дробные символы
    final Map<String, String> fractions = {
      '½': '0.5', '⅓': '0.33', '⅔': '0.66', '¼': '0.25', '¾': '0.75',
      '⅕': '0.2', '⅖': '0.4', '⅗': '0.6', '⅘': '0.8', '⅙': '0.16',
    };
    for (final entry in fractions.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }

    // 13. Нижний регистр
    normalized = normalized.toLowerCase();

    // 14. Обрезка по запятой
    if (normalized.contains(',')) {
      normalized = normalized.split(',').first;
    }

    // 15. Лишние пробелы
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    return normalized;
  }

  String _expandAbbreviations(String text) {
    final Map<String, String> abbreviations = {
      'МОЛ': 'МОЛОКО', 'МОЛОК': 'МОЛОКО', 'СМЕТ': 'СМЕТАНА',
      'ТВОР': 'ТВОРОГ', 'СЛИВ': 'СЛИВКИ', 'ЙОГ': 'ЙОГУРТ',
      'КЕФ': 'КЕФИР', 'РЯЖ': 'РЯЖЕНКА', 'ПРОСТОКВ': 'ПРОСТОКВАША',
      'ГОВ': 'ГОВЯДИНА', 'СВ': 'СВИНИНА', 'КУР': 'КУРИЦА',
      'ФАРШ': 'ФАРШ', 'ФИЛЕ': 'ФИЛЕ', 'ВЫР': 'ВЫРЕЗКА', 'ЛОП': 'ЛОПАТКА',
      'СЕЛ': 'СЕЛЬДЬ', 'СКУМБ': 'СКУМБРИЯ', 'ЛОС': 'ЛОСОСЬ', 'ФОР': 'ФОРЕЛЬ',
      'ОГУР': 'ОГУРЕЦ', 'ПОМ': 'ПОМИДОР', 'КАРТ': 'КАРТОФЕЛЬ',
      'МОРК': 'МОРКОВЬ', 'КАП': 'КАПУСТА',
      'ЯБЛ': 'ЯБЛОКО', 'БАН': 'БАНАН', 'АПЕЛ': 'АПЕЛЬСИН', 'МАНД': 'МАНДАРИН',
      'МУК': 'МУКА', 'САХ': 'САХАР', 'МАСЛ': 'МАСЛО',
      'РАСТ': 'РАСТИТЕЛЬНЫЙ', 'ПОДС': 'ПОДСОЛНЕЧНЫЙ', 'СЛ': 'СЛИВОЧНЫЙ',
      'ХЛ': 'ХЛЕБ', 'БАТ': 'БАТОН',
      'Б/Г': 'БЕЗ ГЛЮТЕНА', 'Б/С': 'БЕЗ САХАРА', 'Б/Л': 'БЕЗ ЛАКТОЗЫ',
      'Н/Ж': 'НЕЖИРНЫЙ', 'ОБЕЗЖ': 'ОБЕЗЖИРЕННЫЙ', 'ЦЕЛЬН': 'ЦЕЛЬНЫЙ',
      'ОТБ': 'ОТБОРНЫЙ', 'В/С': 'ВЫСШИЙ СОРТ', '1С': 'ПЕРВЫЙ СОРТ',
      'ПАСТ': 'ПАСТЕРИЗОВАННЫЙ', 'СТЕР': 'СТЕРИЛИЗОВАННЫЙ',
      'УЛЬТРАПАСТ': 'УЛЬТРАПАСТЕРИЗОВАННЫЙ', 'Д/П': 'ДЕТСКОЕ ПИТАНИЕ',
    };

    String result = text;
    for (final entry in abbreviations.entries) {
      result = result.replaceAll(
        RegExp(r'\b' + entry.key + r'\b', caseSensitive: false), entry.value);
    }
    return result;
  }

  String _fixTypos(String text) {
    final Map<String, String> typos = {
      'ТВАРОГ': 'ТВОРОГ', 'ТВОРОХ': 'ТВОРОГ', 'ТВОРАГ': 'ТВОРОГ',
      'МАЛАКО': 'МОЛОКО', 'МАЛОКО': 'МОЛОКО', 'МОЛАКО': 'МОЛОКО',
      'СМИТАНА': 'СМЕТАНА', 'СМЕТАННА': 'СМЕТАНА', 'СМЯТАНА': 'СМЕТАНА',
      'КЕФИРР': 'КЕФИР', 'КИФИР': 'КЕФИР', 'ЙОГРТ': 'ЙОГУРТ',
      'СЛИФКИ': 'СЛИВКИ', 'СЛИУКИ': 'СЛИВКИ',
      'МАСЛА': 'МАСЛО', 'САХОР': 'САХАР', 'САХАРР': 'САХАР',
      'КАРТОШКА': 'КАРТОФЕЛЬ', 'КАРТОХА': 'КАРТОФЕЛЬ',
      'МАРКОВЬ': 'МОРКОВЬ', 'МАРКОВКА': 'МОРКОВЬ',
      'ПАМИДОР': 'ПОМИДОР', 'ПОМИДОРЫ': 'ПОМИДОР',
      'АГУРЕЦ': 'ОГУРЕЦ', 'ЯЙЦЫ': 'ЯЙЦО', 'ЯЙЦА': 'ЯЙЦО',
      'ХЛЕП': 'ХЛЕБ', 'ХЛЕББ': 'ХЛЕБ', 'БАТТОН': 'БАТОН',
      'ШОКАЛАД': 'ШОКОЛАД', 'ШОКОЛАДД': 'ШОКОЛАД',
    };

    String result = text;
    for (final entry in typos.entries) {
      result = result.replaceAll(
        RegExp(r'\b' + entry.key + r'\b', caseSensitive: false), entry.value);
    }
    return result;
  }

  Product? _fuzzyFindProduct(String normalizedText) {
    Product? bestMatch;
    int bestDistance = 999;
    final String searchText = normalizedText.toLowerCase().trim();

    for (final String key in LocalDatabase.products.keys) {
      final int distance = _levenshteinDistance(searchText, key);

      if (distance == 0) {
        return _productRepository.findByKey(key);
      }

      final int maxDistance = searchText.length <= 5 ? 1 : 2;

      if (distance < bestDistance && distance <= maxDistance) {
        bestDistance = distance;
        bestMatch = _productRepository.findByKey(key);
      }
    }

    return bestMatch;
  }

  int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    final List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < t.length; j++) {
        final int cost = s[i] == t[j] ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost]
            .reduce((a, b) => a < b ? a : b);
      }

      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[t.length];
  }
}